import AppKit
import XCTest
@testable import Keepit

/// One validation boundary for everything the stores hold: the content rules of `Backup.validate`
/// (a format is what it claims), and the stores applying them to their own files on disk and to
/// every mutation — not only to a backup. Seeded from the auditor's deferred-B cases of 5–6 Nov
/// 2026: FF FE under plain text, non-RTF under RTF, invalid UTF-8 under HTML, a TIFF under PNG,
/// relative / URL / NUL file paths, local store files with a duplicate id, a wrong hash and a
/// 201-character name, and an oversize node inserted straight into the TemplateStore.
final class ValidationBoundaryTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUpWithError() throws {
        tmp = TempStorage()
        try FileManager.default.createDirectory(at: tmp.dir, withIntermediateDirectories: true)
    }
    override func tearDown() { tmp.restore() }

    private func item(_ formats: [String: Data], hashOf primary: Data? = nil) -> ClipItem {
        let p = primary ?? formats[ClipItem.Format.files] ?? formats[ClipItem.Format.text] ?? formats[ClipItem.Format.png] ?? formats.values.first!
        return ClipItem(id: UUID(), date: Date(), formats: formats, sourceApp: nil, contentHash: ClipItem.hash(of: p))
    }
    private func valid(_ c: ClipItem) -> Bool { (try? Backup.validate(item: c)) != nil }

    private var png: Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }
    private var tiff: Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.tiffRepresentation!
    }

    // MARK: content rules

    func testTextMustBeUTF8() {
        XCTAssertFalse(valid(item([ClipItem.Format.text: Data([0xFF, 0xFE])])))
        XCTAssertFalse(valid(item([ClipItem.Format.text: Data([0x61, 0xC0, 0x80])])), "overlong sequence")
        XCTAssertTrue(valid(.text("plain ✓")))
        XCTAssertNil(item([ClipItem.Format.text: Data([0xFF, 0xFE])]).validated(), "no rich format to drop: the item goes")
    }

    func testRichFormatsMustBeWhatTheyClaim() {
        let text = Data("hello".utf8)
        let badRTF = item([ClipItem.Format.text: text, ClipItem.Format.rtf: Data("not rtf".utf8)])
        XCTAssertFalse(valid(badRTF))
        XCTAssertEqual(badRTF.validated()?.formats.keys.sorted(), [ClipItem.Format.text], "the text survives without the fake RTF")
        XCTAssertTrue(valid(item([ClipItem.Format.text: text, ClipItem.Format.rtf: Data("{\\rtf1\\ansi hello}".utf8)])))

        let badHTML = item([ClipItem.Format.text: text, ClipItem.Format.html: Data([0x3C, 0xFF, 0x3E])])
        XCTAssertFalse(valid(badHTML))
        XCTAssertEqual(badHTML.validated()?.formats.keys.sorted(), [ClipItem.Format.text])
        XCTAssertTrue(valid(item([ClipItem.Format.text: text, ClipItem.Format.html: Data("<b>hello</b>".utf8)])))
        XCTAssertTrue(valid(item([ClipItem.Format.text: text, ClipItem.Format.html: Data([0xFF, 0xFE, 0x3C, 0x00])])), "UTF-16 with a BOM is accepted")
    }

    func testImageMustBePNG() {
        XCTAssertTrue(valid(item([ClipItem.Format.png: png])))
        XCTAssertFalse(valid(item([ClipItem.Format.png: tiff])), "a decodable TIFF is still not a PNG")
        XCTAssertNil(item([ClipItem.Format.png: tiff]).validated())
    }

    func testFileListMustBeAbsolutePaths() throws {
        func list(_ paths: [String]) -> ClipItem { item([ClipItem.Format.files: try! JSONEncoder().encode(paths)]) }
        XCTAssertTrue(valid(list(["/Users/x/a.txt", "/tmp/b"])))
        XCTAssertFalse(valid(list(["relative/a.txt"])))
        XCTAssertFalse(valid(list(["https://example.test/file"])))
        XCTAssertFalse(valid(list(["/tmp/a\u{0}b"])))
        XCTAssertFalse(valid(list([""])))
        XCTAssertFalse(valid(list(["/" + String(repeating: "a", count: Limits.filePathMaxBytes)])))
    }

    func testUnknownFormatsStayOpaque() {
        XCTAssertTrue(valid(item(["com.example.anything": Data([0xFF, 0x00, 0xFE])])))
    }

    // MARK: history on disk

    func testHistoryFileIsValidatedOnLoad() throws {
        let good = ClipItem.text("good")
        let wrongHash = ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.text: Data("x".utf8)], sourceApp: nil, contentHash: "0000")
        let dupe = ClipItem(id: good.id, date: Date(), formats: [ClipItem.Format.text: Data("dupe".utf8)], sourceApp: nil,
                            contentHash: ClipItem.hash(of: Data("dupe".utf8)))
        let fakeRTF = item([ClipItem.Format.text: Data("rich".utf8), ClipItem.Format.rtf: Data("nope".utf8)])
        let notPNG = item([ClipItem.Format.png: tiff])
        Storage.save([good, wrongHash, dupe, fakeRTF, notPNG], to: Storage.historyURL, encrypt: false)
        let store = HistoryStore(settings: Settings())
        XCTAssertEqual(store.items.map(\.plainText), ["good", "rich"])
        XCTAssertNil(store.items[1].formats[ClipItem.Format.rtf])
        let copies = try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).filter { $0.contains("corrupt-") }
        XCTAssertEqual(copies.count, 1, "the file as it was is kept next to it")
    }

    func testHistoryMutatorsRefuseInvalidItems() {
        let store = HistoryStore(settings: Settings())
        store.add(.text("ok"))
        let bad = item([ClipItem.Format.text: Data([0xFF])])
        store.add(bad)
        XCTAssertFalse(store.insert(bad, at: 0))
        XCTAssertFalse(store.insert(ClipItem(id: store.items[0].id, date: Date(), formats: store.items[0].formats, sourceApp: nil,
                                             contentHash: store.items[0].contentHash), at: 0), "an id already in the list")
        var edited = store.items[0]
        edited.formats[ClipItem.Format.text] = Data(count: Limits.textBytesCeiling + 1)
        XCTAssertFalse(store.replace(edited))
        XCTAssertEqual(store.items.map(\.plainText), ["ok"])
        XCTAssertTrue(store.replace(.init(id: store.items[0].id, date: Date(), formats: [ClipItem.Format.text: Data("new".utf8)],
                                          sourceApp: nil, contentHash: ClipItem.hash(of: Data("new".utf8)))))
        XCTAssertEqual(store.items.map(\.plainText), ["new"])
    }

    // MARK: templates on disk

    func testTemplateFileIsRepairedOnLoad() throws {
        let shared = UUID()
        let longName = String(repeating: "n", count: Limits.templateNameMaxChars + 1)
        let notText = item([ClipItem.Format.text: Data([0xFF, 0xFE])])    // its only format fails: the node goes
        var deep = TemplateNode(name: "leaf", text: "deep")
        for i in 0..<Limits.templateMaxDepth { deep = TemplateNode(name: "d\(i)", children: [deep]) }    // leaf at depth 17 under root
        let tree = TemplateNode(name: "Template", children: [
            TemplateNode(id: shared, name: longName, clip: .text("a")),
            TemplateNode(id: shared, name: "b", clip: .text("b")),
            TemplateNode(name: "not text", clip: notText),
            TemplateNode(name: "fake rtf", clip: item([ClipItem.Format.text: Data("rich".utf8), ClipItem.Format.rtf: Data("nope".utf8)])),
            deep,
        ])
        XCTAssertThrowsError(try Backup.validate(tree: tree))
        Storage.save(tree, to: Storage.templatesURL, encrypt: false)
        let store = TemplateStore()
        let names = store.root.children.map(\.name)
        XCTAssertEqual(names.count, 4, "the invalid item is gone, everything else stays: \(names)")
        XCTAssertEqual(store.root.children[0].name.count, Limits.templateNameMaxChars)
        XCTAssertNotEqual(store.root.children[0].id, store.root.children[1].id, "the second holder of an id gets a new one")
        XCTAssertEqual(Set([store.root.children[0].id, store.root.children[1].id]).contains(shared), true)
        XCTAssertNil(store.root.children[2].clip?.formats[ClipItem.Format.rtf], "the fake RTF is dropped, the text kept")
        XCTAssertNoThrow(try Backup.validate(tree: store.root))
        XCTAssertNil(store.allItems().first { $0.name == "leaf" }, "the node past the depth ceiling is pruned")
        XCTAssertLessThanOrEqual(store.root.height, Limits.templateMaxDepth)
        let copies = try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).filter { $0.contains("corrupt-") }
        XCTAssertEqual(copies.count, 1)
    }

    func testValidTemplateFileLoadsUntouched() throws {
        let store = TemplateStore()
        let n = TemplateNode(name: "sig", text: "sig")
        XCTAssertTrue(store.insert(n, under: store.root))
        store.flush()
        let again = TemplateStore()
        XCTAssertEqual(again.root.find(id: n.id)?.clip?.plainText, "sig")
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).filter { $0.contains("corrupt-") }.isEmpty)
    }

    // MARK: template mutators

    func testTemplateInsertIsTheGate() {
        let store = TemplateStore()
        let before = store.root.subtreeCount
        var oversize = ClipItem.text("x")
        oversize.formats[ClipItem.Format.text] = Data(count: Limits.textBytesCeiling + 1)
        oversize = ClipItem(id: UUID(), date: Date(), formats: oversize.formats, sourceApp: nil,
                            contentHash: ClipItem.hash(of: oversize.formats[ClipItem.Format.text]!))
        XCTAssertFalse(store.insert(TemplateNode(name: "big", clip: oversize), under: store.root))
        XCTAssertFalse(store.insert(TemplateNode(name: "tiff", clip: item([ClipItem.Format.png: tiff])), under: store.root))
        XCTAssertFalse(store.insert(TemplateNode(name: String(repeating: "n", count: 201), text: "x"), under: store.root), "a name past the limit is the caller's to cut")
        let existing = store.allItems().first!
        XCTAssertFalse(store.insert(TemplateNode(id: existing.id, name: "twin", clip: .text("x")), under: store.root), "an id already in the tree")
        var deep = TemplateNode(name: "leaf", text: "x")
        for i in 0..<Limits.templateMaxDepth { deep = TemplateNode(name: "d\(i)", children: [deep]) }
        XCTAssertFalse(store.insert(deep, under: store.root), "too deep for the root")
        XCTAssertEqual(store.root.subtreeCount, before, "nothing entered")
        XCTAssertTrue(store.insert(TemplateNode(name: "ok", text: "x"), under: store.root))
        XCTAssertEqual(store.root.subtreeCount, before + 1)

        let node = store.allItems().first { $0.name == "ok" }!
        XCTAssertFalse(store.update(node, clip: oversize))
        XCTAssertEqual(node.clip?.plainText, "x")
        XCTAssertTrue(store.update(node, clip: .text("y")))
        XCTAssertEqual(node.clip?.plainText, "y")
    }

    // MARK: the auditor's second round on PR #25

    /// A 3.0.3 archive carried HTML as the app had put it on the pasteboard — Latin-1, UTF-16 without
    /// a BOM. That must cost the item its HTML, not the backup its text, images, paths and templates.
    func testArchiveWithLegacyHTMLStillOpens() throws {
        let text = Data("café 🚀".utf8)
        for html in [Data("<meta charset=\"iso-8859-1\"><p>caf\u{E9}</p>".utf8).isoLatin1Reencoded,
                     "<meta charset=\"utf-16le\"><p>🚀</p>".data(using: .utf16LittleEndian)!] {
            let rich = ClipItem(id: UUID(), date: Date(),
                                formats: [ClipItem.Format.text: text, ClipItem.Format.rtf: Data("{\\rtf1\\ansi cafe}".utf8), ClipItem.Format.html: html],
                                sourceApp: "audit", contentHash: ClipItem.hash(of: text))
            XCTAssertFalse(valid(rich))
            let payload = Backup.Payload(history: [rich, item([ClipItem.Format.png: png])],
                                         templates: TemplateNode(name: "Template", children: [TemplateNode(name: "rich", clip: rich)]), settings: nil)
            let json = try Storage.encoder.encode(payload)                      // what 3.0.3 sealed: validated with the old rules
            let back = try Backup.payload(fromJSON: json)
            XCTAssertEqual(back.history.count, 2)
            XCTAssertEqual(back.history[0].plainText, "café 🚀")
            XCTAssertEqual(back.history[0].contentHash, rich.contentHash)
            XCTAssertNil(back.history[0].formats[ClipItem.Format.html])
            XCTAssertNotNil(back.history[0].formats[ClipItem.Format.rtf], "the good RTF stays")
            XCTAssertNil(back.templates.children[0].clip?.formats[ClipItem.Format.html])
            XCTAssertEqual(back.templates.children[0].id, payload.templates.children[0].id)
        }
    }

    func testArchiveNormalisationSoftensNothingElse() throws {
        let bad = item([ClipItem.Format.text: Data([0xFF, 0xFE])])
        let payload = Backup.Payload(history: [bad], templates: TemplateNode(name: "Template"), settings: nil)
        XCTAssertThrowsError(try Backup.payload(fromJSON: try Storage.encoder.encode(payload)))
        let wrongHash = ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.text: Data("x".utf8)], sourceApp: nil, contentHash: "0")
        XCTAssertThrowsError(try Backup.payload(fromJSON: try Storage.encoder.encode(Backup.Payload(history: [wrongHash], templates: TemplateNode(name: "Template"), settings: nil))))
    }

    func testOnlyTheFailingRichFormatIsDropped() {
        let text = Data("hello".utf8)
        let both = item([ClipItem.Format.text: text, ClipItem.Format.rtf: Data("{\\rtf1 ok}".utf8), ClipItem.Format.html: Data([0x3C, 0xFF])])
        XCTAssertEqual(both.validated()?.formats.keys.sorted(), [ClipItem.Format.rtf, ClipItem.Format.text].sorted())
        let other = item([ClipItem.Format.text: text, ClipItem.Format.rtf: Data("nope".utf8), ClipItem.Format.html: Data("<b>ok</b>".utf8)])
        XCTAssertEqual(other.validated()?.formats.keys.sorted(), [ClipItem.Format.html, ClipItem.Format.text].sorted())
    }

    func testRepairKeepsTheChildrenOfANodeWhoseClipFails() throws {
        let bad = item([ClipItem.Format.text: Data([0xFF])])
        let child = TemplateNode(name: "good", text: "g")
        let tree = TemplateNode(name: "Template", clip: bad, children: [
            TemplateNode(name: "folder-ish", clip: bad, children: [child]),
            TemplateNode(name: "leaf", clip: bad),
        ])
        let repaired = TemplateStore.validated(tree)
        XCTAssertEqual(repaired.id, tree.id)
        XCTAssertNil(repaired.clip, "a root never carries a clip; the bad one is gone")
        XCTAssertEqual(repaired.children.map(\.name), ["folder-ish"], "the childless bad leaf is removed")
        XCTAssertNil(repaired.children[0].clip)
        XCTAssertTrue(repaired.children[0].isFolder)
        XCTAssertEqual(repaired.children[0].children.first?.id, child.id)
        XCTAssertEqual(repaired.children[0].children.first?.clip?.plainText, "g")
        XCTAssertNoThrow(try Backup.validate(tree: repaired))
    }

    func testHistoryKeepsOneHolderPerID() {
        let store = HistoryStore(settings: Settings())
        let a = ClipItem.text("a")
        store.add(a)
        store.add(ClipItem(id: a.id, date: Date(), formats: [ClipItem.Format.text: Data("b".utf8)], sourceApp: nil, contentHash: ClipItem.hash(of: Data("b".utf8))))
        XCTAssertEqual(store.items.map(\.plainText), ["b"])
        store.replaceAll([a, ClipItem(id: a.id, date: Date(), formats: [ClipItem.Format.text: Data("c".utf8)], sourceApp: nil, contentHash: ClipItem.hash(of: Data("c".utf8)))])
        XCTAssertEqual(store.items.map(\.plainText), ["a"], "first holder wins in a payload")
    }

    func testInsertCountsHotKeysAgainstTheWholeTree() {
        let store = TemplateStore()
        let key = HotKey(keyCode: 0, modifiers: 0)
        var nodes: [TemplateNode] = []
        for i in 0..<Limits.templateHotKeysMax { let n = TemplateNode(name: "k\(i)", text: "x"); n.hotKey = key; nodes.append(n) }
        store.setRootForTesting(TemplateNode(name: "Template", children: nodes))
        XCTAssertEqual(store.hotKeyCount, Limits.templateHotKeysMax)
        let one = TemplateNode(name: "one more", text: "x"); one.hotKey = key
        XCTAssertFalse(store.insert(one, under: store.root))
        XCTAssertTrue(store.insert(TemplateNode(name: "no key", text: "x"), under: store.root))
        XCTAssertNoThrow(try Backup.validate(tree: store.root))
    }
}

private extension Data {
    /// The bytes as Latin-1 would have them: `é` becomes one byte 0xE9, which is not UTF-8.
    var isoLatin1Reencoded: Data { String(decoding: self, as: UTF8.self).data(using: .isoLatin1)! }
}
