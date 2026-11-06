import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Puts an item on the pasteboard and pastes it into the previously active app.
/// Uses CGEvent to synthesize the paste key stroke, which requires the Accessibility permission.
enum Paster {
    /// Tests only: receives every item `paste` would put on the pasteboard, and nothing touches the
    /// pasteboard or the keyboard. nil in the app.
    static var pasteSinkForTesting: ((ClipItem) -> Void)?

    // MARK: Accessibility

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Open System Settings → Privacy & Security → Accessibility with Keepit already in the list.
    /// We deliberately do not use kAXTrustedCheckOptionPrompt: that system sheet stays on screen even
    /// after the user flips the switch and has to be dismissed with "Deny", which is confusing. A denied
    /// AX query is enough to make TCC list the app, and the pane does the rest.
    static func openAccessibilitySettings() {
        var focused: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Paste

    /// - Parameters:
    ///   - item: what to paste
    ///   - target: the app that was frontmost before our menu appeared (nil = whatever is frontmost now)
    ///   - sendKey: false → only copy to the pasteboard (no key stroke)
    ///   - plainText: put only the plain-text representation on the pasteboard (strip RTF/HTML)
    static func paste(_ item: ClipItem,
                      into target: NSRunningApplication?,
                      monitor: ClipboardMonitor,
                      settings: Settings,
                      sendKey: Bool,
                      plainText: Bool = false,
                      extraDelay: TimeInterval = 0) {
        if let sink = pasteSinkForTesting { sink(item); return }
        let payload = plainText ? (item.plainTextOnly() ?? item) : item
        monitor.performIgnoringChange {
            payload.write(to: NSPasteboard.general)
        }
        guard sendKey else { return }

        // Give focus back to the app the user was typing in.
        if let app = target, !app.isTerminated, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate(options: [])
        }

        guard isTrusted() else {
            // No permission → the data is on the clipboard; the user can ⌘V by hand.
            Log.system.notice("Accessibility not granted, skipping synthetic paste")
            return
        }

        let key = settings.pasteKey(for: target?.bundleIdentifier)
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.pasteDelay + extraDelay) {
            waitForModifiersReleased {
                sendKeyStroke(key)
            }
        }
    }

    /// The user may still be holding ⌥ from the hot key; a ⌘V sent now would arrive as ⌥⌘V.
    private static func waitForModifiersReleased(attempts: Int = 30, then: @escaping () -> Void) {
        let held = NSEvent.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        if held.isEmpty || attempts <= 0 {
            then()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                waitForModifiersReleased(attempts: attempts - 1, then: then)
            }
        }
    }

    static func sendKeyStroke(_ k: PasteKey, times: Int) {
        for _ in 0..<max(0, times) { sendKeyStroke(k) }
    }

    static func sendKeyStroke(_ k: PasteKey) {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        var flags: CGEventFlags = []
        if k.command { flags.insert(.maskCommand) }
        if k.shift   { flags.insert(.maskShift) }
        if k.option  { flags.insert(.maskAlternate) }
        if k.control { flags.insert(.maskControl) }

        guard let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(k.keyCode), keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(k.keyCode), keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: Caret position ("open menu at text cursor")

    /// Screen position (Cocoa coordinates, bottom-left origin) of the text cursor in the focused app, if exposed via AX.
    static func caretScreenPoint() -> NSPoint? {
        guard isTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedAny = focusedRef else { return nil }
        let element = focusedAny as! AXUIElement

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let range = rangeRef else { return nil }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element,
                                                         kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         range,
                                                         &boundsRef) == .success,
              let boundsAny = boundsRef else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsAny as! AXValue, .cgRect, &rect) else { return nil }
        guard rect.width.isFinite, rect.height.isFinite, !(rect.origin.x == 0 && rect.origin.y == 0) else { return nil }

        // AX uses top-left origin of the primary display; Cocoa uses bottom-left.
        guard let primary = NSScreen.screens.first else { return nil }
        let y = primary.frame.height - rect.origin.y - rect.height
        return NSPoint(x: rect.origin.x, y: y)
    }
}
