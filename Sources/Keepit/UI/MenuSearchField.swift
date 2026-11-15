import AppKit

/// The search field's view: a key equivalent of the menu is run before the field editor sees the key
/// (H-9). The field is the first responder while the menu tracks, so without this ⌃⌥V would insert √ and
/// ⌃V would page down instead of reaching the menu's items.
final class MenuSearchField: NSSearchField {
    var keyEquivalentHandler: ((NSEvent) -> Bool)?
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
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
    /// hidden items included, as AppKit would match it): the menu closes and the item's action runs,
    /// once, on the next turn, as after a click. Anything else is the field's. Bare letters and digits
    /// are never taken: with the field present no item has an equivalent without a modifier.
    @discardableResult
    func handleMenuKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let menu else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !mods.isDisjoint(with: [.command, .control, .option]) else { return false }
        Log.system.notice("menu open: key with modifiers reached the search field")
        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1,
              let item = MenuBuilder.item(forKeyEquivalent: key, flags: mods, in: [menu]),
              let action = item.action else { return false }
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
        onChange?(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) {
            onReturn?()
            return true
        }
        // A key the field editor would turn into a command (⌃V = page down, ⌃A, ⌃K…) but that names a
        // menu item: the item wins (H-9). Reached only if performKeyEquivalent did not already take it.
        if let event = NSApp.currentEvent, handleMenuKeyEquivalent(event) { return true }
        return false
    }
}
