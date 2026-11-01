import XCTest
@testable import Keepit

final class BackupTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    private func samplePayload() -> Backup.Payload {
        let root = TemplateNode(name: "Template", children: [
            TemplateNode(name: "Work", children: [TemplateNode(name: "&Sig", text: "-- A")]),
            TemplateNode(name: "Hi", text: "Hello"),
        ])
        return Backup.Payload(history: [.text("one"), .text("two"), .text("three")], templates: root, settings: Settings())
    }

    func testRoundTrip() throws {
        let pw = SecureBuffer.of("backup-pass")
        let data = try Backup.encode(samplePayload(), password: pw)
        XCTAssertTrue(Backup.isBackup(data))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Hello"), "payload must not be readable in clear")
        let back = try Backup.decode(data, password: pw)
        XCTAssertEqual(back.history.map(\.contentHash), samplePayload().history.map(\.contentHash))
        XCTAssertEqual(back.templates.subtreeCount, 4)   // root + Work + Sig + Hi
        XCTAssertEqual(back.templates.children[0].children[0].clip?.plainText, "-- A")
        XCTAssertNotNil(back.settings)
        XCTAssertTrue(back.app.hasPrefix("Keepit"))
    }

    func testWrongPasswordAndGarbage() throws {
        let data = try Backup.encode(samplePayload(), password: SecureBuffer.of("right"))
        XCTAssertThrowsError(try Backup.decode(data, password: SecureBuffer.of("wrong"))) {
            XCTAssertEqual($0 as? Backup.Failure, .wrongPassword)
        }
        XCTAssertThrowsError(try Backup.decode(Data("nope".utf8), password: SecureBuffer.of("x"))) {
            XCTAssertEqual($0 as? Backup.Failure, .notABackup)
        }
        var tampered = data
        tampered[tampered.count - 1] ^= 0xFF
        XCTAssertThrowsError(try Backup.decode(tampered, password: SecureBuffer.of("right")))
        var newer = data
        newer[8] = 99
        XCTAssertThrowsError(try Backup.decode(newer, password: SecureBuffer.of("right"))) {
            XCTAssertEqual($0 as? Backup.Failure, .unsupportedVersion(99))
        }
    }

    func testHistoryMergeSkipsDuplicatesAndReplaceOverwrites() {
        var s = Settings()
        s.historySave = false
        let h = HistoryStore(settings: s)
        h.add(.text("one"))
        h.add(.text("zero"))
        let added = h.merge([.text("one"), .text("two")])
        XCTAssertEqual(added, 1)
        XCTAssertEqual(h.items.map(\.plainText), ["zero", "one", "two"])   // current items stay newest
        h.replaceAll([.text("x")])
        XCTAssertEqual(h.items.map(\.plainText), ["x"])
    }

    func testTemplateMergeGoesIntoFolderAndReplaceSwapsRoot() {
        let t = TemplateStore()
        let before = t.root.subtreeCount
        let imported = TemplateNode(name: "Template", children: [TemplateNode(name: "A", text: "a"), TemplateNode(name: "B", text: "b")])
        XCTAssertTrue(t.mergeImported(imported, folderName: "Imported"))
        XCTAssertEqual(t.root.subtreeCount, before + 3)
        let folder = t.root.children.last!
        XCTAssertEqual(folder.name, "Imported")
        XCTAssertTrue(folder.isFolder)
        XCTAssertEqual(folder.children.count, 2)
        XCTAssertTrue(folder.children[0].parent === folder)
        t.replaceRoot(TemplateNode(name: "Template", children: [TemplateNode(name: "Only", text: "o")]))
        XCTAssertEqual(t.root.subtreeCount, 2)
        XCTAssertTrue(t.root.children[0].parent === t.root)
    }

    func testSuggestedFileName() {
        XCTAssertTrue(Backup.suggestedFileName().hasPrefix("Keepit-backup-"))
        XCTAssertTrue(Backup.suggestedFileName().hasSuffix(".keepit"))
    }
}
