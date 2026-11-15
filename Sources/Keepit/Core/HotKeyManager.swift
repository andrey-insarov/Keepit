import Carbon.HIToolbox
import Foundation

/// System-wide hot keys via Carbon RegisterEventHotKey — the macOS counterpart of RegisterHotKey().
/// Carbon hot keys don't need the Accessibility permission (unlike CGEvent taps).
final class HotKeyManager {
    /// While a menu of ours is tracking, the system still turns the registered combination into a hot-key
    /// event and never delivers the key to the menu, so AppKit cannot run the item's key equivalent itself
    /// (H-8). The app answers true when it has routed or dropped the press because a menu is open;
    /// false means no menu is open and the hot key runs as usual.
    var whileMenuOpen: (HotKey) -> Bool = { _ in false }
    /// Tests: decide registrations without touching Carbon (the test process never holds a system hot key).
    var registrationOverrideForTesting: ((HotKey) -> Bool)?
    private var handlers: [UInt32: (run: () -> Void, immediate: Bool)] = [:]
    private var hotKeysById: [UInt32: HotKey] = [:]
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
                // While one of our menus is open the press belongs to the menu: route it there (H-8).
                if let hk = manager.hotKeysById[hkID.id], manager.whileMenuOpen(hk) { return noErr }
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
        if let override = registrationOverrideForTesting { return override(hotKey) }
        let id = nextId
        nextId += 1
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
    }
}
