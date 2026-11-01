import XCTest
@testable import Keepit

final class ClipItemTests: XCTestCase {
    func testTitleUsesFirstMeaningfulLineAndCollapsesWhitespace() {
        let item = ClipItem.text("\n\n   hello    big\tworld  \nsecond line")
        XCTAssertEqual(item.title(maxLength: 60), "hello big world")
    }

    func testTitleIsTruncatedWithEllipsis() {
        let item = ClipItem.text(String(repeating: "a", count: 100))
        let t = item.title(maxLength: 10)
        XCTAssertEqual(t.count, 10)
        XCTAssertTrue(t.hasSuffix("…"))
    }

    func testEmptyTextTitle() {
        XCTAssertEqual(ClipItem.text("   ").title(maxLength: 20), "(Empty text)")
    }

    func testSameContentSameHash() {
        XCTAssertEqual(ClipItem.text("abc").contentHash, ClipItem.text("abc").contentHash)
        XCTAssertNotEqual(ClipItem.text("abc").contentHash, ClipItem.text("abd").contentHash)
    }

    func testSetTextDropsStaleRichFormats() {
        var item = ClipItem.text("plain")
        item.setData(Data("{\\rtf1}".utf8), for: ClipItem.Format.rtf)
        XCTAssertEqual(item.formats.count, 2)
        item.setText("edited")
        XCTAssertEqual(item.plainText, "edited")
        XCTAssertNil(item.formats[ClipItem.Format.rtf])
    }

    func testFileListRoundTrip() {
        var item = ClipItem.text("")
        item.setFilePaths(["/tmp/a.txt", "/tmp/b.png"])
        item.removeFormat(ClipItem.Format.text)
        XCTAssertEqual(item.kind, .files)
        XCTAssertEqual(item.filePaths, ["/tmp/a.txt", "/tmp/b.png"])
        XCTAssertEqual(item.title(maxLength: 60), "a.txt, b.png")
    }

    func testCodableRoundTrip() throws {
        let item = ClipItem.text("round trip")
        let data = try JSONEncoder().encode(item)
        let back = try JSONDecoder().decode(ClipItem.self, from: data)
        XCTAssertEqual(back.id, item.id)
        XCTAssertEqual(back.plainText, "round trip")
        XCTAssertEqual(back.contentHash, item.contentHash)
    }

    func testPrimaryFormatPriority() {
        var item = ClipItem.text("t")
        item.setData(Data([0x89, 0x50]), for: ClipItem.Format.png)
        XCTAssertEqual(item.primaryFormat, ClipItem.Format.png)
        XCTAssertEqual(item.orderedFormats, [ClipItem.Format.png, ClipItem.Format.text])
    }
}

extension ClipItemTests {
    func testPlainTextOnlyStripsRichFormats() {
        var item = ClipItem.text("hello")
        item.formats[ClipItem.Format.rtf] = Data("{\\rtf1 hello}".utf8)
        XCTAssertTrue(item.hasRichText)
        let plain = item.plainTextOnly()
        XCTAssertEqual(plain?.formats.count, 1)
        XCTAssertEqual(plain?.plainText, "hello")
        XCTAssertEqual(plain?.id, item.id)
        XCTAssertNil(ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.png: Data()], sourceApp: nil, contentHash: "x").plainTextOnly())
    }
}
