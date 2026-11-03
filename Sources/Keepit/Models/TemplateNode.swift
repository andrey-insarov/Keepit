import Foundation

/// A node in the template tree ("Template" items): either a folder or an item.
/// Since 2.0 an item holds a full ClipItem (any formats), not just text — like the original,
/// where a template can be a bitmap or a file list.
/// Class (not struct) so NSOutlineView can use object identity.
final class TemplateNode: Codable {
    var id: UUID
    /// Display name. Empty → the content's own title is shown ("Clear Name" in the Viewer).
    /// "-" → rendered as a menu separator.
    var name: String
    /// nil → folder
    var clip: ClipItem?
    /// Optional direct hot key ("Set Hot Key" in the Viewer).
    var hotKey: HotKey?
    var children: [TemplateNode]

    weak var parent: TemplateNode?

    private enum CodingKeys: String, CodingKey { case id, name, clip, hotKey, children }

    init(id: UUID = UUID(), name: String, clip: ClipItem? = nil, children: [TemplateNode] = []) {
        self.id = id
        self.name = name
        self.clip = clip
        self.children = children
        for c in children { c.parent = self }
    }

    convenience init(name: String, text: String) {
        self.init(name: name, clip: .text(text))
    }

    var isFolder: Bool { clip == nil }
    var isSeparator: Bool { !isFolder && name == "-" }

    /// Name shown in the tree and menus.
    var displayName: String {
        if !name.isEmpty { return name }
        if let c = clip { return c.title(maxLength: 60) }
        return L("(Folder)")
    }

    /// Re-link `parent` pointers after decoding.
    func relink() {
        for c in children {
            c.parent = self
            c.relink()
        }
    }

    var depth: Int {
        var d = 0
        var p = parent
        while let cur = p { d += 1; p = cur.parent }
        return d
    }

    /// Nodes in this subtree, including self.
    var subtreeCount: Int { 1 + children.reduce(0) { $0 + $1.subtreeCount } }

    func insert(_ node: TemplateNode, at index: Int? = nil) {
        node.name = String(node.name.prefix(Limits.templateNameMaxChars))
        node.parent = self
        if let i = index, i >= 0, i <= children.count {
            children.insert(node, at: i)
        } else {
            children.append(node)
        }
    }

    func removeFromParent() {
        guard let p = parent else { return }
        p.children.removeAll { $0 === self }
        parent = nil
    }

    func find(id: UUID) -> TemplateNode? {
        if self.id == id { return self }
        for c in children {
            if let f = c.find(id: id) { return f }
        }
        return nil
    }

    func isDescendant(of other: TemplateNode) -> Bool {
        var p: TemplateNode? = self
        while let cur = p {
            if cur === other { return true }
            p = cur.parent
        }
        return false
    }

    /// Deep copy that keeps ids and hot keys: a snapshot of the tree that later edits of the
    /// live tree do not touch (RestorePlan composes the next tree on one of these).
    func clone() -> TemplateNode {
        let n = TemplateNode(id: id, name: name, clip: clip, children: children.map { $0.clone() })
        n.hotKey = hotKey
        return n
    }

    /// Deep copy with fresh ids (used for drag-copy).
    func duplicate() -> TemplateNode {
        let n = TemplateNode(name: name, clip: clip, children: children.map { $0.duplicate() })
        n.hotKey = nil
        return n
    }
}
