import XCTest
@testable import Keepit

final class RecoveryTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    func testWordListAndRoundTrip() {
        XCTAssertEqual(Mnemonic.words.count, 2048)
        XCTAssertEqual(Mnemonic.words.first, "abandon")
        XCTAssertEqual(Mnemonic.words.last, "zoo")
        let entropy = (0..<32).map { UInt8($0 * 7 % 256) }
        let words = Mnemonic.encode(entropy)
        XCTAssertEqual(words.count, 24)
        XCTAssertEqual(Mnemonic.decode(words), entropy)
    }

    func testChecksumCatchesTypos() {
        let words = Mnemonic.encode([UInt8](repeating: 0xAB, count: 32))
        var bad = words
        bad[3] = bad[3] == "abandon" ? "ability" : "abandon"
        XCTAssertNil(Mnemonic.decode(bad))
        XCTAssertNil(Mnemonic.decode(Array(words.dropLast())))
        XCTAssertNil(Mnemonic.decode(words.map { _ in "notaword" }))
    }

    func testParseIgnoresNumbersAndCase() {
        let parsed = Mnemonic.parse("1. Abandon  2) ability\n3 able")
        XCTAssertEqual(parsed, ["abandon", "ability", "able"])
    }

    func testRecoverySurvivesPasswordChange() throws {
        let key = try Vault.enable(password: .of("first"))
        let words = try Vault.createRecovery(for: key)
        XCTAssertTrue(Vault.hasRecovery)
        XCTAssertNotNil(Vault.unlockWithRecovery(words: words))

        // change password: enable() drops the block, rewrap restores it for the new key
        let oldRec = Vault.currentRecovery
        let key2 = try Vault.enable(password: .of("second"))
        XCTAssertFalse(Vault.hasRecovery)
        XCTAssertTrue(try Vault.rewrapRecovery(from: key, to: key2, oldRecovery: oldRec))
        let recovered = Vault.unlockWithRecovery(words: words)
        XCTAssertNotNil(recovered)
        XCTAssertTrue(Vault.verify(recovered!))
        XCTAssertNil(Vault.unlockWithRecovery(words: words.reversed()))
    }
}
