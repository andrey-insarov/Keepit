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
    /// The format this build can read, compared with a file's `minReader`. Deliberately not
    /// `AppInfo.version` (the bundle's string — the test host's in XCTest) and kept equal to
    /// `VERSION` by a test, so a packaged build always reads its own exports.
    static let readerVersion = "3.0.0"
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
        /// The container opened but the content breaks a model rule (docs/FORMAT.md, `Limits`).
        case invalidContent(String)
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
            return try Container.inspect(data, readerVersion: readerVersion, maxBytes: Limits.dataFileMaxBytes)
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
        try validate(payload)
        return payload
    }

    // MARK: Validation

    /// A backup is untrusted input: every rule the app applies when it records or creates data is
    /// applied here before anything is returned, so nothing out of bounds can enter the store.
    static func validate(_ p: Payload) throws {
        guard p.history.count <= Limits.historyMaxCeiling * 2 else { throw Failure.invalidContent("too many history items") }
        var ids = Set<UUID>()
        for item in p.history {
            try validate(item, where: "history")
            guard ids.insert(item.id).inserted else { throw Failure.invalidContent("duplicate history id") }
        }
        var count = 0, hotKeys = 0
        var nodeIDs = Set<UUID>()
        try validate(p.templates, depth: 0, count: &count, hotKeys: &hotKeys, ids: &nodeIDs)
        // Settings carry no rejectable content: they are clamped when applied.
    }

    private static func validate(_ item: ClipItem, where place: String) throws {
        guard !item.formats.isEmpty else { throw Failure.invalidContent("\(place): item without formats") }
        let d = Settings()
        for (uti, data) in item.formats {
            guard !uti.isEmpty, uti.count <= 255 else { throw Failure.invalidContent("\(place): bad format name") }
            switch uti {
            case ClipItem.Format.text:
                guard data.count <= d.maxTextBytes else { throw Failure.invalidContent("\(place): text too large") }
            case ClipItem.Format.rtf, ClipItem.Format.html:
                guard data.count <= d.maxTextBytes * 4 else { throw Failure.invalidContent("\(place): rich text too large") }
            case ClipItem.Format.png:
                guard data.count <= d.maxImageBytes, ClipItem.pixelCountOK(data) else { throw Failure.invalidContent("\(place): image too large") }
            case ClipItem.Format.files:
                guard data.count <= d.maxTextBytes, let paths = try? JSONDecoder().decode([String].self, from: data),
                      paths.count <= d.maxFileListEntries else { throw Failure.invalidContent("\(place): bad file list") }
            default:
                guard data.count <= d.maxImageBytes else { throw Failure.invalidContent("\(place): format too large") }
            }
        }
        if let app = item.sourceApp, app.count > Limits.bundleIdMaxChars { throw Failure.invalidContent("\(place): bad source app") }
        let primary = item.formats[ClipItem.Format.files] ?? item.formats[ClipItem.Format.text] ?? item.formats[ClipItem.Format.png]
            ?? item.formats.sorted { $0.key < $1.key }.first!.value
        guard item.contentHash == ClipItem.hash(of: primary) else { throw Failure.invalidContent("\(place): contentHash does not match") }
    }

    private static func validate(_ node: TemplateNode, depth: Int, count: inout Int, hotKeys: inout Int, ids: inout Set<UUID>) throws {
        count += 1
        guard count <= Limits.templateMaxCount else { throw Failure.invalidContent("too many templates") }
        guard depth <= Limits.templateMaxDepth else { throw Failure.invalidContent("template tree too deep") }
        guard node.name.count <= Limits.templateNameMaxChars else { throw Failure.invalidContent("template name too long") }
        guard ids.insert(node.id).inserted else { throw Failure.invalidContent("duplicate template id") }
        if let c = node.clip { try validate(c, where: "templates") }
        if node.hotKey != nil {
            hotKeys += 1
            guard hotKeys <= Limits.templateHotKeysMax else { throw Failure.invalidContent("too many template hot keys") }
        }
        for child in node.children { try validate(child, depth: depth + 1, count: &count, hotKeys: &hotKeys, ids: &ids) }
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
