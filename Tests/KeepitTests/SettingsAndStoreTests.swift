import XCTest
import AppKit
@testable import Keepit
import Carbon.HIToolbox

final class SettingsAndStoreTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    func testSettingsTolerateMissingKeys() throws {
        let json = Data(#"{"historyMax": 7}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.historyMax, 7)
        XCTAssertEqual(s.historyHotKey, Settings().historyHotKey)
        XCTAssertEqual(s.lockWithScreen, true)
    }

    func testSettingsRoundTrip() throws {
        var s = Settings()
        s.pasteKeys["com.example"] = .shiftCommandV
        s.ignoreApps = ["a", "b"]
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    func testHistoryDedupeTrimMoveAndPersist() {
        var s = Settings()
        s.historyMax = 3
        let store = HistoryStore(settings: s)
        store.add(.text("1")); store.add(.text("2")); store.add(.text("3")); store.add(.text("4"))
        XCTAssertEqual(store.items.map(\.plainText), ["4", "3", "2"])
        store.add(.text("2"))                                   // duplicate moves to top
        XCTAssertEqual(store.items.map(\.plainText), ["2", "4", "3"])
        store.move(id: store.items[2].id, by: -1)
        XCTAssertEqual(store.items.map(\.plainText), ["2", "3", "4"])
        store.flush()
        let reloaded = HistoryStore(settings: s)
        XCTAssertEqual(reloaded.items.map(\.plainText), ["2", "3", "4"])
    }

    func testHistoryEncryptedOnDiskWhenKeyIsSet() throws {
        let key = try Vault.enable(password: .of("pw"))
        Storage.key = key
        let store = HistoryStore(settings: Settings())
        store.add(.text("secret text"))
        store.flush()
        let raw = try Data(contentsOf: Storage.historyURL)
        XCTAssertTrue(Vault.isEncrypted(raw))
        XCTAssertNil(String(data: raw, encoding: .utf8)?.range(of: "secret text"))
        XCTAssertEqual(HistoryStore(settings: Settings()).items.first?.plainText, "secret text")
        Storage.clearKey()
        XCTAssertNil(HistoryStore(settings: Settings()).items.first, "no key → encrypted file is not readable")
    }

    func testQuitWhileLockedKeepsHistoryAndTemplatesOnDisk() throws {
        let key = try Vault.enable(password: .of("pw"))
        Storage.key = key
        let h = HistoryStore(settings: Settings())
        h.add(.text("keep me"))
        h.flush()
        let t = TemplateStore()
        let n = TemplateNode(name: "sig", text: "sig")
        t.root.insert(n); t.changed(); t.flush()
        // Lock: purge memory, forget the key; then what applicationWillTerminate does.
        h.purge(); t.purge(); Storage.clearKey()
        h.flush(); t.flush(); h.saveNow(); t.saveNow()
        Storage.key = key
        XCTAssertEqual(HistoryStore(settings: Settings()).items.first?.plainText, "keep me")
        XCTAssertEqual(TemplateStore().root.find(id: n.id)?.clip?.plainText, "sig")
        XCTAssertTrue(Vault.isEncrypted(try Data(contentsOf: Storage.historyURL)), "never rewritten as plaintext")
    }

    func testTemplateStorePurgeAndReload() {
        let store = TemplateStore()
        let n = TemplateNode(name: "n", text: "t")
        store.root.insert(n)
        store.changed()
        store.flush()
        store.purge()
        XCTAssertNil(store.root.find(id: n.id))
        store.reload()
        XCTAssertEqual(store.root.find(id: n.id)?.clip?.plainText, "t")
    }
}

final class TextTransformTests: XCTestCase {
    func testTransforms() {
        XCTAssertEqual(TextTransform.upper.apply("héllo wörld"), "HÉLLO WÖRLD")
        XCTAssertEqual(TextTransform.lower.apply("ABC Def"), "abc def")
        XCTAssertEqual(TextTransform.title.apply("the quick brown fox"), "The Quick Brown Fox")
        XCTAssertEqual(TextTransform.sentence.apply("HELLO there. how ARE you? fine!"), "Hello there. How are you? Fine!")
        XCTAssertEqual(TextTransform.trim.apply("  a b \n"), "a b")
        XCTAssertEqual(TextTransform.singleLine.apply("one\n  two\r\n\nthree"), "one two three")
    }

    func testTransformedItemIsNewTextOnlyContent() {
        let item = ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.text: Data("abc".utf8), ClipItem.Format.rtf: Data("x".utf8)],
                            sourceApp: nil, contentHash: "h")
        let out = item.transformed(.upper)!
        XCTAssertEqual(out.plainText, "ABC")
        XCTAssertNil(out.formats[ClipItem.Format.rtf])
        XCTAssertNotEqual(out.id, item.id)
        XCTAssertNotEqual(out.contentHash, item.contentHash)
    }
}

final class SnippetTests: XCTestCase {
    func testDetectsPlaceholders() {
        XCTAssertTrue(Snippets.containsPlaceholders("x {date} y"))
        XCTAssertFalse(Snippets.containsPlaceholders("json {\"a\":1}"))
        XCTAssertFalse(Snippets.containsPlaceholders("no braces"))
    }

    func testExpandsDatesClipboardAndFilters() {
        var ctx = Snippets.Context()
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 1; comps.hour = 12
        ctx.now = Calendar(identifier: .gregorian).date(from: comps)!
        ctx.locale = Locale(identifier: "en_US_POSIX")
        ctx.clipboard = { n in ["  first\nline ", "second"][safe: n - 1] }
        ctx.userName = "Ann"; ctx.shortUserName = "ann"; ctx.hostName = "mac"
        let e = Snippets.expand("{date:yyyy-MM-dd} {date+7d:yyyy-MM-dd} {date-1m:MM} {year} [{clipboard|trim|oneline|upper}] [{clipboard:2}] [{clipboard:9}] {user}/{username}@{host} {{x}} {unknown}", context: ctx)
        XCTAssertEqual(e.text, "2026-11-01 2026-11-08 10 2026 [FIRST LINE] [second] [] Ann/ann@mac {x} {unknown}")
        XCTAssertNil(e.charsAfterCursor)
    }

    func testPromptsAndCursor() {
        let s = "Hi {input:Name=Bob}, {choice:Tone=warm|cold} {input:Name}!{cursor}tail"
        let p = Snippets.prompts(in: s)
        XCTAssertEqual(p, [Snippets.Prompt(name: "Name", defaultValue: "Bob", choices: []),
                           Snippets.Prompt(name: "Tone", defaultValue: "warm", choices: ["warm", "cold"])])
        var ctx = Snippets.Context()
        ctx.answers = ["Name": "Zoë", "Tone": "cold"]
        let e = Snippets.expand(s, context: ctx)
        XCTAssertEqual(e.text, "Hi Zoë, cold Zoë!tail")
        XCTAssertEqual(e.charsAfterCursor, 4)
    }

    func testShift() {
        let cal = Calendar(identifier: .gregorian)
        let d = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(Snippets.shifted(d, by: "+2d", calendar: cal), cal.date(byAdding: .day, value: 2, to: d))
        XCTAssertNil(Snippets.shifted(d, by: "+2x", calendar: cal))
        XCTAssertNil(Snippets.shifted(d, by: "line", calendar: cal))
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

final class HotKeySettingsTests: XCTestCase {
    func testNewHotKeyFieldsRoundTripAndDefaults() throws {
        var s = Settings()
        XCTAssertEqual(s.numberPasteModifiers, HotKey.controlOption)
        XCTAssertEqual(s.latestActionModifiers, HotKey.controlOption)
        XCTAssertEqual(s.lockHotKey, HotKey.option(kVK_ANSI_L))
        s.numberPasteModifiers = nil                      // explicitly off must survive a round trip
        s.lockHotKey = HotKey(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | controlKey))
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertNil(back.numberPasteModifiers)
        XCTAssertEqual(back.lockHotKey, s.lockHotKey)
        XCTAssertEqual(back.latestActionModifiers, HotKey.controlOption)
    }

    func testOldSettingsWithoutNewKeysGetDefaults() throws {
        let back = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        XCTAssertEqual(back.numberPasteModifiers, HotKey.controlOption)
        XCTAssertEqual(back.previousHotKey, HotKey.optionShiftV)
        XCTAssertEqual(back.historyHotKey, HotKey.optionM)
        XCTAssertEqual(back.clearHistoryHotKey, HotKey.option(kVK_ANSI_C))
    }

    func testMigrationDropsNewDefaultsThatCollideWithOldKeys() throws {
        // A 2.9.0 settings file: history on ⌥C, none of the 2.9.1 keys present.
        let json = Data(#"{"historyHotKey":{"keyCode":8,"modifiers":2048}}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.historyHotKey, HotKey.optionC)
        XCTAssertNil(s.clearHistoryHotKey, "⌥C already taken by the history menu")
        XCTAssertEqual(s.viewerHotKey, HotKey.option(kVK_ANSI_E), "unaffected defaults still apply")
        XCTAssertEqual(s.queuePasteHotKey, HotKey.option(kVK_ANSI_V))
    }

    func testViewerMovesFromOptionVToOptionEWhenTheQueueArrives() throws {
        // A 2.9.x file wrote every key explicitly; the Viewer sat on ⌥V, which 2.10 gives to the paste queue.
        let json = Data(#"{"viewerHotKey":{"keyCode":9,"modifiers":2048}}"#.utf8)   // 9 = kVK_ANSI_V
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.viewerHotKey, HotKey.option(kVK_ANSI_E))
        XCTAssertEqual(s.queuePasteHotKey, HotKey.option(kVK_ANSI_V))
        XCTAssertEqual(s.queueHotKey, HotKey.option(kVK_ANSI_N))
        // But a file that already knows about the queue keeps whatever it says.
        let json2 = Data(#"{"viewerHotKey":{"keyCode":9,"modifiers":2048},"queuePasteHotKey":null}"#.utf8)
        let s2 = try JSONDecoder().decode(Settings.self, from: json2)
        XCTAssertEqual(s2.viewerHotKey, HotKey.option(kVK_ANSI_V))
        XCTAssertNil(s2.queuePasteHotKey)
    }

    func testQueueKeysMoveFromRToN() throws {
        // A 2.10.x file on the old defaults follows the new ones; a custom key stays.
        let old = Data(#"{"queueHotKey":{"keyCode":15,"modifiers":2048},"queuePasteAllHotKey":{"keyCode":15,"modifiers":2560}}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: old)
        XCTAssertEqual(s.queueHotKey, HotKey.option(kVK_ANSI_N)); XCTAssertEqual(s.queuePasteAllHotKey, HotKey.optionShift(kVK_ANSI_N))
        let custom = Data(#"{"queueHotKey":{"keyCode":15,"modifiers":2048},"viewerHotKey":{"keyCode":45,"modifiers":2048}}"#.utf8)   // Viewer on ⌥N
        let c = try JSONDecoder().decode(Settings.self, from: custom)
        XCTAssertEqual(c.queueHotKey, HotKey.option(kVK_ANSI_R), "⌥N is the Viewer here, so the queue keeps ⌥R")
    }

    func testQueueSettingsRoundTrip() throws {
        var s = Settings()
        s.queueTimeout = 45; s.queueSeparator = "\t"; s.queuePasteAllHotKey = nil
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.queueTimeout, 45); XCTAssertEqual(back.queueSeparator, "\t"); XCTAssertNil(back.queuePasteAllHotKey)
        XCTAssertEqual(back.queueHotKey, HotKey.option(kVK_ANSI_N))
    }

    func testLatestActionKeyCodesAreDistinct() {
        let codes = HotKey.LatestAction.allCases.map(\.keyCode)
        XCTAssertEqual(Set(codes).count, codes.count)
        XCTAssertTrue(Set(HotKey.digitKeyCodes).isDisjoint(with: codes))
    }
}

final class MenuKeyEquivalentTests: XCTestCase {
    func testHotKeyMapsToMenuKeyEquivalent() {
        let hk = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey))
        let eq = hk.menuKeyEquivalent
        XCTAssertEqual(eq?.key, "v")
        XCTAssertEqual(eq?.mask, [.control, .option])
        XCTAssertEqual(HotKey(keyCode: UInt32(kVK_F5), modifiers: 0).menuKeyEquivalent?.key, String(UnicodeScalar(NSF5FunctionKey)!))
        XCTAssertNil(HotKey(keyCode: 0xFFFF, modifiers: 0).menuKeyEquivalent)
    }
}

final class PasteQueueTests: XCTestCase {
    func testFifoOrderAndAutoStop() {
        let q = PasteQueue(); q.timeout = 0
        var stops = 0; q.onAutoStop = { stops += 1 }
        q.record(ClipItem.text("ignored: queue is off"))
        XCTAssertFalse(q.isActive); XCTAssertEqual(q.remaining, 0)
        q.start()
        q.record(ClipItem.text("a")); q.record(ClipItem.text("b")); q.record(ClipItem.text("c"))
        XCTAssertEqual(q.remaining, 3)
        XCTAssertEqual(q.take()?.plainText, "a")
        XCTAssertEqual(q.take()?.plainText, "b")
        XCTAssertTrue(q.isActive); XCTAssertEqual(q.remaining, 1)
        XCTAssertEqual(q.take()?.plainText, "c")
        XCTAssertFalse(q.isActive, "ends by itself after the last item"); XCTAssertEqual(stops, 1)
        XCTAssertNil(q.take())
    }

    func testMarksAndTakeAll() {
        let q = PasteQueue(); q.timeout = 0
        q.start()
        let a = ClipItem.text("a"), b = ClipItem.text("b"), c = ClipItem.text("c")
        q.record(a); q.record(b); q.record(c)
        _ = q.take()
        XCTAssertTrue(q.wasPasted(a.id)); XCTAssertTrue(q.isNext(b.id)); XCTAssertTrue(q.isQueued(c.id)); XCTAssertFalse(q.isQueued(a.id))
        XCTAssertEqual(q.takeAll(separator: "\n"), "b\nc")
        XCTAssertFalse(q.isActive)
        q.start(); XCTAssertNil(q.takeAll(separator: ","), "nothing queued → nil, queue stays on"); XCTAssertTrue(q.isActive)
        q.stop(); XCTAssertFalse(q.isActive)
    }

    func testTimeoutStopsTheQueue() {
        let q = PasteQueue(); q.timeout = 0.2
        let done = expectation(description: "auto stop")
        q.onAutoStop = { done.fulfill() }
        q.start(); q.record(ClipItem.text("a"))
        wait(for: [done], timeout: 2)
        XCTAssertFalse(q.isActive); XCTAssertEqual(q.remaining, 0)
    }
}

final class InputLimitTests: XCTestCase {
    private func png(width: Int, height: Int) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        return rep.representation(using: .png, properties: [:])!
    }

    func testImagePixelCapReadsTheHeaderOnly() {
        let small = png(width: 40, height: 30)
        XCTAssertTrue(ClipItem.pixelCountOK(small))
        XCTAssertFalse(ClipItem.pixelCountOK(small, maxPixels: 1_000), "1 200 px > 1 000")
        XCTAssertFalse(ClipItem.pixelCountOK(Data([0x00, 0x01, 0x02]), maxPixels: 1_000_000), "garbage fails closed")
    }

    func testPasteQueueStopsGrowingAtTheCap() {
        let q = PasteQueue(); q.timeout = 0
        q.start()
        for i in 0..<(Limits.queueMaxItems + 20) { q.record(ClipItem.text("\(i)")) }
        XCTAssertEqual(q.remaining, Limits.queueMaxItems)
    }
}

