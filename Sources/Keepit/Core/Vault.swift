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

    struct Recovery: Codable {
        var salt: Data            // HKDF salt for the phrase-derived key
        var wrappedKey: Data      // data key, AES-GCM under the phrase-derived key
        var wrappedEntropy: Data  // phrase entropy, AES-GCM under the data key (lets a password change re-wrap)
    }

    struct Meta: Codable {
        var salt: Data
        var check: Data          // encrypt(okToken) with the key
        var recovery: Recovery?  // optional: 24-word recovery phrase
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

    private static func readMeta() -> Meta? {
        guard let data = try? Data(contentsOf: metaURL) else { return nil }
        return try? JSONDecoder().decode(Meta.self, from: data)
    }

    private static func writeMeta(_ meta: Meta) throws {
        let data = try JSONEncoder().encode(meta)
        try data.write(to: metaURL, options: .atomic)
    }

    /// Create the vault for a new password and return its key. Any existing recovery block is
    /// dropped (it wrapped the old key) — call `rewrapRecovery(from:to:)` afterwards to keep it.
    static func enable(password: SecureBuffer) throws -> SecureKey {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = deriveKey(password: password, salt: salt)
        let check = try encrypt(okToken, key: key)
        try writeMeta(Meta(salt: salt, check: check, recovery: nil))
        return key
    }

    // MARK: Recovery phrase

    static var hasRecovery: Bool { readMeta()?.recovery != nil }

    private static func recoveryKey(entropy: [UInt8], salt: Data) -> SecureKey {
        let ikm = SymmetricKey(data: Data(entropy))
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: Data("keepit-recovery-v1".utf8), outputByteCount: SecureKey.size)
        return derived.withUnsafeBytes { SecureKey(bytes: $0) }
    }

    /// Generate a fresh 24-word phrase that can recover `key`, store its wrapped form, return the words.
    static func createRecovery(for key: SecureKey) throws -> [String] {
        guard var meta = readMeta() else { throw CocoaError(.fileNoSuchFile) }
        var entropy = [UInt8](repeating: 0, count: Mnemonic.entropyBytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, entropy.count, &entropy)
        defer { entropy.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let rkey = recoveryKey(entropy: entropy, salt: salt)
        defer { rkey.zero() }
        var keyBytes = key.withBytes { Data($0) }
        defer { keyBytes.resetBytes(in: 0..<keyBytes.count) }
        let wrappedKey = try encrypt(keyBytes, key: rkey)
        let wrappedEntropy = try encrypt(Data(entropy), key: key)
        meta.recovery = Recovery(salt: salt, wrappedKey: wrappedKey, wrappedEntropy: wrappedEntropy)
        try writeMeta(meta)
        return Mnemonic.encode(entropy)
    }

    /// Recover the data key from the phrase; nil if the phrase is wrong or no recovery block exists.
    static func unlockWithRecovery(words: [String]) -> SecureKey? {
        guard let rec = readMeta()?.recovery, var entropy = Mnemonic.decode(words) else { return nil }
        defer { entropy.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        let rkey = recoveryKey(entropy: entropy, salt: rec.salt)
        defer { rkey.zero() }
        guard var keyBytes = try? decrypt(rec.wrappedKey, key: rkey), keyBytes.count == SecureKey.size else { return nil }
        defer { keyBytes.resetBytes(in: 0..<keyBytes.count) }
        let key = keyBytes.withUnsafeBytes { SecureKey(bytes: $0) }
        guard verify(key) else { key.zero(); return nil }
        return key
    }

    /// After the data key changed (password change / recovery), keep the same phrase valid.
    /// `old` must be able to open the previous recovery block; returns false if there was none.
    @discardableResult
    static func rewrapRecovery(from old: SecureKey, to new: SecureKey, oldRecovery: Recovery?) throws -> Bool {
        guard let rec = oldRecovery, var meta = readMeta() else { return false }
        var entropyData = try decrypt(rec.wrappedEntropy, key: old)
        defer { entropyData.resetBytes(in: 0..<entropyData.count) }
        let entropy = [UInt8](entropyData)
        let rkey = recoveryKey(entropy: entropy, salt: rec.salt)
        defer { rkey.zero() }
        var keyBytes = new.withBytes { Data($0) }
        defer { keyBytes.resetBytes(in: 0..<keyBytes.count) }
        meta.recovery = Recovery(salt: rec.salt,
                                 wrappedKey: try encrypt(keyBytes, key: rkey),
                                 wrappedEntropy: try encrypt(entropyData, key: new))
        try writeMeta(meta)
        return true
    }

    /// Snapshot of the current recovery block (take it before `enable` replaces the meta file).
    static var currentRecovery: Recovery? { readMeta()?.recovery }

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
        guard let meta = readMeta(), let plain = try? decrypt(meta.check, key: key) else { return false }
        return plain == okToken
    }

    static func disable() {
        try? FileManager.default.removeItem(at: metaURL)
    }

    // MARK: Dialogs

    enum PromptResult {
        case password(SecureBuffer)
        case recovery
        case cancel
    }

    /// Modal password prompt built on SecurePasswordField. Returns the locked bytes, or nil on Cancel.
    /// `confirm` shows a second field and insists both match (constant-time compare).
    /// The caller must `zero()` the returned buffer when done.
    static func askPassword(title: String, message: String, confirm: Bool = false, cancelQuits: Bool = false) -> SecureBuffer? {
        if case .password(let b) = prompt(title: title, message: message, confirm: confirm, cancelQuits: cancelQuits, offerRecovery: false) {
            return b
        }
        return nil
    }

    /// Same prompt, optionally with a third "Recovery Access…" button.
    static func prompt(title: String, message: String, confirm: Bool = false, cancelQuits: Bool = false, offerRecovery: Bool) -> PromptResult {
        while true {
            let a = NSAlert()
            a.messageText = title
            a.informativeText = message
            a.alertStyle = .informational
            a.icon = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)

            let width: CGFloat = 220        // the alert (and its stacked buttons) take the accessory's width
            // Layout (top → bottom): layout/Caps Lock indicator, password, strength meter, repeat password.
            let indicatorHeight: CGFloat = 18
            let meterHeight: CGFloat = confirm ? 40 : 0
            let boxHeight: CGFloat = indicatorHeight + 24 + (confirm ? 6 + meterHeight + 6 + 24 : 0)
            let f1 = SecurePasswordField(frame: NSRect(x: 0, y: boxHeight - indicatorHeight - 24, width: width, height: 24))
            let f2 = SecurePasswordField(frame: NSRect(x: 0, y: 0, width: width, height: 24))
            f2.placeholder = L("Repeat password")
            let box = NSView(frame: NSRect(x: 0, y: 0, width: width, height: boxHeight))
            let indicator = InputSourceIndicator(width: width)
            indicator.frame.origin = NSPoint(x: 0, y: boxHeight - indicatorHeight + 1)
            box.addSubview(indicator)
            box.addSubview(f1)
            if confirm {
                let meter = PasswordStrengthView(frame: NSRect(x: 0, y: 24 + 6, width: width, height: meterHeight))
                box.addSubview(meter)
                f1.onChange = { [weak meter] buf in meter?.update(PasswordStrength.evaluate(buf)) }
                box.addSubview(f2)
                f1.onTab = { [weak f2] in f2?.window?.makeFirstResponder(f2) }
                f2.onTab = { [weak f1] in f1?.window?.makeFirstResponder(f1) }
            }
            a.accessoryView = box
            a.addButton(withTitle: L("OK"))
            a.addButton(withTitle: cancelQuits ? L("Quit") : L("Cancel"))
            if offerRecovery && hasRecovery { a.addButton(withTitle: L("Recovery Access…")) }
            a.window.initialFirstResponder = f1

            NSApp.activate(ignoringOtherApps: true)
            let result = a.runModal()
            defer { f2.buffer.zero() }
            if result == .alertThirdButtonReturn {
                f1.buffer.zero()
                return .recovery
            }
            guard result == .alertFirstButtonReturn else {
                f1.buffer.zero()
                return .cancel
            }
            if confirm {
                if f1.buffer.isEmpty {
                    f1.buffer.zero()
                    error(L("Password cannot be empty."))
                    continue
                }
                if !SecureBuffer.equal(f1.buffer, f2.buffer) {
                    f1.buffer.zero()
                    error(L("Passwords do not match."))
                    continue
                }
            }
            return .password(f1.buffer)
        }
    }

    static func error(_ text: String) {
        let a = NSAlert()
        a.messageText = text
        a.alertStyle = .warning
        a.runModal()
    }
}
