import AppKit

/// The search field: while the history menu tracks it is the first responder, so a key with modifiers
/// reaches it before the menu's key equivalents (H-9). A combination that names a menu item is run
/// from here; everything else is typed as before.
final class MenuSearchField: NSSearchField {
    var keyEquivalentHandler: ((NSEvent) -> Bool)?
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        Log.system.notice("menu open: performKeyEquivalent reached the search field")
        if keyEquivalentHandler?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// A search field living inside the history menu as the first item: typing filters the list in place.
/// Return picks the first match; ⌘1…⌘0 pick by number; Esc clears, then closes the menu as usual.
final class MenuSearchItem: NSMenuItem, NSSearchFieldDelegate {
    let field = MenuSearchField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    var onChange: ((String) -> Void)?
    var onReturn: (() -> Void)?
    private var lastText = ""

    init(width: CGFloat = 300) {
        super.init(title: "", action: nil, keyEquivalent: "")
        let box = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 32))
        field.frame = NSRect(x: 12, y: 4, width: width - 24, height: 24)
        field.placeholderString = L("Search history…")
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.delegate = self
        field.focusRingType = .none
        field.autoresizingMask = [.width]
        field.keyEquivalentHandler = { [weak self] event in self?.handleMenuKeyEquivalent(event) ?? false }
        box.addSubview(field)
        view = box
    }

    /// A key with ⌘, ⌃ or ⌥ that is the key equivalent of an enabled item of the menu (submenus and
    /// hidden items included, as AppKit would match it): the menu closes and the item's action runs
    /// once, on the next turn, as after a click. Bare letters and digits are never taken.
    @discardableResult
    func handleMenuKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let menu else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !mods.isDisjoint(with: [.command, .control, .option]) else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1,
              let item = MenuBuilder.item(forKeyEquivalent: key, flags: mods, in: [menu]),
              let action = item.action else { return false }
        Log.system.notice("menu open: the search field runs the matching item")
        menu.cancelTracking()
        DispatchQueue.main.async { NSApp.sendAction(action, to: item.target, from: item) }
        return true
    }

    required init(coder: NSCoder) { fatalError() }

    func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let f = self?.field else { return }
            f.window?.makeFirstResponder(f)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        // The key was typed into the field before anything else saw it (a dead key, an ⌥ character):
        // if it names a menu item, the typed text is taken back and the item runs instead (H-9).
        if let event = NSApp.currentEvent, event.type == .keyDown {
            Log.system.notice("menu open: a key with modifiers was typed into the search field")
            if handleMenuKeyEquivalent(event) { field.stringValue = lastText; return }
        }
        lastText = field.stringValue
        onChange?(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) {
            onReturn?()
            return true
        }
        if let event = NSApp.currentEvent, event.type == .keyDown {
            Log.system.notice("menu open: a command key reached the search field's editor")
            if handleMenuKeyEquivalent(event) { return true }
        }
        return false
    }
}
