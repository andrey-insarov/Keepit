import Foundation

/// Template tree persistence.
final class TemplateStore {
    private(set) var root = TemplateNode(name: "Template")
    var onChange: (() -> Void)?
    private lazy var saver = DebouncedSaver(delay: 1.0) { [weak self] in self?.saveNow() }

    init() {
        reload()
    }

    /// (Re)load from disk — used at start and after unlocking.
    func reload() {
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
        saveNow()
        onChange?()
    }

    /// Drop everything from memory without touching the disk (lock).
    func purge() {
        saver.flush()
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

    /// Backup import, "Merge": the imported tree goes into a new folder under the root.
    /// Returns false (and changes nothing) if that would exceed the template limits.
    func mergeImported(_ node: TemplateNode, folderName: String) -> Bool {
        let folder = TemplateNode(name: folderName, children: node.children)
        guard canInsert(folder, under: root) else { return false }
        root.insert(folder)
        root.relink()
        changed()
        return true
    }

    func changed() {
        onChange?()
        saver.schedule()
    }

    func saveNow() {
        Storage.save(root, to: Storage.templatesURL)
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
