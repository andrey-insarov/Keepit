import CryptoKit
import Foundation

/// The `.keepit` container — docs/FORMAT.md is the contract, this file implements it.
///
/// Format 1 (Keepit 2.x):  "KEEPITBK" | 0x01 | salt(16) | SealedBlob(LZFSE(payload))
/// Format 2 (Keepit 3.0):  "KEEPITBK" | 0x02 | headerLength(4, BE) | header(JSON) | nonce(12) | ciphertext | tag(16)
///                          with the header bytes as the GCM additional authenticated data.
///
/// This layer moves bytes: it knows nothing about ClipItems or templates. The payload is opaque
/// JSON to it; the app's model layer encodes and decodes that.
public enum Container {
    public static let magic = Data("KEEPITBK".utf8)
    public static let maxHeaderBytes = 65_536
    public static let saltBytes = 16
    public static let nonceBytes = 12
    public static let tagBytes = 16
    /// Round count written into new files (format 1 is fixed at this value; format 2 writes it into the header).
    public static let defaultRounds: UInt32 = 200_000
    public static let v1Rounds: UInt32 = 200_000

    public enum Mode: String, Codable { case auto, manual }

    /// The recovery block, byte-compatible with the one in vault.json.
    public struct Recovery: Codable, Equatable {
        public var salt: Data
        public var wrappedKey: Data
        public var wrappedEntropy: Data
        public init(salt: Data, wrappedKey: Data, wrappedEntropy: Data) {
            self.salt = salt; self.wrappedKey = wrappedKey; self.wrappedEntropy = wrappedEntropy
        }
    }

    public struct Header: Codable, Equatable {
        public var mode: Mode
        public var kdf: String
        public var rounds: UInt32
        public var salt: Data
        public var recovery: Recovery?
        public var created: Date
        public var app: String
        public var minReader: String
        public var label: String?
        public var sourceID: String?
        public var backupID: String?

        public init(mode: Mode, kdf: String = KDF.pbkdf2Name, rounds: UInt32, salt: Data, recovery: Recovery? = nil,
                    created: Date = Date(), app: String, minReader: String = "3.0",
                    label: String? = nil, sourceID: String? = nil, backupID: String? = nil) {
            self.mode = mode; self.kdf = kdf; self.rounds = rounds; self.salt = salt; self.recovery = recovery
            self.created = created; self.app = app; self.minReader = minReader
            self.label = label; self.sourceID = sourceID; self.backupID = backupID
        }
    }

    public enum Failure: Error, Equatable {
        case notAContainer
        case unsupportedFormat(UInt8)
        case needsNewerReader(String)
        case malformedHeader
        case unsupportedKDF(String)
        case roundsOutOfRange(UInt32)
        case tooLarge
        /// Authentication failed: wrong key or damaged file — indistinguishable by design.
        case wrongKeyOrCorrupt
        case corrupt
    }

    /// What a reader learns before any key exists.
    public enum Inspection: Equatable {
        case v1(salt: Data)
        case v2(header: Header, headerBytes: Data)

        public var format: UInt8 { if case .v1 = self { return 1 } else { return 2 } }
    }

    public static func isContainer(_ data: Data) -> Bool {
        data.count > magic.count + 1 && data.prefix(magic.count) == magic
    }

    // MARK: Inspect

    /// Parse what can be parsed without a key, enforcing every limit on the way. `readerVersion`
    /// (e.g. "3.0.1") is compared with the header's `minReader`.
    public static func inspect(_ data: Data, readerVersion: String, maxBytes: Int) throws -> Inspection {
        guard isContainer(data) else { throw Failure.notAContainer }
        guard data.count <= maxBytes else { throw Failure.tooLarge }
        let format = data[data.startIndex + magic.count]
        switch format {
        case 1:
            let saltStart = data.startIndex + magic.count + 1
            guard data.count >= magic.count + 1 + saltBytes + SealedBlob.magic.count + nonceBytes + tagBytes else { throw Failure.corrupt }
            return .v1(salt: Data(data[saltStart ..< saltStart + saltBytes]))
        case 2:
            var i = data.startIndex + magic.count + 1
            guard data.count - (i - data.startIndex) >= 4 else { throw Failure.corrupt }
            let hl = data[i ..< i + 4].reduce(0) { ($0 << 8) | Int($1) }
            i += 4
            guard hl > 0, hl <= maxHeaderBytes, data.count - (i - data.startIndex) >= hl + nonceBytes + tagBytes else { throw Failure.malformedHeader }
            let headerBytes = Data(data[i ..< i + hl])
            let header: Header
            do { header = try decoder.decode(Header.self, from: headerBytes) } catch { throw Failure.malformedHeader }
            try validate(header)
            if versionLess(readerVersion, than: header.minReader) { throw Failure.needsNewerReader(header.minReader) }
            return .v2(header: header, headerBytes: headerBytes)
        default:
            throw Failure.unsupportedFormat(format)
        }
    }

    private static func validate(_ h: Header) throws {
        guard h.kdf == KDF.pbkdf2Name else { throw Failure.unsupportedKDF(h.kdf) }
        guard KDF.roundsRange.contains(h.rounds) else { throw Failure.roundsOutOfRange(h.rounds) }
        guard h.salt.count == saltBytes else { throw Failure.malformedHeader }
        if let r = h.recovery {
            guard r.salt.count <= 256, r.wrappedKey.count <= 256, r.wrappedEntropy.count <= 256 else { throw Failure.malformedHeader }
        }
        if let l = h.label, l.count > 64 { throw Failure.malformedHeader }
    }

    /// "3.0" < "3.0.1" < "3.1" < "10.0"; missing components are zero.
    static func versionLess(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0 ..< max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    // MARK: Write (format 2)

    /// Seal `payload` (JSON bytes) into a format-2 file. The header is serialised once and those
    /// exact bytes are both written and authenticated.
    public static func sealV2(payload: Data, header: Header, key: SymmetricKey) throws -> Data {
        try validate(header)
        let headerBytes = try encoder.encode(header)
        guard headerBytes.count <= maxHeaderBytes else { throw Failure.malformedHeader }
        let packed = try LZFSE.compress(payload)
        let box = try AES.GCM.seal(packed, using: key, authenticating: headerBytes)
        var out = Data(capacity: magic.count + 1 + 4 + headerBytes.count + nonceBytes + box.ciphertext.count + tagBytes)
        out.append(magic)
        out.append(2)
        let hl = UInt32(headerBytes.count)
        out.append(contentsOf: [UInt8(hl >> 24), UInt8((hl >> 16) & 0xff), UInt8((hl >> 8) & 0xff), UInt8(hl & 0xff)])
        out.append(headerBytes)
        out.append(contentsOf: box.nonce)
        out.append(box.ciphertext)
        out.append(box.tag)
        return out
    }

    // MARK: Read

    /// Open a format-2 file with the file key (manual: PBKDF2 of the file password; auto: `KDF.backupKey`
    /// of the data key). Returns the decompressed payload, never more than `limit` bytes.
    public static func openV2(_ data: Data, inspection: Inspection, key: SymmetricKey, limit: Int) throws -> Data {
        guard case .v2(_, let headerBytes) = inspection else { throw Failure.corrupt }
        let bodyStart = data.startIndex + magic.count + 1 + 4 + headerBytes.count
        let body = data[bodyStart...]
        guard body.count >= nonceBytes + tagBytes else { throw Failure.corrupt }
        let nonce = try AES.GCM.Nonce(data: body.prefix(nonceBytes))
        let ciphertext = body.dropFirst(nonceBytes).dropLast(tagBytes)
        let tag = body.suffix(tagBytes)
        let packed: Data
        do {
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            packed = try AES.GCM.open(box, using: key, authenticating: headerBytes)
        } catch { throw Failure.wrongKeyOrCorrupt }
        return try decompress(packed, limit: limit)
    }

    /// Open a format-1 file with the key derived by PBKDF2(password, salt, `v1Rounds`).
    public static func openV1(_ data: Data, key: SymmetricKey, limit: Int) throws -> Data {
        let sealed = data[(data.startIndex + magic.count + 1 + saltBytes)...]
        let packed: Data
        do { packed = try SealedBlob.open(Data(sealed), key: key) } catch { throw Failure.wrongKeyOrCorrupt }
        return try decompress(packed, limit: limit)
    }

    private static func decompress(_ packed: Data, limit: Int) throws -> Data {
        do { return try LZFSE.decompress(packed, limit: limit) } catch LZFSE.Failure.tooLarge { throw Failure.tooLarge } catch { throw Failure.corrupt }
    }

    // MARK: Recovery

    /// The data key wrapped in `block`, unwrapped with the recovery phrase's entropy. Works on a
    /// block taken from a file's header — no vault.json involved. nil if the entropy does not fit.
    public static func unwrapDataKey(entropy: [UInt8], recovery block: Recovery) -> SymmetricKey? {
        let rkey = KDF.recoveryKey(entropy: entropy, salt: block.salt)
        guard var keyBytes = try? SealedBlob.open(block.wrappedKey, key: rkey), keyBytes.count == KDF.keyBytes else { return nil }
        defer { keyBytes.resetBytes(in: 0 ..< keyBytes.count) }
        return SymmetricKey(data: keyBytes)
    }

    // MARK: Codecs

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
