import Carbon.HIToolbox
import Foundation

/// System-wide hot keys via Carbon RegisterEventHotKey — the macOS counterpart of RegisterHotKey().
/// Carbon hot keys don't need the Accessibility permission (unlike CGEvent taps).
final class HotKeyManager {
    /// Tests: decide registrations without touching Carbon (the test process never holds a system hot key).
    var registrationOverrideForTesting: ((HotKey) -> Bool)?
    private var handlers: [UInt32: (run: () -> Void, immediate: Bool)] = [:]
    private var hotKeysById: [UInt32: HotKey] = [:]
    /// Ids whose Carbon registration is lifted while a menu of ours is tracking (H-9).
    private var suspendedForMenu: Set<UInt32> = []
    /// True between `suspendForMenu()` and `resumeAfterMenu()`.
    private(set) var isSuspendedForMenu = false
    /// Tests: how many registrations `resumeAfterMenu()` has redone.
    private(set) var resumedCountForTesting = 0
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextId: UInt32 = 1
    private static let signature: OSType = 0x4B50_4954  // 'KPIT'

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            let err = GetEventParameter(event,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hkID)
            guard err == noErr, hkID.signature == HotKeyManager.signature else {
                return OSStatus(eventNotHandledErr)
            }
            if let h = manager.handlers[hkID.id] {
                if h.immediate {
                    // Runs inside a modal loop too (modalPanel is a common mode): a main-queue block
                    // would wait for the block that opened the dialog to return (auditor's P2 on PR #28).
                    RunLoop.main.perform(inModes: [.modalPanel, .default, .common], block: h.run)
                } else {
                    DispatchQueue.main.async(execute: h.run)
                }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }, 1, &spec, selfPtr, &eventHandler)
    }

    deinit {
        unregisterAll()
        if let h = eventHandler { RemoveEventHandler(h) }
    }

    /// Returns false if the combination is taken by another app or the system.
    /// - Parameter immediate: deliver even while a modal dialog is up (the lock key); other handlers
    ///   wait for the main queue, so they never open a dialog over another.
    @discardableResult
    func register(_ hotKey: HotKey, immediate: Bool = false, handler: @escaping () -> Void) -> Bool {
        let id = nextId
        nextId += 1
        // Registered while a menu of ours is tracking (a layout change re-registers): the registration
        // waits for the menu to close, like the ones lifted for it. Carbon is not asked, so a refusal
        // surfaces at `resumeAfterMenu()`, whose caller recomputes the statuses (H-9).
        if isSuspendedForMenu {
            handlers[id] = (handler, immediate)
            hotKeysById[id] = hotKey
            suspendedForMenu.insert(id)
            return true
        }
        guard attempt(hotKey, id: id) else { return false }
        handlers[id] = (handler, immediate)
        hotKeysById[id] = hotKey
        return true
    }

    /// One Carbon registration under `id` (or the test override's answer); the ref is kept on success.
    private func attempt(_ hotKey: HotKey, id: UInt32) -> Bool {
        if let override = registrationOverrideForTesting { return override(hotKey) }   // no Carbon in tests
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let r = ref else {
            Log.system.error("RegisterEventHotKey failed for \(hotKey.displayString, privacy: .public): \(status)")
            return false
        }
        refs[id] = r
        return true
    }

    func unregisterAll() {
        for (_, r) in refs { UnregisterEventHotKey(r) }
        refs.removeAll()
        handlers.removeAll()
        hotKeysById.removeAll()
        suspendedForMenu.removeAll()         // a menu still tracking keeps isSuspendedForMenu: new registrations wait too
    }

    /// A menu of ours is about to track (H-9). While it does, the window server would turn a registered
    /// combination into a hot-key event that is not delivered before the menu closes, and the menu would
    /// never see the key; so every registration is lifted for the duration and the keys reach the menu as
    /// key events, which AppKit matches against the items' key equivalents. The lock key too: each menu
    /// of ours carries its combination as an item, so a lock pressed over a menu locks at once (SEC05).
    func suspendForMenu() {
        guard !isSuspendedForMenu else { return }
        isSuspendedForMenu = true
        for id in handlers.keys {
            suspendedForMenu.insert(id)
            if let r = refs.removeValue(forKey: id) { UnregisterEventHotKey(r) }
        }
    }

    /// The last menu of ours closed: the lifted registrations come back under their ids. Returns the
    /// combinations Carbon refused this time (taken by another app meanwhile, or first asked for now);
    /// the caller recomputes the statuses when the list is not empty, so no shortcut stays shown as
    /// registered while it is not.
    @discardableResult
    func resumeAfterMenu() -> [HotKey] {
        guard isSuspendedForMenu else { return [] }
        isSuspendedForMenu = false
        let ids = suspendedForMenu.sorted()
        suspendedForMenu.removeAll()
        var refused: [HotKey] = []
        for id in ids {
            guard let hk = hotKeysById[id], handlers[id] != nil else { continue }
            resumedCountForTesting += 1
            if !attempt(hk, id: id) {
                Log.system.error("RegisterEventHotKey failed after a menu for \(hk.displayString, privacy: .public)")
                handlers[id] = nil
                hotKeysById[id] = nil
                refused.append(hk)
            }
        }
        return refused
    }
}
