import AppKit

/// Right clicks on history rows. Menu tracking consumes right clicks before item views see them, so while
/// a history menu is open a listen+swallow CGEvent tap catches the press (needs Accessibility, which the
/// app has whenever it can paste). Without the tap, a background timer polls the mouse buttons instead.
final class RightClickWatch {
    static let shared = RightClickWatch()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: DispatchSourceTimer?
    private weak var menu: NSMenu?
    private var fire: ((NSMenuItem) -> Void)?
    private var wasDown = false

    func watch(_ menu: NSMenu, onRightClick: @escaping (NSMenuItem) -> Void) {
        stop()
        self.menu = menu
        fire = onRightClick
        if !installTap() { startPolling() }
    }

    func stop(_ menu: NSMenu? = nil) {
        if let menu, self.menu !== menu, self.menu != nil { return }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes); runLoopSource = nil }
        if let t = tap { CGEvent.tapEnable(tap: t, enable: false); tap = nil }
        timer?.cancel(); timer = nil
        self.menu = nil; fire = nil
    }

    // MARK: Event tap

    private func installTap() -> Bool {
        guard Paster.isTrusted() else { return false }
        let mask = (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: CGEventMask(mask), callback: { _, type, event, info in
            let watch = Unmanaged<RightClickWatch>.fromOpaque(info!).takeUnretainedValue()
            return watch.handle(type: type, event: event)
        }, userInfo: me) else { return false }
        tap = t
        runLoopSource = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    /// Runs on the main thread (the tap source is on the main run loop, common modes include tracking).
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let menu, let item = menu.highlightedItem, item.tag == MenuBuilder.historyTag, item.isEnabled else {
            return Unmanaged.passUnretained(event)
        }
        if type == .rightMouseDown {
            let f = fire
            DispatchQueue.main.async { f?(item) }
        }
        return nil      // swallowed: the menu never sees the right click
    }

    // MARK: Polling fallback

    private func startPolling() {
        wasDown = NSEvent.pressedMouseButtons & 2 != 0
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        t.schedule(deadline: .now() + 0.01, repeating: 0.01)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        let down = NSEvent.pressedMouseButtons & 2 != 0
        defer { wasDown = down }
        guard down, !wasDown else { return }
        RunLoop.main.perform(inModes: [.eventTracking, .default, .modalPanel]) { [weak self] in
            guard let self, let menu = self.menu, let item = menu.highlightedItem,
                  item.tag == MenuBuilder.historyTag, item.isEnabled else { return }
            self.fire?(item)
        }
    }
}
