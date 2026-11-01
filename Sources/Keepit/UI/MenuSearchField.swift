import AppKit

/// A search field living inside the history menu as the first item: typing filters the list in place.
/// Return picks the first match; ⌘1…⌘0 pick by number; Esc clears, then closes the menu as usual.
final class MenuSearchItem: NSMenuItem, NSSearchFieldDelegate {
    /// Search field that also handles ⌘1…⌘0 itself: with the extended menu (⌘ held) the history items carry
    /// submenus and AppKit stops firing their key equivalents, so the field picks the item directly.
    final class Field: NSSearchField {
        var onCommandDigit: ((String) -> Bool)?
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == [.command], let ch = event.charactersIgnoringModifiers, ch.count == 1, ch.first!.isNumber,
               onCommandDigit?(ch) == true { return true }
            return super.performKeyEquivalent(with: event)
        }
    }

    let field = Field(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
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
        box.addSubview(field)
        view = box
        field.onCommandDigit = { [weak self] digit in self?.pick(digit) ?? false }
    }

    /// Perform the history item whose shortcut is ⌘<digit>.
    private func pick(_ digit: String) -> Bool {
        guard let menu, let mi = menu.items.first(where: { $0.tag == MenuBuilder.historyTag && !$0.isAlternate && $0.keyEquivalent == digit && $0.isEnabled }) else { return false }
        let idx = menu.index(of: mi)
        guard idx >= 0 else { return false }
        menu.cancelTracking()
        DispatchQueue.main.async { menu.performActionForItem(at: idx) }
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
        return false
    }
}
