import AppKit
import UniformTypeIdentifiers

// MARK: - Tree node

/// A row in the Viewer tree. Cached by `key` so NSOutlineView keeps expansion/selection across reloads.
final class VNode {
    enum Kind {
        case clipboardRoot, historyRoot, templateRoot
        case historyText, historyImages          // the two rings under History
        case clipboardItem
        case history(UUID)
        case template(TemplateNode)
        case format(String)
    }
    let key: String
    var kind: Kind
    weak var parent: VNode?
    var children: [VNode] = []

    init(key: String, kind: Kind, parent: VNode?) {
        self.key = key
        self.kind = kind
        self.parent = parent
    }

    var isRoot: Bool {
        switch kind {
        case .clipboardRoot, .historyRoot, .templateRoot, .historyText, .historyImages: return true
        default: return false
        }
    }
    var isFormat: Bool { if case .format = kind { return true }; return false }
    var templateNode: TemplateNode? { if case .template(let t) = kind { return t }; return nil }
    var historyId: UUID? { if case .history(let id) = kind { return id }; return nil }
    var formatKey: String? { if case .format(let f) = kind { return f }; return nil }
    /// The item-level node (self, or parent for a format node).
    var itemNode: VNode? { isFormat ? parent : self }
    var isInTemplate: Bool {
        var n: VNode? = self
        while let cur = n {
            if case .templateRoot = cur.kind { return true }
            n = cur.parent
        }
        return false
    }
    var isInHistory: Bool {
        var n: VNode? = self
        while let cur = n {
            if case .historyRoot = cur.kind { return true }
            n = cur.parent
        }
        return false
    }
}

/// Outline view that selects the clicked row before showing the context menu and routes Delete/Return.
final class ViewerOutlineView: NSOutlineView {
    var onDelete: (() -> Void)?
    var onReturn: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let p = convert(event.locationInWindow, from: nil)
        let row = self.row(at: p)
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        return super.menu(for: event)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117: onDelete?()          // ⌫ / ⌦
        case 36, 76: onReturn?()           // ↩ / enter
        default: super.keyDown(with: event)
        }
    }
}

// MARK: - Viewer window

/// The Viewer: tree of Clipboard / History / Template on the left,
/// the selected format's contents on the right, editable where the original allowed it.
final class ViewerWindowController: NSWindowController,
    NSOutlineViewDataSource, NSOutlineViewDelegate, NSWindowDelegate, NSMenuDelegate {

    private unowned let app: AppDelegate
    private var history: HistoryStore { app.history }
    private var templates: TemplateStore { app.templates }

    private let outline = ViewerOutlineView()
    private let rightPane = NSView()          // split view's right side: name row + content
    private let contentPane = NSView()        // where the format views go
    private let nameRow = NSStackView()
    private let nameField = NSTextField()
    private let statusBar = NSTextField(labelWithString: "")
    private let textFormat = TextFormatView(frame: .zero)
    private let imageFormat = ImageFormatView(frame: .zero)
    private let filesFormat = FilesFormatView(frame: .zero)
    private let hexFormat = HexFormatView(frame: .zero)
    private let infoFormat = InfoView(frame: .zero)
    private var binaryButton: NSButton!

    private var nodes: [String: VNode] = [:]
    private let clipboardRoot: VNode
    private let historyRoot: VNode
    private let templateRoot: VNode
    private var currentClipboard: ClipItem?
    private var editingNode: VNode?
    private var showBinary = false
    private var suppressSelectionEvents = false

    private static let dragType = NSPasteboard.PasteboardType("com.it.keep.viewer-node")

    init(app: AppDelegate) {
        self.app = app
        clipboardRoot = VNode(key: "clip", kind: .clipboardRoot, parent: nil)
        historyRoot = VNode(key: "hist", kind: .historyRoot, parent: nil)
        templateRoot = VNode(key: "tmpl", kind: .templateRoot, parent: nil)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = L("Keepit — Viewer")
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 640, height: 360)
        w.setFrameAutosaveName("KeepitViewer")
        super.init(window: w)
        w.delegate = self
        nodes = ["clip": clipboardRoot, "hist": historyRoot, "tmpl": templateRoot]
        buildUI()
        textFormat.onCommit = { [weak self] fmt, data in self?.applyEdit(format: fmt, data: data) }
        refresh()
        outline.expandItem(clipboardRoot)
        outline.expandItem(historyRoot)
        outline.expandItem(nodes["hist:text"])
        outline.expandItem(nodes["hist:images"])
        outline.expandItem(templateRoot)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        refresh()
        if window?.isVisible == false { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Build UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // Toolbar row
        func btn(_ title: String, _ sel: Selector, symbol: String) -> NSButton {
            let b = NSButton(title: title, target: self, action: sel)
            b.bezelStyle = .rounded
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            b.imagePosition = .imageLeading
            return b
        }
        binaryButton = btn(L("Binary"), #selector(toggleBinary), symbol: "number")
        binaryButton.setButtonType(.pushOnPushOff)
        let bar = NSStackView(views: [
            btn(L("Send to Clipboard"), #selector(sendToClipboard), symbol: "doc.on.clipboard"),
            btn(L("Paste"), #selector(pasteItem), symbol: "arrow.right.doc.on.clipboard"),
            btn(L("Add to Template"), #selector(addToTemplate), symbol: "text.badge.plus"),
            Spacer(),
            btn(L("New Item"), #selector(newItem), symbol: "plus"),
            btn(L("New Folder"), #selector(newFolder), symbol: "folder.badge.plus"),
            btn(L("Delete"), #selector(deleteSelected), symbol: "trash"),
            btn(L("Up"), #selector(moveUpAction), symbol: "arrow.up"),
            btn(L("Down"), #selector(moveDownAction), symbol: "arrow.down"),
            Spacer(),
            binaryButton,
        ])
        bar.orientation = .horizontal
        bar.spacing = 6
        bar.translatesAutoresizingMaskIntoConstraints = false

        // Tree
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.width = 260
        col.resizingMask = .autoresizingMask
        outline.addTableColumn(col)
        outline.outlineTableColumn = col
        outline.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outline.headerView = nil
        outline.dataSource = self
        outline.delegate = self
        outline.allowsEmptySelection = true
        outline.registerForDraggedTypes([Self.dragType])
        outline.setDraggingSourceOperationMask([.move, .copy], forLocal: true)
        outline.onDelete = { [weak self] in self?.deleteSelected() }
        outline.onReturn = { [weak self] in self?.sendToClipboard() }
        let ctx = NSMenu()
        ctx.delegate = self
        outline.menu = ctx

        let leftScroll = NSScrollView()
        leftScroll.documentView = outline
        leftScroll.hasVerticalScroller = true
        leftScroll.borderType = .noBorder
        leftScroll.focusRingType = .none          // no thick blue focus ring around the whole tree
        outline.focusRingType = .none

        // Right side: "Name" row (template items/folders only) above the content.
        let nameLabel = NSTextField(labelWithString: L("Name:"))
        nameField.placeholderString = L("Empty = show contents · “-” = separator · &x = menu shortcut")
        nameField.target = self
        nameField.action = #selector(nameFieldChanged)
        (nameField.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = true   // commit on focus loss, not only ↩
        nameRow.orientation = .horizontal
        nameRow.spacing = 6
        nameRow.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 4, right: 8)
        nameRow.addArrangedSubview(nameLabel)
        nameRow.addArrangedSubview(nameField)
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let rightStack = NSStackView(views: [nameRow, contentPane])
        rightStack.orientation = .vertical
        rightStack.spacing = 0
        rightStack.alignment = .width
        rightStack.distribution = .fill
        contentPane.setContentHuggingPriority(.defaultLow, for: .vertical)
        rightPane.addSubview(rightStack)
        rightPane.pinToEdges(rightStack)
        nameRow.isHidden = true

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(leftScroll)
        split.addArrangedSubview(rightPane)
        split.translatesAutoresizingMaskIntoConstraints = false
        leftScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        rightPane.widthAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        split.autosaveName = "KeepitViewerSplit"

        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.textColor = .secondaryLabelColor
        statusBar.lineBreakMode = .byTruncatingMiddle
        statusBar.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)

        content.addSubview(bar)
        content.addSubview(split)
        content.addSubview(statusBar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            split.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8),
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.topAnchor.constraint(equalTo: split.bottomAnchor, constant: 4),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -4),
        ])
        split.setPosition(300, ofDividerAt: 0)
        showPane(infoFormat)
        infoFormat.load(L("Select an item in the tree."))
    }

    private func showPane(_ v: NSView) {
        if v.superview === contentPane { return }
        contentPane.subviews.forEach { $0.removeFromSuperview() }
        contentPane.addSubview(v)
        contentPane.pinToEdges(v)
    }

    /// Show the Name row for template nodes (items and folders), hide it elsewhere.
    private func updateNameRow(for n: VNode?) {
        if let t = n?.itemNode?.templateNode {
            nameRow.isHidden = false
            nameField.stringValue = t.name
            nameField.isEnabled = true
        } else {
            nameRow.isHidden = true
            nameField.stringValue = ""
        }
    }

    private func limitBeep() {
        NSSound.beep()
        statusBar.stringValue = LF("Limit reached: at most %d template items, %d levels deep.", Limits.templateMaxCount, Limits.templateMaxDepth)
    }

    @objc private func nameFieldChanged() {
        guard let t = selectedNode?.itemNode?.templateNode else { return }
        let new = String(nameField.stringValue.prefix(Limits.templateNameMaxChars))
        guard new != t.name else { return }
        t.name = new
        templates.changed()
        if t.hotKey != nil { app.registerHotKeys() }
        refresh()
    }

    // MARK: Tree model

    private func node(_ key: String, _ kind: VNode.Kind, parent: VNode) -> VNode {
        if let n = nodes[key] {
            n.kind = kind
            n.parent = parent
            return n
        }
        let n = VNode(key: key, kind: kind, parent: parent)
        nodes[key] = n
        return n
    }

    private func formatChildren(of parent: VNode, clip: ClipItem?) -> [VNode] {
        guard let c = clip else { return [] }
        return c.orderedFormats.map { node("\(parent.key)/\($0)", .format($0), parent: parent) }
    }

    private func buildTemplate(_ t: TemplateNode, parent: VNode) -> VNode {
        let n = node("t:\(t.id.uuidString)", .template(t), parent: parent)
        if t.isFolder {
            n.children = t.children.map { buildTemplate($0, parent: n) }
        } else {
            n.children = formatChildren(of: n, clip: t.clip)
        }
        return n
    }

    /// Rebuild the tree from the stores and reload the outline. Safe to call often.
    func refresh() {
        // Don't yank the editor out from under the user while they are typing (history changes arrive constantly).
        let typing = editingNode != nil && window?.firstResponder === textFormat.textView
        if !typing { textFormat.commit() }
        currentClipboard = ClipItem.capture(from: NSPasteboard.general, settings: app.settings, sourceApp: nil)
        let clipNode = node("clip:item", .clipboardItem, parent: clipboardRoot)
        clipNode.children = formatChildren(of: clipNode, clip: currentClipboard)
        clipboardRoot.children = currentClipboard == nil ? [] : [clipNode]

        let textGroup = node("hist:text", .historyText, parent: historyRoot)
        let imageGroup = node("hist:images", .historyImages, parent: historyRoot)
        func historyNodes(_ items: [ClipItem], parent: VNode) -> [VNode] {
            items.map { item in
                let n = node("h:\(item.id.uuidString)", .history(item.id), parent: parent)
                n.children = formatChildren(of: n, clip: item)
                return n
            }
        }
        textGroup.children = historyNodes(history.textItems, parent: textGroup)
        imageGroup.children = historyNodes(history.imageItems, parent: imageGroup)
        historyRoot.children = [textGroup, imageGroup]
        templateRoot.children = templates.root.children.map { buildTemplate($0, parent: templateRoot) }

        // Drop cache entries that are no longer in the tree.
        var live = Set<String>()
        func walk(_ n: VNode) { live.insert(n.key); n.children.forEach(walk) }
        [clipboardRoot, historyRoot, templateRoot].forEach(walk)
        nodes = nodes.filter { live.contains($0.key) }

        let selected = outline.item(atRow: outline.selectedRow) as? VNode
        suppressSelectionEvents = true
        outline.reloadData()
        if let s = selected, live.contains(s.key) {
            let row = outline.row(forItem: s)
            if row >= 0 { outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        }
        suppressSelectionEvents = false
        if typing, let e = editingNode, live.contains(e.key) { return }
        showSelection()
    }

    private func clip(for n: VNode?) -> ClipItem? {
        guard let n = n else { return nil }
        switch n.kind {
        case .clipboardItem: return currentClipboard
        case .history(let id): return history.item(id: id)
        case .template(let t): return t.clip
        case .format: return clip(for: n.parent)
        default: return nil
        }
    }

    private func setClip(_ c: ClipItem, for n: VNode) {
        guard let item = n.itemNode else { return }
        switch item.kind {
        case .history: history.replace(c)
        case .template(let t):
            t.clip = c
            templates.changed()
        default: break
        }
    }

    private var selectedNode: VNode? {
        outline.item(atRow: outline.selectedRow) as? VNode
    }

    // MARK: Right pane

    private func showSelection() {
        updateNameRow(for: selectedNode)
        guard let n = selectedNode else {
            showPane(infoFormat)
            infoFormat.load(L("Select an item in the tree."))
            statusBar.stringValue = ""
            return
        }
        switch n.kind {
        case .clipboardRoot:
            info(L("Current contents of the clipboard (read-only)."), status: "")
        case .historyRoot:
            info(LF("History — %d text/file item(s) (max %d) and %d image(s) (max %d). Each group drops its oldest entries first.", history.textItems.count, app.settings.historyMax, history.imageItems.count, app.settings.historyImageMax), status: "")
        case .historyText:
            info(LF("Text & files — %d of %d.", history.textItems.count, app.settings.historyMax), status: "")
        case .historyImages:
            info(LF("Images — %d of %d.", history.imageItems.count, app.settings.historyImageMax), status: "")
        case .templateRoot:
            info(LF("Template — %d item(s). Drag history items here to register them.", templates.allItems().count), status: "")
        case .template(let t) where t.isFolder:
            info(LF("Folder “%@” — %d item(s).", t.displayName, t.children.count), status: "")
        case .format(let f):
            guard let c = clip(for: n), let d = c.formats[f] else { info(L("(no data)"), status: ""); return }
            showFormat(f, data: d, clip: c, node: n)
        default:
            guard let c = clip(for: n), let f = c.primaryFormat, let d = c.formats[f] else {
                info(L("(empty item)"), status: ""); return
            }
            showFormat(f, data: d, clip: c, node: n)
        }
    }

    private func info(_ text: String, status: String) {
        editingNode = nil
        showPane(infoFormat)
        infoFormat.load(text)
        statusBar.stringValue = status
    }

    private func showFormat(_ f: String, data: Data, clip c: ClipItem, node n: VNode) {
        let editable: Bool
        if case .clipboardItem = (n.itemNode?.kind ?? .clipboardItem) { editable = false } else { editable = true }

        if showBinary {
            editingNode = nil
            hexFormat.load(data: data)
            showPane(hexFormat)
        } else {
            switch f {
            case ClipItem.Format.text, ClipItem.Format.rtf, ClipItem.Format.html:
                editingNode = n
                textFormat.load(format: f, data: data, editable: editable)
                showPane(textFormat)
            case ClipItem.Format.png:
                editingNode = nil
                imageFormat.load(data: data)
                showPane(imageFormat)
            case ClipItem.Format.files:
                editingNode = nil
                filesFormat.load(paths: c.filePaths)
                showPane(filesFormat)
            default:
                editingNode = nil
                hexFormat.load(data: data)
                showPane(hexFormat)
            }
        }

        var parts: [String] = []
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        parts.append(df.string(from: c.date))
        if let s = c.sourceApp { parts.append(s) }
        parts.append("\(ClipItem.displayName(for: f)) · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        parts.append(LF("%d format(s)", c.formats.count))
        if let t = n.itemNode?.templateNode, let hk = t.hotKey { parts.append(LF("Hot key: %@", hk.displayString)) }
        if !editable { parts.append(L("read-only")) }
        statusBar.stringValue = parts.joined(separator: "  ·  ")
    }

    private func applyEdit(format: String, data: Data) {
        guard let n = editingNode, var c = clip(for: n) else { return }
        guard data.count <= app.settings.maxTextBytes * 4 else {
            NSSound.beep()
            statusBar.stringValue = LF("Edit discarded: larger than the text limit (%d MB).", app.settings.maxTextBytes / 1024 / 1024)
            showSelection()
            return
        }
        if format == ClipItem.Format.text {
            c.setText(String(decoding: data, as: UTF8.self))
        } else {
            c.setData(data, for: format)
        }
        setClip(c, for: n)
        refresh()
    }

    @objc private func toggleBinary() {
        showBinary = binaryButton.state == .on
        showSelection()
    }

    // MARK: Actions

    private func itemForAction() -> (node: VNode, clip: ClipItem)? {
        guard let n = selectedNode, let c = clip(for: n) else { NSSound.beep(); return nil }
        return (n, c)
    }

    /// Item or, for a format row, just that one format.
    private func payloadForAction() -> ClipItem? {
        guard let (n, c) = itemForAction() else { return nil }
        if let f = n.formatKey, let d = c.formats[f] {
            var single = c
            single.formats = [f: d]
            return single
        }
        return c
    }

    @objc private func sendToClipboard() {
        textFormat.commit()
        guard let p = payloadForAction() else { return }
        Paster.paste(p, into: nil, monitor: app.monitor, settings: app.settings, sendKey: false)
        refresh()
    }

    @objc private func pasteItem() {
        textFormat.commit()
        guard let p = payloadForAction() else { return }
        guard let target = app.lastExternalApp else { sendToClipboard(); return }
        Paster.paste(p, into: target, monitor: app.monitor, settings: app.settings, sendKey: true)
    }

    @objc private func addToTemplate() {
        textFormat.commit()
        guard let (n, c) = itemForAction(), !n.isInTemplate else { NSSound.beep(); return }
        let copy = ClipItem(id: UUID(), date: Date(), formats: c.formats, sourceApp: c.sourceApp, contentHash: c.contentHash)
        let (folder, idx) = templateInsertionPoint()
        let t = TemplateNode(name: "", clip: copy)
        guard templates.canInsert(t, under: folder) else { limitBeep(); return }
        folder.insert(t, at: idx)
        templates.changed()
        refresh()
        select(key: "t:\(t.id.uuidString)")
    }

    /// Where "New …" goes in the template tree: selected folder, after selected item, or root.
    private func templateInsertionPoint() -> (TemplateNode, Int?) {
        guard let n = selectedNode?.itemNode, let t = n.templateNode else { return (templates.root, nil) }
        if t.isFolder { return (t, nil) }
        let p = t.parent ?? templates.root
        return (p, p.children.firstIndex { $0 === t }.map { $0 + 1 })
    }

    @objc private func newItem() {
        textFormat.commit()
        let sel = selectedNode
        if sel?.isInHistory == true {
            let idx = sel?.itemNode?.historyId.flatMap { id in history.items.firstIndex { $0.id == id } } ?? 0
            let c = ClipItem.text("")
            history.insert(c, at: idx)
            refresh()
            select(key: "h:\(c.id.uuidString)")
        } else {
            let (folder, idx) = templateInsertionPoint()
            let t = TemplateNode(name: "", clip: .text(""))
            guard templates.canInsert(t, under: folder) else { limitBeep(); return }
            folder.insert(t, at: idx)
            templates.changed()
            refresh()
            select(key: "t:\(t.id.uuidString)")
            window?.makeFirstResponder(nameField)
            return
        }
        window?.makeFirstResponder(textFormat.textView)
    }

    @objc private func newFolder() {
        textFormat.commit()
        let (folder, idx) = templateInsertionPoint()
        let t = TemplateNode(name: L("New Folder"))
        guard templates.canInsert(t, under: folder) else { limitBeep(); return }
        folder.insert(t, at: idx)
        templates.changed()
        refresh()
        select(key: "t:\(t.id.uuidString)")
        window?.makeFirstResponder(nameField)
        nameField.selectText(nil)
    }

    @objc private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = L("Create a template item from a file")
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        var clip: ClipItem
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
           let rep = NSBitmapImageRep(data: data), let png = rep.representation(using: .png, properties: [:]) {
            clip = ClipItem.text("")
            clip.formats = [ClipItem.Format.png: png]
            clip.setData(png, for: ClipItem.Format.png)
        } else if let s = String(data: data, encoding: .utf8) {
            clip = ClipItem.text(s)
        } else {
            clip = ClipItem.text("")
            clip.setFilePaths([url.path])
            clip.removeFormat(ClipItem.Format.text)
        }
        let (folder, idx) = templateInsertionPoint()
        let t = TemplateNode(name: url.lastPathComponent, clip: clip)
        guard templates.canInsert(t, under: folder) else { limitBeep(); return }
        folder.insert(t, at: idx)
        templates.changed()
        refresh()
        select(key: "t:\(t.id.uuidString)")
    }

    @objc private func saveToFile() {
        textFormat.commit()
        guard let (n, c) = itemForAction() else { return }
        let f = n.formatKey ?? c.primaryFormat ?? ClipItem.Format.text
        guard let data = c.formats[f] else { NSSound.beep(); return }
        let panel = NSSavePanel()
        let ext: String
        switch f {
        case ClipItem.Format.text: ext = "txt"
        case ClipItem.Format.rtf: ext = "rtf"
        case ClipItem.Format.html: ext = "html"
        case ClipItem.Format.png: ext = "png"
        case ClipItem.Format.files: ext = "json"
        default: ext = "bin"
        }
        panel.nameFieldStringValue = "keepit-item.\(ext)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url) } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func rename() {
        guard let t = selectedNode?.itemNode?.templateNode else { NSSound.beep(); return }
        let a = NSAlert()
        a.messageText = L("Rename")
        a.informativeText = L("Use “-” for a menu separator, “&x” to make x the menu shortcut, “&&” for a literal &.")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = t.name
        a.accessoryView = field
        a.addButton(withTitle: L("OK"))
        a.addButton(withTitle: L("Cancel"))
        a.window.initialFirstResponder = field
        guard a.runModal() == .alertFirstButtonReturn else { return }
        t.name = String(field.stringValue.prefix(Limits.templateNameMaxChars))
        templates.changed()
        refresh()
    }

    @objc private func clearName() {
        guard let t = selectedNode?.itemNode?.templateNode, !t.isFolder else { NSSound.beep(); return }
        t.name = ""
        templates.changed()
        refresh()
    }

    @objc private func setHotKey() {
        guard let t = selectedNode?.itemNode?.templateNode, !t.isFolder else { NSSound.beep(); return }
        let a = NSAlert()
        a.messageText = LF("Hot key for “%@”", t.displayName)
        a.informativeText = L("Pressing it sends the item to the clipboard and pastes it without showing the menu.")
        let rec = HotKeyRecorderView(frame: NSRect(x: 0, y: 0, width: 200, height: 26))
        rec.hotKey = t.hotKey
        a.accessoryView = rec
        a.addButton(withTitle: L("OK"))
        a.addButton(withTitle: L("Clear"))
        a.addButton(withTitle: L("Cancel"))
        let r = a.runModal()
        if r == .alertFirstButtonReturn {
            t.hotKey = rec.hotKey
        } else if r == .alertSecondButtonReturn {
            t.hotKey = nil
        } else { return }
        templates.changed()
        app.registerHotKeys()
        refresh()
    }

    @objc private func deleteSelected() {
        textFormat.commit()
        guard let n = selectedNode, !n.isRoot else { NSSound.beep(); return }
        if let f = n.formatKey, let item = n.parent, var c = clip(for: item) {
            // Deleting a single format; deleting the last one removes the item.
            if c.formats.count <= 1 { deleteItem(item) } else {
                c.removeFormat(f)
                setClip(c, for: item)
                refresh()
            }
            return
        }
        deleteItem(n)
    }

    private func deleteItem(_ n: VNode) {
        switch n.kind {
        case .history(let id):
            history.remove(id: id)
        case .template(let t):
            if t.isFolder, !t.children.isEmpty {
                let a = NSAlert()
                a.messageText = LF("Delete folder “%@” and its %d item(s)?", t.displayName, t.children.count)
                a.addButton(withTitle: L("Delete"))
                a.addButton(withTitle: L("Cancel"))
                guard a.runModal() == .alertFirstButtonReturn else { return }
            }
            t.removeFromParent()
            templates.changed()
            if t.hotKey != nil { app.registerHotKeys() }
        default:
            NSSound.beep()
            return
        }
        editingNode = nil
        refresh()
    }

    @objc private func clearHistory() {
        let a = NSAlert()
        a.messageText = L("Clear clipboard history?")
        a.informativeText = LF("%d item(s) will be removed.", history.items.count)
        a.addButton(withTitle: L("Clear"))
        a.addButton(withTitle: L("Cancel"))
        if a.runModal() == .alertFirstButtonReturn {
            history.clear()
            refresh()
        }
    }

    private func move(by delta: Int) {
        textFormat.commit()
        guard let n = selectedNode?.itemNode else { NSSound.beep(); return }
        switch n.kind {
        case .history(let id):
            history.move(id: id, by: delta)
        case .template(let t):
            guard let p = t.parent, let i = p.children.firstIndex(where: { $0 === t }),
                  i + delta >= 0, i + delta < p.children.count else { NSSound.beep(); return }
            p.children.swapAt(i, i + delta)
            templates.changed()
        default:
            NSSound.beep()
            return
        }
        refresh()
        select(key: n.key)
    }

    @objc private func moveUpAction() { move(by: -1) }
    @objc private func moveDownAction() { move(by: 1) }

    @objc private func openPreferences() { app.openPreferences() }

    private func select(key: String) {
        guard let n = nodes[key] else { return }
        var chain: [VNode] = []
        var p = n.parent
        while let cur = p { chain.insert(cur, at: 0); p = cur.parent }
        chain.forEach { outline.expandItem($0) }
        let row = outline.row(forItem: n)
        if row >= 0 {
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outline.scrollRowToVisible(row)
        }
    }

    // MARK: Context menu (NSMenuDelegate)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ sel: Selector, _ key: String = "") {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            mi.target = self
            menu.addItem(mi)
        }
        let n = selectedNode
        let t = n?.itemNode?.templateNode
        let hasItem = clip(for: n) != nil

        if hasItem {
            add(L("Send to Clipboard"), #selector(sendToClipboard), "\r")
            add(L("Paste"), #selector(pasteItem))
            menu.addItem(.separator())
        }
        if n?.isInHistory == true || n?.kind.isClipboardSide == true, hasItem {
            add(L("Add to Template"), #selector(addToTemplate))
        }
        if n?.isInTemplate == true {
            add(L("New Item"), #selector(newItem))
            add(L("New Folder"), #selector(newFolder))
            add(L("New Item from File…"), #selector(importFromFile))
            if let t = t {
                add(L("Rename…"), #selector(rename))
                if !t.isFolder {
                    add(L("Clear Name"), #selector(clearName))
                    add(L("Set Hot Key…"), #selector(setHotKey))
                }
            }
        } else if n?.isInHistory == true {
            add(L("New Item"), #selector(newItem))
            add(L("Clear History…"), #selector(clearHistory))
        }
        if hasItem {
            add(L("Save Format to File…"), #selector(saveToFile))
        }
        if let n = n, !n.isRoot {
            menu.addItem(.separator())
            add(L("Up"), #selector(moveUpAction))
            add(L("Down"), #selector(moveDownAction))
            add(L("Delete"), #selector(deleteSelected))
        }
        if menu.items.isEmpty {
            let mi = NSMenuItem(title: L("(no actions)"), action: nil, keyEquivalent: "")
            mi.isEnabled = false
            menu.addItem(mi)
        }
    }

    // MARK: NSOutlineViewDataSource

    private func vnode(_ item: Any?) -> VNode? { item as? VNode }
    private var roots: [VNode] { [clipboardRoot, historyRoot, templateRoot] }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let n = vnode(item) else { return roots.count }
        return n.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let n = vnode(item) else { return roots[index] }
        return n.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let n = vnode(item) else { return false }
        if n.isRoot { return true }
        if let t = n.templateNode, t.isFolder { return true }
        return !n.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let n = vnode(item) else { return nil }
        switch n.kind {
        case .clipboardRoot: return L("Clipboard")
        case .historyRoot: return L("History")
        case .historyText: return LF("Text & files (%d)", history.textItems.count)
        case .historyImages: return LF("Images (%d)", history.imageItems.count)
        case .templateRoot: return L("Template")
        case .clipboardItem: return currentClipboard?.title(maxLength: 60) ?? L("(empty)")
        case .history(let id): return history.item(id: id)?.title(maxLength: 60) ?? "?"
        case .template(let t):
            if t.isFolder { return "📁 \(t.displayName)" }
            if t.isSeparator { return "────────" }
            var s = t.displayName
            if t.hotKey != nil { s += "  [\(t.hotKey!.displayString)]" }
            return s
        case .format(let f): return ClipItem.displayName(for: f)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool { false }

    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        guard let textCell = cell as? NSTextFieldCell, let n = vnode(item) else { return }
        let isTemplate: Bool
        switch n.kind {
        case .templateRoot, .template: isTemplate = true
        case .format: isTemplate = n.isInTemplate
        default: isTemplate = false
        }
        let selected = outlineView.selectedRowIndexes.contains(outlineView.row(forItem: item)) && outlineView.window?.firstResponder === outlineView
        textCell.textColor = isTemplate && !selected ? AppInfo.templateColor : .controlTextColor
        if case .templateRoot = n.kind { textCell.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize) }
        else { textCell.font = NSFont.systemFont(ofSize: NSFont.systemFontSize) }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !suppressSelectionEvents else { return }
        textFormat.commit()
        showSelection()
    }

    // MARK: Drag & drop

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let n = vnode(item), !n.isRoot, !n.isFormat, n.itemNode?.kind.isClipboardSide != true else { return nil }
        let pb = NSPasteboardItem()
        pb.setString(n.key, forType: Self.dragType)
        return pb
    }

    private func draggedNode(_ info: NSDraggingInfo) -> VNode? {
        guard let key = info.draggingPasteboard.string(forType: Self.dragType) else { return nil }
        return nodes[key]
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let src = draggedNode(info) else { return [] }
        guard var target = vnode(item) else { return [] }

        // Dropping onto an item row → retarget to its parent list, after that item.
        if !target.isRoot, !(target.templateNode?.isFolder ?? false) {
            guard let p = target.parent else { return [] }
            let i = p.children.firstIndex { $0 === target } ?? p.children.count
            outlineView.setDropItem(p, dropChildIndex: i + 1)
            target = p
        }
        if target.isFormat { return [] }

        switch target.kind {
        case .historyRoot, .historyText, .historyImages:
            return src.isInHistory ? .move : .copy
        case .templateRoot, .template:
            if let st = src.templateNode, let tt = target.templateNode, tt.isDescendant(of: st) { return [] }
            if case .templateRoot = target.kind, src.templateNode != nil { return .move }
            return src.isInTemplate ? .move : .copy
        default:
            return []
        }
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: Any?, childIndex index: Int) -> Bool {
        textFormat.commit()
        guard let src = draggedNode(info), let target = vnode(item) else { return false }

        switch target.kind {
        case .historyRoot, .historyText, .historyImages:
            // Index within the group → index within the full list.
            let group: [ClipItem] = {
                if case .historyImages = target.kind { return history.imageItems }
                return history.textItems
            }()
            let count = history.items.count
            var at: Int
            if index < 0 || index >= group.count { at = count }
            else { at = history.items.firstIndex { $0.id == group[index].id } ?? count }
            if let id = src.historyId {
                guard let old = history.items.firstIndex(where: { $0.id == id }) else { return false }
                if old < at { at -= 1 }
                let it = history.items[old]
                history.remove(id: id)
                history.insert(it, at: at)
            } else if let t = src.templateNode, let c = t.clip {
                let copy = ClipItem(id: UUID(), date: Date(), formats: c.formats, sourceApp: c.sourceApp, contentHash: c.contentHash)
                history.insert(copy, at: at)
            } else { return false }

        case .templateRoot, .template:
            let folder = target.templateNode ?? templates.root
            var at = index < 0 ? folder.children.count : index
            if let t = src.templateNode {
                if let oldParent = t.parent, oldParent === folder,
                   let old = folder.children.firstIndex(where: { $0 === t }), old < at { at -= 1 }
                guard folder.depth + 1 + (t.isFolder ? 1 : 0) < Limits.templateMaxDepth else { limitBeep(); return false }
                t.removeFromParent()
                folder.insert(t, at: at)
            } else if let id = src.historyId, let c = history.item(id: id) {
                let copy = ClipItem(id: UUID(), date: Date(), formats: c.formats, sourceApp: c.sourceApp, contentHash: c.contentHash)
                let t = TemplateNode(name: "", clip: copy)
                guard templates.canInsert(t, under: folder) else { limitBeep(); return false }
                folder.insert(t, at: at)
            } else { return false }
            templates.changed()

        default:
            return false
        }
        refresh()
        select(key: src.key)
        return true
    }

    // MARK: NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        refresh()
    }

    func windowWillClose(_ notification: Notification) {
        textFormat.commit()
        templates.flush()
        history.flush()
    }
}

private extension VNode.Kind {
    var isClipboardSide: Bool {
        switch self {
        case .clipboardRoot, .clipboardItem: return true
        default: return false
        }
    }
}
