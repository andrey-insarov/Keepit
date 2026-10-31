import AppKit

/// Dialogs around the 24-word recovery phrase.
enum RecoveryDialogs {

    /// Show a freshly generated phrase. The user must tick the disclaimer before continuing.
    /// There is deliberately no "Copy" button: Keepit itself would record the phrase in its history.
    static func present(words: [String], title: String = "Your recovery phrase") {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = "Write these 24 words down or print them and keep the sheet somewhere safe. "
            + "They can unlock your history and templates if you forget the password (on any Mac). "
            + "Keepit never stores the phrase itself."
        a.icon = NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil)

        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.rowSpacing = 4
        grid.columnSpacing = 24
        for row in 0..<8 {
            var cells: [NSView] = []
            for col in 0..<3 {
                let i = row + col * 8                       // 1–8, 9–16, 17–24 in three columns
                let f = NSTextField(labelWithString: String(format: "%2d. %@", i + 1, words[i]))
                f.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                f.isSelectable = false
                cells.append(f)
            }
            grid.addRow(with: cells)
        }

        let printButton = NSButton(title: "Print…", target: nil, action: nil)
        let disclaimer = NSButton(checkboxWithTitle:
            "I understand that if I lose both the password and this recovery phrase, my data is lost forever.",
            target: nil, action: nil)
        disclaimer.lineBreakMode = .byWordWrapping

        let stack = NSStackView(views: [grid, printButton, disclaimer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        stack.frame = NSRect(x: 0, y: 0, width: 460, height: 260)
        disclaimer.widthAnchor.constraint(equalToConstant: 440).isActive = true
        a.accessoryView = stack

        a.addButton(withTitle: "I've saved it")
        let ok = a.buttons[0]
        ok.isEnabled = false

        let toggler = Toggler { ok.isEnabled = disclaimer.state == .on }
        disclaimer.target = toggler
        disclaimer.action = #selector(Toggler.fire)
        let printer = Printer(words: words)
        printButton.target = printer
        printButton.action = #selector(Printer.fire)

        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
        _ = toggler; _ = printer   // keep targets alive until the alert closes
    }

    /// Ask for the 24 words. Returns nil on Cancel; loops until the checksum validates.
    static func askPhrase() -> [String]? {
        while true {
            let a = NSAlert()
            a.messageText = "Enter your recovery phrase"
            a.informativeText = "Type the 24 words in order, separated by spaces or line breaks. Numbers are ignored."
            let scroll = NSTextView.scrollableTextView()
            let tv = scroll.documentView as! NSTextView
            tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            tv.isRichText = false
            tv.isAutomaticQuoteSubstitutionEnabled = false
            tv.isAutomaticSpellingCorrectionEnabled = false
            tv.isAutomaticTextReplacementEnabled = false
            scroll.borderType = .bezelBorder
            scroll.frame = NSRect(x: 0, y: 0, width: 460, height: 110)
            a.accessoryView = scroll
            a.addButton(withTitle: "Unlock")
            a.addButton(withTitle: "Cancel")
            a.window.initialFirstResponder = tv
            NSApp.activate(ignoringOtherApps: true)
            guard a.runModal() == .alertFirstButtonReturn else { return nil }
            let words = Mnemonic.parse(String(tv.string.prefix(Limits.recoveryInputMaxChars)))
            tv.string = ""
            if words.count != Mnemonic.wordCount {
                Vault.error("That's \(words.count) word(s); the phrase has \(Mnemonic.wordCount).")
                continue
            }
            if Mnemonic.decode(words) == nil {
                Vault.error("The phrase doesn't check out — a word is misspelled or out of order.")
                continue
            }
            return words
        }
    }

    // MARK: helpers

    private final class Toggler: NSObject {
        let block: () -> Void
        init(_ block: @escaping () -> Void) { self.block = block }
        @objc func fire() { block() }
    }

    private final class Printer: NSObject {
        let words: [String]
        init(words: [String]) { self.words = words }

        @objc func fire() {
            let page = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))  // US Letter minus margins
            page.isEditable = false
            var text = "Keepit — recovery phrase\n\(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))\n\n"
            for (i, w) in words.enumerated() { text += String(format: "%2d. %@\n", i + 1, w) }
            text += "\nKeep this sheet private. Anyone with these words can read your clipboard history."
            page.string = text
            page.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let op = NSPrintOperation(view: page)
            op.showsPrintPanel = true
            op.showsProgressPanel = true
            op.run()
        }
    }
}
