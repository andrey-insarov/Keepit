import Foundation

/// Files live in ~/Library/Application Support/CLCL/ (CLCL used %LOCALAPPDATA%\CLCL).
enum Storage {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Keepit", isDirectory: true)
        // One-time migration from the pre-rename location (…/Application Support/CLCL).
        let legacy = base.appendingPathComponent("CLCL", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path), FileManager.default.fileExists(atPath: legacy.path) {
            if (try? FileManager.default.moveItem(at: legacy, to: dir)) == nil {
                try? FileManager.default.copyItem(at: legacy, to: dir)
            }
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let settingsURL  = directory.appendingPathComponent("settings.json")
    static let historyURL   = directory.appendingPathComponent("history.json")
    static let templatesURL = directory.appendingPathComponent("templates.json")

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private static let decoder: JSONDecoder = {
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
