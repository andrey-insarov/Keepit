import AppKit

/// A small floating keyboard for entering the password without the physical keyboard.
///
/// - Keys are shuffled every time the panel opens (and on *Shuffle*), so a recording of mouse
///   positions does not reveal the password.
/// - The panel is excluded from screen capture (`sharingType = .none`): screenshots, screen
///   recording and screen sharing do not show it.
/// - Characters go straight into the `SecurePasswordField`'s locked buffer; no key event is
///   generated, so a keylogger sees nothing.
///
/// It does not protect against a person looking at the screen, and macOS's capture exclusion is
/// a system promise, not something Keepit can verify.
final class OnScreenKeyboard: NSObject {
    /// Which field receives the characters (the focused one in the password dialog).
    var targetField: (() -> SecurePasswordField?)?

    private var panel: NSPanel?
    private var shifted = false
    private var symbols = false
    private var letters = Array("abcdefghijklmnopqrstuvwxyz")
    private var digits = Array("0123456789")
    private let symbolSet = Array("!@#$%^&*()-_=+[]{};:'\",.<>/?\\|`~")

    private static let keySize = CGSize(width: 30, height: 28)
    private static let gap: CGFloat = 4
    private static let columns = 10

    @objc func toggle(_ sender: Any?) {
        if let p = panel, p.isVisible { close() } else { open(relativeTo: sender as? NSView) }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func open(relativeTo anchor: NSView?) {
        shuffle()
        let p = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
                        backing: .buffered, defer: false)
        p.title = L("On-screen keyboard")
        p.sharingType = .none                 // not in screenshots, recordings or screen sharing
        p.worksWhenModal = true               // the password dialog is modal
        p.level = .modalPanel
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.contentView = buildContent()
        p.setContentSize(p.contentView!.fittingSize)
        if let a = anchor, let w = a.window {
            let r = w.convertToScreen(a.convert(a.bounds, to: nil))
            p.setFrameTopLeftPoint(NSPoint(x: r.maxX + 12, y: r.maxY + 8))
        } else {
            p.center()
        }
        panel = p
        p.orderFront(nil)
    }

    private func shuffle() {
        letters.shuffle()
        digits.shuffle()
    }

    private func rebuild() {
        guard let p = panel else { return }
        p.contentView = buildContent()
        p.setContentSize(p.contentView!.fittingSize)
    }

    private func buildContent() -> NSView {
        let rows: [[String]]
        if symbols {
            rows = stride(from: 0, to: symbolSet.count, by: Self.columns).map { i in
                symbolSet[i ..< min(i + Self.columns, symbolSet.count)].map(String.init)
            }
        } else {
            let ls = letters.map { shifted ? String($0).uppercased() : String($0) }
            rows = [digits.map(String.init)] + stride(from: 0, to: ls.count, by: Self.columns).map { Array(ls[$0 ..< min($0 + Self.columns, ls.count)]) }
        }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        for row in rows {
            let r = NSStackView(views: row.map { key(title: $0, action: #selector(typeKey(_:))) })
            r.spacing = Self.gap
            stack.addArrangedSubview(r)
        }
        let controls = NSStackView(views: [
            key(title: symbols ? "ABC" : "#+=", action: #selector(toggleSymbols), width: 52),
            key(title: "⇧", action: #selector(toggleShift), width: 40, on: shifted && !symbols),
            key(title: "␣", action: #selector(typeSpace), width: 96),
            key(title: "⌫", action: #selector(backspace), width: 40),
            key(title: L("Shuffle"), action: #selector(reshuffle), width: 72),
        ])
        controls.spacing = Self.gap
        stack.addArrangedSubview(controls)
        return stack
    }

    private func key(title: String, action: Selector, width: CGFloat = OnScreenKeyboard.keySize.width, on: Bool = false) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        b.setButtonType(.momentaryPushIn)
        b.focusRingType = .none
        b.refusesFirstResponder = true                     // focus stays in the password field
        if on { b.contentTintColor = .controlAccentColor }
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: width).isActive = true
        b.heightAnchor.constraint(equalToConstant: Self.keySize.height).isActive = true
        return b
    }

    // MARK: Actions

    @objc private func typeKey(_ sender: NSButton) {
        guard let scalar = sender.title.unicodeScalars.first else { return }
        targetField?()?.append(scalar)
        if shifted && !symbols { shifted = false; rebuild() }   // one-shot shift, like a phone keyboard
    }
    @objc private func typeSpace() { targetField?()?.append(" ") }
    @objc private func backspace() { targetField?()?.deleteBackward() }
    @objc private func toggleShift() { shifted.toggle(); rebuild() }
    @objc private func toggleSymbols() { symbols.toggle(); rebuild() }
    @objc private func reshuffle() { shuffle(); rebuild() }
}
