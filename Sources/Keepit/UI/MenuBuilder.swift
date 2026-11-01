import AppKit
import Carbon.HIToolbox

/// Builds the popup menus: history list with accelerators + thumbnails, template tree.
final class MenuBuilder {
    var settings: Settings
    private var thumbCache: [UUID: NSImage] = [:]

    /// Accelerator characters: 1-9, 0, A-Z.
    private static let accelerators: [Character] = Array("1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    init(settings: Settings) { self.settings = settings }

    func invalidateThumbnails() { thumbCache.removeAll() }

    private var appIconCache: [String: NSImage] = [:]

    /// 16-pt icon of the app the item was copied from (by bundle id), cached; nil if the app is gone.
    func appIcon(for bundleID: String?) -> NSImage? {
        guard let id = bundleID, !id.isEmpty else { return nil }
        if let i = appIconCache[id] { return i }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        appIconCache[id] = icon
        return icon
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        if let t = thumbCache[item.id] { return t }
        guard let t = item.thumbnail(maxSide: CGFloat(settings.thumbnailSize)) else { return nil }
        thumbCache[item.id] = t
        return t
    }

    // MARK: History

    /// Tag on every history entry so the menu can swap them out while filtering.
    static let historyTag = 7

    /// - Parameter commandAccelerators: with the search field in the menu, plain letters go into the
    ///   field, so item shortcuts become ⌘1…⌘0 (letters are dropped).
    /// - Parameter plainAction: when given, every text item gets a ⇧ alternate ("… — plain text") that
    ///   calls it instead; hold ⇧ while clicking or add ⇧ to the shortcut.
    /// - Parameter pinAction: when given, every item gets an ⌥ alternate ("… — add to Templates").
    /// - Parameter deleteAction: when given, every item gets a ⌃ alternate ("… — delete").
    /// Represented object of a "Paste as ▸" entry: the item id and the transformation.
    struct TransformChoice { let id: UUID; let transform: TextTransform }

    /// Selectors for the long-press context menu of a history item.
    struct ContextActions {
        var paste: Selector
        var pastePlain: Selector
        var copyOnly: Selector
        var transform: Selector
        var pin: Selector
        var reveal: Selector
        var delete: Selector
    }

    /// Context menu of a history row (right click): all actions for that one item, with single-letter shortcuts.
    /// - Parameter latestMods: when the item is the latest one and the "actions on the latest item" hot keys are
    ///   on, their modifiers — the entries then show (and respond to) <mods>+letter, which also work globally.
    ///   Otherwise the entries have no shortcuts at all: a key is either always available or not shown.
    func contextMenu(for item: ClipItem, target: AnyObject, actions a: ContextActions, latestMods: UInt32?) -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        let mask = latestMods.map { Self.flags($0) }
        func add(_ title: String, _ sel: Selector, key: HotKey.LatestAction?, symbol: String? = nil, object: Any? = item.id, enabled: Bool = true) {
            let keyChar = (mask != nil && key != nil) ? key!.keyChar : ""
            // With a key: a second, hidden copy with ⇧ added so the shortcut also works while ⇧ (which opened
            // the extended menu) is still held. Hidden items stay out of sight but their key equivalents work.
            for extra in [NSEvent.ModifierFlags(), [.shift]] {
                let mi = NSMenuItem(title: title, action: sel, keyEquivalent: keyChar)
                mi.keyEquivalentModifierMask = (mask ?? []).union(extra)
                mi.isHidden = extra == [.shift]
                mi.isEnabled = enabled
                mi.target = target
                mi.representedObject = object
                if let symbol { mi.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
                m.addItem(mi)
                if keyChar.isEmpty { break }
            }
        }
        let isText = item.kind == .text && item.plainText != nil
        add(L("Paste"), a.paste, key: nil, symbol: "doc.on.clipboard")
        add(L("Paste as plain text"), a.pastePlain, key: .plain, symbol: "doc.plaintext", enabled: isText)
        add(L("Copy only"), a.copyOnly, key: nil, symbol: "doc.on.doc")
        m.addItem(.separator())
        let group = NSMenuItem(title: L("Paste as"), action: nil, keyEquivalent: "")
        group.isEnabled = false
        m.addItem(group)
        for la in HotKey.LatestAction.allCases {
            guard let t = la.transform else { continue }
            add("   " + t.title, a.transform, key: la, object: TransformChoice(id: item.id, transform: t), enabled: isText)
        }
        m.addItem(.separator())
        add(L("Add to Templates"), a.pin, key: .addToTemplates, symbol: "text.badge.star")
        add(L("Show in Viewer"), a.reveal, key: nil, symbol: "eye")
        add(L("Delete"), a.delete, key: .delete, symbol: "trash")
        return m
    }

    /// Carbon modifier bits → AppKit flags.
    static func flags(_ mods: UInt32) -> NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if mods & UInt32(cmdKey) != 0 { f.insert(.command) }
        if mods & UInt32(shiftKey) != 0 { f.insert(.shift) }
        if mods & UInt32(optionKey) != 0 { f.insert(.option) }
        if mods & UInt32(controlKey) != 0 { f.insert(.control) }
        return f
    }

    /// - Parameter numberMods: modifiers of the global "paste item by number" hot keys; the rows then carry
    ///   <mods>+digit as their key equivalent (works in the menu and in the background alike). nil = the
    ///   feature is off: rows get menu-only accelerators (1–9/0/A–Z, or ⌘1…⌘0 with the search field).
    func historyItems(_ items: [ClipItem], target: AnyObject, action: Selector, numberMods: UInt32?,
                      commandAccelerators: Bool = false) -> [NSMenuItem] {
        var out: [NSMenuItem] = []
        let shown = items.prefix(settings.menuMaxItems)
        let global = numberMods != nil
        let accels = (commandAccelerators || global) ? Array(Self.accelerators.prefix(10)) : Self.accelerators
        let mask: NSEvent.ModifierFlags = global ? Self.flags(numberMods!) : (commandAccelerators ? [.command] : [])
        for (i, item) in shown.enumerated() {
            let title = item.title(maxLength: settings.titleLength)
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
            mi.target = target
            mi.representedObject = item.id
            mi.tag = Self.historyTag
            if settings.numberItems, i < accels.count {
                let ch = accels[i]
                mi.keyEquivalent = String(ch).lowercased()
                mi.keyEquivalentModifierMask = mask
                mi.title = "\(ch)  " + title     // visible prefix "1  text"
            }
            if i == 0 {
                // The latest item = the clipboard: bold, like the current item in a Finder path.
                let bold = NSFontManager.shared.convert(NSFont.menuFont(ofSize: 0), toHaveTrait: .boldFontMask)
                mi.attributedTitle = NSAttributedString(string: mi.title, attributes: [.font: bold])
            }
            if settings.showThumbnails, item.kind == .image {
                mi.image = thumbnail(for: item)
            } else if settings.showSourceIcons, let icon = appIcon(for: item.sourceApp) {
                mi.image = icon
            } else if item.kind == .files {
                mi.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            }
            if settings.showTooltips, !settings.showPreview, let tip = item.tooltip {
                mi.toolTip = tip    // the preview panel replaces tooltips when it is on
            }
            out.append(mi)
        }
        if items.count > shown.count {
            let more = NSMenuItem(title: LF("… %d more in the Viewer", items.count - shown.count), action: nil, keyEquivalent: "")
            more.isEnabled = false
            more.tag = Self.historyTag
            out.append(more)
        }
        return out
    }

    /// Case-insensitive substring filter over titles and text contents.
    static func filter(_ items: [ClipItem], query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { item in
            if item.title(maxLength: 10_000).localizedCaseInsensitiveContains(q) { return true }
            if let t = item.plainText, t.localizedCaseInsensitiveContains(q) { return true }
            return false
        }
    }

    // MARK: Templates

    func templateMenu(_ node: TemplateNode, target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu(title: node.name)
        menu.autoenablesItems = false
        if node.children.isEmpty {
            let empty = NSMenuItem(title: L("(Empty)"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for child in node.children {
            if child.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let (title, shortcut) = Self.parseAmpersand(child.displayName)
            if child.isFolder {
                let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                mi.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                mi.submenu = templateMenu(child, target: target, action: action)
                if let k = shortcut { mi.keyEquivalent = k; mi.keyEquivalentModifierMask = [] }
                menu.addItem(mi)
            } else {
                let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
                mi.target = target
                mi.representedObject = child.id
                if let k = shortcut { mi.keyEquivalent = k; mi.keyEquivalentModifierMask = [] }
                if let c = child.clip {
                    if settings.showThumbnails, c.kind == .image { mi.image = thumbnail(for: c) }
                    if settings.showTooltips, let tip = c.tooltip { mi.toolTip = tip }
                }
                menu.addItem(mi)
            }
        }
        return menu
    }

    /// Template name syntax: "&x" makes x the shortcut key, "&&" is a literal ampersand.
    static func parseAmpersand(_ name: String) -> (title: String, shortcut: String?) {
        var title = ""
        var shortcut: String?
        var it = name.makeIterator()
        while let ch = it.next() {
            if ch == "&" {
                guard let next = it.next() else { break }
                if next == "&" { title.append("&") }
                else {
                    if shortcut == nil { shortcut = String(next).lowercased() }
                    title.append(next)
                }
            } else {
                title.append(ch)
            }
        }
        return (title, shortcut)
    }
}
