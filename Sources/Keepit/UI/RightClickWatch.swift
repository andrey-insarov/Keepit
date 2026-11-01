import AppKit

/// Menu tracking swallows right clicks before they reach item views, so detect them by polling the mouse
/// buttons from a background timer (readable from any thread) and hop back into the tracking run loop.
final class RightClickWatch {
    static let shared = RightClickWatch()
    private var timer: DispatchSourceTimer?
    private weak var menu: NSMenu?
    private var fire: ((NSMenuItem) -> Void)?
    private var wasDown = false

    func watch(_ menu: NSMenu, onRightClick: @escaping (NSMenuItem) -> Void) {
        stop()
        self.menu = menu
        fire = onRightClick
        wasDown = NSEvent.pressedMouseButtons & 2 != 0
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        t.schedule(deadline: .now() + 0.03, repeating: 0.03)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop(_ menu: NSMenu? = nil) {
        if let menu, self.menu !== menu, self.menu != nil { return }
        timer?.cancel(); timer = nil
        self.menu = nil; fire = nil
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
