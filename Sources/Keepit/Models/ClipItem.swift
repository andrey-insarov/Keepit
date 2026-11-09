import AppKit
import CryptoKit

/// One clipboard snapshot: a set of pasteboard formats, organised as a tree
/// (one history item → several format children: TEXT, BITMAP, …).
struct ClipItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case text, image, files }

    /// Formats we keep. Everything else on the pasteboard is dropped
    /// (a fixed list for now; a configurable format filter is on the roadmap).
    enum Format {
        static let text  = NSPasteboard.PasteboardType.string.rawValue      // public.utf8-plain-text
        static let rtf   = NSPasteboard.PasteboardType.rtf.rawValue         // public.rtf
        static let html  = NSPasteboard.PasteboardType.html.rawValue        // public.html
        static let png   = NSPasteboard.PasteboardType.png.rawValue         // public.png
        static let files = "com.it.keep.file-list"       // our own: JSON [String] of paths
    }

    let id: UUID
    let date: Date
    var formats: [String: Data]
    var sourceApp: String?
    /// Stable hash of the primary content, used for duplicate detection.
    var contentHash: String

    static func == (a: ClipItem, b: ClipItem) -> Bool { a.id == b.id && a.contentHash == b.contentHash }

    init(id: UUID, date: Date, formats: [String: Data], sourceApp: String?, contentHash: String) {
        self.id = id
        self.date = date
        self.formats = formats
        self.sourceApp = sourceApp
        self.contentHash = contentHash
    }


    /// Display order / priority of formats (primary format is shown in menus and the Viewer).
    static let formatOrder = [Format.files, Format.png, Format.text, Format.rtf, Format.html]

    static func displayName(for format: String) -> String {
        switch format {
        case Format.text:  return "TEXT"
        case Format.rtf:   return "RTF"
        case Format.html:  return "HTML"
        case Format.png:   return "PNG"
        case Format.files: return "FILE LIST"
        default:           return format
        }
    }

    /// Formats present, in priority order.
    var orderedFormats: [String] {
        let known = Self.formatOrder.filter { formats[$0] != nil }
        let other = formats.keys.filter { !Self.formatOrder.contains($0) }.sorted()
        return known + other
    }

    var primaryFormat: String? { orderedFormats.first }

    var byteSize: Int { formats.values.reduce(0) { $0 + $1.count } }
    /// An upper bound on what this item occupies in history.json as `Storage.encoder` writes it —
    /// never below the real size, by construction rather than by allowance (PR #48 round 4: the
    /// previous allowance was under by half for binary full of 0xFF and for a long `sourceApp`):
    /// - every format as Base64, exactly ⌈n/3⌉·4 bytes — exact because `Storage.encoder` does not
    ///   escape `/` (`.withoutEscapingSlashes`; `LimitsTests` pin that);
    /// - every string (`sourceApp`, `contentHash`, format keys) at the worst JSON escaping, 6 output
    ///   bytes per UTF-8 byte (`\u00XX`), plus quotes;
    /// - the fixed fields and punctuation at their maxima (`id` 38, ISO-8601 `date` ≤ 32, keys,
    ///   braces, colons, commas, `null`).
    /// Over by a few hundred bytes per item for ordinary text; that is the price of a bound.
    var serializedEstimate: Int {
        func quoted(_ s: String) -> Int { s.utf8.count * 6 + 2 }
        let fixed = 2 + 14 + 1 + 1 + 6 + 1 + 1 + 9 + 1 + 1 + 4 + 1 + 1 + 11 + 1 + 1   // {} and the five keys with quotes, colons, commas
        let idAndDate = 38 + 32
        let hash = quoted(contentHash)
        let app = sourceApp.map(quoted) ?? 4                                               // null
        let payloads = formats.reduce(0) { $0 + quoted($1.key) + 1 + ($1.value.count + 2) / 3 * 4 + 2 + 1 }   // "key":"base64",
        return fixed + idAndDate + hash + app + payloads
    }

    static func hash(of d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    private mutating func rehash() {
        if let d = formats[Format.files] ?? formats[Format.text] ?? formats[Format.png] ?? formats.values.first {
            contentHash = Self.hash(of: d)
        }
    }

    /// Replace the plain text. Derived rich formats (RTF/HTML) are dropped because they'd be stale.
    mutating func setText(_ s: String) {
        formats[Format.text] = Data(s.utf8)
        formats[Format.rtf] = nil
        formats[Format.html] = nil
        rehash()
    }

    /// Replace one format's raw bytes (Viewer edits RTF/HTML in place).
    mutating func setData(_ d: Data, for format: String) {
        formats[format] = d
        rehash()
    }

    mutating func removeFormat(_ format: String) {
        formats[format] = nil
        rehash()
    }

    mutating func setFilePaths(_ paths: [String]) {
        if let d = try? JSONEncoder().encode(paths) {
            formats[Format.files] = d
            rehash()
        }
    }

    // MARK: - Derived

    var kind: Kind {
        if formats[Format.files] != nil { return .files }
        if formats[Format.png] != nil {
            // Browsers often add a URL/alt text next to a copied picture; the picture is the point.
            let t = plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if t.isEmpty || t.count < 200 { return .image }
        }
        return .text
    }

    var plainText: String? {
        guard let d = formats[Format.text] else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// The item as the validator accepts it, or nil. An item whose only fault is a rich format (RTF,
    /// HTML) that is not what it claims comes back without that format; one whose primary content
    /// fails — or whose hash does not match it — is nil. Used when the stores' own files are loaded.
    func validated() -> ClipItem? {
        let stripped = droppingInvalidRichFormats()
        return (try? Backup.validate(item: stripped)) != nil ? stripped : nil
    }

    /// The item without a secondary rich format (RTF, HTML) whose *content* fails its check — only
    /// that format; a valid RTF next to a bad HTML stays. Secondary means beside a text, image or
    /// file-list primary: an item of rich formats alone has its hash over one of them, and nothing
    /// is dropped from it. A format past its size ceiling is not a content fault and stays, so the
    /// validator refuses the item as before. The primary and the hash are never touched: this never
    /// changes what an item *is*, only what it carries alongside.
    func droppingInvalidRichFormats() -> ClipItem {
        guard formats[Format.files] != nil || formats[Format.text] != nil || formats[Format.png] != nil else { return self }
        var out = self
        for uti in [Format.rtf, Format.html] {
            guard let d = formats[uti], (try? Backup.validateSize(format: uti, data: d)) != nil,
                  (try? Backup.validateContent(format: uti, data: d)) == nil else { continue }
            out.formats[uti] = nil
        }
        return out
    }

    /// Same item reduced to its plain-text format only (same id, so history bookkeeping still matches).
    func plainTextOnly() -> ClipItem? {
        guard let d = formats[Format.text] else { return nil }
        return ClipItem(id: id, date: date, formats: [Format.text: d], sourceApp: sourceApp, contentHash: contentHash)
    }

    var filePaths: [String] {
        guard let d = formats[Format.files],
              let arr = try? JSONDecoder().decode([String].self, from: d) else { return [] }
        return arr
    }

    var image: NSImage? {
        guard let d = formats[Format.png] else { return nil }
        return NSImage(data: d)
    }

    /// Menu title: first meaningful line, whitespace collapsed, truncated.
    /// True when the menu line already shows everything: single-line text that fits in `maxLength`.
    /// The preview panel is skipped for such items (it would only repeat the line).
    func fitsInTitle(maxLength: Int) -> Bool {
        guard kind == .text, let t = plainText else { return false }
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.contains(where: { $0.isNewline }) && trimmed.count <= maxLength
    }

    func title(maxLength: Int) -> String {
        let raw: String
        switch kind {
        case .files:
            let names = filePaths.map { ($0 as NSString).lastPathComponent }
            raw = names.isEmpty ? L("(Files)") : names.joined(separator: ", ")
        case .image:
            if let img = image, let rep = img.representations.first {
                raw = LF("(Image %d×%d)", rep.pixelsWide, rep.pixelsHigh)
            } else {
                raw = L("(Image)")
            }
        case .text:
            let t = plainText ?? ""
            let firstLine = t
                .split(omittingEmptySubsequences: true, whereSeparator: { $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? ""
            let collapsed = firstLine.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            raw = collapsed.isEmpty ? L("(Empty text)") : collapsed
            // More lines after the first one: say so, so a one-liner and a wall of text look different.
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.count <= maxLength, trimmed.contains(where: { $0.isNewline }) { return raw + " …" }
        }
        if raw.count > maxLength {
            return String(raw.prefix(max(1, maxLength - 1))) + "…"
        }
        return raw
    }

    /// Tooltip text: the beginning of the content.
    var tooltip: String? {
        switch kind {
        case .text:
            guard let t = plainText else { return nil }
            return t.count > 600 ? String(t.prefix(600)) + "…" : t
        case .files:
            return filePaths.joined(separator: "\n")
        case .image:
            return nil
        }
    }

    /// Menu thumbnail: fits a box `maxHeight` tall and up to 4× that wide, so wide screenshots
    /// stay recognisable instead of collapsing into a sliver.
    func thumbnail(maxSide: CGFloat) -> NSImage? {
        guard let img = image else { return nil }
        let s = img.size
        guard s.width > 0, s.height > 0 else { return nil }
        let maxHeight = maxSide
        let maxWidth = maxSide * 4
        let scale = min(maxWidth / s.width, maxHeight / s.height, 1)
        let newSize = NSSize(width: max(1, floor(s.width * scale)), height: max(1, floor(s.height * scale)))
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        img.draw(in: NSRect(origin: .zero, size: newSize),
                 from: NSRect(origin: .zero, size: s),
                 operation: .copy, fraction: 1)
        thumb.unlockFocus()
        return thumb
    }

    // MARK: - Pasteboard I/O

    /// Snapshot the pasteboard. Returns nil if nothing we understand is there.
    static func capture(from pb: NSPasteboard, settings: Settings, sourceApp: String?) -> ClipItem? {
        var formats: [String: Data] = [:]

        // Files first: Finder puts file URLs plus a text rendering; we treat it as a file item.
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            guard urls.count <= settings.maxFileListEntries else { return nil }
            let paths = urls.map { $0.path }
            if let d = try? JSONEncoder().encode(paths) {
                formats[Format.files] = d
            }
        }

        if formats[Format.files] == nil {
            if let s = pb.string(forType: .string), !s.isEmpty {
                let text = Data(s.utf8)
                guard text.count <= settings.maxTextBytes else { return nil }
                formats[Format.text] = text
                // A rich format that is not what it claims (Backup.validate(format:)) is left out; the text stays.
                if let rtf = pb.data(forType: .rtf), rtf.count <= settings.maxTextBytes * 4,
                   (try? Backup.validate(format: Format.rtf, data: rtf)) != nil { formats[Format.rtf] = rtf }
                if let html = pb.data(forType: .html), html.count <= settings.maxTextBytes * 4,
                   (try? Backup.validate(format: Format.html, data: html)) != nil { formats[Format.html] = html }
            }

            if let png = Self.pngData(from: pb, maxBytes: settings.maxImageBytes), png.count <= settings.maxImageBytes {
                formats[Format.png] = png
            }
        }

        guard !formats.isEmpty else { return nil }

        let hash: String
        if let d = formats[Format.files] ?? formats[Format.text] ?? formats[Format.png] {
            hash = SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        } else {
            hash = UUID().uuidString
        }

        return ClipItem(id: UUID(), date: Date(), formats: formats, sourceApp: sourceApp, contentHash: hash)
    }

    /// PNG from the pasteboard. Everything is checked *before* decoding: byte size against the cap
    /// (TIFF is allowed a few times more, it is uncompressed) and the pixel count from the image
    /// header alone, so a decompression bomb is refused without ever being inflated.
    private static func pngData(from pb: NSPasteboard, maxBytes: Int) -> Data? {
        if let png = pb.data(forType: .png) {
            guard png.count <= maxBytes, pixelCountOK(png) else { return nil }
            return png
        }
        if let tiff = pb.data(forType: .tiff) {
            guard tiff.count <= maxBytes * 6, pixelCountOK(tiff),
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return nil }
            return png
        }
        return nil
    }

    /// The 8-byte PNG signature — a file is PNG by its bytes, not by its extension or a pasteboard type.
    static func isPNG(_ data: Data) -> Bool {
        data.count >= 8 && Array(data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    }

    /// Width × height from the header, without decoding the pixels. Unreadable headers fail closed.
    static func pixelCountOK(_ data: Data, maxPixels: Int = Limits.imageMaxPixels) -> Bool {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, [kCGImageSourceShouldCache: false] as CFDictionary) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { return false }
        return w.multipliedReportingOverflow(by: h).overflow == false && w * h <= maxPixels
    }

    /// Put this item back onto the pasteboard with all its formats.
    func write(to pb: NSPasteboard) {
        pb.clearContents()
        if kind == .files {
            let urls = filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
            return
        }
        var types: [NSPasteboard.PasteboardType] = []
        for key in formats.keys { types.append(NSPasteboard.PasteboardType(key)) }
        pb.declareTypes(types, owner: nil)
        for (key, data) in formats {
            pb.setData(data, forType: NSPasteboard.PasteboardType(key))
        }
    }

    /// A text-only item (used for templates and for "paste as plain text").
    static func text(_ s: String) -> ClipItem {
        let d = Data(s.utf8)
        let hash = SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        return ClipItem(id: UUID(), date: Date(), formats: [Format.text: d], sourceApp: nil, contentHash: hash)
    }
}
