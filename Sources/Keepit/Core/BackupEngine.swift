import CryptoKit
import Foundation
import KeepitCore

// Automatic encrypted backup — docs/BACKUP.md is the design, this is the engine (stage 3: no UI).
//
// Snapshot (main) → Seal + verify (Storage.ioQueue, needs the key) → Write + read back + rotate
// (backupQueue, needs no key). Lock waits for the seal, never for the write.

/// Where backup files go. The app uses a security-scoped bookmark; tests use a plain folder.
protocol BackupDestination: AnyObject {
    /// Run `body` with the folder reachable (security scope started/stopped around it).
    func withFolder<T>(_ body: (URL) throws -> T) throws -> T
    var displayPath: String { get }
}

/// A folder the process can already reach (tests, KEEPIT_DATA_DIR runs).
final class PlainFolderDestination: BackupDestination {
    let url: URL
    init(_ url: URL) { self.url = url }
    func withFolder<T>(_ body: (URL) throws -> T) throws -> T { try body(url) }
    var displayPath: String { url.path }
}

/// A folder chosen in NSOpenPanel, kept as an app-scoped security bookmark (sandbox-safe).
final class BookmarkDestination: BackupDestination {
    private(set) var bookmark: Data
    /// Set when macOS refreshed the bookmark; the owner should persist the new bytes.
    var onBookmarkRefreshed: ((Data) -> Void)?

    init(bookmark: Data) { self.bookmark = bookmark }

    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func withFolder<T>(_ body: (URL) throws -> T) throws -> T {
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale)
        guard url.startAccessingSecurityScopedResource() else { throw BackupEngine.Failure.folderUnavailable }
        defer { url.stopAccessingSecurityScopedResource() }
        if stale, let fresh = try? Self.makeBookmark(for: url) {      // refresh while access still works
            bookmark = fresh
            onBookmarkRefreshed?(fresh)
        }
        return try body(url)
    }

    var displayPath: String {
        var stale = false
        return (try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale))?.path ?? "?"
    }
}

/// Bookkeeping that survives relaunches — backup.json in the data folder, plaintext (it holds no
/// content: a fingerprint of the last snapshot, the registry of this installation's own files).
struct BackupState: Codable, Equatable {
    struct Record: Codable, Equatable {
        var backupID: String
        var name: String
        var size: Int
        var date: Date
        var sha256: String
    }
    var dirty = false
    var firstDirtyAt: Date?
    var lastFingerprint: String?
    /// Hash of the vault's KDF salt, rounds and recovery salt at the last success: a change forces a backup.
    var credentialsStamp: String?
    var lastSuccess: Date?
    var lastName: String?
    var lastSize: Int?
    var lastError: String?
    var failures = 0
    var nextRetryAt: Date?
    var records: [Record] = []
}

final class BackupEngine {
    enum Failure: Error, Equatable, LocalizedError {
        case notEnabled, locked, noVault, folderUnavailable, writeFailed(String), verifyFailed, nothingToBackUp
        var errorDescription: String? {
            switch self {
            case .notEnabled: return "automatic backup is off"
            case .locked: return "Keepit is locked"
            case .noVault: return "no password set"
            case .folderUnavailable: return L("Backup folder is not available")
            case .writeFailed(let why): return LF("Could not write the backup: %@", why)
            case .verifyFailed: return L("The written backup did not read back correctly")
            case .nothingToBackUp: return "nothing changed"
            }
        }
    }

    static let quietInterval: TimeInterval = 5 * 60
    static let deadline: TimeInterval = 24 * 60 * 60
    static let retryDelays: [TimeInterval] = [60, 300, 900, 3600]
    static let partSuffix = ".part"
    static let beforeRestorePrefix = "Keepit-before-restore-"

    // Dependencies, injected so tests run without AppKit or a vault.
    /// Changing the destination starts a new generation: a job begun for the old folder may finish
    /// writing there, but its result does not touch the state of the new one.
    var destination: BackupDestination? { didSet { generation &+= 1 } }
    var keepCount = 10
    var label: String?
    var sourceID: String
    var appName = "Keepit \(AppInfo.version)"
    /// Builds the payload and the auto header from the live stores; nil when locked or no vault.
    var snapshotProvider: (() -> Snapshot?)?
    var now: () -> Date = { Date() }
    var onStateChange: ((BackupState) -> Void)?

    /// One consistent state, taken on the main thread. Templates are a reference graph the UI keeps
    /// editing, so they are encoded here; the history is an array of values and is encoded off-thread.
    struct Snapshot {
        var history: [ClipItem]
        var templatesJSON: Data
        var settings: Settings?
        var header: Container.Header
        var dataKey: SecureKey
        var credentialsStamp: String
    }

    private(set) var state: BackupState
    private let stateURL: URL
    private var lastChangeAt: Date?
    private var inFlight = false
    /// Every noteChange / forceNext advances this; a job remembers the value at its snapshot and
    /// may clear `dirty` only if nothing advanced it since.
    private(set) var changeSeq: UInt64 = 0
    /// Set by forceNext while a job is in flight: that job's result must not count as the forced copy.
    private var forcedSinceSnapshot = false
    /// First change after the in-flight snapshot: becomes `firstDirtyAt` when the job completes.
    private var firstChangeAfterSnapshot: Date?
    private(set) var generation: UInt64 = 0
    private let backupQueue = DispatchQueue(label: "com.it.keep.backup", qos: .utility)

    init(stateURL: URL, sourceID: String) {
        self.stateURL = stateURL
        self.sourceID = sourceID
        state = (try? JSONDecoder.iso.decode(BackupState.self, from: Data(contentsOf: stateURL))) ?? BackupState()
    }

    // MARK: Triggers

    /// History or templates changed.
    func noteChange() {
        let t = now()
        lastChangeAt = t
        changeSeq &+= 1
        if inFlight, firstChangeAfterSnapshot == nil { firstChangeAfterSnapshot = t }
        if !state.dirty { state.dirty = true; state.firstDirtyAt = t; persist() }
    }

    /// Something that must produce a new file even if the content did not change (password, phrase, folder).
    func forceNext() {
        state.lastFingerprint = nil
        state.credentialsStamp = nil
        changeSeq &+= 1
        if inFlight { forcedSinceSnapshot = true; if firstChangeAfterSnapshot == nil { firstChangeAfterSnapshot = now() } }
        if !state.dirty { state.dirty = true; state.firstDirtyAt = now() }
        persist()
    }

    /// Whether a backup should run now (launch, unlock, wake, timer).
    func isDue() -> Bool {
        guard state.dirty, !inFlight else { return false }
        let t = now()
        if let r = state.nextRetryAt, t < r { return false }
        if let first = state.firstDirtyAt, t.timeIntervalSince(first) >= Self.deadline { return true }
        if let last = lastChangeAt { return t.timeIntervalSince(last) >= Self.quietInterval }
        return true                                    // dirty from a previous run with no change since launch
    }

    /// Run if due. Completion on the main queue with the outcome.
    func runIfDue(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isDue() else { completion?(.failure(Failure.nothingToBackUp)); return }
        run(force: false, completion: completion)
    }

    /// Back Up Now: ignores timers and the fingerprint.
    func backUpNow(completion: ((Result<Void, Error>) -> Void)? = nil) {
        run(force: true, completion: completion)
    }

    // MARK: The three stages

    private func run(force: Bool, completion: ((Result<Void, Error>) -> Void)?) {
        guard !inFlight else { completion?(.failure(Failure.nothingToBackUp)); return }
        guard let destination else { finish(.failure(Failure.notEnabled), completion); return }
        guard let snap = snapshotProvider?() else { finish(.failure(Failure.locked), completion); return }
        inFlight = true
        forcedSinceSnapshot = false
        firstChangeAfterSnapshot = nil
        let seqAtSnapshot = changeSeq
        let gen = generation
        let recordsAtStart = state.records
        let backupID = UUID().uuidString.lowercased()
        var header = snap.header
        header.sourceID = sourceID
        header.backupID = backupID
        header.label = label
        header.app = appName
        header.created = now()
        let name = Self.fileName(created: header.created, sourceID: sourceID, backupID: backupID)
        let keep = keepCount
        let stamp = snap.credentialsStamp
        let lastFingerprint = state.lastFingerprint, lastStamp = state.credentialsStamp

        // Stage 2 — encode, fingerprint, seal and verify while the key is available.
        // Storage.ioQueue: Lock waits for this stage, and only for this stage.
        Storage.ioQueue.async { [self] in
            let sealed: (bytes: Data, sha: String)
            let fingerprint: String
            do {
                let json = try Backup.payloadJSON(history: snap.history, templatesJSON: snap.templatesJSON, settings: snap.settings,
                                                  created: header.created, app: header.app)
                fingerprint = Self.fingerprint(history: snap.history, templates: snap.templatesJSON, settings: snap.settings)
                if !force, fingerprint == lastFingerprint, stamp == lastStamp {
                    DispatchQueue.main.async {
                        self.inFlight = false
                        if gen == self.generation { self.settle(seqAtSnapshot: seqAtSnapshot) }
                        completion?(.failure(Failure.nothingToBackUp))
                    }
                    return
                }
                let bytes = try Backup.encodeAutomatic(json: json, dataKey: snap.dataKey, vault: header)
                // Verify the container with the key: header parses, GCM opens, payload is what we encoded.
                let insp = try Container.inspect(bytes, readerVersion: Backup.readerVersion, maxBytes: Limits.dataFileMaxBytes)
                let back = try snap.dataKey.withKey { k in try Container.openV2(bytes, inspection: insp, key: KDF.backupKey(dataKey: k), limit: Limits.dataFileMaxBytes) }
                guard back == json else { throw Failure.verifyFailed }
                sealed = (bytes, Self.sha256(bytes))
            } catch {
                DispatchQueue.main.async { self.record(failure: error); self.inFlight = false; completion?(.failure(error)) }
                return
            }
            // Stage 3 — write, then rotate, without the key and off the main thread.
            self.backupQueue.async {
                let result = Result { () -> (records: [BackupState.Record], size: Int) in
                    let size = try Self.write(sealed.bytes, sha: sealed.sha, name: name, to: destination)
                    let newRecord = BackupState.Record(backupID: backupID, name: name, size: size, date: header.created, sha256: sealed.sha)
                    let records = Self.rotate(recordsAtStart + [newRecord], keep: keep, in: destination)
                    return (records, size)
                }
                DispatchQueue.main.async {
                    self.inFlight = false
                    guard gen == self.generation else {                 // folder changed or Reset meanwhile: this result is history
                        completion?(result.map { _ in () })
                        return
                    }
                    switch result {
                    case .success(let r):
                        self.state.records = r.records
                        if !self.forcedSinceSnapshot {               // a force after the snapshot keeps these nil → next run writes again
                            self.state.lastFingerprint = fingerprint
                            self.state.credentialsStamp = stamp
                        }
                        self.state.lastSuccess = header.created
                        self.state.lastName = name
                        self.state.lastSize = r.size
                        self.state.lastError = nil
                        self.state.failures = 0
                        self.state.nextRetryAt = nil
                        self.settle(seqAtSnapshot: seqAtSnapshot)
                        completion?(.success(()))
                    case .failure(let error):
                        self.record(failure: error)
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    /// A finished job accounts for its own snapshot only: changes made since it was taken stay dirty.
    private func settle(seqAtSnapshot: UInt64) {
        if changeSeq == seqAtSnapshot {
            state.dirty = false
            state.firstDirtyAt = nil
        } else {
            state.dirty = true
            state.firstDirtyAt = firstChangeAfterSnapshot ?? now()
        }
        persist()
    }

    private func finish(_ r: Result<Void, Error>, _ completion: ((Result<Void, Error>) -> Void)?) {
        // Not being able to start (locked, off) is not a failure to retry with backoff; the dirty state simply waits.
        if case .failure(let e) = r, let f = e as? Failure, ![.nothingToBackUp, .locked, .notEnabled].contains(f) { record(failure: e) }
        completion?(r)
    }

    private func record(failure: Error) {
        state.lastError = (failure as? LocalizedError)?.errorDescription ?? String(describing: failure)
        state.failures += 1
        let delay = Self.retryDelays[min(state.failures - 1, Self.retryDelays.count - 1)]
        state.nextRetryAt = now().addingTimeInterval(delay)
        persist()                                       // dirty stays set
    }

    /// Temp file in the destination, fsync, read back and compare, atomic rename. Returns the size.
    static func write(_ bytes: Data, sha: String, name: String, to destination: BackupDestination) throws -> Int {
        try destination.withFolder { folder in
            let final = folder.appendingPathComponent(name)
            let part = folder.appendingPathComponent("." + name + partSuffix)
            do {
                try bytes.write(to: part, options: [])
                let fh = try FileHandle(forWritingTo: part)
                if fsync(fh.fileDescriptor) != 0 { throw Failure.writeFailed("fsync") }
                try fh.close()
                let back = try Data(contentsOf: part)
                guard sha256(back) == sha else { throw Failure.verifyFailed }
                guard rename(part.path, final.path) == 0 else { throw Failure.writeFailed("rename: \(String(cString: strerror(errno)))") }   // atomic, overwrites
            } catch {
                try? FileManager.default.removeItem(at: part)
                if let f = error as? Failure { throw f }
                throw Failure.writeFailed(error.localizedDescription)
            }
            return bytes.count
        }
    }

    /// Keep the last `keep` files of *this* series — by the registry, never by what the folder
    /// looks like. Foreign files, other series and before-restore copies are untouched. Runs on the
    /// backup queue; returns the registry as it should be afterwards: a record whose file could
    /// not be deleted stays, so the next rotation tries again.
    static func rotate(_ records: [BackupState.Record], keep: Int, in destination: BackupDestination) -> [BackupState.Record] {
        let sorted = records.sorted { $0.date < $1.date }
        guard sorted.count > keep else { return records }
        let doomed = sorted.prefix(sorted.count - keep)
        var gone = Set<String>()
        try? destination.withFolder { folder in
            for r in doomed {
                let url = folder.appendingPathComponent(r.name)
                if !FileManager.default.fileExists(atPath: url.path) { gone.insert(r.backupID); continue }   // deleted by hand: forget it
                if (try? FileManager.default.removeItem(at: url)) != nil { gone.insert(r.backupID) }
            }
        }
        return records.filter { !gone.contains($0.backupID) }
    }

    // MARK: Helpers

    static func fileName(created: Date, sourceID: String, backupID: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return "Keepit-\(f.string(from: created))-\(sourceID)-\(backupID).\(Backup.fileExtension)"
    }

    static func sha256(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }

    /// Fingerprint of what would be backed up: stable content only (no dates of the backup itself).
    static func fingerprint(history: [ClipItem], templates: Data, settings: Settings?) -> String {
        var h = SHA256()
        h.update(data: (try? Storage.encoder.encode(history)) ?? Data())
        h.update(data: templates)
        if let s = settings { h.update(data: (try? Storage.encoder.encode(s)) ?? Data()) }
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func credentialsStamp(_ header: Container.Header) -> String {
        var h = SHA256()
        h.update(data: header.salt)
        h.update(data: Data(String(header.rounds).utf8))
        if let r = header.recovery { h.update(data: r.salt) }
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func resetRegistry() { state.records = []; generation &+= 1; persist() }

    private func persist() {
        if let d = try? JSONEncoder.iso.encode(state) { try? d.write(to: stateURL, options: .atomic) }
        onStateChange?(state)
    }
}

extension JSONEncoder {
    static let iso: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys, .prettyPrinted]; return e }()
}
extension JSONDecoder {
    static let iso: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
}
