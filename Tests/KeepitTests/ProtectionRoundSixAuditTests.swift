import XCTest
@testable import Keepit

/// The auditor's round-6 probe on PR #39, inverted. `confirmPasswordForBackups` adopted whatever
/// key the typed password derived from the vault.json on disk — and when that file had been
/// replaced by another valid vault, it swapped the session's key out from under history and
/// templates, which stayed sealed with the old one. Now the derived key must be the key in memory
/// byte for byte; only its provenance moves over, onto the same key object. A different key is
/// refused with an explanation and a way to save the data first.
final class ProtectionRoundSixAuditTests: XCTestCase {
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

    private func app() -> AppDelegate {
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        app.history.add(.text("local history"))
        app.history.flush()
        return app
    }

    func testTheConfirmationNeverAdoptsADifferentKey() throws {
        let oldKey = try Vault.enable(password: .of("old"), rounds: 1000)
        Storage.key = oldKey
        let app = app()
        let original = try Data(contentsOf: Storage.historyURL)
        XCTAssertNoThrow(try Vault.decrypt(original, key: oldKey))

        // Another valid vault.json swapped in under the live key.
        let replacement = try Vault.prepareEnable(password: .of("other"), rounds: 1000)
        defer { replacement.key.zero() }
        try Vault.encodeMeta(replacement.meta).write(to: Vault.metaURL, options: .atomic)
        XCTAssertNil(app.backupSnapshot())
        XCTAssertEqual(app.backupPause(), .passwordNeeded)

        Vault.askPasswordForTesting = { _ in .of("other") }          // the other vault's password: derives a different key
        XCTAssertFalse(app.confirmPasswordForBackups())
        XCTAssertTrue(Storage.key === oldKey, "the session's key stays")
        XCTAssertFalse(oldKey.isZeroed)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(try XCTUnwrap(errors.first).contains("vault.json has changed"), "\(errors)")
        XCTAssertEqual(app.backupPause(), .passwordNeeded, "still paused")
        app.history.reload()
        XCTAssertNil(app.history.loadFailure, "history still reads with the session's key")
        XCTAssertEqual(app.history.items.map(\.plainText), ["local history"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: FileJournal.protection.directory.path), "no commit happened, none was needed")
    }

    func testTheConfirmationMovesOnlyTheProvenanceOntoTheSameKeyObject() throws {
        // The legitimate case (round 5): a Touch ID key on a vault without a block, the right password.
        let original = try Vault.enable(password: .of("old"), rounds: 1000)
        let app = app()
        let bytes = original.withBytes { Data($0) }
        Storage.clearKey()
        let biometric = bytes.withUnsafeBytes { SecureKey(bytes: $0) }
        XCTAssertTrue(Vault.admitBiometric(biometric))
        Storage.key = biometric
        XCTAssertEqual(app.backupPause(), .passwordNeeded)

        Vault.askPasswordForTesting = { _ in .of("old") }
        XCTAssertTrue(app.confirmPasswordForBackups())
        XCTAssertTrue(Storage.key === biometric, "same object: nothing that holds it sees a swap")
        XCTAssertFalse(biometric.isZeroed)
        XCTAssertTrue(try XCTUnwrap(biometric.provenance).passwordDerives)
        XCTAssertNil(app.backupPause())
        XCTAssertTrue(errors.isEmpty)
    }

    func testSameBytesIsConstantTimeSafeOnZeroedKeys() throws {
        let a = try Vault.prepareEnable(password: .of("a"), rounds: 1000).key
        let b = a.withBytes { Data($0) }.withUnsafeBytes { SecureKey(bytes: $0) }
        let c = try Vault.prepareEnable(password: .of("c"), rounds: 1000).key
        XCTAssertTrue(a.sameBytes(as: b))
        XCTAssertFalse(a.sameBytes(as: c))
        b.zero()
        XCTAssertFalse(a.sameBytes(as: b), "a zeroed key equals nothing")
        a.zero(); c.zero()
    }
}
