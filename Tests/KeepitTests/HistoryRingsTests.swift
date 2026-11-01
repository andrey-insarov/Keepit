import XCTest
@testable import Keepit

final class HistoryRingsTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    private func image(_ tag: UInt8) -> ClipItem {
        var c = ClipItem.text("")
        c.removeFormat(ClipItem.Format.text)
        c.setData(Data([0x89, 0x50, 0x4E, 0x47, tag]), for: ClipItem.Format.png)
        return c
    }

    func testIndependentRings() {
        var s = Settings()
        s.historyMax = 3
        s.historyImageMax = 2
        let store = HistoryStore(settings: s)
        for i in 0..<5 { store.add(.text("t\(i)")); store.add(image(UInt8(i))) }
        XCTAssertEqual(store.textItems.map(\.plainText), ["t4", "t3", "t2"])
        XCTAssertEqual(store.imageItems.count, 2)
        XCTAssertEqual(store.items.count, 5)
        XCTAssertEqual(store.items.first?.kind, .image, "newest overall stays first")
    }
}

extension HistoryRingsTests {
    func testExpireDropsOldItems() {
        var s = Settings()
        s.historySave = false
        s.historyMaxAge = 3600
        let h = HistoryStore(settings: s)
        h.add(.text("fresh"))
        func text(_ t: String, age: TimeInterval) -> ClipItem {
            let base = ClipItem.text(t)
            return ClipItem(id: base.id, date: Date().addingTimeInterval(-age), formats: base.formats, sourceApp: nil, contentHash: base.contentHash)
        }
        h.insert(text("old", age: 7200), at: 1)
        XCTAssertEqual(h.items.count, 1, "trim() on insert already drops items past the age")
        h.insert(text("stale", age: 10), at: 1)
        XCTAssertEqual(h.items.count, 2)
        XCTAssertEqual(h.expire(now: Date().addingTimeInterval(3601 + 10)), 2)
        XCTAssertTrue(h.items.isEmpty)
        s.historyMaxAge = 0
        h.updateSettings(s)
        XCTAssertEqual(h.expire(), 0)
    }
}
