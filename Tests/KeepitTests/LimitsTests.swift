import XCTest
@testable import Keepit

final class LimitsTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    func testSettingsClampOnDecode() throws {
        let json = Data(#"{"historyMax": 999999, "pollInterval": 0, "thumbnailSize": 9999, "menuMaxItems": -5}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.historyMax, Limits.historyMaxCeiling)
        XCTAssertEqual(s.pollInterval, 0.1)
        XCTAssertEqual(s.thumbnailSize, 128)
        XCTAssertEqual(s.menuMaxItems, 1)
    }

    func testHistoryTotalBytesCap() {
        var s = Settings()
        s.historyMax = 1000
        s.maxHistoryBytes = 1024 * 1024          // minimum allowed by clamp
        let store = HistoryStore(settings: s)
        for i in 0..<10 { store.add(.text(String(repeating: "x", count: 300_000) + "\(i)")) }
        XCTAssertLessThanOrEqual(store.items.reduce(0) { $0 + $1.byteSize }, s.maxHistoryBytes)
        XCTAssertTrue(store.items.first!.plainText!.hasSuffix("9"), "newest survives")
    }

    func testTemplateDepthAndNameCaps() {
        let store = TemplateStore()
        var parent = store.root
        for i in 0..<(Limits.templateMaxDepth + 2) {
            let f = TemplateNode(name: "f\(i)")
            if store.canInsert(f, under: parent) { parent.insert(f); parent = f } else { break }
        }
        XCTAssertEqual(parent.depth, Limits.templateMaxDepth)          // the validator's rule: deepest node ≤ max
        XCTAssertNoThrow(try Backup.validate(Backup.Payload(history: [], templates: store.root, settings: nil)))
        let long = TemplateNode(name: String(repeating: "n", count: 1000), text: "t")
        store.root.insert(long)
        XCTAssertEqual(long.name.count, Limits.templateNameMaxChars)
    }

    // Inserting or moving a subtree counts its whole height, so no edit the Viewer admits can
    // produce a tree the backup reader rejects (the auditor's 13 + folder of height 3 case).
    func testSubtreeInsertAndMoveCountTheirFullHeight() throws {
        let store = TemplateStore()
        var parent = store.root
        for i in 0..<13 { let f = TemplateNode(name: "L\(i)"); parent.insert(f); parent = f }      // parent at depth 13
        let tall = TemplateNode(name: "Moved", children: [TemplateNode(name: "N", children: [TemplateNode(name: "D", children: [TemplateNode(name: "Leaf", text: "x")])])])
        XCTAssertEqual(tall.height, 3)
        store.root.insert(tall)
        XCTAssertFalse(store.canMove(tall, under: parent))             // 13 + 1 + 3 = 17 > 16
        XCTAssertFalse(store.canInsert(tall.duplicate(), under: parent))
        let shorter = TemplateNode(name: "Ok", children: [TemplateNode(name: "N", children: [TemplateNode(name: "Leaf", text: "x")])])
        XCTAssertTrue(store.canInsert(shorter, under: parent))         // 13 + 1 + 2 = 16
        parent.insert(shorter)
        XCTAssertNoThrow(try Backup.validate(Backup.Payload(history: [], templates: store.root, settings: nil)))
        var l0 = parent; while l0.depth > 1 { l0 = l0.parent! }                // the default tree has its own first child
        XCTAssertFalse(store.canMove(l0, under: parent))                        // L0 into its own descendant: never
        XCTAssertTrue(store.canMove(parent, under: tall.children[0]))          // 2 + 1 + height(parent) = 6: fine
    }

    func testMenuCap() {
        var s = Settings()
        s.menuMaxItems = 3
        s.historyMax = 100
        let b = MenuBuilder(settings: s)
        let items = (0..<10).map { ClipItem.text("item \($0)") }
        let menu = b.historyItems(items, target: self, action: #selector(noop), numberMods: nil)
        XCTAssertEqual(menu.count, 4)                       // 3 items + "… 7 more"
        XCTAssertFalse(menu.last!.isEnabled)
    }

    @objc private func noop() {}
}
