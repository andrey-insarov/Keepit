import AppKit

extension NSView {
    /// Add Auto Layout constraints gluing `child` to all four edges.
    func pinToEdges(_ child: NSView, inset: CGFloat = 0) {
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            child.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            child.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            child.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }
}

/// Right-hand pane of the Viewer: one view per clipboard format
/// (text, image, file list, hex dump).

// MARK: - Text / RTF / HTML

final class TextFormatView: NSView, NSTextViewDelegate {
    private let scroll: NSScrollView
    let textView: NSTextView
    private var format = ClipItem.Format.text
    private var dirty = false
    /// Called when editing ends with the new bytes for `format`.
    var onCommit: ((String, Data) -> Void)?

    override init(frame: NSRect) {
        // The factory wires up a text view that fills the whole scroll area (clicking anywhere focuses it).
        scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView
        super.init(frame: frame)
        scroll.focusRingType = .none
        textView.focusRingType = .none
        textView.isRichText = false
        textView.allowsUndo = true
        textView.delegate = self
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        addSubview(scroll)
        pinToEdges(scroll)
    }
    required init?(coder: NSCoder) { fatalError() }

    func load(format: String, data: Data, editable: Bool) {
        commit()
        self.format = format
        dirty = false
        textView.isEditable = editable
        textView.textColor = .textColor
        switch format {
        case ClipItem.Format.rtf:
            textView.isRichText = true
            let attr = NSAttributedString(rtf: data, documentAttributes: nil) ?? NSAttributedString(string: L("(unreadable RTF)"))
            textView.textStorage?.setAttributedString(attr)
        default:
            textView.isRichText = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.string = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        }
        textView.undoManager?.removeAllActions()
        textView.scroll(.zero)
    }

    func textDidChange(_ notification: Notification) { dirty = true }

    func textDidEndEditing(_ notification: Notification) { commit() }

    /// Apply pending edits (applied when focus leaves the editor).
    func commit() {
        guard dirty, textView.isEditable else { return }
        dirty = false
        let data: Data
        if format == ClipItem.Format.rtf {
            let s = textView.attributedString()
            data = (try? s.data(from: NSRange(location: 0, length: s.length),
                                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])) ?? Data()
        } else {
            data = Data(textView.string.utf8)
        }
        onCommit?(format, data)
    }
}

// MARK: - Image

/// The image scaled down to fit the pane (never up), centred; the pixel size and byte count above it.
/// No scroll view: the picture is a preview, and a document view sized in points showed a 2x-blown-up
/// corner of the image instead of the image.
final class ImageFormatView: NSView {
    private let imageView = NSImageView()
    private let info = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.imageFrameStyle = .none
        imageView.translatesAutoresizingMaskIntoConstraints = false
        // The image's own size must not drive the layout: the pane decides, the picture fits into it.
        // Priority 1, not the default 250: the stack view around the pane aligns its width at a priority
        // the picture's 250 could beat, which parked the pane at the right edge, as wide as the picture.
        for axis in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            imageView.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: axis)
            imageView.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: axis)
        }
        info.translatesAutoresizingMaskIntoConstraints = false
        info.textColor = .secondaryLabelColor
        info.lineBreakMode = .byTruncatingTail
        info.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        info.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        addSubview(info)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            info.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            info.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func load(data: Data) {
        guard let img = NSImage(data: data) else {
            imageView.image = nil
            info.stringValue = L("(unreadable image)")
            return
        }
        var px = ""
        if let rep = img.representations.first { px = "\(rep.pixelsWide)×\(rep.pixelsHigh) px, " }
        info.stringValue = px + ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        imageView.image = img
    }
}

// MARK: - File list

final class FilesFormatView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let scroll = NSScrollView()
    private let table = NSTableView()
    private var paths: [String] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        col.title = L("Path")
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.focusRingType = .none
        scroll.focusRingType = .none
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.doubleAction = #selector(openSelected)
        table.target = self
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        addSubview(scroll)
        pinToEdges(scroll)
    }
    required init?(coder: NSCoder) { fatalError() }

    func load(paths: [String]) {
        self.paths = paths
        table.reloadData()
    }

    var selectedPath: String? {
        let r = table.selectedRow
        return r >= 0 && r < paths.count ? paths[r] : nil
    }

    @objc func openSelected() {
        guard let p = selectedPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: p))
    }

    func numberOfRows(in tableView: NSTableView) -> Int { paths.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let p = paths[row]
        let exists = FileManager.default.fileExists(atPath: p)
        return exists ? p : p + "  " + L("(missing)")
    }
}

// MARK: - Binary (hex dump)

final class HexFormatView: NSView {
    private let scroll: NSScrollView
    private let textView: NSTextView
    private static let limit = 256 * 1024

    override init(frame: NSRect) {
        scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView
        super.init(frame: frame)
        scroll.focusRingType = .none
        textView.focusRingType = .none
        textView.isEditable = false
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        addSubview(scroll)
        pinToEdges(scroll)
    }
    required init?(coder: NSCoder) { fatalError() }

    func load(data: Data) {
        let shown = data.prefix(Self.limit)
        var out = ""
        out.reserveCapacity(shown.count * 4)
        var offset = 0
        let bytes = [UInt8](shown)
        while offset < bytes.count {
            let line = bytes[offset..<min(offset + 16, bytes.count)]
            out += String(format: "%08X  ", offset)
            var hex = ""
            var ascii = ""
            for (i, b) in line.enumerated() {
                hex += String(format: "%02X ", b)
                if i == 7 { hex += " " }
                ascii.append(b >= 0x20 && b < 0x7F ? Character(UnicodeScalar(b)) : ".")
            }
            out += hex.padding(toLength: 49, withPad: " ", startingAt: 0)
            out += " |" + ascii + "|\n"
            offset += 16
        }
        if data.count > Self.limit {
            out += "\n… \(data.count - Self.limit) more bytes not shown\n"
        }
        textView.string = out
        textView.scroll(.zero)
    }
}

// MARK: - Plain info

final class InfoView: NSView {
    private let label = NSTextField(wrappingLabelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func load(_ text: String) { label.stringValue = text }
}
