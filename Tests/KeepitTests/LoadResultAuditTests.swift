import AppKit
import XCTest
@testable import Keepit

/// The auditor's probes against 606b319 (3.0.6 audit of SEC10), inverted: each test that asserted
/// a defect ("…Currently…") now asserts the fixed behaviour; the three control probes are kept.
final class LoadResultAuditTests: XCTestCase {
    private var storage: TempStorage!

    override func setUp() { storage = TempStorage() }
    override func tearDown() { storage.restore() }

    private func enableVault(_ password: String = "audit-only") throws {
        Storage.key = try Vault.enable(password: .of(password), rounds: 1000)
    }

    private func readBytes(_ url: URL) throws -> Data { try Data(contentsOf: url) }

    private func asideFiles(for url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: storage.dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(url.lastPathComponent + ".corrupt-") }
    }

    /// Finding 2 (P1). The restore UI refuses Merge; this is the commit underneath it.
    func testMergeCommitRefusesUnreadableOriginals() throws {
        _ = NSApplication.shared
        let oldTree = TemplateNode(name: "Template", children: [TemplateNode(name: "Local only", text: "local")])
        let originals = [
            Storage.historyURL: try Storage.encoder.encode([ClipItem.text("local only")]),
            Storage.templatesURL: try Storage.encoder.encode(oldTree)
        ]
        for (url, bytes) in originals { try bytes.write(to: url) }
        try enableVault()  // Simulate enable stopping before the existing files are sealed.
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.hotKeyFailureForTesting = { _ in }
        XCTAssertEqual(app.history.loadFailure, .notEncrypted)
        XCTAssertEqual(app.templates.loadFailure, .notEncrypted)
        XCTAssertTrue(app.hasUnreadableData)
        let payload = Backup.Payload(history: [.text("from backup")],
                                     templates: TemplateNode(name: "Template", children: [TemplateNode(name: "Restored", text: "r")]),
                                     settings: nil)
        let plan = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: app.history.items,
                                        currentTemplates: app.templates.root, currentSettings: app.settings,
                                        restorePreferences: false, folderName: "Imported")
        XCTAssertThrowsError(try app.commit(plan)) {
            guard case RestoreCommit.Failure.cannotReadPrevious = $0 else { return XCTFail("unexpected error: \($0)") }
        }
        XCTAssertEqual(app.history.loadFailure, .notEncrypted)
        XCTAssertEqual(app.templates.loadFailure, .notEncrypted)
        for (url, bytes) in originals {
            XCTAssertEqual(try readBytes(url), bytes)
            XCTAssertTrue(try asideFiles(for: url).isEmpty)
        }
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
    }

    /// Finding 4 (P2). The same purge and key wipe as lock(): Start Fresh does nothing, at either level.
    func testStartFreshDoesNothingAfterPurgeAndKeyWipe() throws {
        try enableVault()
        let original = Data("synthetic unreadable data".utf8)
        try original.write(to: Storage.historyURL)
        try original.write(to: Storage.templatesURL)
        let history = HistoryStore(settings: Settings())
        let templates = TemplateStore()
        history.purge()
        templates.purge()
        Storage.clearKey()
        XCTAssertTrue(history.isPurged && templates.isPurged)
        XCTAssertNotNil(history.loadFailure)
        XCTAssertNotNil(templates.loadFailure)

        try history.startFresh()
        try templates.startFresh()
        XCTAssertTrue(history.isPurged)
        XCTAssertTrue(templates.isPurged)
        for url in [Storage.historyURL, Storage.templatesURL] {
            XCTAssertEqual(try readBytes(url), original)
            XCTAssertTrue(try asideFiles(for: url).isEmpty)
        }
    }

    func testAppStartFreshDoesNothingWhileLocked() throws {
        try enableVault()
        let original = Data("synthetic unreadable data".utf8)
        try original.write(to: Storage.historyURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.hotKeyFailureForTesting = { _ in }
        XCTAssertNotNil(app.history.loadFailure)
        app.lock()
        XCTAssertTrue(app.isLocked)
        app.startFresh()
        XCTAssertEqual(try readBytes(Storage.historyURL), original)
        XCTAssertTrue(try asideFiles(for: Storage.historyURL).isEmpty)
    }

    /// Finding 3 (P2). What the app's Start Fresh calls: all files or none.
    func testSecondRenameFailureLeavesBothStoresAsTheyWere() throws {
        let original = Data("synthetic malformed JSON".utf8)
        try original.write(to: Storage.historyURL)
        try original.write(to: Storage.templatesURL)
        let history = HistoryStore(settings: Settings())
        let templates = TemplateStore()
        let path = Storage.templatesURL.path
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: path) }

        XCTAssertThrowsError(try Storage.setAside([Storage.historyURL, Storage.templatesURL]))
        XCTAssertEqual(history.loadFailure, .malformed)
        XCTAssertEqual(templates.loadFailure, .malformed)
        XCTAssertEqual(try readBytes(Storage.historyURL), original, "the first rename was undone")
        XCTAssertEqual(try readBytes(Storage.templatesURL), original)
        XCTAssertTrue(try asideFiles(for: Storage.historyURL).isEmpty)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL) && Storage.isHeld(Storage.templatesURL))

        history.add(.text("new history"))
        history.flush()
        XCTAssertEqual(try readBytes(Storage.historyURL), original, "and nothing is saved over it")
    }

    /// Finding 3 (P2). Taken names get a counter; nothing is clobbered.
    func testTimestampCollisionGetsACounterWithoutClobbering() throws {
        let original = Data("unreadable original".utf8)
        let older = Data("previous aside".utf8)
        let url = Storage.historyURL
        try original.write(to: url)
        let history = HistoryStore(settings: Settings())
        let now = Int(Date().timeIntervalSince1970)
        for second in (now - 5)...(now + 10) {
            try older.write(to: url.appendingPathExtension("corrupt-\(second)"))
        }
        XCTAssertNoThrow(try history.startFresh())
        XCTAssertNil(history.loadFailure)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let asides = try asideFiles(for: url).map(readBytes)
        XCTAssertEqual(asides.filter { $0 == original }.count, 1, "the original under a new name")
        XCTAssertEqual(asides.filter { $0 == older }.count, 16, "every earlier copy untouched")
    }

    /// Finding 1 (P2).
    func testHistorySaveOffKeepsRefusalAcrossReloadAndPurge() throws {
        let original = Data("synthetic malformed JSON".utf8)
        try original.write(to: Storage.historyURL)
        let history = HistoryStore(settings: Settings())
        XCTAssertEqual(history.loadFailure, .malformed)
        var settings = Settings()
        settings.historySave = false
        history.updateSettings(settings)
        history.purge()
        XCTAssertEqual(try readBytes(Storage.historyURL), original)

        history.reload()
        XCTAssertEqual(history.loadFailure, .malformed)
        history.purge()
        XCTAssertEqual(try readBytes(Storage.historyURL), original)
        XCTAssertTrue(try asideFiles(for: Storage.historyURL).isEmpty)
    }

    /// Finding 1 (P2): no automatic snapshot with saving off either.
    func testHistorySaveOffGivesNoAutomaticSnapshot() throws {
        try enableVault()
        let original = Data("synthetic unreadable history".utf8)
        try original.write(to: Storage.historyURL)
        let withSaving = AppDelegate()
        withSaving.loadStoresForTesting()
        XCTAssertEqual(withSaving.history.loadFailure, .notEncrypted)
        XCTAssertNil(withSaving.backupSnapshot())

        var settings = Settings()
        settings.historySave = false
        Storage.save(settings, to: Storage.settingsURL, encrypt: false)
        let withoutSaving = AppDelegate()
        withoutSaving.loadStoresForTesting()
        XCTAssertEqual(withoutSaving.history.loadFailure, .notEncrypted)
        XCTAssertNil(withoutSaving.backupSnapshot())
        XCTAssertEqual(try readBytes(Storage.historyURL), original)
    }

    /// Control (finding 5): kept as the auditor wrote it.
    func testInterruptedEnableRejectsPlainFilesWithAndWithoutKey() throws {
        Storage.save([ClipItem.text("before protection")], to: Storage.historyURL)
        _ = TemplateStore()
        let historyBytes = try readBytes(Storage.historyURL)
        let templateBytes = try readBytes(Storage.templatesURL)

        try enableVault()
        Storage.clearKey()
        XCTAssertEqual(Storage.read([ClipItem].self, from: Storage.historyURL).failure, .notEncrypted)
        Storage.key = try XCTUnwrap(Vault.unlock(password: .of("audit-only")))
        let history = HistoryStore(settings: Settings())
        let templates = TemplateStore()
        XCTAssertEqual(history.loadFailure, .notEncrypted)
        XCTAssertEqual(templates.loadFailure, .notEncrypted)
        history.saveNow()
        templates.saveNow()
        XCTAssertEqual(try readBytes(Storage.historyURL), historyBytes)
        XCTAssertEqual(try readBytes(Storage.templatesURL), templateBytes)
    }

    /// Finding 5 (P1). The low-level sequence of the probe can still be written by hand; the app no
    /// longer reaches it: every way into a new key or a removed vault refuses while data is unreadable.
    func testPasswordChangesRefuseWhileDataIsUnreadable() throws {
        try enableVault()
        let old = try XCTUnwrap(Storage.key)
        let oldMeta = try readBytes(Vault.metaURL)
        let malformed = Data("synthetic payload requiring repair".utf8)
        let sealed = try Vault.encrypt(malformed, key: old)
        try sealed.write(to: Storage.historyURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.hotKeyFailureForTesting = { _ in }
        XCTAssertEqual(app.history.loadFailure, .malformed)
        var refusals = 0
        app.refusalForTesting = { refusals += 1 }

        app.changePassword()
        app.regenerateRecoveryPhrase()
        XCTAssertFalse(app.disableProtection())
        XCTAssertFalse(app.enableProtection(with: .of("new-audit-only")))
        XCTAssertEqual(refusals, 4, "each one refused before any dialog")

        XCTAssertFalse(old.isZeroed)
        XCTAssertEqual(try readBytes(Vault.metaURL), oldMeta)
        XCTAssertEqual(try readBytes(Storage.historyURL), sealed)
        XCTAssertTrue(Vault.isEnabled)
        let reopened = try XCTUnwrap(Vault.unlock(password: .of("audit-only")))
        XCTAssertEqual(try Vault.decrypt(sealed, key: reopened), malformed, "the old password still opens it")
        reopened.zero()
    }

    /// Finding 7 (P2).
    func testUnreadableSettingsAreKeptAndNothingIsSwitchedOn() throws {
        var previous = Settings()
        previous.historySave = false
        previous.lockAfterScreenLock = 0
        previous.allowURLCommands = true
        previous.backupEnabled = true
        let valid = try Storage.encoder.encode(previous)
        try valid.write(to: Storage.settingsURL)
        XCTAssertEqual(AppDelegate().settings.lockAfterScreenLock, 0)
        let broken = Data(valid.dropLast())
        try broken.write(to: Storage.settingsURL)

        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        XCTAssertTrue(app.settings.historySave)
        XCTAssertEqual(app.settings.lockAfterScreenLock, 0)
        XCTAssertFalse(app.settings.allowURLCommands)
        XCTAssertFalse(app.settings.backupEnabled)
        XCTAssertTrue(app.hasUnreadableData)
        app.history.add(.text("not recorded to disk"))
        app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        XCTAssertEqual(try readBytes(Storage.settingsURL), broken, "the file is kept as it was")
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path))
    }

    /// Control: kept as the auditor wrote it.
    func testRestoreCommitRefusesAnOversizedOriginal() throws {
        let oversized = off_t(Limits.dataFileMaxBytes) + 1
        try Data().write(to: Storage.templatesURL)
        XCTAssertEqual(truncate(Storage.templatesURL.path, oversized), 0)
        XCTAssertEqual(TemplateStore().loadFailure, .tooLarge)

        let replacement = try Storage.encoder.encode(TemplateNode(name: "Template"))
        let settings = try Storage.encoder.encode(Settings())
        XCTAssertThrowsError(try RestoreCommit.writeFiles(templatesJSON: replacement,
                                                          historyJSON: nil, settingsJSON: settings)) {
            guard case .cannotReadPrevious("templates.json", _)? = $0 as? RestoreCommit.Failure else {
                return XCTFail("unexpected error: \($0)")
            }
        }
        XCTAssertEqual(TemplateStore().loadFailure, .tooLarge)
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
    }

    /// Control (finding 6): kept as the auditor wrote it.
    func testRecoveryAcceptsSealedWrapAndRefusesPlaintextWrap() throws {
        try enableVault()
        let key = try XCTUnwrap(Storage.key)
        let words = try Vault.createRecovery(for: key)
        let opened = try XCTUnwrap(Vault.unlockWithRecovery(words: words))
        defer { opened.zero() }
        XCTAssertTrue(Vault.verify(opened))

        var meta = try JSONDecoder().decode(Vault.Meta.self, from: readBytes(Vault.metaURL))
        var recovery = try XCTUnwrap(meta.recovery)
        recovery.wrappedKey = key.withBytes { Data($0) }
        meta.recovery = recovery
        try JSONEncoder().encode(meta).write(to: Vault.metaURL)
        XCTAssertNil(Vault.unlockWithRecovery(words: words))
        XCTAssertTrue(Vault.verify(key))
    }
}
