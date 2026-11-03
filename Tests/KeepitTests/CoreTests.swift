import CryptoKit
import XCTest
@testable import Keepit
@testable import KeepitCore

final class CoreTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    func testLZFSERoundTripAndStreamingLimit() throws {
        let plain = Data(String(repeating: "keepit ", count: 100_000).utf8)      // 700 KB, compresses well
        let packed = try LZFSE.compress(plain)
        XCTAssertLessThan(packed.count, plain.count / 10)
        XCTAssertEqual(try LZFSE.decompress(packed, limit: plain.count), plain)
        XCTAssertThrowsError(try LZFSE.decompress(packed, limit: 100_000)) { XCTAssertEqual($0 as? LZFSE.Failure, .tooLarge) }
        XCTAssertThrowsError(try LZFSE.decompress(Data([1, 2, 3]), limit: 10)) { XCTAssertEqual($0 as? LZFSE.Failure, .corrupt) }
        // Must match what NSData writes (format 1 files were written that way).
        let apple = try (plain as NSData).compressed(using: .lzfse) as Data
        XCTAssertEqual(try LZFSE.decompress(apple, limit: plain.count), plain)
        XCTAssertEqual(try (packed as NSData).decompressed(using: .lzfse) as Data, plain)
    }

    func testVersionComparison() {
        XCTAssertTrue(Container.versionLess("3.0", than: "3.0.1"))
        XCTAssertTrue(Container.versionLess("3.0.9", than: "3.1"))
        XCTAssertTrue(Container.versionLess("9.9", than: "10.0"))
        XCTAssertFalse(Container.versionLess("3.0.0", than: "3.0"))
        XCTAssertFalse(Container.versionLess("3.1", than: "3.0.5"))
    }

    func testHeaderIsAuthenticated() throws {
        let key = SymmetricKey(size: .bits256)
        let header = Container.Header(mode: .manual, rounds: 1_000, salt: Data(repeating: 1, count: 16), app: "test", label: "abc")
        let file = try Container.sealV2(payload: Data("{\"version\":1}".utf8), header: header, key: key)
        let insp = try Container.inspect(file, readerVersion: "3.0.0", maxBytes: 1 << 20)
        XCTAssertEqual(try Container.openV2(file, inspection: insp, key: key, limit: 1 << 20), Data("{\"version\":1}".utf8))
        // Flip one byte inside the header (the label), keep JSON valid: header parses, GCM refuses.
        var t = file
        let range = t.range(of: Data("abc".utf8))!
        t[range.lowerBound] = UInt8(ascii: "x")
        let tinsp = try Container.inspect(t, readerVersion: "3.0.0", maxBytes: 1 << 20)
        XCTAssertThrowsError(try Container.openV2(t, inspection: tinsp, key: key, limit: 1 << 20)) {
            XCTAssertEqual($0 as? Container.Failure, .wrongKeyOrCorrupt)
        }
        // Wrong key → same error (indistinguishable by design).
        XCTAssertThrowsError(try Container.openV2(file, inspection: insp, key: SymmetricKey(size: .bits256), limit: 1 << 20))
    }

    func testInspectRejectsBeforeAnyKeyWork() throws {
        let key = SymmetricKey(size: .bits256)
        let bad = Container.Header(mode: .manual, rounds: 10, salt: Data(repeating: 1, count: 16), app: "t")
        XCTAssertThrowsError(try Container.sealV2(payload: Data("{}".utf8), header: bad, key: key)) {
            XCTAssertEqual($0 as? Container.Failure, .roundsOutOfRange(10))
        }
        let future = Container.Header(mode: .manual, rounds: 1_000, salt: Data(repeating: 1, count: 16), app: "t", minReader: "42.0")
        let file = try Container.sealV2(payload: Data("{}".utf8), header: future, key: key)
        XCTAssertThrowsError(try Container.inspect(file, readerVersion: "3.0", maxBytes: 1 << 20)) {
            XCTAssertEqual($0 as? Container.Failure, .needsNewerReader("42.0"))
        }
        XCTAssertThrowsError(try Container.inspect(Data("hello".utf8), readerVersion: "3.0", maxBytes: 1 << 20)) {
            XCTAssertEqual($0 as? Container.Failure, .notAContainer)
        }
        XCTAssertThrowsError(try Container.inspect(file, readerVersion: "3.0", maxBytes: 10)) {
            XCTAssertEqual($0 as? Container.Failure, .tooLarge)
        }
    }

    func testAutomaticBackupOpensWithPasswordDataKeyAndPhrase() throws {
        // A vault with a recovery phrase, as the app would have it.
        let key = try Vault.enable(password: .of("vault pw"))
        let words = try Vault.createRecovery(for: key)
        let header = try XCTUnwrap(Vault.backupHeader(app: "Keepit test", label: "Mac", sourceID: "s", backupID: "b"))
        XCTAssertEqual(header.mode, .auto)
        XCTAssertNotNil(header.recovery)

        let payload = Backup.Payload(history: [.text("auto one"), .text("auto two")], templates: TemplateNode(name: "Template"), settings: nil)
        let file = try Backup.encodeAutomatic(payload, dataKey: key, vault: header)

        XCTAssertEqual(try Backup.decode(file, password: .of("vault pw")).history.map(\.plainText), ["auto one", "auto two"])
        XCTAssertEqual(try Backup.decode(file, dataKey: key).history.count, 2)
        let entropy = try XCTUnwrap(Mnemonic.decode(words))
        XCTAssertEqual(try Backup.decode(file, recoveryEntropy: entropy).history.count, 2)
        XCTAssertThrowsError(try Backup.decode(file, password: .of("other"))) { XCTAssertEqual($0 as? Backup.Failure, .wrongPassword) }
        // The data key never is the file key: sealing with it directly would not open.
        let direct = try key.withKey { k in try Container.sealV2(payload: Data("{\"version\":1,\"history\":[],\"templates\":{\"id\":\"00000000-0000-0000-0000-000000000000\",\"name\":\"\",\"children\":[]},\"created\":\"2026-01-01T00:00:00Z\",\"app\":\"x\"}".utf8), header: header, key: k) }
        XCTAssertThrowsError(try Backup.decode(direct, dataKey: key))
    }

    func testExportWritesFormat2ManualAndReadsFormat1() throws {
        let payload = Backup.Payload(history: [.text("m")], templates: TemplateNode(name: "Template"), settings: nil)
        let file = try Backup.encode(payload, password: .of("file pw"))
        XCTAssertEqual(file[8], 2)
        guard case .v2(let h, _) = try Backup.inspect(file) else { return XCTFail("not v2") }
        XCTAssertEqual(h.mode, .manual)
        XCTAssertNil(h.recovery)
        XCTAssertEqual(h.minReader, Backup.minReader)
        XCTAssertEqual(try Backup.decode(file, password: .of("file pw")).history.first?.plainText, "m")
        XCTAssertThrowsError(try Backup.decode(file, dataKey: try Vault.enable(password: .of("x")))) // manual files have no auto key
    }

    func testRestoreNeverTakesTrustSettings() {
        var mine = Settings()
        mine.allowURLCommands = false; mine.trustedURLSenders = []; mine.biometricUnlock = true; mine.historyMax = 10
        var theirs = Settings()
        theirs.allowURLCommands = true; theirs.trustedURLSenders = ["com.evil"]; theirs.biometricUnlock = false; theirs.historyMax = 999
        let merged = mine.applyingRestorable(from: theirs)
        XCTAssertEqual(merged.historyMax, 999)
        XCTAssertFalse(merged.allowURLCommands)
        XCTAssertEqual(merged.trustedURLSenders, [])
        XCTAssertTrue(merged.biometricUnlock)
    }

    func testUnsealedBodyIsRefused() throws {
        // "KEEPITBK" | 1 | salt | LZFSE(json) — no KEEPITENC1, no nonce, no tag.
        let json = Data("{\"version\":1,\"history\":[],\"templates\":{\"id\":\"00000000-0000-0000-0000-000000000000\",\"name\":\"T\",\"children\":[]},\"created\":\"2026-01-01T00:00:00Z\",\"app\":\"x\"}".utf8)
        let file = Container.magic + Data([1]) + Data(repeating: 9, count: 16) + (try LZFSE.compress(json))
        XCTAssertThrowsError(try Backup.decode(file, password: .of("anything"))) { XCTAssertEqual($0 as? Backup.Failure, .corrupt) }
        XCTAssertThrowsError(try SealedBlob.open(Data("plain".utf8), key: SymmetricKey(size: .bits256))) {
            XCTAssertEqual($0 as? SealedBlob.Failure, .notSealed)
        }
    }

    func testContentIsValidatedBeforeReturn() throws {
        func file(_ p: Backup.Payload) throws -> Data { try Backup.encode(p, password: .of("p")) }
        func expectInvalid(_ p: Backup.Payload, _ what: String, line: UInt = #line) {
            XCTAssertThrowsError(try Backup.decode(try file(p), password: .of("p")), what, line: line) {
                if case .invalidContent = ($0 as? Backup.Failure) {} else { XCTFail("\(what): \($0)", line: line) }
            }
        }
        let root = { TemplateNode(name: "Template") }
        // template name over the limit
        expectInvalid(Backup.Payload(history: [], templates: TemplateNode(name: "Template", children: [TemplateNode(name: String(repeating: "n", count: Limits.templateNameMaxChars + 1), text: "t")]), settings: nil), "long name")
        // item without formats
        expectInvalid(Backup.Payload(history: [ClipItem(id: UUID(), date: Date(), formats: [:], sourceApp: nil, contentHash: "")], templates: root(), settings: nil), "no formats")
        // wrong contentHash
        expectInvalid(Backup.Payload(history: [ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.text: Data("a".utf8)], sourceApp: nil, contentHash: String(repeating: "0", count: 64))], templates: root(), settings: nil), "bad hash")
        // duplicate ids
        let dup = ClipItem.text("same")
        expectInvalid(Backup.Payload(history: [dup, dup], templates: root(), settings: nil), "duplicate id")
        // too deep
        var deep = TemplateNode(name: "leaf", text: "x")
        for i in 0 ..< (Limits.templateMaxDepth + 1) { deep = TemplateNode(name: "d\(i)", children: [deep]) }
        expectInvalid(Backup.Payload(history: [], templates: TemplateNode(name: "Template", children: [deep]), settings: nil), "too deep")
        // a good one still opens
        XCTAssertNoThrow(try Backup.decode(try file(Backup.Payload(history: [.text("ok")], templates: root(), settings: nil)), password: .of("p")))
    }

    func testReaderVersionMatchesVERSIONFile() throws {
        let versionFile = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("VERSION")
        let v = try String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(Backup.readerVersion, v, "Backup.readerVersion must be bumped with VERSION")
        XCTAssertFalse(Container.versionLess(Backup.readerVersion, than: Backup.minReader), "this build must read its own exports")
        // What Export… writes must open with this reader — without going through the test host's bundle version.
        let f = try Backup.encode(Backup.Payload(history: [], templates: TemplateNode(name: "T"), settings: nil), password: .of("p"))
        XCTAssertNoThrow(try Backup.inspect(f))
    }
}
