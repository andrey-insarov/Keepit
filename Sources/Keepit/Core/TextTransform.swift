import Foundation

/// Text transformations applied on paste ("Paste as ▸" in the history menu).
enum TextTransform: String, CaseIterable, Codable {
    case upper, lower, title, sentence, trim, singleLine, stripFormatting
    /// Decorations as Unicode combining marks after every character: plain text that keeps its
    /// look wherever it is pasted, a chat or a plain field included. `undecorate` removes them.
    case strikethrough, underline, wavy, undecorate

    var title: String {
        switch self {
        case .upper:           return L("UPPERCASE")
        case .lower:           return L("lowercase")
        case .title:           return L("Title Case")
        case .sentence:        return L("Sentence case")
        case .trim:            return L("Trim whitespace")
        case .singleLine:      return L("Single line")
        case .stripFormatting: return L("Plain text (no formatting)")
        case .strikethrough:   return L("Strikethrough")
        case .underline:       return L("Underline")
        case .wavy:            return L("Wavy underline")
        case .undecorate:      return L("Remove decorations")
        }
    }

    /// The combining marks the decorations use (and `undecorate` removes): U+0336 COMBINING LONG
    /// STROKE OVERLAY, U+0332 COMBINING LOW LINE, U+0330 COMBINING TILDE BELOW — plus the short
    /// stroke U+0335 and U+0333 (double low line), which other tools produce for the same look.
    static let decorationMarks: Set<Unicode.Scalar> = ["\u{0336}", "\u{0332}", "\u{0330}", "\u{0335}", "\u{0333}"]

    private var mark: Unicode.Scalar? {
        switch self {
        case .strikethrough: return "\u{0336}"
        case .underline:     return "\u{0332}"
        case .wavy:          return "\u{0330}"
        default:             return nil
        }
    }

    /// One mark after every *grapheme* (a letter with its accents, an emoji with its modifiers, ZWJ
    /// and variation selectors, a flag's two regional indicators — the cluster stays what it was,
    /// the mark comes after it; auditor's P2 on PR #26); spaces too, so the line is continuous;
    /// a grapheme of control or format characters alone — line breaks, tabs, NEL, bidi controls —
    /// gets none. Marks of the family already there are removed first, so decorating twice, or
    /// switching from one decoration to another, does not stack them. `maxBytes`: the output is
    /// counted as it is built and nil comes back as soon as it would pass the ceiling — a 50 MiB
    /// item is refused after a few bytes, not after 150 MiB (his P3).
    private static func decorate(_ s: String, with mark: Unicode.Scalar, maxBytes: Int) -> String? {
        let base = undecorate(s)
        guard base.utf8.count <= maxBytes else { return nil }
        var out = String.UnicodeScalarView()
        var bytes = 0
        let markBytes = String(mark).utf8.count
        for character in base {
            for scalar in character.unicodeScalars { out.append(scalar) }
            bytes += character.utf8.count
            if character.unicodeScalars.contains(where: { !Self.isControlOrFormat($0) }) {
                out.append(mark)
                bytes += markBytes
            }
            if bytes > maxBytes { return nil }
        }
        return String(out)
    }

    /// Cc, Cf, Zl, Zp: nothing visible to draw a line through or under.
    private static func isControlOrFormat(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator: return true
        default: return false
        }
    }

    static func undecorate(_ s: String) -> String {
        guard s.unicodeScalars.contains(where: { decorationMarks.contains($0) }) else { return s }
        return String(String.UnicodeScalarView(s.unicodeScalars.filter { !decorationMarks.contains($0) }))
    }

    func apply(_ s: String) -> String { apply(s, maxBytes: Int.max) ?? s }

    /// nil when the result would pass `maxBytes`. A decoration is bounded as it is built; every
    /// other transform is measured once it exists — Unicode case mapping grows text too (İ → i̇,
    /// ΐ → Ϊ́: 2 bytes → 3 and 6; auditor's P2 on PR #26), so none of them is exempt.
    func apply(_ s: String, maxBytes: Int) -> String? {
        guard let out = applyUnbounded(s, maxBytes: maxBytes), out.utf8.count <= maxBytes else { return nil }
        return out
    }

    private func applyUnbounded(_ s: String, maxBytes: Int) -> String? {
        switch self {
        case .upper:    return s.uppercased()
        case .lower:    return s.lowercased()
        case .title:    return s.capitalized
        case .sentence:
            // Lower everything, then upper-case the first letter of each sentence.
            var out = ""
            var atStart = true
            for ch in s.lowercased() {
                if atStart, ch.isLetter { out.append(contentsOf: String(ch).uppercased()); atStart = false; continue }
                out.append(ch)
                if ".!?\n".contains(ch) { atStart = true } else if !ch.isWhitespace { atStart = false }
            }
            return out
        case .trim:
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .singleLine:
            // Line breaks (and the indentation that follows them) become one space.
            let parts = s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.filter { !$0.isEmpty }.joined(separator: " ")
        case .stripFormatting:
            return s
        case .strikethrough, .underline, .wavy:
            return Self.decorate(s, with: mark!, maxBytes: maxBytes)
        case .undecorate:
            return Self.undecorate(s)
        }
    }
}

extension ClipItem {
    /// A text-only copy of the item with the transformation applied (new id and hash: it is new content).
    func transformed(_ t: TextTransform) -> ClipItem? {
        guard let text = plainText, let out = t.apply(text, maxBytes: Limits.textBytesCeiling) else { return nil }
        let data = Data(out.utf8)
        return ClipItem(id: UUID(), date: Date(), formats: [Format.text: data], sourceApp: sourceApp,
                        contentHash: ClipItem.hash(of: data))
    }
}
