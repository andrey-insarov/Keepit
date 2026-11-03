import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Key derivation used by the .keepit format and by the vault (docs/FORMAT.md).
public enum KDF {
    public static let pbkdf2Name = "pbkdf2-hmac-sha256"
    /// Accepted range for a round count read from a file or vault.json: below is not something
    /// Keepit wrote, above would make opening take hours.
    public static let roundsRange: ClosedRange<UInt32> = 1_000 ... 5_000_000
    public static let keyBytes = 32

    public enum Failure: Error, Equatable {
        case derivation(Int32)
        case roundsOutOfRange(UInt32)
        case randomBytes(Int32)
    }

    /// PBKDF2-HMAC-SHA256 over the exact password bytes. The derived key is handed to `body` as
    /// raw bytes and wiped afterwards, so the caller decides how long a copy lives.
    public static func pbkdf2<T>(password: UnsafeRawBufferPointer, salt: Data, rounds: UInt32,
                                 _ body: (UnsafeRawBufferPointer) throws -> T) throws -> T {
        guard roundsRange.contains(rounds) else { throw Failure.roundsOutOfRange(rounds) }
        var out = [UInt8](repeating: 0, count: keyBytes)
        defer { out.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        let status: Int32 = salt.withUnsafeBytes { saltPtr in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                 password.baseAddress?.assumingMemoryBound(to: CChar.self), password.count,
                                 saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                                 &out, out.count)
        }
        guard status == Int32(kCCSuccess) else { throw Failure.derivation(status) }
        return try out.withUnsafeBytes { try body($0) }
    }

    /// The file key of an automatic backup, derived from the vault's data key. Never the data key itself.
    public static func backupKey(dataKey: SymmetricKey) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: dataKey, salt: Data(), info: Data("keepit-backup-v2".utf8), outputByteCount: keyBytes)
    }

    /// The key that wraps the data key for the recovery phrase (same derivation as vault.json's).
    public static func recoveryKey(entropy: [UInt8], salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(entropy)), salt: salt, info: Data("keepit-recovery-v1".utf8), outputByteCount: keyBytes)
    }

    /// Cryptographically random bytes; throws instead of returning zeros if the system RNG refuses.
    public static func randomBytes(_ count: Int) throws -> Data {
        var d = Data(count: count)
        let status = d.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw Failure.randomBytes(status) }
        return d
    }
}

/// The small sealed blob used inside vault.json and by format 1: `"KEEPITENC1"` + AES-GCM combined
/// (nonce 12 | ciphertext | tag 16), no additional data.
public enum SealedBlob {
    public static let magic = Data("KEEPITENC1".utf8)

    public static func seal(_ plain: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.seal(plain, using: key)
        guard let combined = box.combined else { throw CocoaError(.coderInvalidValue) }
        return magic + combined
    }

    public static func isSealed(_ data: Data) -> Bool {
        data.count > magic.count && data.prefix(magic.count) == magic
    }

    public static func open(_ data: Data, key: SymmetricKey) throws -> Data {
        guard isSealed(data) else { return data }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(magic.count))
        return try AES.GCM.open(box, using: key)
    }
}
