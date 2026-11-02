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

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// When set, history/templates are written encrypted and decrypted on read (see Vault).
    /// Assigning nil (or `clearKey()`) wipes the previous key's bytes.
    static var key: SecureKey? {
        didSet { oldValue?.zero() }
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

    static func save<T: Encodable>(_ value: T, to url: URL, encrypt: Bool = true) {
        // With a password set and no key in memory (locked), writing would replace an encrypted
        // file with plaintext — refuse rather than leak or clobber.
        if encrypt, key == nil, Vault.isEnabled {
            NSLog("Keepit: not saving \(url.lastPathComponent) while locked")
            return
        }
        do {
            var data = try encoder.encode(value)
            if encrypt, let k = key { data = try Vault.encrypt(data, key: k) }
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Keepit: failed to save \(url.lastPathComponent): \(error)")
        }
    }
}

/// Coalesces many rapid change notifications into one disk write.
final class DebouncedSaver {
    private var pending: DispatchWorkItem?
    private let delay: TimeInterval
    private let action: () -> Void

    init(delay: TimeInterval = 1.0, action: @escaping () -> Void) {
        self.delay = delay
        self.action = action
    }

    func schedule() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.action() }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: w)
    }

    func flush() {
        pending?.cancel()
        pending = nil
        action()
    }
}
