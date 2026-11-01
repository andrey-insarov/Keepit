import AppKit
import Carbon.HIToolbox

/// Small label for password prompts: current keyboard layout ("EN", "RU", …) and a Caps Lock warning,
/// updated live. Typing a password blind in the wrong layout is the most common "wrong password".
final class InputSourceIndicator: NSTextField {
    private var monitor: Any?
    private var observer: NSObjectProtocol?

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 16))
        isEditable = false
        isBordered = false
        drawsBackground = false
        isSelectable = false
        alignment = .right
        font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        refresh()
        // Layout switches are announced system-wide; Caps Lock arrives as a flagsChanged event.
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            self?.refresh(); return e
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
        if let o = observer { DistributedNotificationCenter.default().removeObserver(o) }
    }

    /// "EN" for U.S., "RU" for Russian, … — the first language code of the selected layout.
    static func currentLayoutCode() -> String {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "?" }
        if let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages) {
            let langs = Unmanaged<CFArray>.fromOpaque(p).takeUnretainedValue() as? [String] ?? []
            if let first = langs.first, let code = first.split(separator: "-").first { return code.uppercased() }
        }
        if let p = TISGetInputSourceProperty(src, kTISPropertyLocalizedName) {
            return (Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String).uppercased()
        }
        return "?"
    }

    func refresh() {
        let caps = NSEvent.modifierFlags.contains(.capsLock)
        var parts = [LF("Layout: %@", Self.currentLayoutCode())]
        if caps { parts.append("⇪ " + L("CAPS LOCK")) }
        stringValue = parts.joined(separator: "   ")
        textColor = caps ? .systemRed : .secondaryLabelColor
    }
}
