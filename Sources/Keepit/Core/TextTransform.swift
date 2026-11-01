import Foundation

/// Text transformations applied on paste ("Paste as ▸" in the history menu).
enum TextTransform: String, CaseIterable, Codable {
    case upper, lower, title, sentence, trim, singleLine, stripFormatting

    var title: String {
        switch self {
        case .upper:           return L("UPPERCASE")
        case .lower:           return L("lowercase")
        case .title:           return L("Title Case")
        case .sentence:        return L("Sentence case")
        case .trim:            return L("Trim whitespace")
        case .singleLine:      return L("Single line")
        case .stripFormatting: return L("Plain text (no formatting)")
        }
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
        }
    }
}

extension ClipItem {
    /// A text-only copy of the item with the transformation applied (new id and hash: it is new content).
    func transformed(_ t: TextTransform) -> ClipItem? {
        guard let text = plainText else { return nil }
        let out = t.apply(text)
        let data = Data(out.utf8)
        return ClipItem(id: UUID(), date: Date(), formats: [Format.text: data], sourceApp: sourceApp,
                        contentHash: ClipItem.hash(of: data))
    }
}
