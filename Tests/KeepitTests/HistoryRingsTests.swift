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
