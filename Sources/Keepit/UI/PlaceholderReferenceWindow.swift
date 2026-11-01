import AppKit

/// Help → Template Placeholders…: the list of `{…}` tokens understood in template text.
enum PlaceholderReferenceWindow {
    private static var window: NSWindow?

    static let reference: [(String, String)] = [
        ("{date}  {time}  {datetime}", L("Today's date / current time, in the system format")),
        ("{date:yyyy-MM-dd}  {time:HH:mm}", L("Custom format (Unicode date patterns: yyyy MM dd EEEE HH mm …)")),
        ("{date+7d}  {date-1m:MMMM}", L("Shifted date: +/- number and d (days), w (weeks), m (months), y (years), h (hours)")),
        ("{weekday}  {month}  {year}  {iso}  {unix}", L("Day name, month name, year, ISO 8601 timestamp, Unix time")),
        ("{clipboard}  {clipboard:2}", L("Current clipboard (history item #1) or item N")),
        ("{clipboard|upper}  {clipboard|trim|oneline}", L("Filters: upper, lower, title, trim, oneline, url — can be chained")),
        ("{input:Name}  {input:Name=Default}", L("Asks for a value before pasting; the same name is asked once")),
        ("{choice:Label=A|B|C}", L("Asks to pick one of the options")),
        ("{cursor}", L("Where the text cursor ends up after pasting")),
        ("{user}  {username}  {host}", L("Full name, account name, computer name")),
        ("{uuid}  {random:1-100}", L("A new UUID; a random number in the range")),
        ("{{  }}", L("Literal braces")),
    ]

    static let automation: [(String, String)] = [
        ("keepit://paste/2   keepit://paste/latest   keepit://paste/previous", L("Paste history item N into the front app")),
        ("keepit://copy/3", L("Put item N on the clipboard without pasting")),
        ("keepit://template/Signature   keepit://template/Work/Reply?copy=1", L("Paste (or copy) a template by name or folder path")),
        ("keepit://add?text=…   keepit://add-template?text=…&name=…", L("Add text to the history or as a new template")),
        ("keepit://history   keepit://templates   keepit://viewer   keepit://preferences", L("Open the menus and windows")),
        ("keepit://pause   keepit://resume", L("Pause recording for 10 minutes / resume")),
    ]

    static func show() {
        if let w = window { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = L("Placeholders & Automation")
        w.isReleasedWhenClosed = false
        w.center()

        let scroll = NSScrollView(frame: w.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false
        tv.isRichText = true
        tv.textContainerInset = NSSize(width: 16, height: 14)
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        tv.textContainer?.widthTracksTextView = true

        let text = NSMutableAttributedString()
        let body = NSFont.systemFont(ofSize: 13)
        let mono = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .medium)
        let intro = L("Put these tokens into the text of a template; they are replaced when the template is pasted. Plain text without braces is pasted unchanged.") + "\n\n"
        text.append(NSAttributedString(string: intro, attributes: [.font: body, .foregroundColor: NSColor.labelColor]))
        for (token, desc) in reference {
            text.append(NSAttributedString(string: token + "\n", attributes: [.font: mono, .foregroundColor: NSColor.labelColor]))
            text.append(NSAttributedString(string: "    " + desc + "\n\n", attributes: [.font: body, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        let example = L("Example:") + "\n"
        text.append(NSAttributedString(string: example, attributes: [.font: body, .foregroundColor: NSColor.labelColor]))
        text.append(NSAttributedString(string: "Hi {input:Name},\n\nthanks for your message of {date-1d}. I'll get back to you by {date+3d:EEEE}.\n{cursor}\n{user}\n",
                                       attributes: [.font: mono, .foregroundColor: NSColor.labelColor]))

        text.append(NSAttributedString(string: "\n" + L("Automation — keepit:// URLs (Shortcuts “Open URL”, Raycast, Alfred, the open command)") + "\n\n",
                                       attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor.labelColor]))
        for (token, desc) in automation {
            text.append(NSAttributedString(string: token + "\n", attributes: [.font: mono, .foregroundColor: NSColor.labelColor]))
            text.append(NSAttributedString(string: "    " + desc + "\n\n", attributes: [.font: body, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        tv.textStorage?.setAttributedString(text)
        scroll.documentView = tv
        w.contentView?.addSubview(scroll)
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
