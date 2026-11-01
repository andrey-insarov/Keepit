import AppKit

/// The "Insert ▾" menu of the Viewer: every placeholder with a one-line description; the token is the
/// represented object. Shared with the reference window so the two never drift apart.
enum PlaceholderMenu {
    static let groups: [(String, [(String, String)])] = [
        (L("Date & time"), [
            ("{date}", L("Today's date")), ("{time}", L("Current time")), ("{datetime}", L("Date and time")),
            ("{date:yyyy-MM-dd}", L("Custom format")), ("{date+7d}", L("Shifted date (d/w/m/y/h)")),
            ("{weekday}", L("Day name")), ("{month}", L("Month name")), ("{year}", L("Year")),
            ("{iso}", L("ISO 8601 timestamp")), ("{unix}", L("Unix time")),
        ]),
        (L("Clipboard"), [
            ("{clipboard}", L("Current clipboard")), ("{clipboard:2}", L("History item N")),
            ("{clipboard|upper}", L("Clipboard, UPPERCASE")), ("{clipboard|lower}", L("Clipboard, lowercase")),
            ("{clipboard|title}", L("Clipboard, Title Case")), ("{clipboard|trim}", L("Clipboard, trimmed")),
            ("{clipboard|oneline}", L("Clipboard, single line")), ("{clipboard|url}", L("Clipboard, URL-encoded")),
        ]),
        (L("Ask when pasting"), [
            ("{input:Name}", L("Text field")), ("{input:Name=Default}", L("Text field with a default")),
            ("{choice:Label=A|B|C}", L("Pick one of the options")),
        ]),
        (L("Other"), [
            ("{cursor}", L("Caret position after pasting")), ("{user}", L("Full name")),
            ("{username}", L("Account name")), ("{host}", L("Computer name")),
            ("{uuid}", L("New UUID")), ("{random:1-100}", L("Random number")),
        ]),
    ]

    static func make(target: AnyObject, action: Selector, title: String) -> NSMenu {
        let m = NSMenu()
        m.addItem(withTitle: title, action: nil, keyEquivalent: "")   // pull-down title
        let mono = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        for (group, items) in groups {
            let h = NSMenuItem(title: group, action: nil, keyEquivalent: "")
            h.isEnabled = false
            m.addItem(h)
            for (token, desc) in items {
                let mi = NSMenuItem(title: "", action: action, keyEquivalent: "")
                let a = NSMutableAttributedString(string: token + "  ", attributes: [.font: mono])
                a.append(NSAttributedString(string: desc, attributes: [.font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.secondaryLabelColor]))
                mi.attributedTitle = a
                mi.indentationLevel = 1
                mi.target = target
                mi.representedObject = token
                m.addItem(mi)
            }
        }
        return m
    }
}
