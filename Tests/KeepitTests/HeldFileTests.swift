import XCTest
@testable import Keepit

/// The 3.0.6 audit of the SEC10 fix (606b319): paths that still replaced or deleted a file Keepit
/// could not read, asserted the safe way round. A failed `Storage.read` now *holds* the file —
/// `save`, `writeNow`, `removeNow` and a restore commit refuse it — until a later read succeeds,
/// the file is set aside, or Reset removes it.
final class HeldFileTests: XCTestCase {
    private var tmp: TempStorage!

    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    private func bytes(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    private func files() throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).sorted() }
    private func damage(_ url: URL) throws {
        var d = try bytes(url)
        d[d.count - 1] ^= 0xFF
        try d.write(to: url)
    }
    private func enableVault() throws { Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000) }

    // MARK: the hold itself

    func testAFailedReadHoldsTheFileForEveryWriter() throws {
        let junk = Data("{".utf8)
        try junk.write(to: Storage.templatesURL)
        XCTAssertNotNil(Storage.read(TemplateNode.self, from: Storage.templatesURL).failure)
        XCTAssertTrue(Storage.isHeld(Storage.templatesURL))

        Storage.save(TemplateNode(name: "Template"), to: Storage.templatesURL)
        Storage.save(TemplateNode(name: "Template"), to: Storage.templatesURL, background: true); Storage.waitUntilSaved()
        Storage.saveEncoded(Data("[]".utf8), to: Storage.templatesURL)
        XCTAssertThrowsError(try Storage.writeNow(Data("[]".utf8), to: Storage.templatesURL)) {
            XCTAssertEqual($0 as? Storage.Failure, .held("templates.json"))
        }
        XCTAssertThrowsError(try Storage.writeRawNow(Data("[]".utf8), to: Storage.templatesURL))
        XCTAssertThrowsError(try Storage.removeNow(Storage.templatesURL))
        XCTAssertEqual(try bytes(Storage.templatesURL), junk)
    }

    func testAReadThatSucceedsLaterReleasesTheHold() throws {
        try Data("{".utf8).write(to: Storage.templatesURL)
        _ = Storage.read(TemplateNode.self, from: Storage.templatesURL)
        XCTAssertTrue(Storage.isHeld(Storage.templatesURL))
        try Storage.encoder.encode(TemplateNode(name: "Template")).write(to: Storage.templatesURL)   // put right by hand
        XCTAssertNotNil(Storage.read(TemplateNode.self, from: Storage.templatesURL).value)
        XCTAssertFalse(Storage.isHeld(Storage.templatesURL))
    }

    // MARK: finding 1 — "save history" off after a failure

    func testTurningHistorySavingOffDoesNotDeleteAnUnreadableFile() throws {
        try enableVault()
        let h = HistoryStore(settings: Settings()); h.add(.text("mine")); h.flush()
        try damage(Storage.historyURL)
        let before = try bytes(Storage.historyURL)

        let h2 = HistoryStore(settings: Settings())
        XCTAssertNotNil(h2.loadFailure)
        var off = Settings(); off.historySave = false
        h2.updateSettings(off)
        h2.purge()                                           // lock
        h2.reload()                                          // unlock: 3.0.6-pre skipped the read here and lost the failure
        XCTAssertNotNil(h2.loadFailure, "the read still happens with saving off")
        h2.purge(); h2.saveNow()                             // lock again: used to delete the original
        XCTAssertEqual(try bytes(Storage.historyURL), before)

        let h3 = HistoryStore(settings: off)                 // a launch with saving off
        XCTAssertNotNil(h3.loadFailure)
        h3.saveNow()
        XCTAssertEqual(try bytes(Storage.historyURL), before)
    }

    func testWithSavingOffAReadableFileIsStillDeletedAsBefore() throws {
        Storage.save([ClipItem.text("x")], to: Storage.historyURL)
        var off = Settings(); off.historySave = false
        let h = HistoryStore(settings: off)
        XCTAssertNil(h.loadFailure)
        XCTAssertTrue(h.items.isEmpty, "read, not kept")
        h.saveNow()
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path))
    }

    // MARK: finding 2 — a restore commit over a held file

    func testARestoreCommitRefusesAHeldFileBeforeWritingAnything() throws {
        try enableVault()
        let t = TemplateStore(); t.flush()
        let h = HistoryStore(settings: Settings()); h.add(.text("local")); h.flush()
        Storage.save(Settings(), to: Storage.settingsURL, encrypt: false, pretty: true)
        try damage(Storage.historyURL)
        _ = HistoryStore(settings: Settings())               // the failed load holds history.json
        let before = try [Storage.templatesURL, Storage.historyURL, Storage.settingsURL].map(bytes)

        let templatesJSON = try Storage.encoder.encode(TemplateNode(name: "Template", children: [TemplateNode(name: "b", text: "b")]))
        XCTAssertThrowsError(try RestoreCommit.writeFiles(templatesJSON: templatesJSON,
                                                          historyJSON: try Storage.encoder.encode([ClipItem.text("from backup")]),
                                                          settingsJSON: try Storage.prettyEncoder.encode(Settings()))) {
            guard case RestoreCommit.Failure.cannotReadPrevious = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(try [Storage.templatesURL, Storage.historyURL, Storage.settingsURL].map(bytes), before, "nothing written")
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
    }

    func testReplaceSetsAsideThenCommits() throws {
        try enableVault()
        let h = HistoryStore(settings: Settings()); h.add(.text("local")); h.flush()
        try damage(Storage.historyURL)
        let damaged = try bytes(Storage.historyURL)
        let h2 = HistoryStore(settings: Settings())
        XCTAssertNotNil(h2.loadFailure)

        try Storage.setAside([Storage.historyURL])           // what Replace does before its commit
        try RestoreCommit.writeFiles(templatesJSON: try Storage.encoder.encode(TemplateNode(name: "Template")),
                                     historyJSON: try Storage.encoder.encode([ClipItem.text("from backup")]),
                                     settingsJSON: try Storage.prettyEncoder.encode(Settings()))
        let aside = try files().filter { $0.hasPrefix("history.json.corrupt-") }
        XCTAssertEqual(aside.count, 1)
        XCTAssertEqual(try bytes(tmp.dir.appendingPathComponent(aside[0])), damaged, "the original, unchanged")
        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["from backup"])
    }

    // MARK: finding 3 — Start Fresh, all or nothing

    func testSetAsideIsAllOrNothing() throws {
        try Data("a".utf8).write(to: Storage.historyURL)
        let ro = tmp.dir.appendingPathComponent("ro", isDirectory: true)
        try FileManager.default.createDirectory(at: ro, withIntermediateDirectories: false)
        let stuck = ro.appendingPathComponent("templates.json")
        try Data("b".utf8).write(to: stuck)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: ro.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ro.path) }
        Storage.hold(Storage.historyURL); Storage.hold(stuck)

        XCTAssertThrowsError(try Storage.setAside([Storage.historyURL, stuck]))
        XCTAssertEqual(try bytes(Storage.historyURL), Data("a".utf8), "the first rename was undone")
        XCTAssertTrue(try files().filter { $0.contains("corrupt-") }.isEmpty)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL), "and both are still held")
        XCTAssertTrue(Storage.isHeld(stuck))
    }

    func testTwoSetAsidesInOneSecondKeepBoth() throws {
        try Data("one".utf8).write(to: Storage.historyURL)
        let first = try Storage.setAside([Storage.historyURL])
        try Data("two".utf8).write(to: Storage.historyURL)
        let second = try Storage.setAside([Storage.historyURL])
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try bytes(first[0]), Data("one".utf8))
        XCTAssertEqual(try bytes(second[0]), Data("two".utf8))
    }

    func testSetAsideReleasesTheHold() throws {
        try Data("{".utf8).write(to: Storage.templatesURL)
        _ = Storage.read(TemplateNode.self, from: Storage.templatesURL)
        try Storage.setAside([Storage.templatesURL])
        XCTAssertFalse(Storage.isHeld(Storage.templatesURL))
        let t = TemplateStore()                              // a fresh start beside the kept copy
        XCTAssertNil(t.loadFailure)
        XCTAssertTrue(FileManager.default.fileExists(atPath: Storage.templatesURL.path))
    }

    // MARK: finding 7 — unreadable settings

    func testSettingsWhileUnreadableSwitchNothingOn() {
        let s = Settings.whileUnreadable
        XCTAssertFalse(s.historySave)
        XCTAssertEqual(s.lockAfterScreenLock, 0)
        XCTAssertFalse(s.backupEnabled)
        XCTAssertFalse(s.allowURLCommands)
    }

    func testAPinnedHistoryIsNeitherWrittenNorDeleted() throws {
        Storage.save([ClipItem.text("kept")], to: Storage.historyURL)
        let before = try bytes(Storage.historyURL)
        Storage.pin(Storage.historyURL)                      // what the app does while settings.json is unreadable
        let h = HistoryStore(settings: .whileUnreadable)
        XCTAssertNil(h.loadFailure)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL), "a successful read does not end a pin")
        h.add(.text("new")); h.saveNow()                     // saving off: used to delete the file
        XCTAssertEqual(try bytes(Storage.historyURL), before)
        Storage.unpin(Storage.historyURL)
        XCTAssertFalse(Storage.isHeld(Storage.historyURL))
    }

    func testUnreadableSettingsAreHeld() throws {
        let junk = Data("{\"historySave\": fal".utf8)
        try junk.write(to: Storage.settingsURL)
        XCTAssertNotNil(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).failure)
        Storage.save(Settings(), to: Storage.settingsURL, encrypt: false, pretty: true)   // every settings save in the app
        XCTAssertEqual(try bytes(Storage.settingsURL), junk)
    }
}
