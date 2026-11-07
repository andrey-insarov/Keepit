import XCTest
@testable import Keepit

/// A data file that exists but cannot be read is left exactly as it is — not replaced by an empty
/// store, not deleted, not copied aside on its own. Reproductions from the 3.0.5 security review
/// (SEC10: a damaged tag or a wrong key looked like "no file" and the defaults were written over
/// it; SEC06: plain JSON in the place of a sealed file was accepted, and a plaintext `check` in
/// vault.json verified for any password), asserted the safe way round.
final class LoadResultTests: XCTestCase {
    private var tmp: TempStorage!

    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    private func bytes(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    private func files() throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).sorted() }

    /// Flip the last byte: the GCM tag no longer verifies, the file is still "encrypted".
    private func damage(_ url: URL) throws {
        var d = try bytes(url)
        d[d.count - 1] ^= 0xFF
        try d.write(to: url)
    }

    private func enableVault(_ pw: String = "pw") throws {
        Storage.key = try Vault.enable(password: .of(pw), rounds: 1000)
    }

    // MARK: Storage.read tells missing, loaded and failed apart

    func testMissingFileIsAFreshStart() throws {
        if case .missing = Storage.read([ClipItem].self, from: Storage.historyURL) {} else { XCTFail("no file → .missing") }
        let t = TemplateStore()
        XCTAssertNil(t.loadFailure)
        XCTAssertFalse(t.root.children.isEmpty, "the example tree")
        XCTAssertTrue(FileManager.default.fileExists(atPath: Storage.templatesURL.path), "and it is saved")
    }

    func testEveryFailureIsNamed() throws {
        try enableVault()
        Storage.save([ClipItem.text("x")], to: Storage.historyURL)
        try damage(Storage.historyURL)
        XCTAssertEqual(Storage.read([ClipItem].self, from: Storage.historyURL).failure, .wrongKeyOrDamaged)
        Storage.clearKey()
        XCTAssertEqual(Storage.read([ClipItem].self, from: Storage.historyURL).failure, .locked)
        try Data("[]".utf8).write(to: Storage.historyURL)
        XCTAssertEqual(Storage.read([ClipItem].self, from: Storage.historyURL).failure, .notEncrypted, "protection on, plain file")
        Vault.disable()
        try Data("[".utf8).write(to: Storage.historyURL)
        XCTAssertEqual(Storage.read([ClipItem].self, from: Storage.historyURL).failure, .malformed)
        try FileManager.default.createDirectory(at: Storage.templatesURL, withIntermediateDirectories: false)
        let dirFailure = try XCTUnwrap(Storage.read(TemplateNode.self, from: Storage.templatesURL).failure)
        if case .io = dirFailure {} else { XCTFail("a directory → .io, got \(dirFailure)") }
        try FileManager.default.removeItem(at: Storage.templatesURL)
        FileManager.default.createFile(atPath: Storage.templatesURL.path, contents: nil)
        XCTAssertEqual(truncate(Storage.templatesURL.path, off_t(Limits.dataFileMaxBytes) + 1), 0)   // sparse: no disk used
        XCTAssertEqual(Storage.read(TemplateNode.self, from: Storage.templatesURL).failure, .tooLarge)
    }

    // MARK: SEC10 — nothing is written over a file that failed to load

    func testDamagedTemplatesAreNotReplacedByTheDefaults() throws {
        try enableVault()
        let t = TemplateStore()
        let n = TemplateNode(name: "sig", text: "mine")
        XCTAssertTrue(t.insert(n, under: t.root))
        t.flush()
        try damage(Storage.templatesURL)
        let before = try bytes(Storage.templatesURL)
        let list = try files()

        let again = TemplateStore()                          // 3.0.5: defaultTree() + saveNow() here
        XCTAssertEqual(again.loadFailure, .wrongKeyOrDamaged)
        XCTAssertTrue(again.root.children.isEmpty, "nothing of the user's, and not the examples either")
        XCTAssertEqual(try bytes(Storage.templatesURL), before, "the file is exactly as it was")
        XCTAssertEqual(try files(), list, "no copy was made on its own")

        // Edits in memory are not saved over it either — by the debounced saver, flush or saveNow.
        XCTAssertTrue(again.insert(TemplateNode(name: "new", text: "new"), under: again.root))
        again.flush(); again.saveNow(); again.saveNow(background: true); Storage.waitUntilSaved()
        XCTAssertEqual(try bytes(Storage.templatesURL), before)
    }

    func testDamagedHistoryIsNotReplacedByAnEmptyList() throws {
        try enableVault()
        let h = HistoryStore(settings: Settings())
        h.add(.text("mine"))
        h.flush()
        try damage(Storage.historyURL)
        let before = try bytes(Storage.historyURL)

        let again = HistoryStore(settings: Settings())       // 3.0.5: items = [] and the next flush wrote []
        XCTAssertEqual(again.loadFailure, .wrongKeyOrDamaged)
        XCTAssertTrue(again.items.isEmpty)
        again.add(.text("new"))
        again.flush(); again.saveNow(); again.saveNow(background: true); Storage.waitUntilSaved()
        XCTAssertEqual(try bytes(Storage.historyURL), before)

        // Turning "save history" off deletes the file in a healthy store; not this one.
        var s = Settings(); s.historySave = false
        again.updateSettings(s)
        again.saveNow()
        XCTAssertEqual(try bytes(Storage.historyURL), before, "not deleted either")
    }

    func testFilesUnderAnotherKeyAreKept() throws {
        // The SEC01 shape: vault.json already names a new key, the data files are still under the old.
        try enableVault("old")
        let h = HistoryStore(settings: Settings()); h.add(.text("under the old key")); h.flush()
        let t = TemplateStore(); XCTAssertTrue(t.insert(TemplateNode(name: "n", text: "n"), under: t.root)); t.flush()
        let hBytes = try bytes(Storage.historyURL), tBytes = try bytes(Storage.templatesURL)

        Storage.key = try Vault.enable(password: .of("new"), rounds: 1000)   // as rekey() does before the data is re-saved
        let h2 = HistoryStore(settings: Settings()), t2 = TemplateStore()
        XCTAssertEqual(h2.loadFailure, .wrongKeyOrDamaged)
        XCTAssertEqual(t2.loadFailure, .wrongKeyOrDamaged)
        h2.flush(); t2.flush(); h2.saveNow(); t2.saveNow()
        XCTAssertEqual(try bytes(Storage.historyURL), hBytes)
        XCTAssertEqual(try bytes(Storage.templatesURL), tBytes)
    }

    func testEncryptedFilesWithoutAVaultAreKept() throws {
        // The disableProtection() shape: vault.json removed, the data files still sealed.
        try enableVault()
        let h = HistoryStore(settings: Settings()); h.add(.text("sealed")); h.flush()
        let t = TemplateStore(); t.flush()
        let hBytes = try bytes(Storage.historyURL), tBytes = try bytes(Storage.templatesURL)
        Storage.clearKey()
        Vault.disable()

        let h2 = HistoryStore(settings: Settings()), t2 = TemplateStore()
        XCTAssertEqual(h2.loadFailure, .locked)
        XCTAssertEqual(t2.loadFailure, .locked)
        h2.flush(); t2.flush(); h2.saveNow(); t2.saveNow()
        XCTAssertEqual(try bytes(Storage.historyURL), hBytes, "still openable once vault.json is put back")
        XCTAssertEqual(try bytes(Storage.templatesURL), tBytes)
    }

    func testMalformedPlainFileIsKeptWithoutACopy() throws {
        let junk = Data("{\"this is\": \"not a tree\"".utf8)
        try junk.write(to: Storage.templatesURL)
        let t = TemplateStore()                              // 3.0.5: a .corrupt- copy, then the defaults written over it
        XCTAssertEqual(t.loadFailure, .malformed)
        t.saveNow()
        XCTAssertEqual(try bytes(Storage.templatesURL), junk)
        XCTAssertEqual(try files(), ["templates.json"], "the original is the copy")
    }

    func testPurgeAndReloadKeepTheRefusal() throws {
        try enableVault()
        let t = TemplateStore(); t.flush()
        try damage(Storage.templatesURL)
        let before = try bytes(Storage.templatesURL)
        let t2 = TemplateStore()
        t2.purge()                                           // lock
        t2.saveNow()
        t2.reload()                                          // unlock
        XCTAssertEqual(t2.loadFailure, .wrongKeyOrDamaged)
        t2.saveNow()
        XCTAssertEqual(try bytes(Storage.templatesURL), before)
    }

    // MARK: the user's way out

    func testStartFreshSetsTheFileAside() throws {
        try enableVault()
        let h = HistoryStore(settings: Settings()); h.add(.text("old")); h.flush()
        try damage(Storage.historyURL)
        let damaged = try bytes(Storage.historyURL)
        let h2 = HistoryStore(settings: Settings())
        XCTAssertNotNil(h2.loadFailure)
        try h2.startFresh()
        XCTAssertNil(h2.loadFailure)
        h2.add(.text("new")); h2.flush()
        let aside = try files().filter { $0.hasPrefix("history.json.corrupt-") }
        XCTAssertEqual(aside.count, 1)
        XCTAssertEqual(try bytes(tmp.dir.appendingPathComponent(aside[0])), damaged, "the bytes moved, unchanged")
        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["new"])
        XCTAssertNoThrow(try h2.startFresh(), "a no-op once the store is healthy")
        XCTAssertEqual(try files().filter { $0.hasPrefix("history.json.corrupt-") }.count, 1)
    }

    func testRestoreCommitLiftsTheRefusal() throws {
        try enableVault()
        let t = TemplateStore(); t.flush()
        try damage(Storage.templatesURL)
        let t2 = TemplateStore()
        XCTAssertNotNil(t2.loadFailure)
        t2.publish(TemplateNode(name: "Template", children: [TemplateNode(name: "restored", text: "r")]))   // after RestoreCommit wrote the file
        XCTAssertNil(t2.loadFailure)
        t2.saveNow()
        XCTAssertEqual(TemplateStore().root.children.first?.name, "restored")
    }

    // MARK: SEC06 — protection on means sealed, or nothing

    func testPlainJSONInThePlaceOfASealedFileIsRefused() throws {
        try enableVault()
        let h = HistoryStore(settings: Settings()); h.add(.text("real")); h.flush()
        let planted = [ClipItem.text("planted")]
        let plain = try Storage.encoder.encode(planted)
        try plain.write(to: Storage.historyURL)              // 3.0.5: loaded as if it were ours

        let h2 = HistoryStore(settings: Settings())
        XCTAssertEqual(h2.loadFailure, .notEncrypted)
        XCTAssertTrue(h2.items.isEmpty)
        h2.flush(); h2.saveNow()
        XCTAssertEqual(try bytes(Storage.historyURL), plain, "and not written over: the user decides")

        // The same file is fine once protection is off (no vault, no key).
        Storage.clearKey(); Vault.disable()
        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["planted"])
    }

    func testPlainJSONIsRefusedWhileLockedToo() throws {
        try enableVault()
        Storage.clearKey()                                   // vault on, key gone: locked
        try Data("[]".utf8).write(to: Storage.historyURL)
        XCTAssertEqual(Storage.read([ClipItem].self, from: Storage.historyURL).failure, .notEncrypted)
    }

    func testSettingsStayPlain() throws {
        try enableVault()
        Storage.save(Settings(), to: Storage.settingsURL, encrypt: false, pretty: true)
        XCTAssertNotNil(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertEqual(Storage.read(Settings.self, from: Storage.settingsURL).failure, .notEncrypted, "only when asked for")
    }

    func testPlaintextVerifierOpensNothing() throws {
        try enableVault("right")
        var meta = try JSONDecoder().decode(Vault.Meta.self, from: Data(contentsOf: Vault.metaURL))
        meta.check = Data("KEEPIT-OK".utf8)                  // 3.0.5: decrypt() passed it through, so any password "verified"
        try JSONEncoder().encode(meta).write(to: Vault.metaURL)
        XCTAssertNil(Vault.unlock(password: .of("wrong")))
        XCTAssertNil(Vault.unlock(password: .of("right")), "a tampered verifier opens nothing, not everything")
        let k = try Vault.deriveKey(password: .of("right"), salt: meta.salt, rounds: 1000)
        XCTAssertFalse(Vault.verify(k))
        XCTAssertThrowsError(try Vault.decrypt(Data("plain".utf8), key: k)) { XCTAssertEqual($0 as? Vault.Failure, .notSealed) }
        k.zero()
    }
}
