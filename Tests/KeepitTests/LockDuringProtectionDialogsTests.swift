import AppKit
import XCTest
@testable import Keepit

/// SEC13: a lock while one of the protection dialogs is up (screen lock, lock hot key, lock after
/// screen lock) voids the answer. Every flow reads the lock generation before a dialog and checks
/// `!isLocked, lockCount == g` after it; the key is read after the check, never captured before.
/// Before: `regenerateRecoveryPhrase` captured the key before the dialog and crashed on the zeroed
/// buffer (`precondition`); `changePassword` went on to re-key with a key the lock had wiped;
/// `completeRecovery` looped on a dead key and `unlock()` restarted the watcher and hot keys.
final class LockDuringProtectionDialogsTests: XCTestCase {
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
        Vault.promptForTesting = nil
        AbortableModal.responseForTesting = nil
        tmp.restore()
    }

    private func app() throws -> AppDelegate {
        Storage.key = try Vault.enable(password: .of("old"), rounds: 1000)
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.createBackupEngine()
        a.hotKeyFailureForTesting = { _ in }
        a.infoSinkForTesting = { _ in }
        a.history.add(.text("item")); a.history.flush()
        return a
    }

    private func opens(_ pw: String) -> Bool {
        guard let k = Vault.unlock(password: .of(pw)) else { return false }
        k.zero(); return true
    }
    private func bytes(_ url: URL) throws -> Data { try Data(contentsOf: url) }

    /// Nothing changed on disk or in memory: the vault still opens with the old password only,
    /// the key is gone (locked), no journal, no phrase shown.
    private func assertNothingHappened(_ a: AppDelegate, vault: Data, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(a.isLocked, file: file, line: line)
        XCTAssertNil(Storage.key, file: file, line: line)
        XCTAssertEqual(try bytes(Vault.metaURL), vault, "vault.json untouched", file: file, line: line)
        XCTAssertTrue(opens("old"), file: file, line: line)
        XCTAssertFalse(opens("new"), file: file, line: line)
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path), file: file, line: line)
        XCTAssertTrue(errors.isEmpty, "\(errors)", file: file, line: line)
    }

    // MARK: Change Password…

    func testLockDuringAuthenticationVoidsChangePassword() throws {
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        a.authenticateForTesting = { a.lock(); return true }
        var asked = 0
        Vault.askPasswordForTesting = { _ in asked += 1; return .of("new") }
        a.changePassword()
        XCTAssertEqual(asked, 0, "the new-password prompt never comes")
        try assertNothingHappened(a, vault: vault)
    }

    func testLockDuringNewPasswordPromptVoidsChangePassword() throws {
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        a.authenticateForTesting = { true }
        Vault.askPasswordForTesting = { _ in a.lock(); return .of("new") }
        a.changePassword()
        try assertNothingHappened(a, vault: vault)
    }

    func testLockAndUnlockDuringNewPasswordPromptVoidsChangePassword() throws {
        // The generation moved: an answer typed before the lock does not apply after the unlock.
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        a.authenticateForTesting = { true }
        Vault.askPasswordForTesting = { _ in
            a.lock()
            Storage.key = Vault.unlock(password: .of("old")); a.setLockedForTesting(false)   // the unlock, in short
            return .of("new")
        }
        a.changePassword()
        XCTAssertFalse(a.isLocked)
        XCTAssertNotNil(Storage.key)
        XCTAssertEqual(try bytes(Vault.metaURL), vault)
        XCTAssertTrue(opens("old")); XCTAssertFalse(opens("new"))
    }

    // MARK: Create New… (recovery phrase)

    func testLockDuringAuthenticationVoidsRegenerate() throws {
        // Used to crash: the key was captured before the dialog and zeroed by the lock.
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        a.authenticateForTesting = { a.lock(); return true }
        a.regenerateRecoveryPhrase()
        XCTAssertTrue(shownPhrases.isEmpty)
        try assertNothingHappened(a, vault: vault)
    }

    func testLockDuringExposedQuestionVoidsTheRekeyButKeepsTheNewPhrase() throws {
        // The new phrase was written (and shown) before the question; the password change it
        // offers does not run after a lock.
        let a = try app()
        a.authenticateForTesting = { true }
        AbortableModal.responseForTesting = { _ in a.lock(); return .alertFirstButtonReturn }
        var asked = 0
        Vault.askPasswordForTesting = { _ in asked += 1; return .of("new") }
        a.regenerateRecoveryPhrase()
        XCTAssertEqual(shownPhrases.count, 1)
        XCTAssertEqual(asked, 0)
        XCTAssertTrue(a.isLocked)
        XCTAssertTrue(opens("old")); XCTAssertFalse(opens("new"))
        XCTAssertNotNil(Vault.unlockWithRecovery(words: shownPhrases[0]), "the phrase shown is the one in vault.json")
        XCTAssertTrue(errors.isEmpty)
    }

    func testLockDuringNewPasswordAfterExposedQuestionVoidsTheRekey() throws {
        let a = try app()
        a.authenticateForTesting = { true }
        AbortableModal.responseForTesting = { _ in .alertFirstButtonReturn }
        Vault.askPasswordForTesting = { _ in a.lock(); return .of("new") }
        a.regenerateRecoveryPhrase()
        XCTAssertTrue(a.isLocked)
        XCTAssertNil(Storage.key)
        XCTAssertTrue(opens("old")); XCTAssertFalse(opens("new"))
        XCTAssertNotNil(Vault.unlockWithRecovery(words: shownPhrases[0]))
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: Show…

    func testLockDuringAuthenticationVoidsShowPhrase() throws {
        let a = try app()
        _ = try Vault.createRecovery(for: try XCTUnwrap(Storage.key))
        a.authenticateForTesting = { a.lock(); return true }
        a.showRecoveryPhrase()
        XCTAssertTrue(shownPhrases.isEmpty)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: Disable

    func testLockDuringPasswordPromptVoidsDisable() throws {
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        Vault.askPasswordForTesting = { _ in a.lock(); return .of("old") }
        XCTAssertFalse(a.disableProtection())
        XCTAssertTrue(Vault.isEnabled)
        // The lock itself re-saves before purging (fresh nonce, same items), so the bytes differ;
        // what matters is that the file is still sealed, under the old key.
        let history = try bytes(Storage.historyURL)
        XCTAssertTrue(Vault.isEncrypted(history), "not rewritten plain")
        let old = try XCTUnwrap(Vault.unlock(password: .of("old")))
        XCTAssertNoThrow(try Vault.decrypt(history, key: old))
        old.zero()
        try assertNothingHappened(a, vault: vault)
    }

    // MARK: After a phrase unlock: the forced new password

    func testLockDuringForcedNewPasswordEndsTheLoopAndKeepsTheFlag() throws {
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        a.needsPasswordReset = true
        var asked = 0
        Vault.askPasswordForTesting = { _ in asked += 1; a.lock(); return nil }   // a lock closes the prompt: nil
        XCTAssertFalse(a.completeRecovery())
        XCTAssertEqual(asked, 1, "the loop ended with the lock instead of asking again on a dead key")
        XCTAssertTrue(a.needsPasswordReset, "asked again at the next unlock")
        try assertNothingHappened(a, vault: vault)
    }

    func testCancelOfForcedNewPasswordAsksAgainWhileUnlocked() throws {
        let a = try app()
        a.needsPasswordReset = true
        var asked = 0
        Vault.askPasswordForTesting = { _ in asked += 1; return asked < 3 ? nil : .of("new") }   // Cancel twice
        XCTAssertTrue(a.completeRecovery())
        XCTAssertEqual(asked, 3)
        XCTAssertFalse(a.needsPasswordReset)
        XCTAssertTrue(opens("new"))
    }

    func testUnlockDoesNotContinueWhenTheForcedPromptWasLockedAway() throws {
        // unlock() → password accepted → completeRecovery() → lock during the prompt: the rest
        // of unlock() (watcher, hot keys, backup) must not run, and the result is "not unlocked".
        let a = try app()
        a.lock()
        a.needsPasswordReset = true
        Vault.promptForTesting = { _ in .password(.of("old")) }
        Vault.askPasswordForTesting = { _ in a.lock(); return nil }
        XCTAssertFalse(a.unlock())
        XCTAssertTrue(a.isLocked)
        XCTAssertNil(Storage.key)
        XCTAssertFalse(a.monitor.isRunning, "the watcher did not restart")
        XCTAssertTrue(a.needsPasswordReset)
        XCTAssertTrue(a.history.items.isEmpty, "purged by the lock, not reloaded by the rest of unlock()")
    }

    func testUnlockCompletesTheResetWhenNothingInterrupts() throws {
        let a = try app()
        a.lock()
        a.needsPasswordReset = true
        Vault.promptForTesting = { _ in .password(.of("old")) }
        Vault.askPasswordForTesting = { _ in .of("new") }
        XCTAssertTrue(a.unlock())
        XCTAssertFalse(a.isLocked)
        XCTAssertFalse(a.needsPasswordReset)
        XCTAssertTrue(opens("new"))
        XCTAssertEqual(a.history.items.count, 1)
        a.lock()
    }

    // MARK: Reset…

    func testLockDuringResetConfirmationVoidsTheReset() throws {
        let a = try app()
        let vault = try bytes(Vault.metaURL)
        a.authenticateForTesting = { true }
        AbortableModal.responseForTesting = { _ in a.lock(); return .alertFirstButtonReturn }
        a.resetRequested()
        XCTAssertTrue(Vault.isEnabled, "not reset")
        XCTAssertTrue(FileManager.default.fileExists(atPath: Storage.historyURL.path))
        try assertNothingHappened(a, vault: vault)
    }

    func testLockDuringResetAuthenticationVoidsTheReset() throws {
        let a = try app()
        a.authenticateForTesting = { a.lock(); return true }
        var confirmed = 0
        AbortableModal.responseForTesting = { _ in confirmed += 1; return .alertFirstButtonReturn }
        a.resetRequested()
        XCTAssertEqual(confirmed, 0, "the confirmation never comes")
        XCTAssertTrue(Vault.isEnabled)
    }
}
