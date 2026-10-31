import AppKit
import CommonCrypto
import CryptoKit
import Foundation
import Security

/// 32 key bytes in a page-locked (mlock) buffer that is wiped with memset_s on `zero()` and on deinit.
/// CryptoKit's SymmetricKey cannot be zeroed on demand, so one is built only for the duration of a call.
final class SecureKey {
    static let size = 32
    private let ptr: UnsafeMutableRawPointer
    private(set) var isZeroed = false

    init(bytes: UnsafeRawBufferPointer) {
        precondition(bytes.count == SecureKey.size)
        ptr = UnsafeMutableRawPointer.allocate(byteCount: SecureKey.size, alignment: 16)
        _ = mlock(ptr, SecureKey.size)                      // keep out of swap
        ptr.copyMemory(from: bytes.baseAddress!, byteCount: SecureKey.size)
    }

    /// Run `body` with a transient SymmetricKey; the temporary copy is wiped afterwards.
    func withKey<T>(_ body: (SymmetricKey) throws -> T) throws -> T {
        precondition(!isZeroed, "SecureKey used after zeroization")
        var tmp = Data(bytes: ptr, count: SecureKey.size)
        defer { tmp.resetBytes(in: 0..<tmp.count) }
        return try body(SymmetricKey(data: tmp))
    }

    /// Raw access for the keychain write; the caller must wipe any copy it makes.
    func withBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        precondition(!isZeroed, "SecureKey used after zeroization")
        return try body(UnsafeRawBufferPointer(start: ptr, count: SecureKey.size))
    }

    func zero() {
        guard !isZeroed else { return }
        _ = memset_s(ptr, SecureKey.size, 0, SecureKey.size)
        isZeroed = true
    }

    deinit {
        zero()
        _ = munlock(ptr, SecureKey.size)
        ptr.deallocate()
    }
}

/// Password-based encryption of the data files.
/// Key = PBKDF2-HMAC-SHA256(password, salt, 200k rounds) → AES-256-GCM per file.
/// Nothing derived from the password is written to disk except a GCM-sealed verifier.
/// Intermediate buffers (password bytes, derived key) are wiped as soon as they are no longer needed.
enum Vault {
    static let magic = Data("KEEPITENC1".utf8)
    private static let okToken = Data("KEEPIT-OK".utf8)
    private static let rounds: UInt32 = 200_000

    struct Meta: Codable {
        var salt: Data
        var check: Data          // encrypt(okToken) with the key
    }

    static var metaURL: URL { Storage.directory.appendingPathComponent("vault.json") }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: metaURL.path) }

    // MARK: Key derivation

    /// The password arrives as locked bytes (see SecurePasswordField); no String of it exists.
    static func deriveKey(password: SecureBuffer, salt: Data) -> SecureKey {
        var out = [UInt8](repeating: 0, count: SecureKey.size)
        defer {
            out.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) }
        }
        password.withBytes { pw in
            salt.withUnsafeBytes { saltPtr in
                _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                         pw.baseAddress?.assumingMemoryBound(to: CChar.self), pw.count,
                                         saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                         CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                                         &out, out.count)
            }
        }
        return out.withUnsafeBytes { SecureKey(bytes: $0) }
    }

    // MARK: Encrypt / decrypt blobs

    static func encrypt(_ plain: Data, key: SecureKey) throws -> Data {
        try key.withKey { k in
            let box = try AES.GCM.seal(plain, using: k)
            guard let combined = box.combined else { throw CocoaError(.coderInvalidValue) }
            return magic + combined
        }
    }

    static func isEncrypted(_ data: Data) -> Bool {
        data.count > magic.count && data.prefix(magic.count) == magic
    }

    static func decrypt(_ data: Data, key: SecureKey) throws -> Data {
        guard isEncrypted(data) else { return data }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(magic.count))
        return try key.withKey { try AES.GCM.open(box, using: $0) }
    }

    // MARK: Enable / verify / disable

    /// Create the vault for a new password and return its key.
    static func enable(password: SecureBuffer) throws -> SecureKey {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = deriveKey(password: password, salt: salt)
        let check = try encrypt(okToken, key: key)
        let meta = Meta(salt: salt, check: check)
        let data = try JSONEncoder().encode(meta)
        try data.write(to: metaURL, options: .atomic)
        return key
    }

    /// Returns the key if the password matches, nil otherwise.
    static func unlock(password: SecureBuffer) -> SecureKey? {
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }
        let key = deriveKey(password: password, salt: meta.salt)
        guard let plain = try? decrypt(meta.check, key: key), plain == okToken else {
            key.zero()
            return nil
        }
        return key
    }

    /// Does this key open the vault? (Used for keys that came from Touch ID rather than a password.)
    static func verify(_ key: SecureKey) -> Bool {
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(Meta.self, from: data),
              let plain = try? decrypt(meta.check, key: key) else { return false }
        return plain == okToken
    }

    static func disable() {
        try? FileManager.default.removeItem(at: metaURL)
    }

    // MARK: Dialogs

    /// Modal password prompt built on SecurePasswordField. Returns the locked bytes, or nil on Cancel.
    /// `confirm` shows a second field and insists both match (constant-time compare).
    /// The caller must `zero()` the returned buffer when done.
    static func askPassword(title: String, message: String, confirm: Bool = false, cancelQuits: Bool = false) -> SecureBuffer? {
        while true {
            let a = NSAlert()
            a.messageText = title
            a.informativeText = message
            a.alertStyle = .informational
            a.icon = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)

            let width: CGFloat = 280
            let f1 = SecurePasswordField(frame: NSRect(x: 0, y: confirm ? 30 : 0, width: width, height: 24))
            let f2 = SecurePasswordField(frame: NSRect(x: 0, y: 0, width: width, height: 24))
            f2.placeholder = "Repeat password"
            let box = NSView(frame: NSRect(x: 0, y: 0, width: width, height: confirm ? 54 : 24))
            box.addSubview(f1)
            if confirm {
                box.addSubview(f2)
                f1.onTab = { [weak f2] in f2?.window?.makeFirstResponder(f2) }
                f2.onTab = { [weak f1] in f1?.window?.makeFirstResponder(f1) }
            }
            a.accessoryView = box
            a.addButton(withTitle: "OK")
            a.addButton(withTitle: cancelQuits ? "Quit" : "Cancel")
            a.window.initialFirstResponder = f1

            NSApp.activate(ignoringOtherApps: true)
            let result = a.runModal()
            defer { f2.buffer.zero() }
            guard result == .alertFirstButtonReturn else {
                f1.buffer.zero()
                return nil
            }
            if confirm {
                if f1.buffer.isEmpty {
                    f1.buffer.zero()
                    error("Password cannot be empty.")
                    continue
                }
                if !SecureBuffer.equal(f1.buffer, f2.buffer) {
                    f1.buffer.zero()
                    error("Passwords do not match.")
                    continue
                }
            }
            return f1.buffer
        }
    }

    static func error(_ text: String) {
        let a = NSAlert()
        a.messageText = text
        a.alertStyle = .warning
        a.runModal()
    }
}
