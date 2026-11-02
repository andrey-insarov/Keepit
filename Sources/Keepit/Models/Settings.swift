import AppKit
import Foundation
import Carbon.HIToolbox

/// Global hot key (Carbon key code + Carbon modifier mask).
struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // cmdKey | shiftKey | optionKey | controlKey

    static func option(_ key: Int) -> HotKey { HotKey(keyCode: UInt32(key), modifiers: UInt32(optionKey)) }
    static let optionC = option(kVK_ANSI_C)
    static let optionT = option(kVK_ANSI_T)
    static let optionM = option(kVK_ANSI_M)
    static let optionShiftV = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | shiftKey))
    static func optionShift(_ key: Int) -> HotKey { HotKey(keyCode: UInt32(key), modifiers: UInt32(optionKey | shiftKey)) }
    /// Letters of the "actions on the latest item" hot keys (<mods> + letter), shared by the menu and the registry.
    enum LatestAction: CaseIterable {
        case plain, upper, lower, title, sentence, trim, singleLine, addToTemplates, delete
        var keyChar: String {
            switch self {
            case .plain: return "v"; case .upper: return "u"; case .lower: return "l"; case .title: return "t"
            case .sentence: return "s"; case .trim: return "w"; case .singleLine: return "j"
            case .addToTemplates: return "a"; case .delete: return "\u{8}"
            }
        }
        var keyCode: UInt32 {
            switch self {
            case .plain: return UInt32(kVK_ANSI_V); case .upper: return UInt32(kVK_ANSI_U); case .lower: return UInt32(kVK_ANSI_L)
            case .title: return UInt32(kVK_ANSI_T); case .sentence: return UInt32(kVK_ANSI_S); case .trim: return UInt32(kVK_ANSI_W)
            case .singleLine: return UInt32(kVK_ANSI_J); case .addToTemplates: return UInt32(kVK_ANSI_A); case .delete: return UInt32(kVK_Delete)
            }
        }
        var transform: TextTransform? {
            switch self {
            case .upper: return .upper; case .lower: return .lower; case .title: return .title
            case .sentence: return .sentence; case .trim: return .trim; case .singleLine: return .singleLine
            default: return nil
            }
        }
    }
    /// Default modifier set for "paste item N by number" (⌃⌥ + 1–9, 0).
    static let controlOption = UInt32(controlKey | optionKey)

    /// Key codes of 1…9, 0 — the digits used for direct paste.
    static let digitKeyCodes: [UInt32] = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                          kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0].map { UInt32($0) }

    /// The same combination as an NSMenuItem key equivalent, so the menu can show global hot keys
    /// next to their commands. nil for keys AppKit cannot display (F13+, exotic codes).
    var menuKeyEquivalent: (key: String, mask: NSEvent.ModifierFlags)? {
        guard let key = KeyCodes.menuCharacter(for: UInt16(keyCode)) else { return nil }
        var mask: NSEvent.ModifierFlags = []
        if modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        if modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        return (key, mask)
    }

    static func modifierString(_ modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + KeyCodes.name(for: UInt16(keyCode))
    }
}

/// Key stroke sent to the target application to paste; can be overridden per application (`Settings.pasteKeys`).
struct PasteKey: Codable, Equatable {
    var keyCode: UInt16 = UInt16(kVK_ANSI_V)
    var command = true
    var shift = false
    var option = false
    var control = false

    static let commandV = PasteKey()
    /// Terminals usually paste with ⌘V too, but some apps (e.g. Emacs ports) differ; kept as an example.
    static let shiftCommandV = PasteKey(keyCode: UInt16(kVK_ANSI_V), command: true, shift: true)
}

/// Persisted user options.
struct Settings: Codable, Equatable {
    // [history]
    var historyMax = 1000          // text & file items kept (~10–30 MB; images have their own, smaller ring)
    var historyImageMax = 30       // image items kept (separate ring)
    var historyMaxAge: TimeInterval = 0   // seconds; items older than this are forgotten (0 = never)
    var historySave = true         // history.save
    var overlapCheck = true        // history.overlap_check — dedupe identical entries
    var moveToTopOnPaste = true    // pasted item moves to the top
    var maxImageBytes = 10 * 1024 * 1024
    var maxTextBytes = 2 * 1024 * 1024          // larger clipboard texts are not recorded
    var maxFileListEntries = 1_000              // larger file selections are not recorded
    var maxHistoryBytes = 256 * 1024 * 1024     // total size of all history items; oldest are dropped
    var menuMaxItems = 60                       // history entries shown in the popup menu
    var pollInterval: Double = 0.3 // macOS has no clipboard change notification, so we poll

    // [menu]
    var titleLength = 60           // chars
    var showThumbnails = true      // menu.show_bitmap
    var thumbnailSize = 40         // thumbnail height in menus (width up to 4×)
    var showTooltips = true        // menu.show_tooltip
    var numberItems = true         // accelerator digits/letters like "&1 text"
    var searchInMenu = true        // search field at the top of the history menu (type to filter)
    var showPreview = true         // floating preview panel next to the highlighted history item
    var showSourceIcons = true     // icon of the app the item was copied from, in the history menu
    var showAtCaret = true         // action.caret — pop the menu at the text cursor if we can find it

    // [action]
    var historyHotKey = HotKey.optionM
    var templateHotKey = HotKey.optionT
    var previousHotKey: HotKey? = HotKey.optionShiftV   // paste history item #2 directly, no menu
    var numberPasteModifiers: UInt32? = HotKey.controlOption   // <mods>+1…9,0 paste item N; nil = off
    var latestActionModifiers: UInt32? = HotKey.controlOption  // <mods>+V/U/L/T/S/W/J/A/⌫ act on item #1; nil = off
    var lockHotKey: HotKey? = HotKey.option(kVK_ANSI_L)         // global "Lock Keepit"
    var pauseHotKey: HotKey? = HotKey.option(kVK_ANSI_P)        // global "Pause recording for 10 minutes"
    var viewerHotKey: HotKey? = HotKey.option(kVK_ANSI_E)       // global "Viewer…" (was ⌥V before 2.10; ⌥V now pastes from the queue)
    var preferencesHotKey: HotKey? = HotKey.option(kVK_ANSI_S)  // global "Preferences…"
    var clearHistoryHotKey: HotKey? = HotKey.option(kVK_ANSI_C) // global "Clear History"
    var quitHotKey: HotKey? = HotKey.option(kVK_ANSI_Q)         // global "Quit Keepit"
    var pasteAfterSelect = true    // action.paste

    // [queue] — serial copy-and-paste
    var queueHotKey: HotKey? = HotKey.option(kVK_ANSI_R)         // start / stop the paste queue ("Record")
    var queuePasteHotKey: HotKey? = HotKey.option(kVK_ANSI_V)    // paste the next queued item
    var queuePasteAllHotKey: HotKey? = HotKey.optionShift(kVK_ANSI_R) // paste everything left, joined
    var queueTimeout: Double = 120 // seconds without a copy or a paste before the queue switches off (0 = never)
    var queueSeparator = "\n"      // between items for "paste all"

    // [sendkey]
    var pasteDelay: Double = 0.08  // seconds between activating target app and sending the key
    var pasteKeys: [String: PasteKey] = [:]   // bundle id -> paste key override

    // [window_filter] — apps whose copies are ignored (bundle ids)
    var ignoreApps: [String] = [
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
    ]
    var ignoreConcealed = true     // honour org.nspasteboard.ConcealedType (password managers)

    var launchAtLogin = true           // new installs start at login; existing settings files keep their value

    /// Lock Keepit (wipe key, unload data) when the screen locks or the Mac sleeps. Only matters with a password set.
    var lockWithScreen = true
    /// Unlock with Touch ID instead of typing the password (password stays as fallback).
    var biometricUnlock = false
    /// Let Touch ID stand in for the current password when changing it (off = always type the old password).
    var biometricPasswordChange = true

    enum CodingKeys: String, CodingKey {
        case historyMax
        case historyImageMax
        case historyMaxAge
        case historySave
        case overlapCheck
        case moveToTopOnPaste
        case maxImageBytes
        case pollInterval
        case titleLength
        case showThumbnails
        case thumbnailSize
        case showTooltips
        case numberItems
        case searchInMenu
        case showPreview
        case showSourceIcons
        case showAtCaret
        case historyHotKey
        case templateHotKey
        case previousHotKey
        case numberPasteModifiers
        case latestActionModifiers
        case lockHotKey
        case pauseHotKey
        case viewerHotKey
        case preferencesHotKey
        case clearHistoryHotKey
        case quitHotKey
        case pasteAfterSelect
        case queueHotKey
        case queuePasteHotKey
        case queuePasteAllHotKey
        case queueTimeout
        case queueSeparator
        case pasteDelay
        case pasteKeys
        case ignoreApps
        case ignoreConcealed
        case launchAtLogin
        case lockWithScreen
        case biometricUnlock
        case biometricPasswordChange
        case maxTextBytes
        case maxFileListEntries
        case maxHistoryBytes
        case menuMaxItems
    }

    init() {}

    // Tolerant decoding: any missing key falls back to its default, so old settings files keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        historyMax       = try c.decodeIfPresent(Int.self,    forKey: .historyMax)       ?? d.historyMax
        historyImageMax  = try c.decodeIfPresent(Int.self,    forKey: .historyImageMax)  ?? d.historyImageMax
        historyMaxAge    = try c.decodeIfPresent(Double.self, forKey: .historyMaxAge)    ?? d.historyMaxAge
        historySave      = try c.decodeIfPresent(Bool.self,   forKey: .historySave)      ?? d.historySave
        overlapCheck     = try c.decodeIfPresent(Bool.self,   forKey: .overlapCheck)     ?? d.overlapCheck
        moveToTopOnPaste = try c.decodeIfPresent(Bool.self,   forKey: .moveToTopOnPaste) ?? d.moveToTopOnPaste
        maxImageBytes    = try c.decodeIfPresent(Int.self,    forKey: .maxImageBytes)    ?? d.maxImageBytes
        pollInterval     = try c.decodeIfPresent(Double.self, forKey: .pollInterval)     ?? d.pollInterval
        titleLength      = try c.decodeIfPresent(Int.self,    forKey: .titleLength)      ?? d.titleLength
        showThumbnails   = try c.decodeIfPresent(Bool.self,   forKey: .showThumbnails)   ?? d.showThumbnails
        thumbnailSize    = try c.decodeIfPresent(Int.self,    forKey: .thumbnailSize)    ?? d.thumbnailSize
        showTooltips     = try c.decodeIfPresent(Bool.self,   forKey: .showTooltips)     ?? d.showTooltips
        numberItems      = try c.decodeIfPresent(Bool.self,   forKey: .numberItems)      ?? d.numberItems
        searchInMenu     = try c.decodeIfPresent(Bool.self,   forKey: .searchInMenu)     ?? d.searchInMenu
        showPreview      = try c.decodeIfPresent(Bool.self,   forKey: .showPreview)      ?? d.showPreview
        showSourceIcons  = try c.decodeIfPresent(Bool.self,   forKey: .showSourceIcons)  ?? d.showSourceIcons
        showAtCaret      = try c.decodeIfPresent(Bool.self,   forKey: .showAtCaret)      ?? d.showAtCaret
        historyHotKey    = try c.decodeIfPresent(HotKey.self, forKey: .historyHotKey)    ?? d.historyHotKey
        templateHotKey   = try c.decodeIfPresent(HotKey.self, forKey: .templateHotKey)   ?? d.templateHotKey
        previousHotKey   = c.contains(.previousHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .previousHotKey) : d.previousHotKey
        numberPasteModifiers = c.contains(.numberPasteModifiers) ? try c.decodeIfPresent(UInt32.self, forKey: .numberPasteModifiers) : d.numberPasteModifiers
        latestActionModifiers = c.contains(.latestActionModifiers) ? try c.decodeIfPresent(UInt32.self, forKey: .latestActionModifiers) : d.latestActionModifiers
        // Optional keys: absent → default, explicit null → off.
        lockHotKey       = c.contains(.lockHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .lockHotKey) : d.lockHotKey
        pauseHotKey      = c.contains(.pauseHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .pauseHotKey) : d.pauseHotKey
        viewerHotKey     = c.contains(.viewerHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .viewerHotKey) : d.viewerHotKey
        preferencesHotKey = c.contains(.preferencesHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .preferencesHotKey) : d.preferencesHotKey
        clearHistoryHotKey = c.contains(.clearHistoryHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .clearHistoryHotKey) : d.clearHistoryHotKey
        quitHotKey       = c.contains(.quitHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .quitHotKey) : d.quitHotKey
        queueHotKey      = c.contains(.queueHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .queueHotKey) : d.queueHotKey
        queuePasteHotKey = c.contains(.queuePasteHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .queuePasteHotKey) : d.queuePasteHotKey
        queuePasteAllHotKey = c.contains(.queuePasteAllHotKey) ? try c.decodeIfPresent(HotKey.self, forKey: .queuePasteAllHotKey) : d.queuePasteAllHotKey
        queueTimeout     = try c.decodeIfPresent(Double.self, forKey: .queueTimeout)     ?? d.queueTimeout
        queueSeparator   = try c.decodeIfPresent(String.self, forKey: .queueSeparator)   ?? d.queueSeparator
        // 2.10: ⌥V moved from the Viewer to the paste queue. A settings file from before the queue
        // existed keeps its Viewer on ⌥V only if the user had chosen it; the old default moves to ⌥E.
        if !c.contains(.queuePasteHotKey), viewerHotKey == HotKey.option(kVK_ANSI_V) {
            viewerHotKey = HotKey.option(kVK_ANSI_E)
            if isTaken(viewerHotKey) { viewerHotKey = nil }
        }
        // New defaults must not shadow keys an older settings file already uses (history was ⌥C before 2.9.1).
        for key in [CodingKeys.viewerHotKey, .preferencesHotKey, .clearHistoryHotKey, .pauseHotKey, .lockHotKey, .quitHotKey,
                    .queueHotKey, .queuePasteHotKey, .queuePasteAllHotKey]
        where !c.contains(key) {
            switch key {
            case .viewerHotKey:       if isTaken(viewerHotKey) { viewerHotKey = nil }
            case .preferencesHotKey:  if isTaken(preferencesHotKey) { preferencesHotKey = nil }
            case .clearHistoryHotKey: if isTaken(clearHistoryHotKey) { clearHistoryHotKey = nil }
            case .pauseHotKey:        if isTaken(pauseHotKey) { pauseHotKey = nil }
            case .lockHotKey:         if isTaken(lockHotKey) { lockHotKey = nil }
            case .quitHotKey:         if isTaken(quitHotKey) { quitHotKey = nil }
            case .queueHotKey:        if isTaken(queueHotKey) { queueHotKey = nil }
            case .queuePasteHotKey:   if isTaken(queuePasteHotKey) { queuePasteHotKey = nil }
            case .queuePasteAllHotKey: if isTaken(queuePasteAllHotKey) { queuePasteAllHotKey = nil }
            default: break
            }
        }
        pasteAfterSelect = try c.decodeIfPresent(Bool.self,   forKey: .pasteAfterSelect) ?? d.pasteAfterSelect
        pasteDelay       = try c.decodeIfPresent(Double.self, forKey: .pasteDelay)       ?? d.pasteDelay
        pasteKeys        = try c.decodeIfPresent([String: PasteKey].self, forKey: .pasteKeys) ?? d.pasteKeys
        ignoreApps       = try c.decodeIfPresent([String].self, forKey: .ignoreApps)     ?? d.ignoreApps
        ignoreConcealed  = try c.decodeIfPresent(Bool.self,   forKey: .ignoreConcealed)  ?? d.ignoreConcealed
        launchAtLogin    = try c.decodeIfPresent(Bool.self,   forKey: .launchAtLogin)    ?? d.launchAtLogin
        lockWithScreen   = try c.decodeIfPresent(Bool.self,   forKey: .lockWithScreen)   ?? d.lockWithScreen
        biometricUnlock  = try c.decodeIfPresent(Bool.self,   forKey: .biometricUnlock)  ?? d.biometricUnlock
        biometricPasswordChange = try c.decodeIfPresent(Bool.self, forKey: .biometricPasswordChange) ?? d.biometricPasswordChange
        maxTextBytes     = try c.decodeIfPresent(Int.self,    forKey: .maxTextBytes)     ?? d.maxTextBytes
        maxFileListEntries = try c.decodeIfPresent(Int.self,  forKey: .maxFileListEntries) ?? d.maxFileListEntries
        maxHistoryBytes  = try c.decodeIfPresent(Int.self,    forKey: .maxHistoryBytes)  ?? d.maxHistoryBytes
        menuMaxItems     = try c.decodeIfPresent(Int.self,    forKey: .menuMaxItems)     ?? d.menuMaxItems
        clamp()
    }

    /// Explicit encoding so that an optional set to nil (a hot key switched off) is written as `null`
    /// instead of being omitted — an omitted key would come back as its default on the next launch.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(historyMax, forKey: .historyMax)
        try c.encode(historyImageMax, forKey: .historyImageMax)
        try c.encode(historyMaxAge, forKey: .historyMaxAge)
        try c.encode(historySave, forKey: .historySave)
        try c.encode(overlapCheck, forKey: .overlapCheck)
        try c.encode(moveToTopOnPaste, forKey: .moveToTopOnPaste)
        try c.encode(maxImageBytes, forKey: .maxImageBytes)
        try c.encode(pollInterval, forKey: .pollInterval)
        try c.encode(titleLength, forKey: .titleLength)
        try c.encode(showThumbnails, forKey: .showThumbnails)
        try c.encode(thumbnailSize, forKey: .thumbnailSize)
        try c.encode(showTooltips, forKey: .showTooltips)
        try c.encode(numberItems, forKey: .numberItems)
        try c.encode(searchInMenu, forKey: .searchInMenu)
        try c.encode(showPreview, forKey: .showPreview)
        try c.encode(showSourceIcons, forKey: .showSourceIcons)
        try c.encode(showAtCaret, forKey: .showAtCaret)
        try c.encode(historyHotKey, forKey: .historyHotKey)
        try c.encode(templateHotKey, forKey: .templateHotKey)
        try c.encode(previousHotKey, forKey: .previousHotKey)
        try c.encode(numberPasteModifiers, forKey: .numberPasteModifiers)
        try c.encode(latestActionModifiers, forKey: .latestActionModifiers)
        try c.encode(lockHotKey, forKey: .lockHotKey)
        try c.encode(pauseHotKey, forKey: .pauseHotKey)
        try c.encode(viewerHotKey, forKey: .viewerHotKey)
        try c.encode(preferencesHotKey, forKey: .preferencesHotKey)
        try c.encode(clearHistoryHotKey, forKey: .clearHistoryHotKey)
        try c.encode(quitHotKey, forKey: .quitHotKey)
        try c.encode(pasteAfterSelect, forKey: .pasteAfterSelect)
        try c.encode(queueHotKey, forKey: .queueHotKey)
        try c.encode(queuePasteHotKey, forKey: .queuePasteHotKey)
        try c.encode(queuePasteAllHotKey, forKey: .queuePasteAllHotKey)
        try c.encode(queueTimeout, forKey: .queueTimeout)
        try c.encode(queueSeparator, forKey: .queueSeparator)
        try c.encode(pasteDelay, forKey: .pasteDelay)
        try c.encode(pasteKeys, forKey: .pasteKeys)
        try c.encode(ignoreApps, forKey: .ignoreApps)
        try c.encode(ignoreConcealed, forKey: .ignoreConcealed)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(lockWithScreen, forKey: .lockWithScreen)
        try c.encode(biometricUnlock, forKey: .biometricUnlock)
        try c.encode(biometricPasswordChange, forKey: .biometricPasswordChange)
        try c.encode(maxTextBytes, forKey: .maxTextBytes)
        try c.encode(maxFileListEntries, forKey: .maxFileListEntries)
        try c.encode(maxHistoryBytes, forKey: .maxHistoryBytes)
        try c.encode(menuMaxItems, forKey: .menuMaxItems)
    }

    /// True when `hk` is already used by another hot key of these settings (duplicates counted once).
    private func isTaken(_ hk: HotKey?) -> Bool {
        guard let hk else { return false }
        let all: [HotKey?] = [historyHotKey, templateHotKey, previousHotKey, viewerHotKey, preferencesHotKey,
                              clearHistoryHotKey, pauseHotKey, lockHotKey, quitHotKey,
                              queueHotKey, queuePasteHotKey, queuePasteAllHotKey]
        return all.compactMap { $0 }.filter { $0 == hk }.count > 1
    }

    /// Bring every numeric option back into a sane range (hand-edited settings.json, old versions).
    mutating func clamp() {
        historyMax = Limits.clamp(historyMax, 1, Limits.historyMaxCeiling)
        historyImageMax = Limits.clamp(historyImageMax, 1, Limits.historyMaxCeiling)
        historyMaxAge = historyMaxAge <= 0 ? 0 : Limits.clamp(historyMaxAge, 60, 366 * 86400)
        titleLength = Limits.clamp(titleLength, 10, 500)
        thumbnailSize = Limits.clamp(thumbnailSize, 16, 128)
        pollInterval = Limits.clamp(pollInterval, 0.1, 5)
        pasteDelay = Limits.clamp(pasteDelay, 0, 5)
        queueTimeout = queueTimeout <= 0 ? 0 : Limits.clamp(queueTimeout, 10, 3600)
        maxImageBytes = Limits.clamp(maxImageBytes, 64 * 1024, 100 * 1024 * 1024)
        maxTextBytes = Limits.clamp(maxTextBytes, 1024, 50 * 1024 * 1024)
        maxFileListEntries = Limits.clamp(maxFileListEntries, 1, 10_000)
        maxHistoryBytes = Limits.clamp(maxHistoryBytes, 1024 * 1024, 4 * 1024 * 1024 * 1024)
        menuMaxItems = Limits.clamp(menuMaxItems, 1, Limits.menuMaxItemsCeiling)
        ignoreApps = Array(ignoreApps.prefix(Limits.ignoreAppsMaxLines)).map { String($0.prefix(Limits.bundleIdMaxChars)) }
    }

    func pasteKey(for bundleId: String?) -> PasteKey {
        if let id = bundleId, let k = pasteKeys[id] { return k }
        return .commandV
    }
}

/// Human-readable names for virtual key codes (US layout; good enough for display).
enum KeyCodes {
    private static let names: [UInt16: String] = [
        UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C", UInt16(kVK_ANSI_D): "D",
        UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F", UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H",
        UInt16(kVK_ANSI_I): "I", UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
        UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O", UInt16(kVK_ANSI_P): "P",
        UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R", UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T",
        UInt16(kVK_ANSI_U): "U", UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
        UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
        UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2", UInt16(kVK_ANSI_3): "3",
        UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5", UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7",
        UInt16(kVK_ANSI_8): "8", UInt16(kVK_ANSI_9): "9",
        UInt16(kVK_Space): "Space", UInt16(kVK_Return): "↩", UInt16(kVK_Tab): "⇥", UInt16(kVK_Escape): "⎋",
        UInt16(kVK_Delete): "⌫", UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→", UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Home): "↖", UInt16(kVK_End): "↘", UInt16(kVK_PageUp): "⇞", UInt16(kVK_PageDown): "⇟",
        UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_Equal): "=", UInt16(kVK_ANSI_LeftBracket): "[",
        UInt16(kVK_ANSI_RightBracket): "]", UInt16(kVK_ANSI_Backslash): "\\", UInt16(kVK_ANSI_Semicolon): ";",
        UInt16(kVK_ANSI_Quote): "'", UInt16(kVK_ANSI_Comma): ",", UInt16(kVK_ANSI_Period): ".",
        UInt16(kVK_ANSI_Slash): "/", UInt16(kVK_ANSI_Grave): "`",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "key\(keyCode)"
    }

    /// Character for NSMenuItem.keyEquivalent, or nil if AppKit has no representation.
    static func menuCharacter(for keyCode: UInt16) -> String? {
        let special: [UInt16: String] = [
            UInt16(kVK_Space): " ", UInt16(kVK_Return): "\r", UInt16(kVK_Tab): "\t", UInt16(kVK_Escape): "\u{1B}",
            UInt16(kVK_Delete): "\u{8}", UInt16(kVK_ForwardDelete): String(UnicodeScalar(NSDeleteFunctionKey)!),
            UInt16(kVK_LeftArrow): String(UnicodeScalar(NSLeftArrowFunctionKey)!), UInt16(kVK_RightArrow): String(UnicodeScalar(NSRightArrowFunctionKey)!),
            UInt16(kVK_UpArrow): String(UnicodeScalar(NSUpArrowFunctionKey)!), UInt16(kVK_DownArrow): String(UnicodeScalar(NSDownArrowFunctionKey)!),
            UInt16(kVK_Home): String(UnicodeScalar(NSHomeFunctionKey)!), UInt16(kVK_End): String(UnicodeScalar(NSEndFunctionKey)!),
            UInt16(kVK_PageUp): String(UnicodeScalar(NSPageUpFunctionKey)!), UInt16(kVK_PageDown): String(UnicodeScalar(NSPageDownFunctionKey)!),
            UInt16(kVK_F1): String(UnicodeScalar(NSF1FunctionKey)!), UInt16(kVK_F2): String(UnicodeScalar(NSF2FunctionKey)!),
            UInt16(kVK_F3): String(UnicodeScalar(NSF3FunctionKey)!), UInt16(kVK_F4): String(UnicodeScalar(NSF4FunctionKey)!),
            UInt16(kVK_F5): String(UnicodeScalar(NSF5FunctionKey)!), UInt16(kVK_F6): String(UnicodeScalar(NSF6FunctionKey)!),
            UInt16(kVK_F7): String(UnicodeScalar(NSF7FunctionKey)!), UInt16(kVK_F8): String(UnicodeScalar(NSF8FunctionKey)!),
            UInt16(kVK_F9): String(UnicodeScalar(NSF9FunctionKey)!), UInt16(kVK_F10): String(UnicodeScalar(NSF10FunctionKey)!),
            UInt16(kVK_F11): String(UnicodeScalar(NSF11FunctionKey)!), UInt16(kVK_F12): String(UnicodeScalar(NSF12FunctionKey)!),
        ]
        if let s = special[keyCode] { return s }
        if let n = names[keyCode], n.count == 1 { return n.lowercased() }
        return nil
    }
}
