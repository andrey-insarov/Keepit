import Carbon.HIToolbox
import Foundation

/// System-wide hot keys via Carbon RegisterEventHotKey — the macOS counterpart of RegisterHotKey().
/// Carbon hot keys don't need the Accessibility permission (unlike CGEvent taps).
final class HotKeyManager {
    /// Return true to swallow hot keys for the moment (a menu of ours is tracking).
    var isSuppressed: () -> Bool = { false }
    private var handlers: [UInt32: () -> Void] = [:]
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
                // While one of our menus is open the same combination is also a menu key equivalent,
                // which AppKit fires itself — don't run the action twice.
                if manager.isSuppressed() { return noErr }
                DispatchQueue.main.async { h() }
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
    @discardableResult
    func register(_ hotKey: HotKey, handler: @escaping () -> Void) -> Bool {
        let id = nextId
        nextId += 1
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hkID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let r = ref else {
            NSLog("Keepit: RegisterEventHotKey failed for \(hotKey.displayString): \(status)")
            return false
        }
        refs[id] = r
        handlers[id] = handler
        return true
    }

    func unregisterAll() {
        for (_, r) in refs { UnregisterEventHotKey(r) }
        refs.removeAll()
        handlers.removeAll()
    }
}
