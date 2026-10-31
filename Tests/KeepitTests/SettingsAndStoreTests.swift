import XCTest
@testable import Keepit

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
