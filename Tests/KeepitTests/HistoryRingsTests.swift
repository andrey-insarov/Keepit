import AppKit
import XCTest
@testable import Keepit

final class HistoryRingsTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    /// A real 1×1 PNG whose pixel carries `tag`: the store validates every item it takes, so a
    /// PNG signature with a few bytes behind it is no longer an image.
    private func image(_ tag: UInt8) -> ClipItem {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let px = rep.bitmapData!                    // one opaque pixel; alpha 0 would premultiply every tag to the same PNG
        px[0] = tag; px[1] = 0; px[2] = 0; px[3] = 255
        var c = ClipItem.text("")
        c.removeFormat(ClipItem.Format.text)
        c.setData(rep.representation(using: .png, properties: [:])!, for: ClipItem.Format.png)
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
