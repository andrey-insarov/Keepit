import XCTest
@testable import Keepit

final class VaultTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    func testSecureBufferAppendRemoveEqualZero() {
        let a = SecureBuffer.of("héllo")
        let b = SecureBuffer.of("héllo")
        XCTAssertEqual(a.count, 6)
        XCTAssertTrue(SecureBuffer.equal(a, b))
        b.removeLast(2)                       // remove "o" and one byte of "é"? no: last 2 bytes = "lo"
        XCTAssertFalse(SecureBuffer.equal(a, b))
        a.zero()
        XCTAssertTrue(a.isZeroed)
        XCTAssertEqual(a.count, 0)
    }

    func testEncryptDecryptRoundTripAndTamperDetection() throws {
        let key = try Vault.enable(password: .of("correct horse"))
        let plain = Data("payload ✓".utf8)
        var sealed = try Vault.encrypt(plain, key: key)
        XCTAssertTrue(Vault.isEncrypted(sealed))
        XCTAssertEqual(try Vault.decrypt(sealed, key: key), plain)
        sealed[sealed.count - 1] ^= 0xFF
        XCTAssertThrowsError(try Vault.decrypt(sealed, key: key), "GCM must reject a modified ciphertext")
    }

    func testUnlockAcceptsOnlyTheRightPassword() throws {
        let key = try Vault.enable(password: .of("right"))
        key.zero()
        XCTAssertTrue(Vault.isEnabled)
        XCTAssertNotNil(Vault.unlock(password: .of("right")))
        XCTAssertNil(Vault.unlock(password: .of("wrong")))
        Vault.disable()
        XCTAssertFalse(Vault.isEnabled)
    }

    func testSameKeyFromSamePasswordAndSalt() throws {
        let salt = Data(repeating: 7, count: 16)
        let k1 = try Vault.deriveKey(password: .of("pw"), salt: salt)
        let k2 = try Vault.deriveKey(password: .of("pw"), salt: salt)
        let box = try Vault.encrypt(Data("x".utf8), key: k1)
        XCTAssertEqual(try? Vault.decrypt(box, key: k2), Data("x".utf8))
        let k3 = try Vault.deriveKey(password: .of("pw"), salt: salt, rounds: 1_000)
        XCTAssertThrowsError(try Vault.decrypt(box, key: k3), "different round count → different key")
    }

    func testNewVaultRecordsKDFParameters() throws {
        _ = try Vault.enable(password: .of("pw"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: Vault.metaURL)) as? [String: Any]
        XCTAssertEqual(json?["formatVersion"] as? Int, Vault.formatVersion)
        XCTAssertEqual(json?["kdf"] as? String, Vault.kdfPBKDF2SHA256)
        XCTAssertEqual(json?["rounds"] as? UInt32, Vault.defaultRounds)
    }

    func testFormat1VaultWithoutKDFFieldsStillUnlocks() throws {
        // vault.json written by Keepit ≤ 2.11.1 has only salt / check (/ recovery).
        let key = try Vault.enable(password: .of("old"))
        key.zero()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: Vault.metaURL)) as? [String: Any])
        json["formatVersion"] = nil; json["kdf"] = nil; json["rounds"] = nil
        try JSONSerialization.data(withJSONObject: json).write(to: Vault.metaURL)
        XCTAssertNotNil(Vault.unlock(password: .of("old")))
        XCTAssertNil(Vault.unlock(password: .of("wrong")))
        XCTAssertEqual(Vault.kdfDescription, "\(Vault.kdfPBKDF2SHA256), \(Vault.defaultRounds) rounds (format 1)")
    }

    func testVaultHonoursRecordedRoundsAndRefusesUnknownKDF() throws {
        let key = try Vault.enable(password: .of("pw"), rounds: 1_000)
        key.zero()
        XCTAssertNotNil(Vault.unlock(password: .of("pw")), "rounds come from vault.json, not from the binary")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: Vault.metaURL)) as? [String: Any])
        json["kdf"] = "argon2id"
        try JSONSerialization.data(withJSONObject: json).write(to: Vault.metaURL)
        XCTAssertNil(Vault.unlock(password: .of("pw")), "a KDF this build does not know is refused, not guessed")
    }

    func testRandomBytesAreFreshAndRightSized() throws {
        let a = try Vault.randomBytes(16), b = try Vault.randomBytes(16)
        XCTAssertEqual(a.count, 16)
        XCTAssertNotEqual(a, b)
    }

    func testStorageKeyAssignmentZeroesPreviousKey() throws {
        let k1 = try Vault.enable(password: .of("a"))
        Storage.key = k1
        Storage.key = nil
        XCTAssertTrue(k1.isZeroed)
    }
}
