import AppKit
import XCTest
@testable import Keepit

/// The auditor's round-3 probes on PR #39, inverted.
/// 1 (P1): the deferred "undo copies could not be removed" alert was shown inside `unlock()`; a
///   lock during it was followed by the rest of the unlock (watcher, hot keys, `true`). It is now
///   shown after the unlock has finished, one alert at a time, each behind its own lock check.
/// 2 (P2): `Vault.verify` passed a vault.json with a damaged salt and an intact check, so a backup
///   carried a header whose parameters do not derive the key — the password opened nothing. A
///   backup header is now built only from the vault.json the key in memory belongs to
///   (`Vault.liveMeta`, read once with the header).
final class ProtectionRoundThreeAuditTests: XCTestCase {
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
        Vault.promptForTesting = nil
        RecoveryDialogs.presentSinkForTesting = nil
        AbortableModal.responseForTesting = nil
        RestoreCommit.beforeDisarmForTesting = nil
        RestoreCommit.clearUnsweptForTesting()
        Storage.releaseAll()
        tmp.restore()
    }

    private func app() -> AppDelegate {
        _ = NSApplication.shared
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        app.infoSinkForTesting = { _ in }
        app.authenticateForTesting = { true }
        app.history.add(.text("local history"))
        app.history.flush()
        return app
    }

    /// A restore that creates the vault, whose sweep fails, cut short by a lock: the report waits.
    private func restoreWithPendingReport(_ app: AppDelegate) throws {
        let prepared = try app.prepareVault(password: .of("new"))
        let copy = FileJournal.protection.directory.appendingPathComponent("history.json")
        let fm = FileManager.default
        RestoreCommit.beforeDisarmForTesting = {
            do { try fm.setAttributes([.immutable: true], ofItemAtPath: copy.path) } catch { XCTFail("could not inject sweep failure: \(error)") }
        }
        addTeardownBlock { try? fm.setAttributes([.immutable: false], ofItemAtPath: copy.path) }
        let payload = Backup.Payload(history: [.text("restored")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: app.history.items,
                                        currentTemplates: app.templates.root, currentSettings: app.settings,
                                        restorePreferences: false, folderName: "Imported")
        app.history.onChange = { [unowned app] in if !app.isLocked { app.lock() } }
        XCTAssertThrowsError(try app.commit(plan, newVault: prepared)) {
            guard case RestoreCommit.Failure.lockedAfterWrite? = $0 as? RestoreCommit.Failure else { return XCTFail("unexpected error: \($0)") }
        }
        if Storage.key !== prepared.key { prepared.discard() }
        app.history.onChange = nil
        XCTAssertTrue(app.isLocked)
        XCTAssertEqual(app.unsweptToReport.count, 1)
    }

    private func spinMainQueue() {
        let e = expectation(description: "main queue turn")
        DispatchQueue.main.async { e.fulfill() }
        wait(for: [e], timeout: 2)
    }

    // MARK: 1 — a lock during the deferred alert

    func testLockDuringTheDeferredSweepAlertLeavesNothingOfTheUnlockToRun() throws {
        let app = app()
        try restoreWithPendingReport(app)

        Vault.promptForTesting = { _ in .password(.of("new")) }
        var alerts = 0
        Vault.errorSinkForTesting = { [unowned app] warning in
            alerts += 1
            XCTAssertTrue(warning.contains("protection-journal"))
            XCTAssertFalse(app.isLocked, "shown unlocked")
            app.lock()                                             // the screen lock lands while the alert is up
        }

        XCTAssertTrue(app.unlock())
        XCTAssertEqual(alerts, 0, "not inside unlock()")
        XCTAssertTrue(app.monitor.isRunning, "unlock() finished first")
        spinMainQueue()
        XCTAssertEqual(alerts, 1)
        XCTAssertTrue(app.isLocked)
        XCTAssertNil(Storage.key)
        XCTAssertFalse(app.monitor.isRunning, "nothing restarted it: the unlock was already over")
        XCTAssertTrue(app.unsweptToReport.isEmpty, "said once")
    }

    func testTheDeferredAlertWaitsForTheNextUnlockWhenALockComesFirst() throws {
        let app = app()
        try restoreWithPendingReport(app)

        Vault.promptForTesting = { _ in .password(.of("new")) }
        XCTAssertTrue(app.unlock())
        app.lock()                                                 // before the main queue turns
        spinMainQueue()
        XCTAssertTrue(errors.isEmpty, "not while locked")
        XCTAssertEqual(app.unsweptToReport.count, 1, "still queued")

        XCTAssertTrue(app.unlock())
        spinMainQueue()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("protection-journal"))
        app.lock()
    }

    func testTheEndOfCommitReportIsAlsoAfterTheFlow() throws {
        // No lock: the restore flow (commit and what follows it) finishes first, the alert after.
        let app = app()
        let prepared = try app.prepareVault(password: .of("new"))
        let copy = FileJournal.protection.directory.appendingPathComponent("history.json")
        let fm = FileManager.default
        RestoreCommit.beforeDisarmForTesting = { try? fm.setAttributes([.immutable: true], ofItemAtPath: copy.path) }
        addTeardownBlock { try? fm.setAttributes([.immutable: false], ofItemAtPath: copy.path) }
        let payload = Backup.Payload(history: [.text("restored")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: app.history.items,
                                        currentTemplates: app.templates.root, currentSettings: app.settings,
                                        restorePreferences: false, folderName: "Imported")
        try app.commit(plan, newVault: prepared)
        XCTAssertTrue(errors.isEmpty, "queued, not shown inside the commit")
        spinMainQueue()
        XCTAssertEqual(errors.count, 1)
        app.lock()
    }

    // MARK: 2 — the backup header is the vault of the key in memory

    func testNoSnapshotWhenTheSaltOnDiskNoLongerDerivesTheKey() throws {
        let key = try Vault.enable(password: .of("old"), rounds: 1000)
        Storage.key = key
        let app = app()
        XCTAssertNotNil(app.backupSnapshot(), "intact: a snapshot")
        var meta = try JSONDecoder().decode(Vault.Meta.self, from: Data(contentsOf: Vault.metaURL))
        var salt = meta.salt
        salt[salt.startIndex] ^= 1
        meta.salt = salt
        try Vault.encodeMeta(meta).write(to: Vault.metaURL, options: .atomic)

        XCTAssertTrue(Vault.verify(key), "the check still opens — which is why verify was not enough")
        XCTAssertNil(Vault.unlock(password: .of("old")), "the password no longer derives the key")
        XCTAssertNil(Vault.backupHeader(app: "Keepit test"), "no header from a vault.json the key does not belong to")
        XCTAssertNil(app.backupSnapshot())
    }

    func testHeaderFollowsTheLiveVaultThroughItsOwnChanges() throws {
        // The legitimate writers of vault.json keep the header available: a new recovery block
        // for the live key, a password change, Create New… through the app.
        Storage.key = try Vault.enable(password: .of("old"), rounds: 1000)
        let app = app()
        XCTAssertNotNil(Vault.backupHeader(app: "Keepit test"))
        _ = try Vault.createRecovery(for: try XCTUnwrap(Storage.key))
        let withPhrase = try XCTUnwrap(Vault.backupHeader(app: "Keepit test"))
        XCTAssertNotNil(withPhrase.recovery)

        Vault.askPasswordForTesting = { _ in .of("new") }
        defer { Vault.askPasswordForTesting = nil }
        app.changePassword()
        XCTAssertTrue(errors.isEmpty, "\(errors)")
        let rekeyed = try XCTUnwrap(Vault.backupHeader(app: "Keepit test"))
        XCTAssertNotEqual(rekeyed.salt, withPhrase.salt)
        XCTAssertNotNil(app.backupSnapshot())

        AbortableModal.responseForTesting = { _ in .alertSecondButtonReturn }   // keep the password
        app.regenerateRecoveryPhrase()
        let regenerated = try XCTUnwrap(Vault.backupHeader(app: "Keepit test"))
        XCTAssertNotEqual(regenerated.recovery?.salt, rekeyed.recovery?.salt)
        XCTAssertNotNil(app.backupSnapshot())
    }

    func testHeaderAndCheckComeFromOneReadOfTheFile() throws {
        // A second, whole, valid vault.json swapped in under the live key: not "verified by the
        // check, header from the other file" — refused as one.
        Storage.key = try Vault.enable(password: .of("old"), rounds: 1000)
        let app = app()
        let other = try Vault.enable(password: .of("other"), rounds: 1000)
        other.zero()
        XCTAssertNil(Vault.backupHeader(app: "Keepit test"))
        XCTAssertNil(app.backupSnapshot())
        // And the key going live again against the current file makes the file the live one.
        Storage.key = try XCTUnwrap(Vault.unlock(password: .of("other")))
        XCTAssertNotNil(Vault.backupHeader(app: "Keepit test"))
    }
}
