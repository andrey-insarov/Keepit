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

    func testSameKeyFromSamePasswordAndSalt() {
        let salt = Data(repeating: 7, count: 16)
        let k1 = Vault.deriveKey(password: .of("pw"), salt: salt)
        let k2 = Vault.deriveKey(password: .of("pw"), salt: salt)
        let box = try! Vault.encrypt(Data("x".utf8), key: k1)
        XCTAssertEqual(try? Vault.decrypt(box, key: k2), Data("x".utf8))
    }

    func testStorageKeyAssignmentZeroesPreviousKey() throws {
        let k1 = try Vault.enable(password: .of("a"))
        Storage.key = k1
        Storage.key = nil
        XCTAssertTrue(k1.isZeroed)
    }
}
