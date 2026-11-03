import CryptoKit
import Foundation
import KeepitCore

/// Export / import of history and templates as one password-protected file (`.keepit`).
///
/// The bytes are KeepitCore's job (`Container`, docs/FORMAT.md); this type is the model layer:
/// it turns the app's history, templates and settings into the payload JSON and back, decides
/// which key opens a file, and enforces the 3.0 reader rules (payload version, limits).
///
/// Writing: format 2, mode `manual` (a password for this file). Mode `auto` files are written by
/// the automatic backup (3.0, stage 3) with the vault's data key. Reading: formats 1 and 2, both
/// modes, with a password, the current data key, or the recovery phrase's entropy.
enum Backup {
    static let fileExtension = "keepit"
    /// Container format written by Export… (format 1 is read, never written, since 3.0).
    static let formatVersion: UInt8 = 2
    static let payloadVersion = 1
    /// Lowest Keepit that can read what this version writes.
    static let minReader = "3.0"
    /// Format 1 derives the key with exactly this many PBKDF2 rounds (docs/FORMAT.md).
    static let v1Rounds: UInt32 = Container.v1Rounds

    struct Payload: Codable {
        var version: Int = Backup.payloadVersion
        var created: Date = Date()
        var app: String = "Keepit \(AppInfo.version)"
        var history: [ClipItem]
        var templates: TemplateNode
        var settings: Settings?
    }

    enum Failure: Error, Equatable {
        case notABackup, unsupportedVersion(UInt8), needsNewerKeepit(String), unsupportedPayloadVersion(Int)
        case tooLarge, wrongPassword, corrupt
    }

    static func suggestedFileName(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "Keepit-backup-\(f.string(from: date)).\(fileExtension)"
    }

    static func isBackup(_ data: Data) -> Bool { Container.isContainer(data) }

    // MARK: Encode

    /// Format 2, mode `manual`: fresh salt, `Container.defaultRounds`, the given password.
    static func encode(_ payload: Payload, password: SecureBuffer) throws -> Data {
        let json = try Storage.encoder.encode(payload)
        let salt = try KDF.randomBytes(Container.saltBytes)
        let header = Container.Header(mode: .manual, rounds: Container.defaultRounds, salt: salt,
                                      created: payload.created, app: payload.app, minReader: minReader)
        return try password.withBytes { pw in
            try KDF.pbkdf2(password: pw, salt: salt, rounds: header.rounds) { keyBytes in
                try Container.sealV2(payload: json, header: header, key: SymmetricKey(data: keyBytes))
            }
        }
    }

    /// Format 2, mode `auto`: sealed with the backup key derived from the vault's data key; the
    /// header carries the vault's KDF parameters and recovery block so the same password — or the
    /// phrase — opens it anywhere.
    static func encodeAutomatic(_ payload: Payload, dataKey: SecureKey, vault: Container.Header) throws -> Data {
        let json = try Storage.encoder.encode(payload)
        return try dataKey.withKey { k in
            try Container.sealV2(payload: json, header: vault, key: KDF.backupKey(dataKey: k))
        }
    }

    // MARK: Decode

    /// What can be known about a file before it is opened.
    static func inspect(_ data: Data) throws -> Container.Inspection {
        do {
            return try Container.inspect(data, readerVersion: AppInfo.version, maxBytes: Limits.dataFileMaxBytes)
        } catch let e as Container.Failure {
            throw map(e)
        }
    }

    /// Open with a password: the file password (manual, format 1) or the vault password of the
    /// installation that wrote it (auto).
    static func decode(_ data: Data, password: SecureBuffer) throws -> Payload {
        let insp = try inspect(data)
        switch insp {
        case .v1(let salt):
            return try password.withBytes { pw in
                try KDF.pbkdf2(password: pw, salt: salt, rounds: v1Rounds) { keyBytes in
                    try open(data, insp, key: SymmetricKey(data: keyBytes))
                }
            }
        case .v2(let header, _):
            return try password.withBytes { pw in
                try KDF.pbkdf2(password: pw, salt: header.salt, rounds: header.rounds) { keyBytes -> Payload in
                    let derived = SymmetricKey(data: keyBytes)
                    let fileKey = header.mode == .auto ? KDF.backupKey(dataKey: derived) : derived
                    return try open(data, insp, key: fileKey)
                }
            }
        }
    }

    /// Open an `auto` file with a data key already in memory (the current vault's, when the salt matches).
    static func decode(_ data: Data, dataKey: SecureKey) throws -> Payload {
        let insp = try inspect(data)
        guard case .v2(let header, _) = insp, header.mode == .auto else { throw Failure.wrongPassword }
        return try dataKey.withKey { k in try open(data, insp, key: KDF.backupKey(dataKey: k)) }
    }

    /// Open an `auto` file with the recovery phrase's entropy, using the recovery block in the file.
    static func decode(_ data: Data, recoveryEntropy entropy: [UInt8]) throws -> Payload {
        let insp = try inspect(data)
        guard case .v2(let header, _) = insp, header.mode == .auto, let block = header.recovery else { throw Failure.wrongPassword }
        guard let dataKey = Container.unwrapDataKey(entropy: entropy, recovery: block) else { throw Failure.wrongPassword }
        return try open(data, insp, key: KDF.backupKey(dataKey: dataKey))
    }

    private static func open(_ data: Data, _ insp: Container.Inspection, key: SymmetricKey) throws -> Payload {
        let json: Data
        do {
            switch insp {
            case .v1: json = try Container.openV1(data, key: key, limit: Limits.dataFileMaxBytes)
            case .v2: json = try Container.openV2(data, inspection: insp, key: key, limit: Limits.dataFileMaxBytes)
            }
        } catch let e as Container.Failure {
            throw map(e)
        }
        let payload: Payload
        do { payload = try Storage.decoder.decode(Payload.self, from: json) } catch { throw Failure.corrupt }
        guard payload.version == payloadVersion else { throw Failure.unsupportedPayloadVersion(payload.version) }
        return payload
    }

    private static func map(_ e: Container.Failure) -> Failure {
        switch e {
        case .notAContainer: return .notABackup
        case .unsupportedFormat(let v): return .unsupportedVersion(v)
        case .needsNewerReader(let v): return .needsNewerKeepit(v)
        case .tooLarge: return .tooLarge
        case .wrongKeyOrCorrupt: return .wrongPassword
        case .malformedHeader, .unsupportedKDF, .roundsOutOfRange, .corrupt: return .corrupt
        }
    }
}

extension Settings {
    /// Keys a restore never takes from a backup: they express trust in a particular installation.
    /// Everything else is copied from `other`.
    func applyingRestorable(from other: Settings) -> Settings {
        var s = other
        s.allowURLCommands = allowURLCommands
        s.trustedURLSenders = trustedURLSenders
        s.biometricUnlock = biometricUnlock
        s.biometricPasswordChange = biometricPasswordChange
        return s
    }
}
