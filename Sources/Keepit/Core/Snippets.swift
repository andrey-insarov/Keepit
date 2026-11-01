import Foundation

/// Placeholders in template text — a light text expander.
///
///     {date} {time} {datetime} {date:yyyy-MM-dd} {date+7d} {date-1m:EEEE}
///     {iso} {unix} {weekday} {month} {year}
///     {clipboard} {clipboard:2} {clipboard|upper} {clipboard:2|trim|oneline}
///     {input:Name} {input:Name=Default} {choice:Label=A|B|C}
///     {user} {username} {host} {uuid} {random:1-100}
///     {cursor}   — where the caret goes after pasting
///     {{ and }} — literal braces
enum Snippets {

    /// What the dialog has to ask the user before the text can be expanded.
    struct Prompt: Equatable {
        let name: String
        let defaultValue: String
        let choices: [String]     // empty = free text
    }

    struct Expansion {
        let text: String
        /// Characters after the `{cursor}` marker, i.e. how many ← presses move the caret there. nil = no marker.
        let charsAfterCursor: Int?
    }

    /// Cheap check used on every template paste.
    static func containsPlaceholders(_ s: String) -> Bool {
        s.contains("{") && s.range(of: #"\{[a-z]"#, options: .regularExpression) != nil
    }

    // MARK: Parsing

    /// Split into literal text and `{…}` tokens. `{{`/`}}` are literal braces.
    private enum Piece { case literal(String), token(String) }

    private static func pieces(_ s: String) -> [Piece] {
        var out: [Piece] = []
        var lit = ""
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            let next = s.index(after: i)
            if c == "{" {
                if next < s.endIndex, s[next] == "{" { lit.append("{"); i = s.index(after: next); continue }
                if let close = s[next...].firstIndex(of: "}") {
                    let body = String(s[next..<close])
                    if body.first?.isLetter == true, !body.contains("{") {
                        if !lit.isEmpty { out.append(.literal(lit)); lit = "" }
                        out.append(.token(body))
                        i = s.index(after: close)
                        continue
                    }
                }
                lit.append("{"); i = next; continue
            }
            if c == "}", next < s.endIndex, s[next] == "}" { lit.append("}"); i = s.index(after: next); continue }
            lit.append(c); i = next
        }
        if !lit.isEmpty { out.append(.literal(lit)) }
        return out
    }

    /// `input:` and `choice:` tokens, in order of first appearance (same name = one prompt).
    static func prompts(in s: String) -> [Prompt] {
        var seen: [String] = []
        var out: [Prompt] = []
        for case .token(let t) in pieces(s) {
            guard let p = prompt(from: t), !seen.contains(p.name) else { continue }
            seen.append(p.name)
            out.append(p)
        }
        return out
    }

    private static func prompt(from token: String) -> Prompt? {
        let (head, filters) = splitFilters(token)
        if head.hasPrefix("input:") {
            let spec = String(head.dropFirst(6))
            let (name, def) = splitDefault(spec)
            return Prompt(name: name, defaultValue: def ?? "", choices: [])
        }
        if head.hasPrefix("choice:") {
            let spec = String(head.dropFirst(7))
            let (name, list) = splitDefault(spec)
            let choices = (list ?? name).split(separator: "|").map { String($0) }
            return Prompt(name: list == nil ? L("Choice") : name, defaultValue: choices.first ?? "", choices: choices)
        }
        _ = filters
        return nil
    }

    private static func splitDefault(_ spec: String) -> (String, String?) {
        guard let eq = spec.firstIndex(of: "=") else { return (spec, nil) }
        return (String(spec[..<eq]), String(spec[spec.index(after: eq)...]))
    }

    /// "clipboard:2|trim|upper" → ("clipboard:2", ["trim","upper"]). A `choice:` list keeps its `|`.
    private static func splitFilters(_ token: String) -> (String, [String]) {
        if token.hasPrefix("choice:") { return (token, []) }
        var parts = token.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let head = parts.removeFirst()
        return (head, parts)
    }

    // MARK: Expansion

    struct Context {
        var now = Date()
        var clipboard: (Int) -> String? = { _ in nil }   // 1-based history index
        var answers: [String: String] = [:]
        var userName = NSFullUserName()
        var shortUserName = NSUserName()
        var hostName = ProcessInfo.processInfo.hostName
        var locale = Locale.current
    }

    static func expand(_ s: String, context: Context) -> Expansion {
        var out = ""
        var cursorAt: Int?
        for p in pieces(s) {
            switch p {
            case .literal(let l): out += l
            case .token(let t):
                if t == "cursor" { if cursorAt == nil { cursorAt = out.count }; continue }
                let (head, filters) = splitFilters(t)
                var v = value(for: head, context: context) ?? "{\(t)}"
                for f in filters { v = applyFilter(f, v) }
                out += v
            }
        }
        return Expansion(text: out, charsAfterCursor: cursorAt.map { out.count - $0 })
    }

    private static func value(for head: String, context c: Context) -> String? {
        let (name, arg) = head.firstIndex(of: ":").map { (String(head[..<$0]), String(head[head.index(after: $0)...])) } ?? (head, nil)
        switch name.lowercased() {
        case "clipboard":
            let n = arg.flatMap(Int.init) ?? 1
            return c.clipboard(max(1, n)) ?? ""
        case "input":
            return c.answers[splitDefault(arg ?? "").0] ?? splitDefault(arg ?? "").1 ?? ""
        case "choice":
            let (label, list) = splitDefault(arg ?? "")
            let key = list == nil ? L("Choice") : label
            return c.answers[key] ?? ((list ?? label).split(separator: "|").first.map(String.init) ?? "")
        case "user":     return c.userName
        case "username": return c.shortUserName
        case "host":     return c.hostName
        case "uuid":     return UUID().uuidString
        case "random":
            let r = (arg ?? "0-9").split(separator: "-").compactMap { Int($0) }
            let lo = r.first ?? 0, hi = r.count > 1 ? r[1] : 9
            return String(Int.random(in: min(lo, hi)...max(lo, hi)))
        case "iso":
            let f = ISO8601DateFormatter(); return f.string(from: c.now)
        case "unix":     return String(Int(c.now.timeIntervalSince1970))
        case "time":     return formatted(c.now, format: arg, style: (.none, .short), c)
        case "datetime": return formatted(c.now, format: arg, style: (.short, .short), c)
        case "weekday":  return formatted(c.now, format: arg ?? "EEEE", style: nil, c)
        case "month":    return formatted(c.now, format: arg ?? "LLLL", style: nil, c)
        case "year":     return formatted(c.now, format: arg ?? "yyyy", style: nil, c)
        default: break
        }
        // {date}, {date:fmt}, {date+7d}, {date-1m:fmt}
        if name.lowercased().hasPrefix("date") {
            let shiftSpec = String(name.dropFirst(4))
            guard let date = shifted(c.now, by: shiftSpec, calendar: Calendar.current) else { return nil }
            return formatted(date, format: arg, style: (.short, .none), c)
        }
        return nil
    }

    /// "+7d", "-1m", "+2w", "+1y", "" → shifted date; anything else → nil.
    static func shifted(_ date: Date, by spec: String, calendar: Calendar) -> Date? {
        if spec.isEmpty { return date }
        guard let sign = spec.first, sign == "+" || sign == "-", let unit = spec.last,
              let n = Int(spec.dropFirst().dropLast()) else { return nil }
        let amount = sign == "-" ? -n : n
        let comp: Calendar.Component
        switch unit {
        case "d": comp = .day
        case "w": comp = .weekOfYear
        case "m": comp = .month
        case "y": comp = .year
        case "h": comp = .hour
        default: return nil
        }
        return calendar.date(byAdding: comp, value: amount, to: date)
    }

    private static func formatted(_ d: Date, format: String?, style: (DateFormatter.Style, DateFormatter.Style)?, _ c: Context) -> String {
        let f = DateFormatter()
        f.locale = c.locale
        if let fmt = format, !fmt.isEmpty {
            f.dateFormat = fmt
        } else if let s = style {
            f.dateStyle = s.0; f.timeStyle = s.1
        }
        return f.string(from: d)
    }

    static func applyFilter(_ f: String, _ v: String) -> String {
        switch f.lowercased() {
        case "upper":   return TextTransform.upper.apply(v)
        case "lower":   return TextTransform.lower.apply(v)
        case "title":   return TextTransform.title.apply(v)
        case "trim":    return TextTransform.trim.apply(v)
        case "oneline": return TextTransform.singleLine.apply(v)
        case "url":     return v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+/?#"))) ?? v
        default:        return v
        }
    }
}
