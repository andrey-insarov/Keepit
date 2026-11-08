import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// What `Paster.paste` needs from its target. `NSRunningApplication` conforms; tests use a stand-in,
/// so the whole timeline runs without a second process or the real event system.
protocol PasteTarget: AnyObject {
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    var bundleIdentifier: String? { get }
    func bringToFront()
}

/// Puts an item on the pasteboard and pastes it into the previously active app.
/// Uses CGEvent to synthesize the paste key stroke, which requires the Accessibility permission.
enum Paster {
    /// Tests only: receives every item `paste` would put on the pasteboard, and nothing touches the
    /// pasteboard or the keyboard. nil in the app.
    static var pasteSinkForTesting: ((ClipItem) -> Void)?

    // MARK: Accessibility

    static func isTrusted() -> Bool {
        trustedForTesting ?? AXIsProcessTrusted()
    }
    /// Tests only: stands for the Accessibility permission.
    static var trustedForTesting: Bool?

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

    // MARK: Paste (SEC08: a paste is a ticket, checked immediately before every key event)

    /// One pending paste. Created when the user asked; every key event it posts is preceded by the
    /// same checks, and anything that fails them cancels the rest — nothing is ever typed into a
    /// window the user did not ask for.
    final class Ticket {
        let generation: Int
        let target: PasteTarget
        let expectedChangeCount: Int
        /// Remaining key events, in order: the paste key, then one left arrow per `{cursor}` step.
        /// `delay` is the pause before that event once the previous one has been posted.
        var actions: [(delay: TimeInterval, key: PasteKey)]
        let requestedAt: Date
        let minimumDelay: TimeInterval
        private(set) var cancelled = false
        private(set) var reason: String?
        init(generation: Int, target: PasteTarget, expectedChangeCount: Int, actions: [(delay: TimeInterval, key: PasteKey)], requestedAt: Date, minimumDelay: TimeInterval) {
            self.generation = generation; self.target = target; self.expectedChangeCount = expectedChangeCount
            self.actions = actions; self.requestedAt = requestedAt; self.minimumDelay = minimumDelay
        }
        func cancel(_ why: String) {
            guard !cancelled else { return }
            cancelled = true; reason = why; actions = []
            Log.system.notice("paste cancelled: \(why, privacy: .public)")
        }
    }

    /// The one ticket in flight; a new paste replaces it, cancelling whatever it still had to do.
    private(set) static var pending: Ticket?

    /// Set once by the app: `{ generation in !isLocked && lockCount == generation }`. Nil (tests) = unlocked.
    static var gate: ((Int) -> Bool)?
    /// Set once by the app: `{ lockCount }`. Nil = 0.
    static var currentGeneration: (() -> Int)?

    /// How long after `minimumDelay` the target may still take to come to the front.
    static let readinessWindow: TimeInterval = 0.5
    static let modifierPoll: TimeInterval = 0.04
    static let modifierAttempts = 30
    static let cursorMoveDelay: TimeInterval = 0.25

    // Seams for tests; nil in the app.
    static var eventSinkForTesting: ((PasteKey, pid_t) -> Void)?
    static var pasteboardWriteForTesting: ((ClipItem) -> Void)?
    static var frontmostPIDForTesting: (() -> pid_t?)?
    static var changeCountForTesting: (() -> Int)?
    static var modifiersHeldForTesting: (() -> Bool)?
    static var scheduleForTesting: ((TimeInterval, @escaping () -> Void) -> Void)?
    static var nowForTesting: (() -> Date)?

    /// - Parameters:
    ///   - item: what to paste
    ///   - target: the app that was frontmost before our menu appeared. **nil → pasteboard only**:
    ///     without a known target there is nowhere to type, and a key stroke into "whatever is in
    ///     front" is what SEC08 was about.
    ///   - sendKey: false → only copy to the pasteboard (no key stroke, nothing pending)
    ///   - plainText: put only the plain-text representation on the pasteboard (strip RTF/HTML)
    ///   - extraDelay: added to the user's paste delay (a dialog had the focus)
    ///   - cursorBack: left-arrow presses after the paste (`{cursor}` in a template); part of the same ticket
    static func paste(_ item: ClipItem,
                      into target: PasteTarget?,
                      monitor: ClipboardMonitor,
                      settings: Settings,
                      sendKey: Bool,
                      plainText: Bool = false,
                      extraDelay: TimeInterval = 0,
                      cursorBack: Int = 0) {
        if let sink = pasteSinkForTesting { sink(item); return }
        let payload = plainText ? (item.plainTextOnly() ?? item) : item
        if let fake = pasteboardWriteForTesting {
            fake(payload)                                   // tests never touch the real pasteboard
        } else {
            monitor.performIgnoringChange { payload.write(to: NSPasteboard.general) }
        }
        let changeCount = changeCountForTesting?() ?? NSPasteboard.general.changeCount   // right after our write
        cancelPending("a new paste replaces it")
        guard sendKey else { return }
        guard let app = target, !app.isTerminated, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            Log.system.notice("paste: no target app; the item is on the pasteboard, no key stroke")
            return
        }
        guard isTrusted() else {
            // No permission → the data is on the clipboard; the user can ⌘V by hand.
            Log.system.notice("Accessibility not granted, skipping synthetic paste")
            return
        }
        // Give focus back to the app the user was typing in. Whether it took is checked before every event.
        app.bringToFront()

        var actions: [(delay: TimeInterval, key: PasteKey)] = [(0, settings.pasteKey(for: app.bundleIdentifier))]
        if cursorBack > 0 {
            let left = PasteKey(keyCode: UInt16(kVK_LeftArrow), command: false)
            actions.append((cursorMoveDelay, left))
            for _ in 1 ..< cursorBack { actions.append((0, left)) }
        }
        let ticket = Ticket(generation: currentGeneration?() ?? 0, target: app, expectedChangeCount: changeCount,
                            actions: actions, requestedAt: now(), minimumDelay: settings.pasteDelay + extraDelay)
        pending = ticket
        // Not before the user's delay; then wait for the target to be in front (bounded); then for
        // the modifiers to be released; then the final check and the first event.
        schedule(after: ticket.minimumDelay) { awaitReadiness(ticket, deadline: ticket.requestedAt.addingTimeInterval(ticket.minimumDelay + readinessWindow)) }
    }

    /// `lock()` and a new paste: whatever the ticket still had to do is dropped — the paste key and
    /// every cursor move. The item stays on the pasteboard.
    static func cancelPending(_ why: String = "cancelled") {
        pending?.cancel(why)
        pending = nil
    }

    // MARK: the timeline

    private static func awaitReadiness(_ t: Ticket, deadline: Date) {
        guard !t.cancelled else { return }
        if frontmostPID() == t.target.processIdentifier {
            awaitModifiersReleased(t, attempts: modifierAttempts)
        } else if now() < deadline {
            schedule(after: modifierPoll) { awaitReadiness(t, deadline: deadline) }
        } else {
            finish(t, "the target app did not come to the front")
        }
    }

    /// The user may still be holding ⌥ from the hot key; a ⌘V sent now would arrive as ⌥⌘V. Held
    /// past the attempts → cancelled, not sent with the modifiers (a different command in most apps).
    private static func awaitModifiersReleased(_ t: Ticket, attempts: Int) {
        guard !t.cancelled else { return }
        if !modifiersHeld() {
            fireNext(t)
        } else if attempts > 0 {
            schedule(after: modifierPoll) { awaitModifiersReleased(t, attempts: attempts - 1) }
        } else {
            finish(t, "modifier keys still held")
        }
    }

    /// The final check, then one balanced key-down/key-up pair to the target's process.
    private static func fireNext(_ t: Ticket) {
        guard !t.cancelled, !t.actions.isEmpty else { if pending === t { pending = nil }; return }
        if let g = gate, !g(t.generation) { return finish(t, "Keepit was locked meanwhile") }
        if t.target.isTerminated { return finish(t, "the target app quit") }
        if frontmostPID() != t.target.processIdentifier { return finish(t, "another app is in front") }
        if (changeCountForTesting?() ?? NSPasteboard.general.changeCount) != t.expectedChangeCount { return finish(t, "the pasteboard was written by someone else") }
        if modifiersHeld() { return finish(t, "modifier keys held") }
        let action = t.actions.removeFirst()
        post(action.key, to: t.target.processIdentifier)
        guard let next = t.actions.first else { if pending === t { pending = nil }; return }
        schedule(after: next.delay) { fireNext(t) }
    }

    private static func finish(_ t: Ticket, _ why: String) {
        t.cancel(why)
        if pending === t { pending = nil }
    }

    private static func frontmostPID() -> pid_t? {
        frontmostPIDForTesting?() ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
    }
    private static func modifiersHeld() -> Bool {
        if let test = modifiersHeldForTesting { return test() }
        return !NSEvent.modifierFlags.intersection([.command, .option, .control, .shift, .function]).isEmpty
    }
    private static func now() -> Date { nowForTesting?() ?? Date() }
    private static func schedule(after delay: TimeInterval, _ body: @escaping () -> Void) {
        if let test = scheduleForTesting { test(delay, body); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: body)
    }

    /// One key-down/key-up pair, posted together to one process (`CGEvent.postToPid`): it addresses
    /// the event, it does not confirm that the app handled it. Never posted to the session tap.
    private static func post(_ k: PasteKey, to pid: pid_t) {
        if let sink = eventSinkForTesting { sink(k, pid); return }
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
        down.postToPid(pid)
        up.postToPid(pid)
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

extension NSRunningApplication: PasteTarget {
    func bringToFront() { activate(options: []) }
}
