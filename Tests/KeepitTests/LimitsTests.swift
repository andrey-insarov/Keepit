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
        XCTAssertEqual(parent.depth, Limits.templateMaxDepth - 1)
        let long = TemplateNode(name: String(repeating: "n", count: 1000), text: "t")
        store.root.insert(long)
        XCTAssertEqual(long.name.count, Limits.templateNameMaxChars)
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
