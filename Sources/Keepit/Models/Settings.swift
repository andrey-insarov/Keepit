import Foundation
import Carbon.HIToolbox

/// Global hot key (Carbon key code + Carbon modifier mask).
/// Mirrors CLCL's `action_info.modifiers / virtkey`.
struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // cmdKey | shiftKey | optionKey | controlKey

    static let optionC = HotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey))
    static let optionT = HotKey(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(optionKey))

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s + KeyCodes.name(for: UInt16(keyCode))
    }
}

/// Key stroke sent to the target application to paste.
/// Mirrors CLCL's `sendkey` section (`def_paste_modifiers`, `def_paste_virtkey`).
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

/// Persisted user options. Field names follow CLCL's ini keys where sensible.
struct Settings: Codable, Equatable {
    // [history]
    var historyMax = 30            // history.max
    var historySave = true         // history.save
    var overlapCheck = true        // history.overlap_check — dedupe identical entries
    var moveToTopOnPaste = true    // CLCL re-adds pasted item at the top
    var maxImageBytes = 10 * 1024 * 1024
    var pollInterval: Double = 0.3 // macOS has no clipboard listener; CLCL used WM_CLIPBOARDUPDATE

    // [menu]
    var titleLength = 60           // chars (CLCL used menu.max_width in px)
    var showThumbnails = true      // menu.show_bitmap
    var thumbnailSize = 32         // menu.bitmap_width / height
    var showTooltips = true        // menu.show_tooltip
    var numberItems = true         // accelerator digits/letters like "&1 text"
    var showAtCaret = true         // action.caret — pop the menu at the text cursor if we can find it

    // [action]
    var historyHotKey = HotKey.optionC
    var templateHotKey = HotKey.optionT
    var pasteAfterSelect = true    // action.paste

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

    var launchAtLogin = false

    /// Lock Keep it (wipe key, unload data) when the screen locks or the Mac sleeps. Only matters with a password set.
    var lockWithScreen = true

    init() {}

    // Tolerant decoding: any missing key falls back to its default, so old settings files keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        historyMax       = try c.decodeIfPresent(Int.self,    forKey: .historyMax)       ?? d.historyMax
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
        showAtCaret      = try c.decodeIfPresent(Bool.self,   forKey: .showAtCaret)      ?? d.showAtCaret
        historyHotKey    = try c.decodeIfPresent(HotKey.self, forKey: .historyHotKey)    ?? d.historyHotKey
        templateHotKey   = try c.decodeIfPresent(HotKey.self, forKey: .templateHotKey)   ?? d.templateHotKey
        pasteAfterSelect = try c.decodeIfPresent(Bool.self,   forKey: .pasteAfterSelect) ?? d.pasteAfterSelect
        pasteDelay       = try c.decodeIfPresent(Double.self, forKey: .pasteDelay)       ?? d.pasteDelay
        pasteKeys        = try c.decodeIfPresent([String: PasteKey].self, forKey: .pasteKeys) ?? d.pasteKeys
        ignoreApps       = try c.decodeIfPresent([String].self, forKey: .ignoreApps)     ?? d.ignoreApps
        ignoreConcealed  = try c.decodeIfPresent(Bool.self,   forKey: .ignoreConcealed)  ?? d.ignoreConcealed
        launchAtLogin    = try c.decodeIfPresent(Bool.self,   forKey: .launchAtLogin)    ?? d.launchAtLogin
        lockWithScreen   = try c.decodeIfPresent(Bool.self,   forKey: .lockWithScreen)   ?? d.lockWithScreen
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
}
