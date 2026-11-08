import Foundation

/// Files live in ~/Library/Application Support/Keepit/.
enum Storage {
    /// Data folder. Tests and `--selftest` point this at a temporary directory
    /// (also honoured from the environment: KEEPIT_DATA_DIR).
    static var directory: URL = {
        let dir: URL
        if let env = ProcessInfo.processInfo.environment["KEEPIT_DATA_DIR"], !env.isEmpty {
            dir = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            dir = defaultDirectory
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }() {
        didSet { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    }

    /// Where a normal installation keeps its data (Application Support, or the sandbox container).
    static let defaultDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Keepit", isDirectory: true)
    }()

    /// True when `directory` is the normal one — not a test, self-test or KEEPIT_DATA_DIR location.
    static var isDefaultDirectory: Bool {
        directory.standardizedFileURL.path == defaultDirectory.standardizedFileURL.path
    }

    static var settingsURL: URL  { directory.appendingPathComponent("settings.json") }
    static var historyURL: URL   { directory.appendingPathComponent("history.json") }
    static var templatesURL: URL { directory.appendingPathComponent("templates.json") }

    /// Data files: compact JSON. History can run to hundreds of megabytes, and pretty-printing
    /// a Base64 blob only makes it bigger and slower to write; nobody reads history.json by hand.
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    /// settings.json stays human-readable — people do open it.
    static let prettyEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Every encode → encrypt → write runs on this serial queue, in order. Debounced saves go
    /// through it asynchronously, so a large history no longer freezes the interface for the
    /// duration of a save; lock, quit and explicit saves wait on it (see `save`).
    static let ioQueue = DispatchQueue(label: "com.it.keep.storage", qos: .utility)

    /// Block until every write queued so far has landed on disk.
    static func waitUntilSaved() { ioQueue.sync {} }
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// When set, history/templates are written encrypted and decrypted on read (see Vault).
    /// Assigning nil (or `clearKey()`) wipes the previous key's bytes — after any write still in
    /// flight on `ioQueue` has finished with it, so a background save can never see a zeroed key.
    /// Only ever assigned on the main thread.
    static var key: SecureKey? {
        didSet {
            Vault.keyDidChange(key)                      // the vault.json this key belongs to (Vault.liveMeta)
            guard let old = oldValue, old !== key else { return }
            ioQueue.sync { old.zero() }
        }
    }

    static func clearKey() { key = nil }

    /// Why a file that exists could not be used. Every case means the same thing to a store: the
    /// file is not to be written over — what is on disk may be recoverable (with the right key,
    /// from the right metadata, by hand), and a store that cannot read it has nothing to replace
    /// it with. Only `missing` (no file at all) is a fresh start.
    enum LoadFailure: Error, Equatable {
        case locked                 // encrypted, and there is no key in memory
        case notEncrypted           // protection is on, but the file is plain JSON (a swapped file)
        case wrongKeyOrDamaged      // the GCM tag did not verify: another key, or altered bytes
        case malformed              // decrypted (or plain) bytes that are not the expected JSON
        case tooLarge
        case io(Int32)              // errno from open/read, or the path is not a regular file
        case interruptedMove        // settings.json only: a Start Fresh or Replace stopped after moving it, and it could not be moved back yet
    }

    /// The outcome of reading a data file: three answers, not one `nil` for all of them. A store
    /// creates defaults only for `missing`; on `failed` it keeps the file as it is and refuses to
    /// save over it (auditor's SEC10 on 3.0.5: a damaged tag or a wrong key used to look like an
    /// empty install, and the empty install was written back over the only copy).
    enum LoadResult<T> {
        case missing
        case loaded(T)
        case failed(LoadFailure)

        var value: T? { if case .loaded(let v) = self { return v } else { return nil } }
        var failure: LoadFailure? { if case .failed(let f) = self { return f } else { return nil } }
    }

    /// Read and decode `url`. With `encrypted` (the default — history and templates) the file must
    /// be sealed whenever a key is set or protection is on: plain JSON in the place of a sealed
    /// file is `notEncrypted`, not data (auditor's SEC06 — the format was taken from the file
    /// itself, so swapping the file for plaintext was accepted without a key). settings.json is
    /// read with `encrypted: false`.
    static func read<T: Decodable>(_ type: T.Type, from url: URL, encrypted: Bool = true) -> LoadResult<T> {
        // On `ioQueue`, like every write: a read and a write of the same file never overlap, so a
        // hold set by a failed read is set before the next write runs, and a write in flight has
        // finished before the read sees the file (3.0.6 audit, round 3). Never call from the queue.
        ioQueue.sync {
            let result: LoadResult<T> = readUnheld(type, from: url, encrypted: encrypted)
            if result.failure != nil { hold(url) } else { release(url) }
            return result
        }
    }

    private static func readUnheld<T: Decodable>(_ type: T.Type, from url: URL, encrypted: Bool) -> LoadResult<T> {
        var data: Data
        do {
            data = try BoundedFileReader.read(url, max: Limits.dataFileMaxBytes)
        } catch BoundedFileReader.Failure.cannotOpen(ENOENT) {
            return .missing
        } catch BoundedFileReader.Failure.tooLarge {
            Log.storage.error("refusing to load \(url.lastPathComponent): larger than the limit")
            return .failed(.tooLarge)
        } catch BoundedFileReader.Failure.cannotOpen(let code) {
            Log.storage.error("refusing to load \(url.lastPathComponent): open failed, errno \(code)")
            return .failed(.io(code))
        } catch BoundedFileReader.Failure.readFailed(let code) {
            Log.storage.error("refusing to load \(url.lastPathComponent): read failed, errno \(code)")
            return .failed(.io(code))
        } catch {
            Log.storage.error("refusing to load \(url.lastPathComponent): \(String(describing: error))")
            return .failed(.io(0))
        }
        if Vault.isEncrypted(data) {
            guard let k = key else {
                Log.storage.notice("\(url.lastPathComponent) is encrypted and no key is available")
                return .failed(.locked)
            }
            do {
                data = try Vault.decrypt(data, key: k)
            } catch {
                Log.storage.error("\(url.lastPathComponent) did not decrypt with the current key — leaving it as it is")
                return .failed(.wrongKeyOrDamaged)
            }
        } else if encrypted, key != nil || Vault.isEnabled {
            Log.storage.error("\(url.lastPathComponent) is not encrypted while protection is on — refusing it")
            return .failed(.notEncrypted)
        }
        do {
            return .loaded(try decoder.decode(T.self, from: data))
        } catch {
            let kind = String(describing: Swift.type(of: error))     // the type only: the description can quote the file
            Log.storage.error("failed to decode \(url.lastPathComponent): \(kind) — leaving it as it is")
            return .failed(.malformed)
        }
    }

    /// `read` for a caller that only wants the value (settings at launch, tests): nil for missing
    /// and for every failure alike. Not for the stores — they must tell the two apart.
    static func load<T: Decodable>(_ type: T.Type, from url: URL, encrypted: Bool = true) -> T? {
        read(type, from: url, encrypted: encrypted).value
    }

    /// `name.corrupt-<unix time>` next to the file: what was on disk before a load changed its mind
    /// about part of it. Best effort; the encrypted bytes are copied as they are.
    static func keepCopy(of url: URL) {
        let bak = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.copyItem(at: url, to: bak)
    }

    // MARK: Held files

    /// Files that exist but could not be read (`read` returned `.failed`), or that the app holds on
    /// purpose (history.json while settings.json is unreadable). Nothing writes or removes a held
    /// file: `save` / `saveEncoded` skip it, `writeNow` / `removeNow` throw `Failure.held` — so a
    /// path that forgets its store's `loadFailure` still cannot replace the only copy (3.0.6 audit of
    /// SEC10: a reload that skipped the read, a restore Merge, a password change). A hold ends when
    /// a later `read` succeeds or finds no file, when `setAside` moves the file away, or on Reset.
    private static let heldLock = NSLock()
    private static var heldPaths: Set<String> = []
    private static var pinnedPaths: Set<String> = []      // held on purpose; a successful read does not release these

    private static func heldKey(_ url: URL) -> String { url.standardizedFileURL.path }

    static func hold(_ url: URL) { heldLock.lock(); heldPaths.insert(heldKey(url)); heldLock.unlock() }
    static func release(_ url: URL) { heldLock.lock(); heldPaths.remove(heldKey(url)); heldLock.unlock() }
    static func releaseAll() { heldLock.lock(); heldPaths.removeAll(); pinnedPaths.removeAll(); heldLock.unlock() }
    /// Hold a readable file on purpose — history.json while the settings that say whether to keep
    /// it are unknown. Only `unpin`, `setAside` or Reset end it.
    static func pin(_ url: URL) { heldLock.lock(); pinnedPaths.insert(heldKey(url)); heldLock.unlock() }
    static func unpin(_ url: URL) { heldLock.lock(); pinnedPaths.remove(heldKey(url)); heldLock.unlock() }
    static func isHeld(_ url: URL) -> Bool {
        heldLock.lock(); defer { heldLock.unlock() }
        let k = heldKey(url)
        return heldPaths.contains(k) || pinnedPaths.contains(k)
    }

    /// Rename unreadable files to `name.corrupt-<unix time>[-n]` so the stores can start fresh beside
    /// them — the user's explicit choice; nothing does this on its own. All or nothing within the
    /// process: if one rename fails, the ones already done are moved back and the error is thrown,
    /// so no store is reset while another is not. The renames are not journalled: if the process
    /// stops between two of them, the first file is already under its `.corrupt-…` name and the
    /// second is reported again at the next launch — nothing is lost, but that store starts over on
    /// its own. A rename, never a copy and a delete: the bytes always have a name. A name that exists
    /// already (two in one second) gets a counter. Through `ioQueue`, after any pending write.
    /// Returns where each file went; the files are released.
    @discardableResult
    static func setAside(_ urls: [URL]) throws -> [URL] {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        let moved: [URL] = try ioQueue.sync {
            var done: [(from: URL, to: URL)] = []
            do {
                for url in urls where fm.fileExists(atPath: url.path) {
                    var bak = url.appendingPathExtension("corrupt-\(stamp)")
                    var n = 1
                    while fm.fileExists(atPath: bak.path) {
                        n += 1
                        bak = url.appendingPathExtension("corrupt-\(stamp)-\(n)")
                    }
                    // settings.json alone leaves a marker first: without the file, a launch looks
                    // like a first run and the defaults replace safe mode (3.0.6 audit, round 5).
                    // The caller clears it once the new settings.json exists; a launch that finds
                    // the marker and no settings.json moves the file back (`recoverSetAside`).
                    if url == settingsURL {
                        try Data(bak.lastPathComponent.utf8).write(to: setAsideMarker, options: .atomic)
                    }
                    try fm.moveItem(at: url, to: bak)
                    done.append((url, bak))
                }
            } catch {
                try? fm.removeItem(at: setAsideMarker)
                for d in done.reversed() {
                    do { try fm.moveItem(at: d.to, to: d.from) }
                    catch let undo { Log.storage.error("could not move \(d.to.lastPathComponent) back: \(undo.localizedDescription)") }
                }
                throw error
            }
            return done.map(\.to)
        }
        urls.forEach { release($0); unpin($0) }
        return moved
    }

    /// Undo `setAside` for the files it returned: each goes back under its original name (the
    /// `.corrupt-…` extension stripped) and is held again, so the state is exactly what it was
    /// before — a restore commit that fails after the rename uses it (3.0.6 audit, round 4: a
    /// settings.json left aside looked like a first run at the next launch). A file whose original
    /// name is taken again meanwhile, or that cannot be moved, is left where it is and logged; for
    /// settings.json the marker then stays, and the next launch tries again.
    static func putBack(_ moved: [URL]) {
        let fm = FileManager.default
        ioQueue.sync {
            for aside in moved {
                let original = aside.deletingPathExtension()
                guard !fm.fileExists(atPath: original.path) else {
                    Log.storage.error("could not put \(aside.lastPathComponent) back: \(original.lastPathComponent) exists again")
                    continue
                }
                do {
                    try fm.moveItem(at: aside, to: original)
                    hold(original)
                    if original == settingsURL { try? fm.removeItem(at: setAsideMarker) }
                } catch { Log.storage.error("could not put \(aside.lastPathComponent) back: \(error.localizedDescription)") }
            }
        }
    }

    /// Where `setAside` notes that settings.json is being moved: the aside file's name, written
    /// before the rename, removed by `clearSetAsideMarker` once a new settings.json exists.
    static var setAsideMarker: URL { settingsURL.appendingPathExtension("set-aside") }

    /// The caller of `setAside` says the new settings.json is in place (Start Fresh wrote the running
    /// settings; a restore commit wrote the plan's).
    static func clearSetAsideMarker() {
        ioQueue.sync { try? FileManager.default.removeItem(at: setAsideMarker) }
    }

    enum SetAsideRecovery: Equatable {
        case nothing        // no marker, or a leftover beside an existing settings.json (removed)
        case restored       // settings.json was put back under its name; the marker is gone
        case pending        // settings.json is absent and could not be put back; the marker stays
    }

    /// At launch, before settings.json is read: a marker with no settings.json means Start Fresh or
    /// a Replace stopped between the rename and the new file. The old file goes back under its name
    /// (so the launch is in safe mode again, not a first run), and the marker goes. A marker beside
    /// an existing settings.json is a leftover from a completed operation and just goes. If the
    /// file cannot be put back — the move fails, or the named file is gone — the marker stays, so
    /// the launch is still not a first run (`.pending`: the app runs in safe mode and the next
    /// launch tries again; 3.0.6 audit, round 6). Only a marker that names no usable file at all
    /// is dropped.
    @discardableResult
    static func recoverSetAside() -> SetAsideRecovery {
        let fm = FileManager.default
        return ioQueue.sync {
            guard fm.fileExists(atPath: setAsideMarker.path) else { return .nothing }
            if fm.fileExists(atPath: settingsURL.path) { try? fm.removeItem(at: setAsideMarker); return .nothing }
            guard let name = try? String(contentsOf: setAsideMarker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty, !name.contains("/"), name.hasPrefix(settingsURL.lastPathComponent + ".corrupt-") else {
                Log.storage.error("set-aside marker names no file; dropping it")
                try? fm.removeItem(at: setAsideMarker)
                return .nothing
            }
            let aside = directory.appendingPathComponent(name)
            guard fm.fileExists(atPath: aside.path) else {
                Log.storage.error("set-aside marker names \(name), which is gone; keeping safe mode")
                return .pending
            }
            do {
                try fm.moveItem(at: aside, to: settingsURL)
                try? fm.removeItem(at: setAsideMarker)
                Log.storage.notice("settings.json put back after an interrupted Start Fresh or Replace")
                return .restored
            } catch {
                Log.storage.error("could not put settings.json back: \(error.localizedDescription); keeping safe mode")
                return .pending
            }
        }
    }

    /// Write `value` to `url` (encrypted when a key is set). `value` is captured as it is now;
    /// a later change to the store does not affect a save already queued.
    /// - `background: false` (default) returns once the file is on disk — lock, quit, password
    ///   changes and tests rely on that. `background: true` queues the work and returns at once;
    ///   the debounced savers use it. Both go through `ioQueue`, so writes never overtake each other.
    /// - `pretty`: human-readable JSON (settings.json only).
    ///
    /// `value` must be a value type (or otherwise immutable) when `background` is true: it is encoded
    /// on the I/O queue. A reference-type graph that the main thread keeps editing — the template
    /// tree — must be encoded first and handed over as bytes: see `saveEncoded`.
    static func save<T: Encodable>(_ value: T, to url: URL, encrypt: Bool = true, background: Bool = false, pretty: Bool = false) {
        let enc = pretty ? prettyEncoder : encoder
        write(to: url, encrypt: encrypt, background: background) { try enc.encode(value) }
    }

    /// Like `save`, for data already encoded on the caller's thread (a snapshot of mutable state).
    static func saveEncoded(_ data: Data, to url: URL, encrypt: Bool = true, background: Bool = false) {
        write(to: url, encrypt: encrypt, background: background) { data }
    }

    enum Failure: Error, Equatable {
        case locked
        case held(String)           // the file could not be read and is kept as it is (see `hold`)
    }

    /// The throwing, synchronous write for a caller that must know the outcome (a restore commit).
    /// Same rules as `save`: encrypted with the current key, refused while locked, through `ioQueue`.
    static func writeNow(_ data: Data, to url: URL, encrypt: Bool = true) throws {
        if isHeld(url) { throw Failure.held(url.lastPathComponent) }
        if encrypt, key == nil, Vault.isEnabled { throw Failure.locked }
        let k: SecureKey? = encrypt ? key : nil
        try ioQueue.sync {
            if isHeld(url) { throw Failure.held(url.lastPathComponent) }   // again, in order with the reads
            var d = data
            if let k { d = try Vault.encrypt(d, key: k) }
            try d.write(to: url, options: .atomic)
        }
    }

    /// Put bytes back exactly as they were read (already encrypted, or not): undo for `writeNow`.
    static func writeRawNow(_ bytes: Data, to url: URL) throws {
        if isHeld(url) { throw Failure.held(url.lastPathComponent) }
        try ioQueue.sync {
            if isHeld(url) { throw Failure.held(url.lastPathComponent) }
            try bytes.write(to: url, options: .atomic)
        }
    }

    static func removeNow(_ url: URL) throws {
        if isHeld(url) { throw Failure.held(url.lastPathComponent) }
        try ioQueue.sync {
            if isHeld(url) { throw Failure.held(url.lastPathComponent) }
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    private static func write(to url: URL, encrypt: Bool, background: Bool, _ produce: @escaping () throws -> Data) {
        if isHeld(url) {
            Log.storage.notice("not saving \(url.lastPathComponent): it could not be read and is kept as it is")
            return
        }
        // With a password set and no key in memory (locked), writing would replace an encrypted
        // file with plaintext — refuse rather than leak or clobber.
        if encrypt, key == nil, Vault.isEnabled {
            Log.storage.notice("not saving \(url.lastPathComponent) while locked")
            return
        }
        // The key is captured here, on the caller's thread. `key.didSet` zeroes an old key only
        // after draining the queue, so this reference stays usable for the whole write.
        let k: SecureKey? = encrypt ? key : nil
        let work = {
            // Checked again here, when the write actually runs: a read that failed after this save
            // was queued has held the file meanwhile (3.0.6 audit, round 2).
            if isHeld(url) {
                Log.storage.notice("not saving \(url.lastPathComponent): it could not be read and is kept as it is")
                return
            }
            do {
                var data = try produce()
                if let k { data = try Vault.encrypt(data, key: k) }
                if isHeld(url) { return }                      // held while encoding (a read on another queue)
                try data.write(to: url, options: .atomic)
            } catch {
                Log.storage.error("failed to save \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if background { ioQueue.async(execute: work) } else { ioQueue.sync(execute: work) }
    }
}

/// Coalesces many rapid change notifications into one disk write.
/// The action receives `background: true` from the timer (the write may run off the main thread)
/// and `false` from `flush()` (the caller needs the file on disk before going on).
final class DebouncedSaver {
    private var pending: DispatchWorkItem?
    private let delay: TimeInterval
    private let action: (_ background: Bool) -> Void

    init(delay: TimeInterval = 1.0, action: @escaping (_ background: Bool) -> Void) {
        self.delay = delay
        self.action = action
    }

    func schedule() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.action(true) }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: w)
    }

    func flush() {
        pending?.cancel()
        pending = nil
        action(false)
    }
}
