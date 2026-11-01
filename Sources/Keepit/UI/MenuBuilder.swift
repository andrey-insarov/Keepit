import AppKit

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
    func contextMenu(for item: ClipItem, target: AnyObject, actions a: ContextActions) -> NSMenu {
        let m = NSMenu()
        m.autoenablesItems = false
        func add(_ title: String, _ sel: Selector, key: String, symbol: String? = nil, object: Any? = item.id) {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            mi.keyEquivalentModifierMask = []
            mi.target = target
            mi.representedObject = object
            if let symbol { mi.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            m.addItem(mi)
        }
        add(L("Paste"), a.paste, key: "\r", symbol: "doc.on.clipboard")
        if item.kind == .text, item.plainText != nil {
            if item.hasRichText { add(L("Paste as plain text"), a.pastePlain, key: "p", symbol: "doc.plaintext") }
            add(L("Copy only"), a.copyOnly, key: "c", symbol: "doc.on.doc")
            m.addItem(.separator())
            let group = NSMenuItem(title: L("Paste as"), action: nil, keyEquivalent: "")
            group.isEnabled = false
            m.addItem(group)
            let keys: [TextTransform: String] = [.upper: "u", .lower: "l", .title: "t", .sentence: "s", .trim: "w", .singleLine: "j"]
            for t in TextTransform.allCases where t != .stripFormatting {
                add("   " + t.title, a.transform, key: keys[t] ?? "", object: TransformChoice(id: item.id, transform: t))
            }
        } else {
            add(L("Copy only"), a.copyOnly, key: "c", symbol: "doc.on.doc")
        }
        m.addItem(.separator())
        add(L("Add to Templates"), a.pin, key: "a", symbol: "text.badge.star")
        add(L("Show in Viewer"), a.reveal, key: "v", symbol: "eye")
        add(L("Delete"), a.delete, key: "\u{8}", symbol: "trash")
        return m
    }

    /// Builds the right-click action menu for a history entry (set by the app delegate).
    var actionMenu: ((UUID) -> NSMenu?)?

    func historyItems(_ items: [ClipItem], target: AnyObject, action: Selector, plainAction: Selector? = nil,
                      pinAction: Selector? = nil, deleteAction: Selector? = nil, commandAccelerators: Bool = false) -> [NSMenuItem] {
        var out: [NSMenuItem] = []
        var views: [HistoryItemView] = []
        let shown = items.prefix(settings.menuMaxItems)
        let accels = commandAccelerators ? Array(Self.accelerators.prefix(10)) : Self.accelerators
        let baseMask: NSEvent.ModifierFlags = commandAccelerators ? [.command] : []
        let cmd = commandAccelerators ? "⌘" : ""

        /// One menu item + its custom row view.
        func make(_ item: ClipItem, title: String, action: Selector?, key: String, mask: NSEvent.ModifierFlags,
                  prefix: String, keyLabel: String, image: NSImage?, imageSize: NSSize, alternate: Bool) -> NSMenuItem {
            let mi = NSMenuItem(title: (prefix.isEmpty ? "" : prefix + "  ") + title, action: action, keyEquivalent: key)
            mi.keyEquivalentModifierMask = mask
            mi.target = target
            mi.representedObject = item.id
            mi.tag = Self.historyTag
            mi.isAlternate = alternate
            let v = HistoryItemView()
            v.prefix = prefix
            v.title = title
            v.keyLabel = keyLabel
            v.image = image
            v.imageSize = imageSize
            v.actionMenu = { [weak self] _ in self?.actionMenu?(item.id) }
            if settings.showTooltips, !settings.showPreview, let tip = item.tooltip { v.toolTip = tip }
            mi.view = v
            views.append(v)
            return mi
        }

        for (i, item) in shown.enumerated() {
            let title = item.title(maxLength: settings.titleLength)
            var key = "", prefix = "", keyLabel = ""
            if settings.numberItems, i < accels.count {
                let ch = accels[i]
                key = String(ch).lowercased()
                prefix = String(ch)
                keyLabel = cmd + String(ch)
            }
            var image: NSImage?
            var imageSize = NSSize(width: 16, height: 16)
            if settings.showThumbnails, item.kind == .image, let t = thumbnail(for: item) {
                image = t
                imageSize = t.size
            } else if settings.showSourceIcons, let icon = appIcon(for: item.sourceApp) {
                image = icon
            } else if item.kind == .files {
                image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            }
            out.append(make(item, title: title, action: action, key: key, mask: baseMask, prefix: prefix,
                            keyLabel: keyLabel, image: image, imageSize: imageSize, alternate: false))
            if let plain = plainAction, item.plainText != nil, item.kind == .text {
                out.append(make(item, title: LF("%@ — plain text", title), action: plain, key: key, mask: baseMask.union(.shift),
                                prefix: prefix, keyLabel: key.isEmpty ? "" : "⇧" + keyLabel, image: image, imageSize: imageSize, alternate: true))
            }
            if let pin = pinAction {
                out.append(make(item, title: LF("%@ — add to Templates", title), action: pin, key: key, mask: baseMask.union(.option),
                                prefix: prefix, keyLabel: key.isEmpty ? "" : "⌥" + keyLabel,
                                image: NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: nil), imageSize: NSSize(width: 16, height: 16), alternate: true))
            }
            if let del = deleteAction {
                out.append(make(item, title: LF("%@ — delete", title), action: del, key: key, mask: baseMask.union(.control),
                                prefix: prefix, keyLabel: key.isEmpty ? "" : "⌃" + keyLabel,
                                image: NSImage(systemSymbolName: "trash", accessibilityDescription: nil), imageSize: NSSize(width: 16, height: 16), alternate: true))
            }
        }
        if items.count > shown.count {
            let more = NSMenuItem(title: LF("… %d more in the Viewer", items.count - shown.count), action: nil, keyEquivalent: "")
            more.isEnabled = false
            more.tag = Self.historyTag
            out.append(more)
        }
        // All rows share the widest width (the menu is as wide as its widest item).
        let width = min(max(views.map { $0.preferredWidth() }.max() ?? 200, 200), 640)
        views.forEach { $0.sizeToFit(width: width) }
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
