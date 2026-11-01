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
    func historyItems(_ items: [ClipItem], target: AnyObject, action: Selector, plainAction: Selector? = nil,
                      pinAction: Selector? = nil, commandAccelerators: Bool = false) -> [NSMenuItem] {
        var out: [NSMenuItem] = []
        let shown = items.prefix(settings.menuMaxItems)
        let accels = commandAccelerators ? Array(Self.accelerators.prefix(10)) : Self.accelerators
        let baseMask: NSEvent.ModifierFlags = commandAccelerators ? [.command] : []
        for (i, item) in shown.enumerated() {
            let title = item.title(maxLength: settings.titleLength)
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
            mi.target = target
            mi.representedObject = item.id
            mi.tag = Self.historyTag

            var prefix = ""
            if settings.numberItems, i < accels.count {
                let ch = accels[i]
                mi.keyEquivalent = String(ch).lowercased()
                mi.keyEquivalentModifierMask = baseMask
                // Visible prefix "1  text" (the key equivalent column shows it too).
                prefix = "\(ch)  "
                mi.title = prefix + title
            }
            var alternates: [NSMenuItem] = []
            if let plain = plainAction, item.plainText != nil, item.kind == .text {
                let alt = NSMenuItem(title: prefix + LF("%@ — plain text", title), action: plain, keyEquivalent: mi.keyEquivalent)
                alt.target = target
                alt.representedObject = item.id
                alt.tag = Self.historyTag
                alt.isAlternate = true
                alt.keyEquivalentModifierMask = baseMask.union(.shift)
                alternates.append(alt)
            }
            if let pin = pinAction {
                let alt = NSMenuItem(title: prefix + LF("%@ — add to Templates", title), action: pin, keyEquivalent: mi.keyEquivalent)
                alt.target = target
                alt.representedObject = item.id
                alt.tag = Self.historyTag
                alt.isAlternate = true
                alt.keyEquivalentModifierMask = baseMask.union(.option)
                alt.image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: nil)
                alternates.append(alt)
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
            out.append(contentsOf: alternates)   // alternates must directly follow their item
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
