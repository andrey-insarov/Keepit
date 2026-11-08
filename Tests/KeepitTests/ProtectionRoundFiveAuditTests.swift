import XCTest
@testable import Keepit

/// The auditor's round-5 probe on PR #39, inverted. A Touch ID key on a vault without a recovery
/// phrase pauses automatic backups (nothing proves an archive would open) — but the pause looked
/// like "Keepit is locked" in an unlocked app, with the last success still on the status line.
/// Now the engine answers `.passwordNeeded`, Settings shows why, and Back Up Now asks for the
/// password once; the key derived from it carries the proof.
final class ProtectionRoundFiveAuditTests: XCTestCase {
    private var tmp: TempStorage!
    private var errors: [String] = []
    override func setUp() {
        tmp = TempStorage()
        errors = []
        Vault.errorSinkForTesting = { [weak self] in self?.errors.append($0) }
    }
    override func tearDown() {
        Vault.errorSinkForTesting = nil
        Vault.askPasswordForTesting = nil
        Storage.releaseAll()
        tmp.restore()
    }

    /// A legacy vault (no block), one good backup, then the key admitted the Touch ID way.
    private func appAfterBiometricUnlock() throws -> (AppDelegate, URL) {
        Storage.key = try Vault.enable(password: .of("old"), rounds: 1000)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        app.history.add(.text("before"))
        app.history.flush()
        let folder = tmp.dir.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        app.backup.destination = PlainFolderDestination(folder)
        let first = expectation(description: "password-backed initial backup")
        app.backup.backUpNow {
            if case .failure(let error) = $0 { XCTFail("first backup: \(error)") }
            first.fulfill()
        }
        wait(for: [first], timeout: 5)
        let bytes = try XCTUnwrap(Storage.key).withBytes { Data($0) }
        Storage.clearKey()
        let biometricKey = bytes.withUnsafeBytes { SecureKey(bytes: $0) }
        XCTAssertTrue(Vault.admitBiometric(biometricKey))
        Storage.key = biometricKey
        app.history.add(.text("after biometric unlock"))
        return (app, folder)
    }

    func testThePauseIsNamedNotMistakenForALock() throws {
        let (app, _) = try appAfterBiometricUnlock()
        let priorSuccess = try XCTUnwrap(app.backup.state.lastSuccess)
        let priorName = app.backup.state.lastName

        XCTAssertFalse(app.isLocked)
        XCTAssertEqual(app.backupPause(), .passwordNeeded, "what Settings shows instead of the last success")
        XCTAssertNil(app.backupSnapshot())
        var failure: BackupEngine.Failure?
        app.backup.backUpNow { if case .failure(let error) = $0 { failure = error as? BackupEngine.Failure } }
        XCTAssertEqual(failure, .passwordNeeded, "not .locked")
        XCTAssertNil(app.backup.state.lastError, "a pause, not a failure: no backoff")
        XCTAssertEqual(app.backup.state.lastSuccess, priorSuccess)
        XCTAssertEqual(app.backup.state.lastName, priorName)
        XCTAssertTrue(app.backup.state.dirty, "the change waits")
        XCTAssertTrue(try XCTUnwrap(BackupEngine.Failure.passwordNeeded.errorDescription).contains("Back Up Now"))
    }

    func testConfirmingThePasswordResumesBackups() throws {
        let (app, folder) = try appAfterBiometricUnlock()
        let before = app.backup.state.records.map(\.name)
        Vault.askPasswordForTesting = { _ in .of("old") }
        XCTAssertTrue(app.confirmPasswordForBackups())
        XCTAssertTrue(try XCTUnwrap(Storage.key?.provenance).passwordDerives)
        XCTAssertNil(app.backupPause())

        let done = expectation(description: "backup after the confirmation")
        app.backup.backUpNow {
            if case .failure(let error) = $0 { XCTFail("after confirmation: \(error)") }
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        let names = app.backup.state.records.map(\.name)
        XCTAssertNotEqual(names, before)
        let newest = try XCTUnwrap(app.backup.state.lastName)
        let payload = try Backup.decode(Data(contentsOf: folder.appendingPathComponent(newest)), password: .of("old"))
        XCTAssertEqual(payload.history.map(\.plainText), ["after biometric unlock", "before"], "and the password opens it")
        XCTAssertTrue(errors.isEmpty)
    }

    func testAWrongOrCancelledConfirmationChangesNothing() throws {
        let (app, _) = try appAfterBiometricUnlock()
        let key = try XCTUnwrap(Storage.key)
        Vault.askPasswordForTesting = { _ in .of("wrong") }
        XCTAssertFalse(app.confirmPasswordForBackups())
        XCTAssertEqual(errors, [L("Wrong password.")])
        XCTAssertTrue(Storage.key === key)
        XCTAssertEqual(app.backupPause(), .passwordNeeded)

        Vault.askPasswordForTesting = { _ in nil }
        XCTAssertFalse(app.confirmPasswordForBackups())
        XCTAssertTrue(Storage.key === key)
    }

    func testALockDuringTheConfirmationVoidsIt() throws {
        let (app, _) = try appAfterBiometricUnlock()
        Vault.askPasswordForTesting = { _ in app.lock(); return .of("old") }
        XCTAssertFalse(app.confirmPasswordForBackups())
        XCTAssertTrue(app.isLocked)
        XCTAssertNil(Storage.key)
        XCTAssertEqual(app.backupPause(), .locked)
    }

    // Self-review: the restore's rollback copy is sealed under the same header.

    func testReplaceAsksForThePasswordBeforeTheRollbackCopyUnderThePause() throws {
        let (app, folder) = try appAfterBiometricUnlock()
        var asked = 0
        Vault.askPasswordForTesting = { _ in asked += 1; return .of("old") }
        let inputs = try XCTUnwrap(app.askRollbackInputs(), "the dialog stage asks, and goes on")
        XCTAssertEqual(asked, 1)
        XCTAssertNil(inputs.password, "the copy is sealed with the vault key, not an archive password")
        XCTAssertNil(app.backupPause())
        XCTAssertNotNil(Vault.backupHeader(app: "Keepit test", sourceID: app.settings.backupSourceID), "what the commit stage needs for the copy")
        XCTAssertTrue(inputs.destination?.displayPath.hasSuffix("backups") ?? false, "\(folder.lastPathComponent)")
    }

    func testRollbackCopyUnderThePauseNamesThePauseNotALock() throws {
        let (app, _) = try appAfterBiometricUnlock()
        Vault.askPasswordForTesting = { _ in nil }
        XCTAssertNil(app.askRollbackInputs(), "declined: Replace does not proceed")
        let inputs = AppDelegate.RollbackInputs(password: nil, destination: app.backup.destination)
        XCTAssertFalse(app.writeRollbackCopy(inputs))
        XCTAssertEqual(errors, [BackupEngine.Failure.passwordNeeded.errorDescription])
    }

    func testUnreadableDataIsItsOwnPause() throws {
        Storage.key = try Vault.enable(password: .of("old"), rounds: 1000)
        try Data("{".utf8).write(to: Storage.templatesURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        XCTAssertTrue(app.hasUnreadableData)
        XCTAssertEqual(app.backupPause(), .unreadableData)
        var failure: BackupEngine.Failure?
        app.backup.destination = PlainFolderDestination(tmp.dir)
        app.backup.backUpNow { if case .failure(let error) = $0 { failure = error as? BackupEngine.Failure } }
        XCTAssertEqual(failure, .unreadableData)
        XCTAssertNil(app.backup.state.lastError)
    }
}
