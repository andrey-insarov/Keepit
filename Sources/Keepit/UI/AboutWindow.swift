import AppKit

/// "About Keepit": icon, name, version / commit / build date, Help button, link to keep.it.com.
final class AboutWindow: NSWindowController {
    static let shared = AboutWindow()

    private init() {
        let w = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
                        styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.title = L("About Keepit")
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.contentView = makeContent()
        w.center()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeContent() -> NSView {
        let root = NSView()

        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let img = NSImage(contentsOf: url) {
            icon.image = img
        } else {
            icon.image = NSApp.applicationIconImage
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 128).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 128).isActive = true

        // "Keepit – Clipboard Manager" in a serif face, the subtitle in italic.
        let title = NSTextField(labelWithAttributedString: Self.titleString())
        title.alignment = .center
        title.maximumNumberOfLines = 2
        title.lineBreakMode = .byWordWrapping

        let version = Self.grayLabel(LF("Version %@ (%@)", AppInfo.version, AppInfo.gitSHA))
        var dateText = ""
        if let d = AppInfo.buildDate {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            dateText = f.string(from: d)
        }
        let date = Self.grayLabel(dateText)
        date.isHidden = dateText.isEmpty

        let help = NSButton(title: L("Help"), target: self, action: #selector(openHelp))
        help.bezelStyle = .rounded
        help.controlSize = .large
        help.keyEquivalent = "\r"
        let source = NSButton(title: L("Source code on GitHub (MIT License)"), target: self, action: #selector(openSource))
        source.bezelStyle = .rounded
        source.controlSize = .large
        for b in [help, source] {
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 260).isActive = true
        }

        let link = NSTextField(labelWithAttributedString: Self.linkString())
        link.alignment = .center
        link.allowsEditingTextAttributes = true
        link.isSelectable = true

        let copyright = Self.grayLabel(AppInfo.copyright, size: 11)

        let stack = NSStackView(views: [icon, title, version, date, help, source, link, copyright])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(18, after: icon)
        stack.setCustomSpacing(10, after: title)
        stack.setCustomSpacing(22, after: date)
        stack.setCustomSpacing(8, after: help)
        stack.setCustomSpacing(18, after: source)
        stack.setCustomSpacing(4, after: link)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 44),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -22),
        ])
        return root
    }

    private static func titleString() -> NSAttributedString {
        let base = NSFont.systemFont(ofSize: 26, weight: .semibold)
        let serif = NSFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: 26) ?? base
        let italicDesc = serif.fontDescriptor.withSymbolicTraits(.italic)
        let italic = NSFont(descriptor: italicDesc, size: 26) ?? serif
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let s = NSMutableAttributedString(string: AppInfo.name + "\n", attributes: [.font: serif, .paragraphStyle: p, .foregroundColor: NSColor.labelColor])
        s.append(NSAttributedString(string: "Clipboard Manager", attributes: [.font: italic, .paragraphStyle: p, .foregroundColor: NSColor.labelColor]))
        return s
    }

    private static func linkString() -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        return NSAttributedString(string: "keep.it.com", attributes: [
            .link: URL(string: AppInfo.homepage)!,
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .paragraphStyle: p,
        ])
    }

    private static func grayLabel(_ text: String, size: CGFloat = 14) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: size)
        l.textColor = .secondaryLabelColor
        l.alignment = .center
        return l
    }

    @objc private func openHelp() { NSWorkspace.shared.open(URL(string: AppInfo.supportURL)!) }
    @objc private func openSource() { NSWorkspace.shared.open(URL(string: AppInfo.sourceURL)!) }
}
