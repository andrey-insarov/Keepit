import AppKit

/// Detects a long press (mouse held ~0.5 s without moving) on a history item of an open menu.
/// Local event monitors keep delivering events while a menu tracks, so this needs no custom item views.
final class LongPress {
    static let shared = LongPress()
    static let duration: TimeInterval = 0.5
    static let slop: CGFloat = 4

    private var monitor: Any?
    private var timer: Timer?
    private var origin = NSPoint.zero
    private weak var menu: NSMenu?
    private var fire: ((NSMenuItem) -> Void)?

    func watch(_ menu: NSMenu, onLongPress: @escaping (NSMenuItem) -> Void) {
        stop(menu)
        self.menu = menu
        self.fire = onLongPress
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .mouseMoved]) { [weak self] e in
            self?.handle(e)
            return e
        }
    }

    func stop(_ menu: NSMenu) {
        guard self.menu === menu || self.menu == nil else { return }
        cancel()
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        self.menu = nil
        fire = nil
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown:
            origin = NSEvent.mouseLocation
            cancel()
            timer = Timer.scheduledTimer(withTimeInterval: Self.duration, repeats: false) { [weak self] _ in self?.fired() }
            RunLoop.current.add(timer!, forMode: .eventTracking)
        case .leftMouseUp:
            cancel()
        case .leftMouseDragged, .mouseMoved:
            let p = NSEvent.mouseLocation
            if abs(p.x - origin.x) > Self.slop || abs(p.y - origin.y) > Self.slop { cancel() }
        default: break
        }
    }

    private func fired() {
        timer = nil
        guard let menu, let item = menu.highlightedItem, item.tag == MenuBuilder.historyTag, item.isEnabled else { return }
        fire?(item)
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
