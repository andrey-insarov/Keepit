import AppKit

/// Builds the popup menus: history list with accelerators + thumbnails, template tree.
final class MenuBuilder {
    var settings: Settings
    private var thumbCache: [UUID: NSImage] = [:]

    /// Accelerator characters: 1-9, 0, A-Z.
    private static let accelerators: [Character] = Array("1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    init(settings: Settings) { self.settings = settings }

    func invalidateThumbnails() { thumbCache.removeAll() }

    func thumbnail(for item: ClipItem) -> NSImage? {
        if let t = thumbCache[item.id] { return t }
        guard let t = item.thumbnail(maxSide: CGFloat(settings.thumbnailSize)) else { return nil }
        thumbCache[item.id] = t
        return t
    }

    // MARK: History

    func historyItems(_ items: [ClipItem], target: AnyObject, action: Selector) -> [NSMenuItem] {
        var out: [NSMenuItem] = []
        let shown = items.prefix(settings.menuMaxItems)
        for (i, item) in shown.enumerated() {
            let title = item.title(maxLength: settings.titleLength)
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
            mi.target = target
            mi.representedObject = item.id

            if settings.numberItems, i < Self.accelerators.count {
                let ch = Self.accelerators[i]
                mi.keyEquivalent = String(ch).lowercased()
                mi.keyEquivalentModifierMask = []
                // Visible prefix "1  text" (the key equivalent column shows it too).
                mi.title = "\(ch)  \(title)"
            }
            if settings.showThumbnails, item.kind == .image {
                mi.image = thumbnail(for: item)
            } else if item.kind == .files {
                mi.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            }
            if settings.showTooltips, let tip = item.tooltip {
                mi.toolTip = tip
            }
            out.append(mi)
        }
        if items.count > shown.count {
            let more = NSMenuItem(title: LF("… %d more in the Viewer", items.count - shown.count), action: nil, keyEquivalent: "")
            more.isEnabled = false
            out.append(more)
        }
        return out
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
