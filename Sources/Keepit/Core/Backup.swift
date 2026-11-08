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
    static let readerVersion = "3.0.6"
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
        // "archive" and "manual" both say it: not one of the automatic series, made by hand, own password.
        return "Keepit-archive-\(f.string(from: date))-manual.\(fileExtension)"
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
        var payload: Payload
        do { payload = try Storage.decoder.decode(Payload.self, from: json) } catch { throw Failure.corrupt }
        guard payload.version == payloadVersion else { throw Failure.unsupportedPayloadVersion(payload.version) }
        payload = normalised(payload)
        try validate(payload)
        return payload
    }

    /// What a reader may do for an archive before judging it: an item's *secondary* rich format
    /// (RTF or HTML beside a text, image or file-list primary) whose bytes are not what they claim
    /// is dropped, the item otherwise untouched. Keepit before 3.0.4 recorded those bytes unchecked
    /// — an HTML in Latin-1 from one app must not keep the text, images, paths and templates of a
    /// whole backup from restoring (auditor's P2 on PR #25). Nothing else is softened: the primary
    /// the hash was computed over is never touched, so a bad primary or a wrong hash still fails,
    /// and a format past its size ceiling is kept for the validator to refuse (his second round).
    static func normalised(_ p: Payload) -> Payload {
        var out = p
        out.history = p.history.map { $0.droppingInvalidRichFormats() }
        out.templates = p.templates.clone()
        normaliseClips(out.templates)
        return out
    }

    private static func normaliseClips(_ node: TemplateNode) {
        if let c = node.clip { node.clip = c.droppingInvalidRichFormats() }
        node.children.forEach(normaliseClips)
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
    /// One item on its own. This is the one boundary for content: a backup, the Viewer's file import,
    /// keepit://, the stores' own files on disk and every store mutator apply the same rules — a
    /// model the stores hold has passed here. Known formats must be what they claim: text is UTF-8
    /// (`plainText` relies on it), RTF starts with `{\rtf`, HTML is UTF-8 or BOM-led UTF-16, an
    /// image is a PNG by its bytes with a header-declared pixel count under the ceiling, a file list
    /// is absolute paths. An unknown UTI is bounded opaque data and is kept as such.
    static func validate(item: ClipItem) throws { try validate(item, where: "item") }

    /// A template subtree about to be inserted (name, depth, count, hot keys, every clip, unique ids
    /// within it). Whether it fits the tree it goes into is `TemplateStore.canInsert`.
    static func validate(subtree node: TemplateNode) throws {
        var count = 0, hotKeys = 0
        var ids = Set<UUID>()
        try validate(node, depth: 1, count: &count, hotKeys: &hotKeys, ids: &ids)
    }

    /// A whole tree as loaded from disk — the same rules as a payload's templates.
    static func validate(tree root: TemplateNode) throws {
        var count = 0, hotKeys = 0
        var ids = Set<UUID>()
        try validate(root, depth: 0, count: &count, hotKeys: &hotKeys, ids: &ids)
    }

    private static func validate(_ item: ClipItem, where place: String) throws {
        guard !item.formats.isEmpty else { throw Failure.invalidContent("\(place): item without formats") }
        for (uti, data) in item.formats { try validate(format: uti, data: data, where: place) }
        if let app = item.sourceApp, app.count > Limits.bundleIdMaxChars { throw Failure.invalidContent("\(place): bad source app") }
        let primary = item.formats[ClipItem.Format.files] ?? item.formats[ClipItem.Format.text] ?? item.formats[ClipItem.Format.png]
            ?? item.formats.sorted { $0.key < $1.key }.first!.value
        guard item.contentHash == ClipItem.hash(of: primary) else { throw Failure.invalidContent("\(place): contentHash does not match") }
    }

    /// One format on its own: its name and size, then — for a known UTI — that the bytes are what
    /// it claims. The two halves are separate because only the second is ever repairable: a
    /// secondary rich format with the wrong encoding may be dropped, one past the size ceiling may not.
    static func validate(format uti: String, data: Data, where place: String = "item") throws {
        try validateSize(format: uti, data: data, where: place)
        try validateContent(format: uti, data: data, where: place)
    }

    static func validateSize(format uti: String, data: Data, where place: String = "item") throws {
        guard !uti.isEmpty, uti.count <= 255 else { throw Failure.invalidContent("\(place): bad format name") }
        switch uti {
        case ClipItem.Format.text, ClipItem.Format.files:
            guard data.count <= Limits.textBytesCeiling else { throw Failure.invalidContent("\(place): text too large") }
        case ClipItem.Format.rtf, ClipItem.Format.html:
            guard data.count <= Limits.textBytesCeiling * 4 else { throw Failure.invalidContent("\(place): rich text too large") }
        default:
            guard data.count <= Limits.imageBytesCeiling else { throw Failure.invalidContent("\(place): format too large") }
        }
    }

    static func validateContent(format uti: String, data: Data, where place: String = "item") throws {
        switch uti {
        case ClipItem.Format.text:
            guard isUTF8(data) else { throw Failure.invalidContent("\(place): text is not UTF-8") }
        case ClipItem.Format.rtf:
            guard data.starts(with: Array("{\\rtf".utf8)) else { throw Failure.invalidContent("\(place): not RTF") }
        case ClipItem.Format.html:
            guard isUTF8(data) || data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) else {
                throw Failure.invalidContent("\(place): HTML is not UTF-8 or UTF-16")
            }
        case ClipItem.Format.png:
            guard ClipItem.isPNG(data), ClipItem.pixelCountOK(data) else { throw Failure.invalidContent("\(place): not a PNG, or too large") }
        case ClipItem.Format.files:
            guard let paths = try? JSONDecoder().decode([String].self, from: data),
                  paths.count <= Limits.fileListEntriesCeiling else { throw Failure.invalidContent("\(place): bad file list") }
            for path in paths {
                guard path.hasPrefix("/"), path.utf8.count <= Limits.filePathMaxBytes, !path.utf8.contains(0) else {
                    throw Failure.invalidContent("\(place): a file path is not an absolute path")
                }
            }
        default:
            break                                   // an unknown UTI is opaque: bounded by its size only
        }
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

    /// Valid UTF-8, without building a String for a large item (an invalid sequence fails fast).
    static func isUTF8(_ data: Data) -> Bool {
        var utf8 = UTF8()
        var it = data.makeIterator()
        while true {
            switch utf8.decode(&it) {
            case .scalarValue: continue
            case .emptyInput: return true
            case .error: return false
            }
        }
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
