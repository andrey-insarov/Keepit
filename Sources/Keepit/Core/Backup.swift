import Foundation

/// Export / import of history and templates as one password-protected file (`.keepit`).
///
/// Layout: `KEEPITBK` · format version (1 byte) · 16-byte PBKDF2 salt · Vault.encrypt(LZFSE(JSON)).
/// Format 1 implies PBKDF2-HMAC-SHA256 with exactly 200 000 rounds (`v1Rounds`); format 2 carries its KDF parameters.
/// The password is independent of the vault password, so a backup can be moved to a Mac
/// where protection is off (or on with a different password).
enum Backup {
    static let fileExtension = "keepit"
    static let formatVersion: UInt8 = 1
    /// Format 1 derives the key with exactly this many PBKDF2 rounds — a literal, not
    /// `Vault.defaultRounds`: raising the vault default must never change how v1 files are read.
    /// The complete format is in docs/FORMAT.md.
    static let v1Rounds: UInt32 = 200_000
    private static let magic = Data("KEEPITBK".utf8)
    private static let saltSize = 16

    struct Payload: Codable {
        var version: Int = 1
        var created: Date = Date()
        var app: String = "Keepit \(AppInfo.version)"
        var history: [ClipItem]
        var templates: TemplateNode
        var settings: Settings?
    }

    enum Failure: Error, Equatable {
        case notABackup, unsupportedVersion(UInt8), tooLarge, wrongPassword, corrupt
    }

    static func suggestedFileName(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "Keepit-backup-\(f.string(from: date)).\(fileExtension)"
    }

    // MARK: Encode / decode

    static func encode(_ payload: Payload, password: SecureBuffer) throws -> Data {
        let json = try Storage.encoder.encode(payload)
        let packed = try (json as NSData).compressed(using: .lzfse) as Data
        let salt = try Vault.randomBytes(saltSize)
        let key = try Vault.deriveKey(password: password, salt: salt, rounds: v1Rounds)
        defer { key.zero() }
        let sealed = try Vault.encrypt(packed, key: key)
        return magic + Data([formatVersion]) + salt + sealed
    }

    static func isBackup(_ data: Data) -> Bool {
        data.count > magic.count + 1 + saltSize && data.prefix(magic.count) == magic
    }

    static func decode(_ data: Data, password: SecureBuffer) throws -> Payload {
        guard isBackup(data) else { throw Failure.notABackup }
        guard data.count <= Limits.dataFileMaxBytes else { throw Failure.tooLarge }
        let version = data[data.startIndex + magic.count]
        guard version == formatVersion else { throw Failure.unsupportedVersion(version) }
        let saltStart = data.startIndex + magic.count + 1
        let salt = data[saltStart ..< saltStart + saltSize]
        let sealed = data[(saltStart + saltSize)...]
        guard let key = try? Vault.deriveKey(password: password, salt: Data(salt), rounds: v1Rounds) else { throw Failure.corrupt }
        defer { key.zero() }
        guard let packed = try? Vault.decrypt(Data(sealed), key: key) else { throw Failure.wrongPassword }
        guard let json = try? (packed as NSData).decompressed(using: .lzfse) as Data,
              json.count <= Limits.dataFileMaxBytes else { throw Failure.corrupt }
        do {
            return try Storage.decoder.decode(Payload.self, from: json)
        } catch {
            throw Failure.corrupt
        }
    }
}
