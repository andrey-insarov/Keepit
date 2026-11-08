import AppKit
import XCTest
@testable import Keepit

/// SEC01: turning protection on, changing the password and turning it off are one transaction.
/// Each path through `ProtectionCommit`; a write failure at any file leaves vault.json, the data
/// files and `Storage.key` as they were; a process stopped mid-commit is put right at launch.
final class ProtectionCommitTests: XCTestCase {
    private var tmp: TempStorage!
    private var errors: [String] = []
    private var shownPhrases: [[String]] = []

    override func setUp() {
        tmp = TempStorage()
        errors = []; shownPhrases = []
        Vault.errorSinkForTesting = { [weak self] in self?.errors.append($0) }
        RecoveryDialogs.presentSinkForTesting = { [weak self] in self?.shownPhrases.append($0) }
    }
    override func tearDown() {
        Vault.errorSinkForTesting = nil
        RecoveryDialogs.presentSinkForTesting = nil
        Vault.askPasswordForTesting = nil
        AbortableModal.responseForTesting = nil
        Storage.releaseAll()
        tmp.restore()
    }

    private func bytes(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    private func files() throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).sorted() }

    /// An unlocked app with items in both stores; with `vault` the stores are sealed under "old".
    private func app(vault: Bool) throws -> AppDelegate {
        if vault { Storage.key = try Vault.enable(password: .of("old"), rounds: 1000) }
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.createBackupEngine()
        a.hotKeyFailureForTesting = { _ in }
        a.infoSinkForTesting = { _ in }
        a.history.add(.text("item one")); a.history.add(.text("item two"))
        XCTAssertTrue(a.templates.insert(TemplateNode(name: "sig", text: "mine"), under: a.templates.root))
        a.history.flush(); a.templates.flush()
        return a
    }

    private func freeze(_ url: URL) throws {
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
    }
    private func thaw(_ url: URL) {
        try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
    }

    private func opens(_ pw: String) -> Bool {
        guard let k = Vault.unlock(password: .of(pw)) else { return false }
        k.zero(); return true
    }

    private func loads(_ url: URL, with pw: String) throws -> Bool {
        guard let k = Vault.unlock(password: .of(pw)) else { return false }
        defer { k.zero() }
        let d = try Data(contentsOf: url)
        return (try? Vault.decrypt(d, key: k)) != nil
    }

    // MARK: enable

    func testEnableIsOneCommit() throws {
        let a = try app(vault: false)
        let plainHistory = try bytes(Storage.historyURL)
        XCTAssertFalse(Vault.isEncrypted(plainHistory))

        XCTAssertTrue(a.enableProtection(with: .of("new")))
        XCTAssertTrue(Vault.isEnabled)
        XCTAssertNotNil(Storage.key)
        XCTAssertTrue(opens("new"))
        XCTAssertTrue(try loads(Storage.historyURL, with: "new"))
        XCTAssertTrue(try loads(Storage.templatesURL, with: "new"))
        XCTAssertEqual(shownPhrases.count, 1, "the phrase, from the same vault.json the commit wrote")
        XCTAssertTrue(Vault.hasRecovery, "in the first vault.json, not a second write")
        XCTAssertNotNil(Vault.unlockWithRecovery(words: try XCTUnwrap(shownPhrases.first)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path))
        XCTAssertEqual(a.history.items.map(\.plainText), ["item two", "item one"], "memory untouched")
    }

    func testEnableFailureLeavesEverythingPlain() throws {
        let a = try app(vault: false)
        let plainHistory = try bytes(Storage.historyURL), plainTemplates = try bytes(Storage.templatesURL)
        try freeze(Storage.templatesURL)
        defer { thaw(Storage.templatesURL) }

        XCTAssertFalse(a.enableProtection(with: .of("new")))
        XCTAssertFalse(Vault.isEnabled, "no vault.json without the data under it")
        XCTAssertNil(Storage.key)
        XCTAssertEqual(try bytes(Storage.historyURL), plainHistory)
        XCTAssertEqual(try bytes(Storage.templatesURL), plainTemplates)
        XCTAssertTrue(shownPhrases.isEmpty)
        XCTAssertEqual(errors.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path))
        thaw(Storage.templatesURL)
        XCTAssertTrue(a.enableProtection(with: .of("new")), "and it works once the disk does")
    }

    func testEnableRefusedWhileAFileIsUnreadable() throws {
        let a = try app(vault: false)
        try Data("{".utf8).write(to: Storage.templatesURL)
        a.templates.reload()
        XCTAssertNotNil(a.templates.loadFailure)
        var refused = 0
        a.refusalForTesting = { refused += 1 }
        XCTAssertFalse(a.enableProtection(with: .of("new")))
        XCTAssertEqual(refused, 1)
        XCTAssertFalse(Vault.isEnabled)
    }

    // MARK: rekey (change password)

    private func changePassword(_ a: AppDelegate, to pw: String) {
        a.authenticateForTesting = { true }
        Vault.askPasswordForTesting = { _ in .of(pw) }
        a.changePassword()
    }

    func testChangePasswordIsOneCommit() throws {
        let a = try app(vault: true)
        let oldKey = try XCTUnwrap(Storage.key)
        let words = try Vault.createRecovery(for: oldKey)

        changePassword(a, to: "new")
        XCTAssertTrue(opens("new"))
        XCTAssertFalse(opens("old"))
        XCTAssertTrue(oldKey.isZeroed, "the old key went with the commit")
        XCTAssertFalse(Storage.key === oldKey)
        XCTAssertTrue(try loads(Storage.historyURL, with: "new"))
        XCTAssertTrue(try loads(Storage.templatesURL, with: "new"))
        XCTAssertNotNil(Vault.unlockWithRecovery(words: words), "the phrase survived the re-key")
        XCTAssertTrue(errors.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path))
    }

    func testChangePasswordFailureKeepsTheOldVaultAndKey() throws {
        let a = try app(vault: true)
        let oldKey = try XCTUnwrap(Storage.key)
        let vaultBytes = try bytes(Vault.metaURL), historyBytes = try bytes(Storage.historyURL)
        try freeze(Storage.historyURL)
        defer { thaw(Storage.historyURL) }

        changePassword(a, to: "new")
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(Storage.key === oldKey, "same object, still live")
        XCTAssertFalse(oldKey.isZeroed)
        XCTAssertEqual(try bytes(Vault.metaURL), vaultBytes)
        XCTAssertEqual(try bytes(Storage.historyURL), historyBytes)
        XCTAssertTrue(opens("old"))
        XCTAssertFalse(opens("new"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path))
        thaw(Storage.historyURL)
        a.history.add(.text("after")); a.history.flush()
        XCTAssertNotEqual(try bytes(Storage.historyURL), historyBytes)
        XCTAssertTrue(try loads(Storage.historyURL, with: "old"), "and saving goes on under the old key")
    }

    func testChangePasswordRefusedWhileAFileIsUnreadable() throws {
        let a = try app(vault: true)
        var d = try bytes(Storage.historyURL); d[d.count - 1] ^= 0xFF; try d.write(to: Storage.historyURL)
        a.history.reload()
        XCTAssertEqual(a.history.loadFailure, .wrongKeyOrDamaged)
        var refused = 0
        a.refusalForTesting = { refused += 1 }
        changePassword(a, to: "new")
        XCTAssertEqual(refused, 1)
        XCTAssertTrue(opens("old"), "the damaged file can still be opened by hand with the old key")
    }

    // MARK: disable

    func testDisableIsOneCommit() throws {
        let a = try app(vault: true)
        var s = a.settings; s.backupEnabled = true; a.apply(settings: s)
        Vault.askPasswordForTesting = { _ in .of("old") }

        XCTAssertTrue(a.disableProtection())
        XCTAssertFalse(Vault.isEnabled)
        XCTAssertNil(Storage.key)
        XCTAssertFalse(Vault.isEncrypted(try bytes(Storage.historyURL)))
        XCTAssertFalse(Vault.isEncrypted(try bytes(Storage.templatesURL)))
        XCTAssertFalse(a.settings.backupEnabled, "automatic backup needs the vault: off in the same commit")
        let saved = try XCTUnwrap(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertFalse(saved.backupEnabled)
        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["item two", "item one"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path))
    }

    func testDisableFailureKeepsTheVault() throws {
        let a = try app(vault: true)
        let oldKey = try XCTUnwrap(Storage.key)
        let vaultBytes = try bytes(Vault.metaURL), templatesBytes = try bytes(Storage.templatesURL)
        try freeze(Storage.templatesURL)
        defer { thaw(Storage.templatesURL) }
        Vault.askPasswordForTesting = { _ in .of("old") }

        XCTAssertFalse(a.disableProtection())
        XCTAssertTrue(Vault.isEnabled)
        XCTAssertTrue(Storage.key === oldKey)
        XCTAssertEqual(try bytes(Vault.metaURL), vaultBytes)
        XCTAssertEqual(try bytes(Storage.templatesURL), templatesBytes)
        XCTAssertTrue(try loads(Storage.historyURL, with: "old"), "history still sealed, not left plain")
        XCTAssertEqual(errors.count, 1)
    }

    func testDisableWithWrongPasswordChangesNothing() throws {
        let a = try app(vault: true)
        Vault.askPasswordForTesting = { _ in .of("wrong") }
        XCTAssertFalse(a.disableProtection())
        XCTAssertTrue(Vault.isEnabled)
        XCTAssertEqual(errors, [L("Wrong password.")])
    }

    // MARK: a process stopped mid-commit

    func testCommitStoppedAfterSomeWritesIsRolledBackAtLaunch() throws {
        let a = try app(vault: true)
        let oldVault = try bytes(Vault.metaURL), oldHistory = try bytes(Storage.historyURL), oldTemplates = try bytes(Storage.templatesURL)
        let oldKey = try XCTUnwrap(Storage.key)
        let prepared = try Vault.prepareRekey(password: .of("new"), from: oldKey, oldRecovery: nil)
        defer { prepared.key.zero() }
        let plan = ProtectionCommit.Plan(meta: try Vault.encodeMeta(prepared.meta), key: prepared.key,
                                         templatesJSON: try Storage.encoder.encode(a.templates.root),
                                         historyJSON: try Storage.encoder.encode(a.history.items),
                                         settingsJSON: try Storage.prettyEncoder.encode(a.settings))
        let steps = try ProtectionCommit.steps(plan)
        // The commit's own sequence, stopped after vault.json and templates.json were written.
        try FileJournal.protection.write()
        try Storage.writeNow(try XCTUnwrap(steps[0].data), to: steps[0].url, encrypt: false)
        try Storage.writeNow(try XCTUnwrap(steps[1].data), to: steps[1].url, encrypt: false)
        XCTAssertTrue(opens("new"), "the half-written state: the new vault over old history")
        XCTAssertFalse(try loads(Storage.historyURL, with: "new"))

        XCTAssertTrue(try RestoreCommit.recoverIfNeeded())
        XCTAssertEqual(try bytes(Vault.metaURL), oldVault)
        XCTAssertEqual(try bytes(Storage.historyURL), oldHistory)
        XCTAssertEqual(try bytes(Storage.templatesURL), oldTemplates)
        XCTAssertTrue(opens("old"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path))
    }

    func testEnableStoppedMidCommitLeavesNoVaultAtLaunch() throws {
        let a = try app(vault: false)
        let oldHistory = try bytes(Storage.historyURL)
        let prepared = try a.prepareVault(password: .of("new"))
        defer { prepared.discard() }
        let steps = try ProtectionCommit.steps(.init(meta: prepared.meta, key: prepared.key,
                                                     templatesJSON: try Storage.encoder.encode(a.templates.root),
                                                     historyJSON: try Storage.encoder.encode(a.history.items),
                                                     settingsJSON: try Storage.prettyEncoder.encode(a.settings)))
        try FileJournal.protection.write()
        try Storage.writeNow(try XCTUnwrap(steps[0].data), to: steps[0].url, encrypt: false)   // vault.json only
        XCTAssertTrue(Vault.isEnabled)

        XCTAssertTrue(try RestoreCommit.recoverIfNeeded())
        XCTAssertFalse(Vault.isEnabled, "the previous vault.json was absent: removed again")
        XCTAssertEqual(try bytes(Storage.historyURL), oldHistory)
    }

    func testDisarmIsTheCommitPoint() throws {
        // Marker gone, copies left (the sweep failed or the process stopped): the new state stands
        // and the next launch only tidies up.
        let a = try app(vault: true)
        let oldKey = try XCTUnwrap(Storage.key)
        let prepared = try Vault.prepareRekey(password: .of("new"), from: oldKey, oldRecovery: nil)
        defer { prepared.key.zero() }
        let steps = try ProtectionCommit.steps(.init(meta: try Vault.encodeMeta(prepared.meta), key: prepared.key,
                                                     templatesJSON: try Storage.encoder.encode(a.templates.root),
                                                     historyJSON: try Storage.encoder.encode(a.history.items),
                                                     settingsJSON: try Storage.prettyEncoder.encode(a.settings)))
        try FileJournal.protection.write()
        for s in steps { try Storage.writeNow(try XCTUnwrap(s.data), to: s.url, encrypt: false) }
        try FileJournal.protection.disarm()
        XCTAssertTrue(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path), "copies still there")

        XCTAssertFalse(try RestoreCommit.recoverIfNeeded(), "nothing to replay")
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path), "tidied")
        XCTAssertTrue(opens("new"))
        XCTAssertTrue(try loads(Storage.historyURL, with: "new"))
    }

    func testAFailedDisarmIsUndone() throws {
        let a = try app(vault: true)
        let oldKey = try XCTUnwrap(Storage.key)
        let vaultBytes = try bytes(Vault.metaURL)
        let prepared = try Vault.prepareRekey(password: .of("new"), from: oldKey, oldRecovery: nil)
        defer { prepared.key.zero() }
        let steps = try ProtectionCommit.steps(.init(meta: try Vault.encodeMeta(prepared.meta), key: prepared.key,
                                                     templatesJSON: try Storage.encoder.encode(a.templates.root),
                                                     historyJSON: try Storage.encoder.encode(a.history.items),
                                                     settingsJSON: try Storage.prettyEncoder.encode(a.settings)))
        RestoreCommit.beforeDisarmForTesting = { _ = try? FileManager.default.setAttributes([.immutable: true], ofItemAtPath: FileJournal.protection.directory.path) }
        defer {
            RestoreCommit.beforeDisarmForTesting = nil
            thaw(FileJournal.protection.directory)
        }
        XCTAssertThrowsError(try RestoreCommit.writeFiles(steps, journal: .protection)) {
            // The marker could not go, and neither could the replay remove the journal: the
            // files are back, the journal reports the leftover.
            guard case RestoreCommit.Failure.undoFailed("commit", _, let undo)? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
            XCTAssertEqual(undo.map(\.0), ["journal"])
        }
        XCTAssertEqual(try bytes(Vault.metaURL), vaultBytes, "rolled back")
        XCTAssertTrue(opens("old"))
        thaw(FileJournal.protection.directory)
        XCTAssertTrue(try RestoreCommit.recoverIfNeeded(), "the armed journal is replayed at launch (idempotent)")
        XCTAssertTrue(opens("old"))
    }

    // MARK: the two journals

    func testLegacyRestoreJournalDoesNotTouchTheVault() throws {
        // An armed restore-journal left by 3.0.5 (templates, history, settings; no vault.json):
        // replayed exactly as before, the vault untouched.
        _ = try app(vault: true)
        let vaultBytes = try bytes(Vault.metaURL)
        let fm = FileManager.default
        try fm.createDirectory(at: FileJournal.restore.directory, withIntermediateDirectories: true)
        try Data("old-templates".utf8).write(to: FileJournal.restore.directory.appendingPathComponent("templates.json"))
        try Data("old-settings".utf8).write(to: FileJournal.restore.directory.appendingPathComponent("settings.json"))
        try Data("1".utf8).write(to: FileJournal.restore.marker)

        XCTAssertTrue(try RestoreCommit.recoverIfNeeded())
        XCTAssertEqual(try bytes(Vault.metaURL), vaultBytes)
        XCTAssertEqual(try bytes(Storage.templatesURL), Data("old-templates".utf8))
        XCTAssertFalse(fm.fileExists(atPath: Storage.historyURL.path), "absent in the journal → removed, as before")
    }

    func testOneJournalAtATime() throws {
        let a = try app(vault: true)
        try FileJournal.restore.write()                      // an armed restore journal
        let steps = try ProtectionCommit.steps(.init(meta: nil, key: nil,
                                                     templatesJSON: try Storage.encoder.encode(a.templates.root), historyJSON: nil,
                                                     settingsJSON: try Storage.prettyEncoder.encode(a.settings)))
        XCTAssertThrowsError(try RestoreCommit.writeFiles(steps, journal: .protection)) {
            guard case RestoreCommit.Failure.journalArmed? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
        }
        XCTAssertTrue(Vault.isEnabled)
    }

    // MARK: history not kept on disk

    func testHistorySaveOffStaysOffThroughEnableAndDisable() throws {
        let a = try app(vault: false)
        var s = a.settings; s.historySave = false; a.apply(settings: s)
        a.history.saveNow()                                      // with the setting off, a save removes the file
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path))

        XCTAssertTrue(a.enableProtection(with: .of("new")))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path), "not written by the commit")
        XCTAssertEqual(a.history.items.count, 2, "still in memory")
        Vault.askPasswordForTesting = { _ in .of("new") }
        XCTAssertTrue(a.disableProtection())
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path))
        XCTAssertFalse(a.settings.historySave)
    }

    // MARK: the phrase can be shown again

    func testRecoveryWordsCanBeShownAgain() throws {
        let a = try app(vault: false)
        XCTAssertTrue(a.enableProtection(with: .of("new")))
        let first = try XCTUnwrap(shownPhrases.first)
        a.authenticateForTesting = { true }
        a.showRecoveryPhrase()
        XCTAssertEqual(shownPhrases.count, 2)
        XCTAssertEqual(shownPhrases.dropFirst().first, first, "the same phrase, from the entropy wrapped under the data key")
    }
}
