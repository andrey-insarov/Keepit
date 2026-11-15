import AppKit

/// A search field living inside the history menu as the first item: typing filters the list in place.
/// Return picks the first match; ⌘1…⌘0 pick by number; Esc clears, then closes the menu as usual.
final class MenuSearchItem: NSMenuItem, NSSearchFieldDelegate {
    let field = NSSearchField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    var onChange: ((String) -> Void)?
    var onReturn: (() -> Void)?
    private var lastText = ""
    /// The event being handled; tests hand in a key event of their own.
    var currentEvent: () -> NSEvent? = { NSApp.currentEvent }

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
        box.addSubview(field)
        view = box
    }

    /// H-9: while the history menu tracks, the search field is usually the first responder, so a key with
    /// modifiers is typed into it (⌃⌥U on German is the dead key "¨") instead of reaching the menu's key
    /// equivalents. A key with ⌘, ⌃ or ⌥ that is the key equivalent of an enabled item of the menu
    /// (submenus and hidden items included, as AppKit would match it) closes the menu and runs the item's
    /// action once, on the next turn, as after a click. Bare letters and digits are never taken.
    /// The key is the physical one: the items' equivalents are the ASCII-capable layout's characters for
    /// their key codes (H-6), so the event's key code is read the same way (on Russian the U key arrives
    /// as "г" and still names the UPPERCASE item). A key the layout table does not name falls back to
    /// the event's own unmodified character, as AppKit matches it.
    /// Not every key gets here: the menu takes ⌃⌥V as "page down" before the field sees it.
    @discardableResult
    func handleMenuKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let menu else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !mods.isDisjoint(with: [.command, .control, .option]) else { return false }
        var keys: [String] = []
        if let k = KeyCodes.menuCharacter(for: event.keyCode) { keys.append(k) }
        if let k = event.charactersIgnoringModifiers?.lowercased(), k.count == 1, !keys.contains(k) { keys.append(k) }
        guard let item = keys.lazy.compactMap({ MenuBuilder.item(forKeyEquivalent: $0, flags: mods, in: [menu]) }).first,
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
        if let event = currentEvent(), event.type == .keyDown {
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
        if let event = currentEvent(), event.type == .keyDown {
            if handleMenuKeyEquivalent(event) { return true }
        }
        return false
    }
}
