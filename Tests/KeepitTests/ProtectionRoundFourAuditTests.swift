import XCTest
@testable import Keepit

/// The auditor's round-4 probes on PR #39, inverted. `liveMeta` used to be whatever vault.json
/// held when `Storage.key` was assigned: a Touch ID key admitted by `verify` over a damaged salt
/// made that file "the key's own", and assigning the same key object again rebased it onto a
/// replaced file. Now the metadata travels with the key (`SecureKey.provenance`), set by the
/// operation that derived, unwrapped or prepared it, together with what that operation proved —
/// and a backup header needs the file to be that metadata *and* a proven way in.
final class ProtectionRoundFourAuditTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    private func app() -> AppDelegate {
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.history.add(.text("local history"))
        app.history.flush()
        return app
    }

    private func damageSalt() throws {
        var meta = try JSONDecoder().decode(Vault.Meta.self, from: Data(contentsOf: Vault.metaURL))
        var salt = meta.salt
        salt[salt.startIndex] ^= 1
        meta.salt = salt
        try Vault.encodeMeta(meta).write(to: Vault.metaURL, options: .atomic)
    }

    /// The Touch ID branch of `unlockVault`, without the Keychain: the key bytes come back after a lock.
    private func biometricCopy(of key: SecureKey) -> SecureKey {
        let bytes = key.withBytes { Data($0) }
        return bytes.withUnsafeBytes { SecureKey(bytes: $0) }
    }

    // MARK: 1 — a Touch ID key over a damaged salt

    func testTouchIDKeyOverADamagedSaltGetsNoBackupHeader() throws {
        let originalKey = try Vault.enable(password: .of("old"), rounds: 1000)     // a legacy vault: no recovery block
        defer { originalKey.zero() }
        Storage.key = originalKey
        let app = app()
        let biometricKey = biometricCopy(of: originalKey)
        defer { biometricKey.zero() }
        Storage.clearKey()
        try damageSalt()

        XCTAssertTrue(Vault.verify(biometricKey), "the check still opens — not a proof of anything else")
        XCTAssertTrue(Vault.admitBiometric(biometricKey), "admitted: the data opens")
        Storage.key = biometricKey
        let p = try XCTUnwrap(biometricKey.provenance)
        XCTAssertFalse(p.passwordDerives)
        XCTAssertFalse(p.phraseOpens, "no block to prove")
        XCTAssertNil(Vault.unlock(password: .of("old")))
        XCTAssertNil(Vault.backupHeader(app: "Keepit test"))
        XCTAssertNil(app.backupSnapshot(), "no archive that nothing would open")
    }

    func testTouchIDKeyOnALegacyVaultWaitsForAPasswordUnlock() throws {
        // Intact file, no block, key not from the password: nothing is proven, so no backup until
        // the password has been typed once (the auditor's trade-off for the legacy vault).
        let originalKey = try Vault.enable(password: .of("old"), rounds: 1000)
        defer { originalKey.zero() }
        let app = app()
        let biometricKey = biometricCopy(of: originalKey)
        defer { biometricKey.zero() }
        XCTAssertTrue(Vault.admitBiometric(biometricKey))
        Storage.key = biometricKey
        XCTAssertNil(app.backupSnapshot())

        Storage.key = try XCTUnwrap(Vault.unlock(password: .of("old")))
        XCTAssertTrue(try XCTUnwrap(Storage.key?.provenance).passwordDerives)
        XCTAssertNotNil(app.backupSnapshot())
    }

    func testTouchIDKeyWithAnIntactBlockIsProvenByThePhrase() throws {
        let originalKey = try Vault.enable(password: .of("old"), rounds: 1000)
        defer { originalKey.zero() }
        let words = try Vault.createRecovery(for: originalKey)
        let app = app()
        let biometricKey = biometricCopy(of: originalKey)
        defer { biometricKey.zero() }
        try damageSalt()                                                        // the password half is broken; the block is intact
        XCTAssertTrue(Vault.admitBiometric(biometricKey))
        Storage.key = biometricKey
        XCTAssertTrue(try XCTUnwrap(biometricKey.provenance).phraseOpens)
        let snapshot = try XCTUnwrap(app.backupSnapshot(), "the phrase opens what this header describes")
        let json = try Backup.payloadJSON(history: snapshot.history, templatesJSON: snapshot.templatesJSON,
                                          settings: snapshot.settings, created: snapshot.header.created, app: snapshot.header.app)
        let bytes = try Backup.encodeAutomatic(json: json, dataKey: snapshot.dataKey, vault: snapshot.header)
        XCTAssertThrowsError(try Backup.decode(bytes, password: .of("old")))
        var entropy = try XCTUnwrap(Mnemonic.decode(words))
        defer { entropy.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        XCTAssertEqual(try Backup.decode(bytes, recoveryEntropy: entropy).history.first?.plainText, "local history")
    }

    func testABlockThatDoesNotUnwrapToTheKeyProvesNothing() throws {
        // vault.json with a recovery block made for another key: the check opens (same key), the
        // block does not — Touch ID admission records phraseOpens == false.
        let key = try Vault.enable(password: .of("old"), rounds: 1000)
        defer { key.zero() }
        let stranger = try Vault.prepareEnable(password: .of("x"), rounds: 1000).key
        defer { stranger.zero() }
        var meta = try JSONDecoder().decode(Vault.Meta.self, from: Data(contentsOf: Vault.metaURL))
        _ = try Vault.addRecovery(to: &meta, for: stranger)
        try Vault.encodeMeta(meta).write(to: Vault.metaURL, options: .atomic)
        XCTAssertFalse(Vault.recoveryOpens(meta, with: key))
        let biometricKey = biometricCopy(of: key)
        defer { biometricKey.zero() }
        XCTAssertTrue(Vault.admitBiometric(biometricKey))
        XCTAssertFalse(try XCTUnwrap(biometricKey.provenance).phraseOpens)
    }

    // MARK: 2 — assigning the same key again does not rebase its metadata

    func testReassigningTheKeyDoesNotAdoptAReplacedFile() throws {
        let oldKey = try Vault.enable(password: .of("old"), rounds: 1000)
        Storage.key = oldKey
        let app = app()
        let other = try Vault.prepareEnable(password: .of("other"), rounds: 1000)
        defer { other.key.zero() }
        try Vault.encodeMeta(other.meta).write(to: Vault.metaURL, options: .atomic)
        XCTAssertNil(app.backupSnapshot(), "the replacement is not the key's file")

        Storage.key = oldKey                                                    // what a second publication does
        XCTAssertFalse(Vault.verify(oldKey))
        XCTAssertEqual(try XCTUnwrap(oldKey.provenance).meta.salt, try XCTUnwrap(Vault.liveMeta).salt)
        XCTAssertNotEqual(other.meta.salt, Vault.liveMeta?.salt, "still the metadata the key was made with")
        XCTAssertNil(Vault.backupHeader(app: "Keepit test"))
        XCTAssertNil(app.backupSnapshot())
    }

    // MARK: the provenance each way in records

    func testProvenanceByOrigin() throws {
        let key = try Vault.enable(password: .of("pw"), rounds: 1000)
        XCTAssertEqual(key.provenance.map { [$0.passwordDerives, $0.phraseOpens] }, [true, false], "prepared, no block yet")
        let words = try Vault.createRecovery(for: key)
        XCTAssertEqual(key.provenance.map { [$0.passwordDerives, $0.phraseOpens] }, [true, true], "a block made for it")
        key.zero()

        let byPassword = try XCTUnwrap(Vault.unlock(password: .of("pw")))
        XCTAssertEqual(byPassword.provenance.map { [$0.passwordDerives, $0.phraseOpens] }, [true, true], "both proven on the way in")
        byPassword.zero()

        let byPhrase = try XCTUnwrap(Vault.unlockWithRecovery(words: words))
        XCTAssertEqual(byPhrase.provenance.map { [$0.passwordDerives, $0.phraseOpens] }, [false, true], "the password half is unknown")
        Storage.key = byPhrase
        XCTAssertNotNil(Vault.backupHeader(app: "Keepit test"), "the phrase opens it: enough for an archive")

        let bare = biometricCopy(of: byPhrase)
        defer { bare.zero() }
        XCTAssertNil(bare.provenance)
        Storage.key = bare
        XCTAssertNil(Vault.backupHeader(app: "Keepit test"), "a key with no provenance seals nothing")
    }
}
