import Foundation

/// Template tree persistence.
final class TemplateStore {
    private(set) var root = TemplateNode(name: "Template")
    var onChange: (() -> Void)?
    /// Bumped on every change to the tree (edits, reload, purge). See HistoryStore.revision.
    private(set) var revision = 0
    private lazy var saver = DebouncedSaver(delay: 1.0) { [weak self] background in self?.saveNow(background: background) }
    /// See HistoryStore.isPurged.
    private(set) var isPurged = false

    init() {
        reload()
    }

    /// (Re)load from disk — used at start and after unlocking.
    func reload() {
        isPurged = false
        revision += 1
        if let loaded = Storage.load(TemplateNode.self, from: Storage.templatesURL) {
            root = Self.validated(loaded)
            root.relink()
        } else {
            root = Self.defaultTree()
            saveNow()
        }
        onChange?()
    }

    /// The file on disk is decoded, not trusted: the tree passes the same validator as a backup's
    /// templates. A tree that fails is repaired, not thrown away — a name is cut to the limit, a
    /// second node with an id already seen gets a new one, a node whose clip fails (after dropping a
    /// rich format that is not what it claims) is removed with its subtree, as is anything beyond
    /// the depth or count ceiling; hot keys past the ceiling are cleared. The file is copied aside
    /// first. If the repair still does not validate, the fresh-install tree is used.
    static func validated(_ loaded: TemplateNode) -> TemplateNode {
        if (try? Backup.validate(tree: loaded)) != nil { return loaded }
        Log.storage.error("templates.json does not validate — repairing; a copy was kept next to it")
        Storage.keepCopy(of: Storage.templatesURL)
        var count = 0, hotKeys = 0
        var ids = Set<UUID>()
        let repaired = repair(loaded, depth: 0, count: &count, hotKeys: &hotKeys, ids: &ids) ?? TemplateNode(name: "Template")
        guard (try? Backup.validate(tree: repaired)) != nil else {
            Log.storage.error("templates.json could not be repaired — starting with the example tree")
            return defaultTree()
        }
        return repaired
    }

    private static func repair(_ node: TemplateNode, depth: Int, count: inout Int, hotKeys: inout Int, ids: inout Set<UUID>) -> TemplateNode? {
        guard depth <= Limits.templateMaxDepth, count < Limits.templateMaxCount else { return nil }
        var clip: ClipItem?
        if let c = node.clip {
            guard let ok = c.validated() else { return nil }
            clip = ok
        }
        count += 1
        let id = ids.insert(node.id).inserted ? node.id : UUID()
        let out = TemplateNode(id: id, name: String(node.name.prefix(Limits.templateNameMaxChars)), clip: clip)
        if node.hotKey != nil, hotKeys < Limits.templateHotKeysMax {
            hotKeys += 1
            out.hotKey = node.hotKey
        }
        for child in node.children {
            if let c = repair(child, depth: depth + 1, count: &count, hotKeys: &hotKeys, ids: &ids) { out.insert(c) }
        }
        return out
    }

    /// The tree a fresh install gets: one "Examples" folder that shows what placeholders can do.
    static func defaultTree() -> TemplateNode {
        TemplateNode(name: "Template", children: [
            TemplateNode(name: L("Examples"), children: [
                TemplateNode(name: "&" + L("Greeting"), text: L("Hi {input:Name},\n\n{cursor}\n\nBest regards")),
                TemplateNode(name: "&" + L("Today's date"), text: "{date:EEEE, d MMMM yyyy}"),
                TemplateNode(name: "&" + L("Quote the clipboard"), text: L("> {clipboard}\n\n")),
                TemplateNode(name: "-", text: ""),
                TemplateNode(name: "&" + L("Signature"), text: L("--\nBest regards,\n{input:Your name}")),
            ]),
        ])
    }

    /// True while the tree is still the fresh-install example set, untouched: nothing of the user's
    /// in it. A first-run Replace has nothing to lose then and needs no rollback copy.
    var isDefaultTree: Bool { Self.same(root, Self.defaultTree()) }

    /// Name, every format byte for byte, source app, hot key, children — not a hash or the plain
    /// text alone: an RTF added to an example keeps the same plain text and is the user's work.
    private static func same(_ a: TemplateNode, _ b: TemplateNode) -> Bool {
        guard a.name == b.name, a.isFolder == b.isFolder, a.hotKey == b.hotKey,
              a.clip?.formats == b.clip?.formats, a.clip?.sourceApp == b.clip?.sourceApp,
              a.children.count == b.children.count else { return false }
        return zip(a.children, b.children).allSatisfy { same($0, $1) }
    }

    /// Back to the fresh-install tree (Reset).
    func resetToDefaults() {
        isPurged = false                       // Reset purges first; the store is live again from here
        root = Self.defaultTree()
        revision += 1
        saveNow()
        onChange?()
    }

    /// Drop everything from memory without touching the disk (lock).
    func purge() {
        saver.flush()
        isPurged = true
        revision += 1
        root = TemplateNode(name: "Template")
        onChange?()
    }

    /// Would adding `node` (with everything below it) under `parent` exceed the depth or count
    /// ceilings? The depth rule is the validator's: the deepest node of the result ≤ templateMaxDepth,
    /// root being 0 — so a subtree counts with its full height, not just its top.
    func canInsert(_ node: TemplateNode, under parent: TemplateNode) -> Bool {
        guard parent.depth + 1 + node.height <= Limits.templateMaxDepth else { return false }
        return root.subtreeCount + node.subtreeCount <= Limits.templateMaxCount
    }

    /// Same for moving a node that is already in the tree: the count does not change, the depth may.
    func canMove(_ node: TemplateNode, under parent: TemplateNode) -> Bool {
        guard !parent.isDescendant(of: node) else { return false }
        return parent.depth + 1 + node.height <= Limits.templateMaxDepth
    }

    /// Backup import, "Replace". The payload has passed Backup.validate; the store checks on its own account.
    func replaceRoot(_ node: TemplateNode) {
        isPurged = false
        root = Self.validated(node)
        root.relink()
        changed()
    }

    /// Tests only: a tree the validator would refuse, as if it had got past the boundary — for the
    /// checks downstream (the backup engine runs the reader's own validation on what it sealed).
    func setRootForTesting(_ node: TemplateNode) {
        isPurged = false
        root = node
        root.relink()
        changed()
    }

    /// The one way into the tree for a new node (with everything below it): the subtree must validate
    /// on its own and fit under `parent`. False = nothing changed. The caller refreshes the UI.
    @discardableResult
    func insert(_ node: TemplateNode, under parent: TemplateNode, at index: Int? = nil) -> Bool {
        guard (try? Backup.validate(subtree: node)) != nil, canInsert(node, under: parent),
              !contains(anyIDOf: node) else { return false }
        parent.insert(node, at: index)
        changed()
        return true
    }

    /// Viewer edit of an item's content in place. False = the clip fails validation; nothing changed.
    @discardableResult
    func update(_ node: TemplateNode, clip: ClipItem) -> Bool {
        guard (try? Backup.validate(item: clip)) != nil else { return false }
        node.clip = clip
        changed()
        return true
    }

    /// Items with a hot key, tree-wide.
    var hotKeyCount: Int { allItems().reduce(0) { $0 + ($1.hotKey != nil ? 1 : 0) } }

    private func contains(anyIDOf node: TemplateNode) -> Bool {
        var ids = Set<UUID>()
        func collect(_ n: TemplateNode) { ids.insert(n.id); n.children.forEach(collect) }
        collect(root)
        func hit(_ n: TemplateNode) -> Bool { ids.contains(n.id) || n.children.contains(where: hit) }
        return hit(node)
    }

    func changed() {
        revision += 1
        onChange?()
        saver.schedule()
    }

    /// The tree is a graph of reference objects the UI keeps editing, so it is encoded here, on the
    /// caller's thread, and only the bytes go to the I/O queue — a background writer must never
    /// serialise a structure that is changing under it. Templates are small; this is cheap.
    func saveNow(background: Bool = false) {
        if isPurged { return }
        do {
            let snapshot = try Storage.encoder.encode(root)
            Storage.saveEncoded(snapshot, to: Storage.templatesURL, background: background)
        } catch {
            Log.storage.error("failed to encode templates: \(error.localizedDescription)")
        }
    }

    func flush() { saver.flush() }

    /// Depth-first list of all text items (used for quick-add checks and searching).
    func allItems() -> [TemplateNode] {
        var out: [TemplateNode] = []
        func walk(_ n: TemplateNode) {
            if !n.isFolder { out.append(n) }
            n.children.forEach(walk)
        }
        walk(root)
        return out
    }
}
