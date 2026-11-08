import AppKit
import XCTest
@testable import Keepit

/// The auditor's round-1 probes on PR #39 (SEC01 / SEC13), inverted: each asserted the defect,
/// each now asserts the fix.
/// 1 (P1): an undo that did not finish (the journal stays armed) used to leave the app running —
///   the first alert came before the holds, a lock and an unlock released them, and Create New…
///   wrote vault.json around them; the launch replay then discarded all of it. Now the files are
///   pinned before the alert and the process quits (`exitForTesting` stands for the exit here).
/// 2 (P1): `publishEnabledVault` showed the phrase after a lock delivered during the Touch ID step.
/// 3 (P2): a sweep that failed after a successful enable left plain copies and stopped the next
///   launch; now it is reported, and the launch goes on.
/// 4 (P2): a plain restore into an existing vault compared the JSON against the limit, not the
///   sealed bytes.
final class ProtectionSecondOrderAuditTests: XCTestCase {
    private var tmp: TempStorage!
    private var errors: [String] = []
    private var exits: [Error] = []

    override func setUp() {
        tmp = TempStorage()
        errors = []; exits = []
        Vault.errorSinkForTesting = { [weak self] in self?.errors.append($0) }
        RecoveryDialogs.presentSinkForTesting = { _ in }
        RestoreCommit.clearUnsweptForTesting()
    }
    override func tearDown() {
        Vault.errorSinkForTesting = nil
        Vault.askPasswordForTesting = nil
        Vault.promptForTesting = nil
        AbortableModal.responseForTesting = nil
        RecoveryDialogs.presentSinkForTesting = nil
        RestoreCommit.beforeDisarmForTesting = nil
        RestoreCommit.clearUnsweptForTesting()
        Storage.releaseAll()
        tmp.restore()
    }

    private func app(protected: Bool = true) throws -> AppDelegate {
        if protected { Storage.key = try Vault.enable(password: .of("old"), rounds: 1000) }
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        app.infoSinkForTesting = { _ in }
        app.authenticateForTesting = { true }
        app.exitForTesting = { [weak self] in self?.exits.append($0) }   // every app-level failure path below needs it: the real thing is exit(1)
        app.history.add(.text("original local history"))
        app.history.flush()
        return app
    }

    private func setImmutable(_ value: Bool, _ url: URL) throws {
        try FileManager.default.setAttributes([.immutable: value], ofItemAtPath: url.path)
    }

    private func failDisarm() {
        RestoreCommit.beforeDisarmForTesting = { [unowned self] in
            do { try self.setImmutable(true, FileJournal.protection.marker) } catch { XCTFail(String(describing: error)) }
        }
    }

    private func reloadAfterRepair() throws -> AppDelegate {
        try setImmutable(false, FileJournal.protection.marker)
        Storage.clearKey()
        Storage.releaseAll()
        let restarted = AppDelegate()
        Storage.key = try XCTUnwrap(Vault.unlock(password: .of("old")))
        restarted.loadStoresForTesting()
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        return restarted
    }

    private func historyOnDisk() -> [String?] {
        HistoryStore(settings: Settings()).items.map(\.plainText)
    }

    // MARK: 1 — an undo that did not finish

    func testFailedDisarmPinsTheFilesBeforeTheAlertAndQuits() throws {
        let app = try app()
        defer { try? setImmutable(false, FileJournal.protection.marker) }
        failDisarm()
        var insideAlert = 0
        Vault.errorSinkForTesting = { [weak self] text in
            self?.errors.append(text)
            insideAlert += 1
            guard insideAlert == 1 else { return }
            // What a debounced save does while the alert is up: nothing lands.
            XCTAssertTrue(RestoreCommit.hasArmedJournal)
            XCTAssertTrue(Storage.isHeld(Storage.historyURL))
            XCTAssertTrue(Storage.isHeld(Vault.metaURL))
            app.history.add(.text("captured during error"))
            app.history.flush()
        }
        Vault.askPasswordForTesting = { _ in .of("new") }
        app.changePassword()
        XCTAssertEqual(errors.count, 1, "one alert, then the quit")
        XCTAssertEqual(exits.count, 1, "the process leaves")
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertNotEqual(historyOnDisk().first, "captured during error")

        let restarted = try reloadAfterRepair()
        XCTAssertEqual(restarted.history.items.map(\.plainText), ["original local history"])
        XCTAssertNotNil(Vault.unlock(password: .of("old")))
    }

    func testLockAndUnlockDoNotReleaseThePinsAfterAFailedUndo() throws {
        // The process would be gone; this is the belt for the braces: even if it were not, a
        // successful read releases a hold, not a pin.
        let app = try app()
        defer { try? setImmutable(false, FileJournal.protection.marker) }
        failDisarm()
        Vault.askPasswordForTesting = { _ in .of("new") }
        app.changePassword()
        XCTAssertEqual(exits.count, 1)
        XCTAssertTrue(RestoreCommit.hasArmedJournal)

        app.lock()
        Vault.promptForTesting = { _ in .password(.of("old")) }
        _ = app.unlock()
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertTrue(Storage.isHeld(Storage.templatesURL))
        XCTAssertTrue(Storage.isHeld(Storage.settingsURL))
        XCTAssertTrue(Storage.isHeld(Vault.metaURL))
        app.history.add(.text("captured after unlock"))
        app.history.flush()
        XCTAssertNotEqual(historyOnDisk().first, "captured after unlock")

        let restarted = try reloadAfterRepair()
        XCTAssertEqual(restarted.history.items.map(\.plainText), ["original local history"])
    }

    func testCreateNewIsRefusedWhileTheJournalIsArmed() throws {
        let app = try app()
        let key = try XCTUnwrap(Storage.key)
        let oldWords = try Vault.createRecovery(for: key)
        defer { try? setImmutable(false, FileJournal.protection.marker) }
        failDisarm()
        Vault.askPasswordForTesting = { _ in .of("new") }
        app.changePassword()
        XCTAssertEqual(exits.count, 1)
        XCTAssertTrue(RestoreCommit.hasArmedJournal)
        XCTAssertFalse(app.hasUnreadableData, "the stores read fine; the refusal comes from the journal")

        var newWords: [String]?
        RecoveryDialogs.presentSinkForTesting = { newWords = $0 }
        AbortableModal.responseForTesting = { _ in .alertSecondButtonReturn }
        var refused = 0
        app.refusalForTesting = { refused += 1 }
        app.regenerateRecoveryPhrase()
        XCTAssertEqual(refused, 1)
        XCTAssertNil(newWords)
        XCTAssertNotNil(Vault.unlockWithRecovery(words: oldWords))
        // And vault.json itself is pinned: the direct write refuses too.
        XCTAssertThrowsError(try Vault.createRecovery(for: key)) {
            XCTAssertEqual($0 as? Storage.Failure, .held("vault.json"))
        }

        _ = try reloadAfterRepair()
        XCTAssertNotNil(Vault.unlockWithRecovery(words: oldWords))
    }

    // MARK: 2 — a lock after the commit, before the phrase

    func testEnableDoesNotShowThePhraseAfterAPostCommitLock() throws {
        let app = try app(protected: false)
        var shown: [String]?
        RecoveryDialogs.presentSinkForTesting = { shown = $0 }
        // A synchronous follow-up callback stands in for a lock delivered during a Touch ID alert.
        app.backup.onStateChange = { _ in app.lock() }
        defer { app.backup.onStateChange = nil }

        XCTAssertTrue(app.enableProtection(with: .of("new")), "the commit stands")
        XCTAssertTrue(app.isLocked)
        XCTAssertNil(Storage.key)
        XCTAssertNil(shown, "not while locked")
        // The phrase is in vault.json: Show… after the unlock.
        let key = try XCTUnwrap(Vault.unlock(password: .of("new")))
        XCTAssertNotNil(Vault.recoveryWords(for: key))
        key.zero()
    }

    func testRestoredVaultNoteIsNotShownAfterAPostCommitLock() throws {
        let app = try app(protected: false)
        var infos: [String] = []
        app.infoSinkForTesting = { infos.append($0) }
        app.backup.onStateChange = { _ in app.lock() }
        defer { app.backup.onStateChange = nil }
        let entropy = [UInt8](repeating: 7, count: Mnemonic.entropyBytes)
        XCTAssertTrue(app.enableProtection(with: .of("new"), recoveryEntropy: entropy))
        XCTAssertTrue(app.isLocked)
        XCTAssertTrue(infos.isEmpty)
        XCTAssertNotNil(Vault.unlockWithRecovery(words: Mnemonic.encode(entropy)), "the kept phrase opens the vault")
    }

    // MARK: 3 — the sweep fails after a successful enable

    func testUnsweptCopiesAreReportedAndDoNotStopTheNextLaunch() throws {
        let app = try app(protected: false)
        let copy = FileJournal.protection.directory.appendingPathComponent("history.json")
        RestoreCommit.beforeDisarmForTesting = { [unowned self] in
            do { try self.setImmutable(true, copy) } catch { XCTFail(String(describing: error)) }
        }
        defer { try? setImmutable(false, copy) }

        XCTAssertTrue(app.enableProtection(with: .of("new")))
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertNotNil(Storage.key, "published: the commit stands")
        XCTAssertTrue(Vault.isEncrypted(try Data(contentsOf: Storage.historyURL)))
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("protection-journal"), "names the folder: \(errors[0])")
        XCTAssertFalse(Vault.isEncrypted(try Data(contentsOf: copy)), "the plain copy is still there — which is what the alert says")

        // The next launch: no replay (nothing armed), no stop; the leftover is noted for the alert.
        XCTAssertFalse(try RestoreCommit.recoverIfNeeded())
        XCTAssertEqual(RestoreCommit.unsweptJournals.map { $0.0.lastPathComponent }, ["protection-journal"])
        try setImmutable(false, copy)
        RestoreCommit.clearUnsweptForTesting()
        XCTAssertFalse(try RestoreCommit.recoverIfNeeded())
        XCTAssertTrue(RestoreCommit.unsweptJournals.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path), "gone once the disk allows")
    }

    // MARK: 4 — the size check counts the seal

    func testSizeCheckCountsTheSealForStepsStorageSeals() throws {
        let json = Data(repeating: 0x20, count: 1000)
        let sealed = [RestoreCommit.Step(name: "a", url: Storage.templatesURL, data: json, encrypt: false)]
        let toSeal = [RestoreCommit.Step(name: "b", url: Storage.templatesURL, data: json, encrypt: true)]
        XCTAssertNil(RestoreCommit.stepOverLimit(sealed, limit: 1000))
        XCTAssertEqual(RestoreCommit.stepOverLimit(toSeal, limit: 1000), "b")
        XCTAssertNil(RestoreCommit.stepOverLimit(toSeal, limit: 1000 + Vault.sealOverhead))
        XCTAssertEqual(RestoreCommit.stepOverLimit(toSeal, limit: 1000 + Vault.sealOverhead - 1), "b")
        // The overhead is what encrypt adds.
        let key = try Vault.enable(password: .of("k"), rounds: 1000)
        defer { key.zero() }
        XCTAssertEqual(try Vault.encrypt(json, key: key).count, json.count + Vault.sealOverhead)
    }
}
