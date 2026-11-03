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
            root = loaded
            root.relink()
        } else {
            root = Self.defaultTree()
            saveNow()
        }
        onChange?()
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

    /// Back to the fresh-install tree (Reset).
    func resetToDefaults() {
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

    /// Would adding `node` under `parent` exceed the depth/count ceilings?
    func canInsert(_ node: TemplateNode, under parent: TemplateNode) -> Bool {
        guard parent.depth + 1 < Limits.templateMaxDepth else { return false }
        return root.subtreeCount + node.subtreeCount <= Limits.templateMaxCount
    }

    /// Backup import, "Replace".
    func replaceRoot(_ node: TemplateNode) {
        root = node
        root.relink()
        changed()
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
