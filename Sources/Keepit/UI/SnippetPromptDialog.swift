import AppKit

/// Asks for the `{input:…}` / `{choice:…}` values of a template before it is pasted.
enum SnippetPromptDialog {
    /// Tests only: answers the dialog without showing it (and may do anything a user could do while
    /// it is open, such as lock Keepit). nil in the app.
    static var askForTesting: (([Snippets.Prompt], String) -> [String: String]?)?

    /// nil = cancelled.
    static func ask(_ prompts: [Snippets.Prompt], templateName: String) -> [String: String]? {
        if let test = askForTesting { return test(prompts, templateName) }
        let alert = NSAlert()
        alert.messageText = templateName.isEmpty ? L("Fill in the template") : templateName
        alert.informativeText = L("Values for the placeholders in this template:")
        alert.addButton(withTitle: L("Paste"))
        alert.addButton(withTitle: L("Cancel"))

        // Frame-based accessory (Auto Layout accessories collapse inside NSAlert).
        let rowH: CGFloat = 26, labelW: CGFloat = 130, fieldW: CGFloat = 240, gap: CGFloat = 6
        let height = CGFloat(prompts.count) * rowH
        let view = NSView(frame: NSRect(x: 0, y: 0, width: labelW + gap + fieldW, height: height))
        var controls: [NSControl] = []
        for (i, p) in prompts.enumerated() {
            let y = height - CGFloat(i + 1) * rowH + 2
            let label = NSTextField(labelWithString: p.name + ":")
            label.alignment = .right
            label.frame = NSRect(x: 0, y: y, width: labelW, height: 20)
            view.addSubview(label)
            if p.choices.isEmpty {
                let f = NSTextField(frame: NSRect(x: labelW + gap, y: y, width: fieldW, height: 22))
                f.stringValue = p.defaultValue
                f.placeholderString = p.name
                view.addSubview(f); controls.append(f)
            } else {
                let pop = NSPopUpButton(frame: NSRect(x: labelW + gap, y: y - 2, width: fieldW, height: 26), pullsDown: false)
                pop.addItems(withTitles: p.choices)
                view.addSubview(pop); controls.append(pop)
            }
        }
        // Tab order
        for (a, b) in zip(controls, controls.dropFirst()) { a.nextKeyView = b }
        alert.accessoryView = view
        alert.window.initialFirstResponder = controls.first

        NSApp.activate(ignoringOtherApps: true)
        guard AbortableModal.run(alert) == .alertFirstButtonReturn else { return nil }
        var answers: [String: String] = [:]
        for (p, c) in zip(prompts, controls) {
            if let pop = c as? NSPopUpButton { answers[p.name] = pop.titleOfSelectedItem ?? p.defaultValue }
            else { answers[p.name] = String(c.stringValue.prefix(Limits.promptInputMaxChars)) }
        }
        return answers
    }
}
