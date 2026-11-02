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
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = base.appendingPathComponent("Keepit", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }() {
        didSet { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
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
            guard let old = oldValue, old !== key else { return }
            ioQueue.sync { old.zero() }
        }
    }

    static func clearKey() { key = nil }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue,
           size > Limits.dataFileMaxBytes {
            NSLog("Keepit: refusing to load \(url.lastPathComponent): \(size) bytes exceeds the limit")
            return nil
        }
        guard var data = try? Data(contentsOf: url) else { return nil }
        if Vault.isEncrypted(data) {
            guard let k = key, let plain = try? Vault.decrypt(data, key: k) else {
                NSLog("Keepit: \(url.lastPathComponent) is encrypted and no valid key is available")
                return nil
            }
            data = plain
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            NSLog("Keepit: failed to decode \(url.lastPathComponent): \(error)")
            // Keep a copy so the user doesn't lose data to a parsing bug.
            let bak = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.copyItem(at: url, to: bak)
            return nil
        }
    }

    /// Write `value` to `url` (encrypted when a key is set). `value` is captured as it is now;
    /// a later change to the store does not affect a save already queued.
    /// - `background: false` (default) returns once the file is on disk — lock, quit, password
    ///   changes and tests rely on that. `background: true` queues the work and returns at once;
    ///   the debounced savers use it. Both go through `ioQueue`, so writes never overtake each other.
    /// - `pretty`: human-readable JSON (settings.json only).
    static func save<T: Encodable>(_ value: T, to url: URL, encrypt: Bool = true, background: Bool = false, pretty: Bool = false) {
        // With a password set and no key in memory (locked), writing would replace an encrypted
        // file with plaintext — refuse rather than leak or clobber.
        if encrypt, key == nil, Vault.isEnabled {
            NSLog("Keepit: not saving \(url.lastPathComponent) while locked")
            return
        }
        // The key is captured here, on the caller's thread. `key.didSet` zeroes an old key only
        // after draining the queue, so this reference stays usable for the whole write.
        let k: SecureKey? = encrypt ? key : nil
        let enc = pretty ? prettyEncoder : encoder
        let work = {
            do {
                var data = try enc.encode(value)
                if let k { data = try Vault.encrypt(data, key: k) }
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Keepit: failed to save \(url.lastPathComponent): \(error)")
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
