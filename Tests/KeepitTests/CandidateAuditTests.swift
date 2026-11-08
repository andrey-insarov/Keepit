import AppKit
import XCTest
@testable import Keepit

/// The whole-tree review of the 3.0.6 candidate (`0f2d15b`), inverted. Two findings where the
/// three groups of fixes meet: a restore that creates the vault and is cut short by a lock in
/// a publication callback skipped the sealing of the `.corrupt-…` copies (P1 / SEC02, it lived in
/// `publishEnabledVault`, after the commit); Save to Archive checked the lock only before its two
/// dialogs and sealed the purged stores into a valid, empty archive announced as saved (P2).
final class CandidateAuditTests: XCTestCase {
    private var tmp: TempStorage!
    private var infos: [String] = []
    private var errors: [String] = []

    override func setUp() {
        tmp = TempStorage()
        infos = []; errors = []
        _ = NSApplication.shared
        Vault.errorSinkForTesting = { [weak self] in self?.errors.append($0) }
        RecoveryDialogs.presentSinkForTesting = { _ in }
    }
    override func tearDown() {
        Vault.errorSinkForTesting = nil
        Vault.promptForTesting = nil
        Vault.askPasswordForTesting = nil
        RecoveryDialogs.presentSinkForTesting = nil
        Storage.releaseAll()
        tmp.restore()
    }

    private func app(protected: Bool) throws -> AppDelegate {
        if protected { Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000) }
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.createBackupEngine()
        a.hotKeyFailureForTesting = { _ in }
        a.infoSinkForTesting = { [weak self] in self?.infos.append($0) }
        return a
    }

    private func spinMainQueue() {
        let e = expectation(description: "main queue turn")
        DispatchQueue.main.async { e.fulfill() }
        wait(for: [e], timeout: 2)
    }

    // MARK: P1 / SEC02 — a restore that makes the vault seals the copies inside its commit

    /// The auditor's probe: no vault, an unreadable history.json with private text, Replace with a
    /// new vault, a lock in the first publication callback → `lockedAfterWrite`. The copy set aside
    /// by the Replace is sealed with the vault's key all the same — the sealing runs right after the
    /// key goes live, before the stores publish — and opens with the new password after the unlock.
    /// The phrase that was never shown gets the note after the unlock, as in `publishEnabledVault`.
    func testARestoreThatMakesTheVaultSealsTheCopiesEvenWhenALockCutsItShort() throws {
        let a = try app(protected: false)
        let original = Data("private old clipboard content: broken JSON".utf8)
        try original.write(to: Storage.historyURL)
        a.history.reload()
        XCTAssertTrue(a.hasUnreadableData)
        let prepared = try a.prepareVault(password: .of("new"))
        defer { if Storage.key !== prepared.key { prepared.discard() } }
        XCTAssertNotNil(prepared.words, "a new phrase, never shown in this test")
        let payload = Backup.Payload(history: [.text("restored")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: a.history.items,
                                        currentTemplates: a.templates.root, currentSettings: a.settings,
                                        restorePreferences: false, folderName: "Imported")
        a.history.onChange = { [unowned a] in if !a.isLocked { a.lock() } }
        XCTAssertThrowsError(try a.commit(plan, newVault: prepared)) {
            guard case RestoreCommit.Failure.lockedAfterWrite? = $0 as? RestoreCommit.Failure else { return XCTFail("unexpected error: \($0)") }
        }
        a.history.onChange = nil
        XCTAssertTrue(a.isLocked)
        XCTAssertTrue(Vault.isEnabled)
        XCTAssertNil(Storage.key)
        XCTAssertTrue(a.phraseNotConfirmedForTesting, "the phrase was never shown")

        let copy = try XCTUnwrap(Storage.setAsideCopies().first)
        let bytes = try Data(contentsOf: copy)
        XCTAssertTrue(Vault.isEncrypted(bytes), "sealed inside the commit, before any callback")
        XCTAssertNotEqual(bytes, original)

        Vault.promptForTesting = { _ in .password(.of("new")) }
        XCTAssertTrue(a.unlock())
        XCTAssertEqual(a.history.items.map(\.plainText), ["restored"])
        let key = try XCTUnwrap(Storage.key)
        XCTAssertEqual(try Vault.decrypt(bytes, key: key), original, "opens with the vault's key")
        spinMainQueue()
        XCTAssertEqual(infos.count, 1)
        XCTAssertTrue(try XCTUnwrap(infos.first).contains("Show…"))
        XCTAssertFalse(a.phraseNotConfirmedForTesting)
        a.lock()
    }

    /// The same restore without a lock: the copies are sealed once (the commit) and
    /// `publishEnabledVault` afterwards finds nothing to do; the phrase is shown as before.
    func testARestoreThatMakesTheVaultSealsTheCopiesOnce() throws {
        let a = try app(protected: false)
        try Data("broken".utf8).write(to: Storage.historyURL)
        a.history.reload()
        let prepared = try a.prepareVault(password: .of("new"))
        defer { if Storage.key !== prepared.key { prepared.discard() } }
        let payload = Backup.Payload(history: [.text("restored")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: a.history.items,
                                        currentTemplates: a.templates.root, currentSettings: a.settings,
                                        restorePreferences: false, folderName: "Imported")
        try a.commit(plan, newVault: prepared)
        let copy = try XCTUnwrap(Storage.setAsideCopies().first)
        let sealedByTheCommit = try Data(contentsOf: copy)
        XCTAssertTrue(Vault.isEncrypted(sealedByTheCommit))
        var shown = 0
        RecoveryDialogs.presentSinkForTesting = { _ in shown += 1 }
        a.publishEnabledVault(prepared)
        XCTAssertEqual(try Data(contentsOf: copy), sealedByTheCommit, "already sealed: left as it is")
        XCTAssertEqual(shown, 1)
        XCTAssertFalse(a.phraseNotConfirmedForTesting)
        XCTAssertEqual(try Vault.decrypt(sealedByTheCommit, key: try XCTUnwrap(Storage.key)), Data("broken".utf8))
        a.lock()
    }

    // MARK: P2 — Save to Archive after a lock

    /// The auditor's probe: a lock while the archive password is asked. Nothing is written and
    /// nothing is announced; the purged stores are not what the user asked to archive.
    func testSaveToArchiveWritesNothingAfterALockDuringThePasswordPrompt() throws {
        let a = try app(protected: true)
        a.history.add(.text("must be in the archive")); a.history.flush()
        let out = tmp.dir.appendingPathComponent("audit.keepit")
        Vault.askPasswordForTesting = { _ in a.lock(); return .of("archive") }
        a.exportBackup(to: out, generation: a.lockCount)
        XCTAssertTrue(a.isLocked)
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.path), "no archive of purged stores")
        XCTAssertTrue(infos.isEmpty, "nothing announced")
        XCTAssertTrue(errors.isEmpty, "nothing said over a locked app either")
    }

    /// A lock and an unlock during the prompt: the answer belongs to an earlier generation and is
    /// refused with a reason — the stores are back, but the user did not see what happened.
    func testSaveToArchiveRefusesAnAnswerFromAnEarlierGeneration() throws {
        let a = try app(protected: true)
        a.history.add(.text("item")); a.history.flush()
        let out = tmp.dir.appendingPathComponent("audit.keepit")
        Vault.askPasswordForTesting = { _ in
            a.lock()
            Vault.promptForTesting = { _ in .password(.of("pw")) }
            XCTAssertTrue(a.unlock())
            return .of("archive")
        }
        a.exportBackup(to: out, generation: a.lockCount)
        XCTAssertFalse(a.isLocked)
        XCTAssertFalse(FileManager.default.fileExists(atPath: out.path))
        XCTAssertTrue(infos.isEmpty)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(try XCTUnwrap(errors.first).contains("Archive not saved"))
        a.lock()
    }

    /// A lock during the save panel itself (before the password): the flow ends at the first
    /// re-check, no password is asked.
    func testSaveToArchiveStopsBeforeThePasswordWhenTheLockCameDuringThePanel() throws {
        let a = try app(protected: true)
        a.history.add(.text("item")); a.history.flush()
        let g = a.lockCount
        a.lock()                                   // what a lock during the save panel leaves behind
        var asked = 0
        Vault.askPasswordForTesting = { _ in asked += 1; return .of("archive") }
        a.exportBackup(to: tmp.dir.appendingPathComponent("audit.keepit"), generation: g)
        XCTAssertEqual(asked, 0)
        XCTAssertTrue(infos.isEmpty)
    }

    /// The ordinary case still works: one archive with the items, one announcement.
    func testSaveToArchiveWithoutALockSavesTheItems() throws {
        let a = try app(protected: true)
        a.history.add(.text("must be in the archive")); a.history.flush()
        let out = tmp.dir.appendingPathComponent("audit.keepit")
        Vault.askPasswordForTesting = { _ in .of("archive") }
        a.exportBackup(to: out, generation: a.lockCount)
        let saved = try Backup.decode(try Data(contentsOf: out), password: .of("archive"))
        XCTAssertEqual(saved.history.map(\.plainText), ["must be in the archive"])
        XCTAssertEqual(infos.count, 1)
        a.lock()
    }
}
