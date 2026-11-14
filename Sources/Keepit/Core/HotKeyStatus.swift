// What became of each hot key: what the keyboard layouts say about it, and what Carbon did.
// Design: claude/keepit-hotkey-layouts-design.md, H-2 to H-4 (stage 2).
//
// The two are independent fields. One enabled layout can fail to read while another is proven to
// need the combination, and a registration can fail whatever the layouts said. Menus set a key
// equivalent only for `.registered`; Settings reads both fields for its notes; the "Hot key
// unavailable" alert reads `.failed` only.

import Foundation

/// Every shortcut Keepit registers, by name. The raw values are stored in `Settings.chosenHotKeys`.
enum HotKeyID: String, CaseIterable, Codable {
    case history, template          // required: never skipped
    case previous
    case numbers, latest            // the ⌃⌥ families: never checked against layouts (UCKeyTranslate ignores Control)
    case lock, pause, viewer, preferences, clearHistory, quit
    case queue, queuePaste, queuePasteAll

    /// Optional single shortcuts whose factory default may be left free for a layout (H-2).
    static let filterable: [HotKeyID] = [.previous, .lock, .pause, .viewer, .preferences, .clearHistory, .quit, .queue, .queuePaste, .queuePasteAll]
    /// Shortcuts the layouts are asked about at all: the filterable ones and the two required ones.
    static let checked: [HotKeyID] = [.history, .template] + filterable
    var isRequired: Bool { self == .history || self == .template }
}

struct HotKeyStatus: Equatable {
    enum Layout: Equatable {
        case notNeeded
        /// The first enabled layout that needs the combination, and the character it types there.
        case needed(layout: String, types: String)
        /// No readable layout needs it, but these could not be read (or a call failed).
        case unchecked(failed: [String])
    }
    enum Registration: Equatable {
        case off          // stored nil
        case skipped      // default left free for a layout (H-2)
        case registered
        case failed       // RegisterEventHotKey refused it: another app or macOS holds it
        case suspended    // locked: unregistered by lock(), back on unlock()
    }
    var layout: Layout
    /// Dead-key chains the layout analysis did not follow; a measure of what was not seen, never evidence.
    var incomplete: Int
    var registration: Registration

    static let off = HotKeyStatus(layout: .notNeeded, incomplete: 0, registration: .off)
    static let registered = HotKeyStatus(layout: .notNeeded, incomplete: 0, registration: .registered)

    /// The shortcut is live: Carbon holds it and a menu may show it.
    var isActive: Bool { registration == .registered }
}

extension Settings {
    /// The stored single shortcut for an id; nil when off. The two families have no single combination.
    func hotKey(_ id: HotKeyID) -> HotKey? {
        switch id {
        case .history: return historyHotKey
        case .template: return templateHotKey
        case .previous: return previousHotKey
        case .numbers, .latest: return nil
        case .lock: return lockHotKey
        case .pause: return pauseHotKey
        case .viewer: return viewerHotKey
        case .preferences: return preferencesHotKey
        case .clearHistory: return clearHistoryHotKey
        case .quit: return quitHotKey
        case .queue: return queueHotKey
        case .queuePaste: return queuePasteHotKey
        case .queuePasteAll: return queuePasteAllHotKey
        }
    }

    /// The factory default for an id.
    static func defaultHotKey(_ id: HotKeyID) -> HotKey? { Settings().hotKey(id) }

    func isChosen(_ id: HotKeyID) -> Bool { chosenHotKeys.contains(id.rawValue) }
}

extension HotKeyStatus {
    /// The layouts' verdict on every checked shortcut and whether its default is left free (H-2): skipped
    /// when it is filterable, stored equal to the factory default, not recorded by the user, and some
    /// enabled layout needs it. A required default that a layout needs is never skipped; its verdict is
    /// kept so Settings can say so. Pure: no Carbon, no UI.
    static func decide(_ settings: Settings, probe: LayoutProbe) -> [HotKeyID: Decision] {
        var ids: [HotKeyID] = [], combos: [(keyCode: UInt16, modifiers: UInt32)] = []
        for id in HotKeyID.checked {
            guard let hk = settings.hotKey(id) else { continue }
            ids.append(id)
            combos.append((UInt16(truncatingIfNeeded: hk.keyCode), hk.modifiers))
        }
        let checks = probe.checkAll(combos)
        var out: [HotKeyID: Decision] = [:]
        for (i, id) in ids.enumerated() {
            let check = checks[i]
            let layout: Layout
            switch check.verdict {
            case .notNeeded: layout = .notNeeded
            case .needed(let l, let t): layout = .needed(layout: l, types: t)
            case .unchecked(let f): layout = .unchecked(failed: f)
            }
            var skip = false
            if case .needed = layout, !id.isRequired, HotKeyID.filterable.contains(id),
               settings.hotKey(id) == Settings.defaultHotKey(id), !settings.isChosen(id) {
                skip = true
            }
            out[id] = Decision(layout: layout, incomplete: check.incomplete, skip: skip)
        }
        return out
    }

    struct Decision: Equatable {
        var layout: Layout
        var incomplete: Int
        var skip: Bool
    }
}
