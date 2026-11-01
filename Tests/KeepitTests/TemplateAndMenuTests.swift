import XCTest
@testable import Keepit

final class TemplateAndMenuTests: XCTestCase {
    func testTreeInsertFindRemove() {
        let root = TemplateNode(name: "root")
        let folder = TemplateNode(name: "F")
        let item = TemplateNode(name: "i", text: "x")
        root.insert(folder)
        folder.insert(item)
        XCTAssertTrue(item.isDescendant(of: root))
        XCTAssertTrue(root.find(id: item.id) === item)
        XCTAssertEqual(item.parent?.id, folder.id)
        item.removeFromParent()
        XCTAssertNil(root.find(id: item.id))
        XCTAssertNil(item.parent)
    }

    func testDisplayNameFallsBackToContent() {
        let n = TemplateNode(name: "", text: "first line\nsecond")
        XCTAssertEqual(n.displayName, "first line …")
        XCTAssertTrue(TemplateNode(name: "-", text: "").isSeparator)
        XCTAssertTrue(TemplateNode(name: "F").isFolder)
    }

    func testCodableKeepsHierarchyAndRelinks() throws {
        let root = TemplateNode(name: "root", children: [
            TemplateNode(name: "F", children: [TemplateNode(name: "a", text: "A")]),
        ])
        let data = try JSONEncoder().encode(root)
        let back = try JSONDecoder().decode(TemplateNode.self, from: data)
        back.relink()
        XCTAssertEqual(back.children.first?.children.first?.clip?.plainText, "A")
        XCTAssertTrue(back.children.first?.children.first?.parent === back.children.first)
    }

    func testAmpersandParsing() {
        XCTAssertEqual(MenuBuilder.parseAmpersand("&Greeting").title, "Greeting")
        XCTAssertEqual(MenuBuilder.parseAmpersand("&Greeting").shortcut, "g")
        XCTAssertEqual(MenuBuilder.parseAmpersand("Tom && Jerry").title, "Tom & Jerry")
        XCTAssertNil(MenuBuilder.parseAmpersand("Tom && Jerry").shortcut)
        XCTAssertEqual(MenuBuilder.parseAmpersand("a&b&c").shortcut, "b")
    }

    func testTemplateMenuRendersSeparatorsAndShortcuts() {
        let root = TemplateNode(name: "root", children: [
            TemplateNode(name: "&One", text: "1"),
            TemplateNode(name: "-", text: ""),
            TemplateNode(name: "Folder", children: [TemplateNode(name: "", text: "inner")]),
        ])
        let builder = MenuBuilder(settings: Settings())
        let menu = builder.templateMenu(root, target: self, action: #selector(dummy))
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "One")
        XCTAssertEqual(menu.items[0].keyEquivalent, "o")
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(menu.items[2].submenu?.items.first?.title, "inner")
    }

    @objc private func dummy() {}
}
