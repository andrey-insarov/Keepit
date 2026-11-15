import AppKit

/// The search field's own field editor (H-9). While the history menu tracks, a key goes to the first
/// responder's editor as text before anything else: without this, ⌃⌥V with the field focused inserted √
/// and ⌃⌥U a dead ¨; and with the field unfocused the menu's own navigation took ⌃V as "page down" before
/// matching any item's key equivalent. The editor is the one place the app sees the key first, so a
/// combination that names a menu item is run from here, and everything else is typed as before.
final class MenuSearchFieldEditor: NSTextView {
    var keyHandler: ((NSEvent) -> Bool)?
    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }
}

final class MenuSearchFieldCell: NSSearchFieldCell {
    var keyHandler: ((NSEvent) -> Bool)?
    private lazy var editor: MenuSearchFieldEditor = {
        let e = MenuSearchFieldEditor()
        e.isFieldEditor = true
        return e
    }()
    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        editor.keyHandler = keyHandler
        return editor
    }
}

final class MenuSearchField: NSSearchField {
    override class var cellClass: AnyClass? {
        get { MenuSearchFieldCell.self }
        set {}
    }
    var keyHandler: ((NSEvent) -> Bool)? {
        get { (cell as? MenuSearchFieldCell)?.keyHandler }
        set { (cell as? MenuSearchFieldCell)?.keyHandler = newValue }
    }
    /// Tests: the editor the cell hands out.
    var fieldEditorForTesting: NSTextView? { cell?.fieldEditor(for: self) }
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
        field.keyHandler = { [weak self] event in self?.handleMenuKeyEquivalent(event) ?? false }
        box.addSubview(field)
        view = box
    }

    /// From the field's editor: a key with ⌘, ⌃ or ⌥ that is the key equivalent of an enabled item of
    /// the menu (submenus and hidden items included, as AppKit would match it) closes the menu and runs
    /// the item's action once, on the next turn, as after a click. Anything else is typed. Bare letters
    /// and digits are never taken: with the field present no item has an equivalent without a modifier.
    @discardableResult
    func handleMenuKeyEquivalent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, let menu else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !mods.isDisjoint(with: [.command, .control, .option]) else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1,
              let item = MenuBuilder.item(forKeyEquivalent: key, flags: mods, in: [menu]),
              let action = item.action else { return false }
        menu.cancelTracking()
        DispatchQueue.main.async { NSApp.sendAction(action, to: item.target, from: item) }
        return true
    }

    required init(coder: NSCoder) { fatalError() }

    /// The field takes the focus as soon as the menu's window exists (a few turns after menuWillOpen),
    /// so that keys go through its editor (H-9) rather than to the menu's own navigation.
    func focus(attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0 : 0.05)) { [weak self] in
            guard let self, let w = self.field.window else {
                if attempt < 10 { self?.focus(attempt: attempt + 1) }
                return
            }
            if w.firstResponder !== self.field.currentEditor() { w.makeFirstResponder(self.field) }
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
        return false
    }
}
