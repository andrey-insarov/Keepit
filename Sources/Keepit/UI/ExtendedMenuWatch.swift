import AppKit

/// "Hold ⌘ for the extended menu": while a history menu is open, a background timer watches the modifier
/// flags (menu tracking starves ordinary timers and local event monitors). When ⌘ goes down every history
/// row gets its action submenu (AppKit shows ▸ and opens it on hover or →); when ⌘ goes up the submenus
/// are removed again — after the open one, if any, has closed.
final class ExtendedMenuWatch {
    static let shared = ExtendedMenuWatch()
    static let modifier: NSEvent.ModifierFlags = .command

    private var timer: DispatchSourceTimer?
    private weak var menu: NSMenu?
    private var build: ((NSMenuItem) -> NSMenu?)?
    private var wasHeld = false
    private var attached = false
    private var openSubmenus = 0
    private var detachPending = false

    func watch(_ menu: NSMenu, build: @escaping (NSMenuItem) -> NSMenu?) {
        stop()
        self.menu = menu
        self.build = build
        wasHeld = Self.held
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        t.schedule(deadline: .now() + 0.03, repeating: 0.03)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop(_ menu: NSMenu? = nil) {
        if let menu, self.menu !== menu, self.menu != nil { return }
        timer?.cancel(); timer = nil
        self.menu = nil; build = nil
        attached = false; openSubmenus = 0; detachPending = false
    }

    /// Action submenus report their open/close so detaching can wait for them.
    func submenuOpened() { openSubmenus += 1 }
    func submenuClosed() {
        openSubmenus = max(0, openSubmenus - 1)
        if openSubmenus == 0, detachPending { detachPending = false; detach() }
    }

    private static var held: Bool {
        NSEvent.modifierFlags.intersection([.command, .shift, .option, .control]) == modifier
    }

    private func poll() {
        let held = Self.held
        guard held != wasHeld else { return }
        wasHeld = held
        RunLoop.main.perform(inModes: [.eventTracking, .default, .modalPanel]) { [weak self] in
            guard let self else { return }
            if held { self.attach() } else if self.openSubmenus > 0 { self.detachPending = true } else { self.detach() }
        }
    }

    private func attach() {
        guard !attached, let menu, let build else { return }
        attached = true
        for mi in menu.items where mi.tag == MenuBuilder.historyTag && mi.isEnabled && !mi.isAlternate && mi.submenu == nil {
            mi.submenu = build(mi)
            mi.view?.needsDisplay = true
        }
    }

    private func detach() {
        guard attached, let menu else { return }
        attached = false
        for mi in menu.items where mi.tag == MenuBuilder.historyTag && mi.submenu != nil {
            mi.submenu = nil
            mi.view?.needsDisplay = true
        }
    }
}
