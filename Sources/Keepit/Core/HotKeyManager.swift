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
        if let override = registrationOverrideForTesting {
            guard override(hotKey) else { return false }
            handlers[id] = (handler, immediate)                 // bookkeeping as in the real path, no Carbon
            hotKeysById[id] = hotKey
            if isSuspendedForMenu, !immediate { suspendedForMenu.insert(id) }
            return true
        }
        // Registered while a menu of ours is tracking (a layout change re-registers): the registration
        // waits for the menu to close, like the ones lifted for it. Carbon is not asked, so a refusal
        // surfaces only at resume; the next pass recomputes the status.
        if isSuspendedForMenu, !immediate {
            handlers[id] = (handler, immediate)
            hotKeysById[id] = hotKey
            suspendedForMenu.insert(id)
            return true
        }
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hkID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let r = ref else {
            Log.system.error("RegisterEventHotKey failed for \(hotKey.displayString): \(status)")
            return false
        }
        refs[id] = r
        handlers[id] = (handler, immediate)
        hotKeysById[id] = hotKey
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
    /// combination into a hot-key event that is queued until the menu closes, and the menu would never
    /// see the key; so the registrations are lifted for the duration and the keys reach the menu as key
    /// events, which AppKit matches against the items' key equivalents. The `immediate` handler (the lock
    /// key) keeps its registration: it is not a menu item, and its queued delivery after the menu closes
    /// is the behaviour it always had.
    func suspendForMenu() {
        guard !isSuspendedForMenu else { return }
        isSuspendedForMenu = true
        for (id, h) in handlers where !h.immediate {
            suspendedForMenu.insert(id)
            if let r = refs.removeValue(forKey: id) { UnregisterEventHotKey(r) }
        }
    }

    /// The last menu of ours closed: the lifted registrations come back under their ids. A combination
    /// another app took meanwhile is logged; the next `registerHotKeys()` pass recomputes its status.
    func resumeAfterMenu() {
        guard isSuspendedForMenu else { return }
        isSuspendedForMenu = false
        let ids = suspendedForMenu.sorted()
        suspendedForMenu.removeAll()
        for id in ids {
            guard let hk = hotKeysById[id], handlers[id] != nil else { continue }
            resumedCountForTesting += 1
            if registrationOverrideForTesting != nil { continue }
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: Self.signature, id: id)
            let status = RegisterEventHotKey(hk.keyCode, hk.modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let r = ref { refs[id] = r }
            else { Log.system.error("RegisterEventHotKey failed after a menu for \(hk.displayString, privacy: .public): \(status)") }
        }
    }
}
