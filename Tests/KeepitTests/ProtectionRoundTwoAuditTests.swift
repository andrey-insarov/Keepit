import AppKit
import XCTest
@testable import Keepit

/// The auditor's round-2 probes on PR #39, inverted.
/// 1 (P1): while the unfinished-undo alert was up, the backup engine could take a snapshot of the
///   new vault.json over the old key in memory — an archive no password and no phrase opens — and
///   rotation dropped the last good copy for it. `backupSnapshot` now refuses while a journal is
///   armed, and whenever the key in memory does not open the vault on disk.
/// 2 (P2): Reset from inside that alert cleared the pins and left the journal armed. Refused, before
///   and after the confirmation.
/// 3 (P2): a restore that created the vault and was cut short by a lock (`lockedAfterWrite`) lost
///   the report about copies the sweep could not remove. It is queued and shown at the next unlock.
final class ProtectionRoundTwoAuditTests: XCTestCase {
    private var tmp: TempStorage!
    private var errors: [String] = []

    override func setUp() {
        tmp = TempStorage()
        errors = []
        Vault.errorSinkForTesting = { [weak self] in self?.errors.append($0) }
        RecoveryDialogs.presentSinkForTesting = { _ in }
    }
    override func tearDown() {
        Vault.errorSinkForTesting = nil
        Vault.askPasswordForTesting = nil
        Vault.promptForTesting = nil
        RecoveryDialogs.presentSinkForTesting = nil
        AbortableModal.responseForTesting = nil
        RestoreCommit.beforeDisarmForTesting = nil
        RestoreCommit.clearUnsweptForTesting()
        Storage.releaseAll()
        tmp.restore()
    }

    private func app(protected: Bool = true) throws -> AppDelegate {
        _ = NSApplication.shared
        if protected { Storage.key = try Vault.enable(password: .of("old"), rounds: 1000) }
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        app.infoSinkForTesting = { _ in }
        app.authenticateForTesting = { true }
        app.exitForTesting = { _ in }
        app.history.add(.text("local history"))
        app.history.flush()
        return app
    }

    private func makeImmutable(_ url: URL) {
        do { try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path) }
        catch { XCTFail("could not inject failure: \(error)") }
    }
    private func thaw(_ url: URL) {
        try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
    }

    // MARK: 1 — no backup of a mixed state

    func testNoAutomaticBackupWhileTheUndoIsUnfinished() throws {
        let app = try app()
        let oldKey = try XCTUnwrap(Storage.key)
        let destination = tmp.dir.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        app.backup.destination = PlainFolderDestination(destination)
        app.backup.keepCount = 1
        app.backup.now = { Date(timeIntervalSince1970: 1000) }
        let first = expectation(description: "healthy backup written")
        app.backup.backUpNow {
            if case .failure(let error) = $0 { XCTFail("healthy backup: \(error)") }
            first.fulfill()
        }
        wait(for: [first], timeout: 5)
        let goodName = try XCTUnwrap(app.backup.state.records.first?.name)
        let goodURL = destination.appendingPathComponent(goodName)
        XCTAssertEqual(try Backup.decode(Data(contentsOf: goodURL), password: .of("old")).history.first?.plainText, "local history")

        defer { thaw(Vault.metaURL); thaw(FileJournal.protection.marker) }
        // The rekey writes the new vault, but the rollback cannot put the old vault back.
        RestoreCommit.beforeDisarmForTesting = { [unowned self] in
            self.makeImmutable(Vault.metaURL)
            self.makeImmutable(FileJournal.protection.marker)
        }
        Vault.askPasswordForTesting = { _ in .of("new") }
        app.backup.now = { Date(timeIntervalSince1970: 2000) }
        var outcome: Result<Void, Error>?
        Vault.errorSinkForTesting = { [unowned self] text in
            self.errors.append(text)
            // The engine's timer firing inside the modal alert.
            XCTAssertNil(app.backupSnapshot(), "no snapshot of a vault the key in memory does not open")
            let second = self.expectation(description: "backup attempt during the alert")
            app.backup.backUpNow { outcome = $0; second.fulfill() }
            self.wait(for: [second], timeout: 5)
        }

        app.changePassword()
        XCTAssertTrue(RestoreCommit.hasArmedJournal)
        XCTAssertTrue(Storage.key === oldKey)
        guard case .failure(let e)? = outcome else { return XCTFail("the backup ran: \(String(describing: outcome))") }
        XCTAssertEqual(e as? BackupEngine.Failure, .locked)
        XCTAssertTrue(FileManager.default.fileExists(atPath: goodURL.path), "the last good copy stays")
        XCTAssertEqual(app.backup.state.records.map(\.name), [goodName])
    }

    func testSnapshotNeedsTheKeyThatOpensTheVaultOnDisk() throws {
        // The general form of the guard: vault.json replaced under a live key (by hand, by a sync
        // tool) → no automatic backup until the two agree again.
        let app = try app()
        XCTAssertNotNil(app.backupSnapshot())
        let other = try Vault.enable(password: .of("other"), rounds: 1000)   // writes a new vault.json
        other.zero()
        XCTAssertNil(app.backupSnapshot())
    }

    // MARK: 2 — Reset while a journal is armed

    func testResetIsRefusedWhileTheJournalIsArmed() throws {
        let app = try app()
        let directory = FileJournal.protection.directory
        RestoreCommit.beforeDisarmForTesting = { [unowned self] in self.makeImmutable(directory) }
        defer { thaw(directory) }
        Vault.askPasswordForTesting = { _ in .of("new") }
        var offeredReset = 0
        AbortableModal.responseForTesting = { _ in offeredReset += 1; return .alertFirstButtonReturn }
        var refused = 0
        app.refusalForTesting = { refused += 1 }
        Vault.errorSinkForTesting = { [unowned self] text in
            self.errors.append(text)
            XCTAssertTrue(Storage.isHeld(Vault.metaURL))
            app.resetRequested()
            app.uninstallRequested()
        }

        app.changePassword()
        XCTAssertEqual(refused, 2, "both refused before any dialog")
        XCTAssertEqual(offeredReset, 0)
        XCTAssertTrue(Vault.isEnabled)
        XCTAssertTrue(Storage.isHeld(Vault.metaURL))
        XCTAssertTrue(RestoreCommit.hasArmedJournal)
        XCTAssertNotNil(Vault.unlock(password: .of("old")), "the replay put the old vault back; the journal waits for the relaunch")
    }

    func testResetChecksTheJournalAgainAfterTheConfirmation() throws {
        // Armed between the confirmation and the action (a commit on another path is not possible
        // in one process, but the check is cheap and the guard is per step).
        let app = try app()
        var refused = 0
        app.refusalForTesting = { refused += 1 }
        AbortableModal.responseForTesting = { _ in
            try? FileJournal.protection.write()
            return .alertFirstButtonReturn
        }
        app.resetRequested()
        XCTAssertEqual(refused, 1)
        XCTAssertTrue(Vault.isEnabled, "not reset")
        XCTAssertTrue(FileManager.default.fileExists(atPath: Storage.historyURL.path))
    }

    // MARK: 3 — the sweep report survives a lock during the restore commit

    func testRestoreWithNewVaultReportsTheSweepAtTheNextUnlock() throws {
        let app = try app(protected: false)
        let prepared = try app.prepareVault(password: .of("new"))
        defer { if Storage.key !== prepared.key { prepared.discard() } }
        let copy = FileJournal.protection.directory.appendingPathComponent("history.json")
        RestoreCommit.beforeDisarmForTesting = { [unowned self] in self.makeImmutable(copy) }
        defer { thaw(copy) }
        let payload = Backup.Payload(history: [.text("restored")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: app.history.items,
                                        currentTemplates: app.templates.root, currentSettings: app.settings,
                                        restorePreferences: false, folderName: "Imported")
        app.history.onChange = { [unowned app] in if !app.isLocked { app.lock() } }

        XCTAssertThrowsError(try app.commit(plan, newVault: prepared)) {
            guard case RestoreCommit.Failure.lockedAfterWrite? = $0 as? RestoreCommit.Failure else { return XCTFail("unexpected error: \($0)") }
        }
        XCTAssertTrue(app.isLocked)
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertTrue(errors.isEmpty, "not while locked")
        XCTAssertEqual(app.unsweptToReport.map { $0.0.lastPathComponent }, ["protection-journal"])

        app.history.onChange = nil
        Vault.promptForTesting = { _ in .password(.of("new")) }
        XCTAssertTrue(app.unlock())
        XCTAssertEqual(app.history.items.map(\.plainText), ["restored"])
        // Round 3: the alert comes after unlock() has returned, on the next main-queue turn.
        XCTAssertTrue(errors.isEmpty, "not inside unlock()")
        let turn = expectation(description: "main queue turn")
        DispatchQueue.main.async { turn.fulfill() }
        wait(for: [turn], timeout: 2)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.contains("protection-journal") ?? false, "\(errors)")
        XCTAssertTrue(app.unsweptToReport.isEmpty)
        app.lock()
    }
}
