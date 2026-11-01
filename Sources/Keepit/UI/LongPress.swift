import AppKit

/// Detects a long press (mouse button held ~0.5 s without moving) on a history item of an open menu.
///
/// Menu tracking runs its own event loop, so neither local event monitors nor ordinary timers are
/// reliable there. Instead a GCD timer polls `NSEvent.pressedMouseButtons` / `mouseLocation` (both
/// readable from any thread) and hops back to the main run loop in the tracking modes to fire.
final class LongPress {
    static let shared = LongPress()
    static let duration: TimeInterval = 0.5
    static let slop: CGFloat = 4
    private static let tick: TimeInterval = 0.04

    private var timer: DispatchSourceTimer?
    private weak var menu: NSMenu?
    private var fire: ((NSMenuItem) -> Void)?
    private var downSince: Date?
    private var origin = NSPoint.zero
    private var consumed = false
    /// Called (on the main run loop) when the button is released after a long press fired.
    var onRelease: (() -> Void)?

    func watch(_ menu: NSMenu, onLongPress: @escaping (NSMenuItem) -> Void) {
        stopAll()
        self.menu = menu
        self.fire = onLongPress
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        t.schedule(deadline: .now() + Self.tick, repeating: Self.tick)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop(_ menu: NSMenu) {
        guard self.menu === menu || self.menu == nil else { return }
        stopAll()
    }

    private func stopAll() {
        timer?.cancel()
        timer = nil
        menu = nil
        fire = nil
        onRelease = nil
        downSince = nil
        consumed = false
    }

    /// Runs on the background queue; only reads global input state.
    private func poll() {
        let down = NSEvent.pressedMouseButtons & 1 != 0
        let p = NSEvent.mouseLocation
        if !down {
            downSince = nil
            if consumed {
                consumed = false
                RunLoop.main.perform(inModes: [.eventTracking, .default, .modalPanel]) { [weak self] in self?.onRelease?() }
            }
            return
        }
        guard let since = downSince else {
            downSince = Date()
            origin = p
            return
        }
        if abs(p.x - origin.x) > Self.slop || abs(p.y - origin.y) > Self.slop {
            downSince = Date()      // moved: restart the clock from here
            origin = p
            return
        }
        guard !consumed, Date().timeIntervalSince(since) >= Self.duration else { return }
        consumed = true
        RunLoop.main.perform(inModes: [.eventTracking, .default, .modalPanel]) { [weak self] in
            self?.fired()
        }
    }

    /// Move the pointer by one pixel and back so the menu re-evaluates the highlighted item (opens a submenu
    /// attached while tracking). Needs Accessibility; silently does nothing without it.
    static func nudgePointer() {
        guard Paster.isTrusted(), let cur = CGEvent(source: nil)?.location else { return }
        let down = NSEvent.pressedMouseButtons & 1 != 0
        let type: CGEventType = down ? .leftMouseDragged : .mouseMoved
        for dx: CGFloat in [1, 0] {
            let p = CGPoint(x: cur.x + dx, y: cur.y)
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
    }

    private func fired() {
        guard let menu, let item = menu.highlightedItem, item.tag == MenuBuilder.historyTag, item.isEnabled else { return }
        fire?(item)
    }
}
