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

    /// Every character of every line gets the mark (spaces too, so the line is continuous); control
    /// characters — line breaks, tabs — stay as they are. Marks already there are removed first, so
    /// decorating twice, or switching from one decoration to another, does not stack them.
    private static func decorate(_ s: String, with mark: Unicode.Scalar) -> String {
        var out = String.UnicodeScalarView()
        for scalar in undecorate(s).unicodeScalars {
            out.append(scalar)
            if scalar.value >= 0x20, scalar != "\u{2028}", scalar != "\u{2029}", scalar.value != 0x7F { out.append(mark) }
        }
        return String(out)
    }

    static func undecorate(_ s: String) -> String {
        guard s.unicodeScalars.contains(where: { decorationMarks.contains($0) }) else { return s }
        return String(String.UnicodeScalarView(s.unicodeScalars.filter { !decorationMarks.contains($0) }))
    }

    func apply(_ s: String) -> String {
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
            return Self.decorate(s, with: mark!)
        case .undecorate:
            return Self.undecorate(s)
        }
    }
}

extension ClipItem {
    /// A text-only copy of the item with the transformation applied (new id and hash: it is new content).
    func transformed(_ t: TextTransform) -> ClipItem? {
        guard let text = plainText else { return nil }
        let out = t.apply(text)
        let data = Data(out.utf8)
        guard data.count <= Limits.textBytesCeiling else { return nil }     // a decoration triples the bytes
        return ClipItem(id: UUID(), date: Date(), formats: [Format.text: data], sourceApp: sourceApp,
                        contentHash: ClipItem.hash(of: data))
    }
}
