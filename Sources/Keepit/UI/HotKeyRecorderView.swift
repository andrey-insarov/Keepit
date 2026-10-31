import AppKit
import Carbon.HIToolbox

/// Click, then press a key combination.
final class HotKeyRecorderView: NSControl {
    var hotKey: HotKey? {
        didSet { needsDisplay = true }
    }
    var onChange: ((HotKey) -> Void)?
    private var recording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType { get { .exterior } set {} }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
    }

    override func becomeFirstResponder() -> Bool {
        recording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return false }
        return handle(event)
    }

    override func keyDown(with event: NSEvent) {
        if recording, handle(event) { return }
        super.keyDown(with: event)
    }

    private func handle(_ event: NSEvent) -> Bool {
        if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            recording = false
            window?.makeFirstResponder(nil)
            return true
        }
        var mods: UInt32 = 0
        let f = event.modifierFlags
        if f.contains(.command) { mods |= UInt32(cmdKey) }
        if f.contains(.option)  { mods |= UInt32(optionKey) }
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.shift)   { mods |= UInt32(shiftKey) }
        // Require at least one non-shift modifier, like the original (plain letters would break typing).
        guard mods & ~UInt32(shiftKey) != 0 else { NSSound.beep(); return true }

        let hk = HotKey(keyCode: UInt32(event.keyCode), modifiers: mods)
        hotKey = hk
        recording = false
        window?.makeFirstResponder(nil)
        onChange?(hk)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = recording ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25) : NSColor.controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        let text = recording ? "Press keys… (⎋ cancels)" : (hotKey?.displayString ?? "Click to set")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: recording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: origin, withAttributes: attrs)
    }
}
