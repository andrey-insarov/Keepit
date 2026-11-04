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
        try encode(json: try Storage.encoder.encode(payload), created: payload.created, app: payload.app, password: password)
    }

    /// Same, for payload JSON already built (`payloadJSON`) from a snapshot taken on the main thread.
    static func encode(json: Data, created: Date, app: String, password: SecureBuffer) throws -> Data {
        let salt = try KDF.randomBytes(Container.saltBytes)
        let header = Container.Header(mode: .manual, rounds: Container.defaultRounds, salt: salt,
                                      created: created, app: app, minReader: minReader)
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
        try encodeAutomatic(json: try Storage.encoder.encode(payload), dataKey: dataKey, vault: vault)
    }

    static func encodeAutomatic(json: Data, dataKey: SecureKey, vault: Container.Header) throws -> Data {
        try dataKey.withKey { k in
            try Container.sealV2(payload: json, header: vault, key: KDF.backupKey(dataKey: k))
        }
    }

    /// Payload JSON from parts encoded at different moments: the template tree is encoded on the main
    /// thread (it is a mutable reference graph), the history (values) wherever convenient. Splicing
    /// the three JSON documents avoids decoding the tree again just to re-encode it.
    static func payloadJSON(history: [ClipItem], templatesJSON: Data, settings: Settings?, created: Date, app: String) throws -> Data {
        let h = try Storage.encoder.encode(history)
        let created = try Storage.encoder.encode([created])            // "[\"…\"]" → strip the brackets
        let appJSON = try Storage.encoder.encode([app])
        var out = Data("{\"app\":".utf8)
        out.append(appJSON.dropFirst().dropLast())
        out.append(Data(",\"created\":".utf8)); out.append(created.dropFirst().dropLast())
        out.append(Data(",\"history\":".utf8)); out.append(h)
        if let s = settings { out.append(Data(",\"settings\":".utf8)); out.append(try Storage.encoder.encode(s)) }
        out.append(Data(",\"templates\":".utf8)); out.append(templatesJSON)
        out.append(Data(",\"version\":\(payloadVersion)}".utf8))
        return out
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
        return try payload(fromJSON: json)
    }

    /// Payload JSON → model, checked as the reader will check it. The engine runs this on what it
    /// just sealed, so a file that would not open is never reported as a successful backup.
    static func payload(fromJSON json: Data) throws -> Payload {
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

    /// Per-item limits are the *ceilings* of the corresponding settings, not their defaults: any
    /// installation may have been configured up to the ceiling, and what it recorded must restore.
    /// The user's own (narrower) settings govern recording, never reading a backup — and nothing
    /// inside the backup is trusted to set a limit.
    private static func validate(_ item: ClipItem, where place: String) throws {
        guard !item.formats.isEmpty else { throw Failure.invalidContent("\(place): item without formats") }
        for (uti, data) in item.formats {
            guard !uti.isEmpty, uti.count <= 255 else { throw Failure.invalidContent("\(place): bad format name") }
            switch uti {
            case ClipItem.Format.text:
                guard data.count <= Limits.textBytesCeiling else { throw Failure.invalidContent("\(place): text too large") }
            case ClipItem.Format.rtf, ClipItem.Format.html:
                guard data.count <= Limits.textBytesCeiling * 4 else { throw Failure.invalidContent("\(place): rich text too large") }
            case ClipItem.Format.png:
                guard data.count <= Limits.imageBytesCeiling, ClipItem.pixelCountOK(data) else { throw Failure.invalidContent("\(place): image too large") }
            case ClipItem.Format.files:
                guard data.count <= Limits.textBytesCeiling, let paths = try? JSONDecoder().decode([String].self, from: data),
                      paths.count <= Limits.fileListEntriesCeiling else { throw Failure.invalidContent("\(place): bad file list") }
            default:
                guard data.count <= Limits.imageBytesCeiling else { throw Failure.invalidContent("\(place): format too large") }
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
        s.backupEnabled = backupEnabled
        s.backupBookmark = backupBookmark
        s.backupSourceID = backupSourceID
        return s
    }

    /// What goes into a backup: preferences, not this installation's trust or its own backup setup.
    var forBackup: Settings {
        let d = Settings()
        var s = self
        s.allowURLCommands = d.allowURLCommands
        s.trustedURLSenders = d.trustedURLSenders
        s.biometricUnlock = d.biometricUnlock
        s.biometricPasswordChange = d.biometricPasswordChange
        s.backupEnabled = d.backupEnabled
        s.backupBookmark = nil
        s.backupSourceID = nil
        return s
    }
}
