import CryptoKit
import XCTest
@testable import Keepit
@testable import KeepitCore

/// Opens every reference file in Fixtures/ — written by Scripts/make_fixtures.py, an independent
/// Python implementation of docs/FORMAT.md — and checks the outcome its sidecar promises.
/// The fixtures are committed; this test never regenerates them.
final class FixtureTests: XCTestCase {
    static let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures", isDirectory: true)

    struct Sidecar: Decodable {
        var format: Int?
        var password: String
        var outcome: String
        var history: Int?
        var templateNodes: Int?
        var settings: Bool?
        var texts: [String]?
        var kinds: [String]?
        var sourceApps: [String?]?
        var formatCounts: [Int]?
        var pngBytes: [Int]?
        var filePaths: [[String]]?
        var templatePaths: [String]?
        var hotKeys: [String: [UInt32]]?
        var historyMax: Int?
        var historyImageMax: Int?
        var menuMaxItems: Int?
        var formatHashes: [[String: String]]?
        var mode: String?
        var recoveryEntropyHex: String?
        var dataKeyHex: String?
        var label: String?
        var minReader: String?
        var payloadVersion: Int?
    }

    private func bytes(_ hex: String) -> [UInt8] {
        stride(from: 0, to: hex.count, by: 2).map { i in
            let a = hex.index(hex.startIndex, offsetBy: i)
            return UInt8(hex[a ..< hex.index(a, offsetBy: 2)], radix: 16)!
        }
    }

    private func fixtures() throws -> [(name: String, data: Data, side: Sidecar)] {
        let files = try FileManager.default.contentsOfDirectory(at: Self.dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "keepit" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertGreaterThanOrEqual(files.count, 24, "fixtures missing — run Scripts/make_fixtures.py")
        return try files.map { url in
            let side = try JSONDecoder().decode(Sidecar.self, from: Data(contentsOf: url.deletingPathExtension().appendingPathExtension("json")))
            return (url.deletingPathExtension().lastPathComponent, try Data(contentsOf: url), side)
        }
    }

    private func paths(_ node: TemplateNode, prefix: String = "") -> [String] {
        node.children.flatMap { c -> [String] in
            let p = prefix.isEmpty ? c.name : prefix + "/" + c.name
            return [p] + paths(c, prefix: p)
        }
    }

    func testEveryFixtureBehavesAsItsSidecarSays() throws {
        for f in try fixtures() {
            let pw = SecureBuffer.of(f.side.password)
            defer { pw.zero() }
            switch f.side.outcome {
            case "ok":
                let p: Backup.Payload
                do { p = try Backup.decode(f.data, password: pw) } catch { XCTFail("\(f.name): \(error)"); continue }
                XCTAssertEqual(p.version, 1, f.name)
                XCTAssertEqual(try Backup.inspect(f.data).format, UInt8(f.side.format ?? 0), "\(f.name) container format")
                if case .v2(let h, _) = try Backup.inspect(f.data) {
                    XCTAssertEqual(h.mode.rawValue, f.side.mode, "\(f.name) mode")
                    XCTAssertEqual(h.label, f.side.label, "\(f.name) label")
                }
                // auto files also open with the data key and with the recovery phrase's entropy, no vault.json involved
                if let hex = f.side.dataKeyHex {
                    let keyBytes = bytes(hex)
                    let sk = keyBytes.withUnsafeBytes { SecureKey(bytes: $0) }
                    defer { sk.zero() }
                    XCTAssertEqual(try Backup.decode(f.data, dataKey: sk).history.count, p.history.count, "\(f.name) via data key")
                }
                if let hex = f.side.recoveryEntropyHex {
                    XCTAssertEqual(try Backup.decode(f.data, recoveryEntropy: bytes(hex)).history.count, p.history.count, "\(f.name) via recovery entropy")
                    XCTAssertThrowsError(try Backup.decode(f.data, recoveryEntropy: [UInt8](repeating: 7, count: 32)), "\(f.name) wrong entropy")
                }
                if let n = f.side.history { XCTAssertEqual(p.history.count, n, "\(f.name) history count") }
                if let n = f.side.templateNodes { XCTAssertEqual(p.templates.subtreeCount, n, "\(f.name) template nodes") }
                if let s = f.side.settings { XCTAssertEqual(p.settings != nil, s, "\(f.name) settings presence") }
                if let t = f.side.texts { XCTAssertEqual(p.history.map { $0.plainText }, t, f.name) }
                if let k = f.side.kinds { XCTAssertEqual(p.history.map { $0.kind.rawValue }, k, f.name) }
                if let s = f.side.sourceApps { XCTAssertEqual(p.history.map { $0.sourceApp }, s, f.name) }
                if let c = f.side.formatCounts { XCTAssertEqual(p.history.map { $0.formats.count }, c, f.name) }
                if let b = f.side.pngBytes { XCTAssertEqual(p.history.map { $0.formats[ClipItem.Format.png]?.count ?? 0 }, b, f.name) }
                if let fp = f.side.filePaths { XCTAssertEqual(p.history.map { $0.filePaths }, fp, f.name) }
                if let fh = f.side.formatHashes {
                    XCTAssertEqual(p.history.map { $0.formats.mapValues { ClipItem.hash(of: $0) } }, fh, "\(f.name) exact bytes of every format")
                }
                if let tp = f.side.templatePaths { XCTAssertEqual(paths(p.templates), tp, f.name) }
                if let hk = f.side.hotKeys {
                    for (name, key) in hk {
                        let node = p.templates.children.first { $0.name == name }
                        XCTAssertEqual(node?.hotKey.map { [$0.keyCode, $0.modifiers] }, key, "\(f.name) hot key of \(name)")
                    }
                }
                if let v = f.side.historyMax { XCTAssertEqual(p.settings?.historyMax, v, f.name) }
                if let v = f.side.historyImageMax { XCTAssertEqual(p.settings?.historyImageMax, v, f.name) }
                if let v = f.side.menuMaxItems { XCTAssertEqual(p.settings?.menuMaxItems, v, f.name) }
                // Every item's hash must match the rule in FORMAT.md (primary format's SHA-256).
                for item in p.history {
                    let primary = item.formats[ClipItem.Format.files] ?? item.formats[ClipItem.Format.text] ?? item.formats[ClipItem.Format.png] ?? item.formats.values.first!
                    XCTAssertEqual(item.contentHash, ClipItem.hash(of: primary), "\(f.name) contentHash")
                }
            case "wrongPassword":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) { XCTAssertEqual($0 as? Backup.Failure, .wrongPassword, f.name) }
            case "corruptOrWrongPassword":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) {
                    let e = $0 as? Backup.Failure
                    XCTAssertTrue(e == .corrupt || e == .wrongPassword, "\(f.name): \(String(describing: e))")
                }
            case "needsNewerKeepit":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) { XCTAssertEqual($0 as? Backup.Failure, .needsNewerKeepit(f.side.minReader ?? ""), f.name) }
            case "corrupt":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) { XCTAssertEqual($0 as? Backup.Failure, .corrupt, f.name) }
            case "invalidContent":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) {
                    if case .invalidContent = ($0 as? Backup.Failure) {} else { XCTFail("\(f.name): \($0)") }
                }
            case "unsupportedPayloadVersion":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) { XCTAssertEqual($0 as? Backup.Failure, .unsupportedPayloadVersion(f.side.payloadVersion ?? 0), f.name) }
            case "notABackup":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) { XCTAssertEqual($0 as? Backup.Failure, .notABackup, f.name) }
            case "unsupportedVersion":
                XCTAssertThrowsError(try Backup.decode(f.data, password: pw), f.name) { XCTAssertEqual($0 as? Backup.Failure, .unsupportedVersion(UInt8(f.side.format ?? 0)), f.name) }
            default:
                XCTFail("\(f.name): unknown outcome \(f.side.outcome)")
            }
        }
    }

    /// The fixtures are the reference: Swift must round-trip them, but what Swift writes is not what
    /// the fixtures are — this guards against someone "fixing" a failure by regenerating them.
    func testFixturesWereNotWrittenBySwift() throws {
        for f in try fixtures() where f.side.outcome == "ok" {
            let p = try Backup.decode(f.data, password: SecureBuffer.of(f.side.password))
            XCTAssertTrue(p.app.contains("make_fixtures.py"), "\(f.name) was not produced by the independent generator")
        }
    }
}
