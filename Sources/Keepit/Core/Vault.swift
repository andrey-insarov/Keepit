import AppKit
import CommonCrypto
import CryptoKit
import Foundation
import KeepitCore
import Security

/// 32 key bytes in a buffer that is wiped with memset_s on `zero()` and on deinit. The buffer is
/// mlock'ed to keep it out of swap; if the kernel refuses (resource limits), that is logged and the
/// key still works — the wipe is the guarantee, the page lock is best effort. CryptoKit's SymmetricKey
/// cannot be zeroed on demand, so one is built only for the duration of a call.
final class SecureKey {
    static let size = 32
    private let ptr: UnsafeMutableRawPointer
    private(set) var isZeroed = false
    /// True when mlock succeeded for this buffer.
    private(set) var isPageLocked = false

    init(bytes: UnsafeRawBufferPointer) {
        precondition(bytes.count == SecureKey.size)
        ptr = UnsafeMutableRawPointer.allocate(byteCount: SecureKey.size, alignment: 16)
        isPageLocked = mlock(ptr, SecureKey.size) == 0      // keep out of swap
        if !isPageLocked { Log.vault.notice("mlock failed for a key buffer (errno \(errno)); continuing without page lock") }
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
        if isPageLocked { _ = munlock(ptr, SecureKey.size) }
        ptr.deallocate()
    }
}

/// Password-based encryption of the data files.
/// Key = PBKDF2-HMAC-SHA256(password, salt, rounds) → AES-256-GCM per file.
/// Nothing derived from the password is written to disk except a GCM-sealed verifier.
/// Intermediate buffers (password bytes, derived key) are wiped as soon as they are no longer needed.
enum Vault {
    static let magic = Data("KEEPITENC1".utf8)
    private static let okToken = Data("KEEPIT-OK".utf8)

    // KDF parameters are recorded in vault.json (format 2, Keepit 2.12+) so they can change
    // later without breaking existing vaults. A file without them (format 1, ≤ 2.11.1) means
    // the values below; a vault that names a KDF this build does not know is refused, not guessed.
    // Raising `defaultRounds` only affects vaults created from then on — the data key is derived
    // from the password, so moving an existing vault to new parameters is a re-key (see rekey).
    static let formatVersion = 2
    static let kdfPBKDF2SHA256 = "pbkdf2-hmac-sha256"
    static let defaultRounds: UInt32 = 200_000
    /// Accepted range for `rounds` read from vault.json. Below: too weak to be ours. Above: a tampered
    /// file could make every unlock take hours (UInt32.max ≈ 20 000 × the default).
    static let roundsRange: ClosedRange<UInt32> = 1_000 ... 5_000_000

    enum Failure: Error, Equatable {
        case randomBytes(OSStatus)        // SecRandomCopyBytes refused
        case keyDerivation(Int32)         // CCKeyDerivationPBKDF status
        case unsupportedKDF(String)
    }

    struct Recovery: Codable {
        var salt: Data            // HKDF salt for the phrase-derived key
        var wrappedKey: Data      // data key, AES-GCM under the phrase-derived key
        var wrappedEntropy: Data  // phrase entropy, AES-GCM under the data key (lets a password change re-wrap)
    }

    struct Meta: Codable {
        var formatVersion: Int?  // nil = 1 (no KDF fields)
        var kdf: String?         // nil = pbkdf2-hmac-sha256
        var rounds: UInt32?      // nil = 200 000
        var salt: Data
        var check: Data          // encrypt(okToken) with the key
        var recovery: Recovery?  // optional: 24-word recovery phrase

        var kdfName: String { kdf ?? Vault.kdfPBKDF2SHA256 }
        var kdfRounds: UInt32 { rounds ?? Vault.defaultRounds }
    }

    /// Cryptographically random bytes; throws instead of returning zeros if the system RNG refuses.
    static func randomBytes(_ count: Int) throws -> Data {
        var d = Data(count: count)
        let status = d.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        guard status == errSecSuccess else { throw Failure.randomBytes(status) }
        return d
    }

    static var metaURL: URL { Storage.directory.appendingPathComponent("vault.json") }

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: metaURL.path) }

    // MARK: Key derivation

    /// The password arrives as locked bytes (see SecurePasswordField); no String of it exists.
    static func deriveKey(password: SecureBuffer, salt: Data, rounds: UInt32 = defaultRounds) throws -> SecureKey {
        var out = [UInt8](repeating: 0, count: SecureKey.size)
        defer {
            out.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) }
        }
        let status: Int32 = password.withBytes { pw in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     pw.baseAddress?.assumingMemoryBound(to: CChar.self), pw.count,
                                     saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds,
                                     &out, out.count)
            }
        }
        guard status == Int32(kCCSuccess) else { throw Failure.keyDerivation(status) }
        return out.withUnsafeBytes { SecureKey(bytes: $0) }
    }

    /// Key for an existing vault's parameters; nil (logged) if the vault names a KDF this build lacks.
    private static func deriveKey(password: SecureBuffer, meta: Meta) -> SecureKey? {
        guard meta.kdfName == kdfPBKDF2SHA256 else {
            Log.vault.error("vault.json uses KDF \(meta.kdfName), which this version does not support")
            return nil
        }
        guard roundsRange.contains(meta.kdfRounds) else {
            Log.vault.error("vault.json asks for \(meta.kdfRounds) KDF rounds, outside the accepted range")
            return nil
        }
        return try? deriveKey(password: password, salt: meta.salt, rounds: meta.kdfRounds)
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
    static func enable(password: SecureBuffer, rounds: UInt32 = defaultRounds) throws -> SecureKey {
        let salt = try randomBytes(16)
        let key = try deriveKey(password: password, salt: salt, rounds: rounds)
        let check = try encrypt(okToken, key: key)
        try writeMeta(Meta(formatVersion: formatVersion, kdf: kdfPBKDF2SHA256, rounds: rounds,
                           salt: salt, check: check, recovery: nil))
        return key
    }

    /// The KDF parameters of the current vault (nil when protection is off) — for the security
    /// page's "about this vault" line and for tests.
    static var kdfDescription: String? {
        guard let m = readMeta() else { return nil }
        return "\(m.kdfName), \(m.kdfRounds) rounds (format \(m.formatVersion ?? 1))"
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
        var entropy = try [UInt8](randomBytes(Mnemonic.entropyBytes))
        defer { entropy.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
        let salt = try randomBytes(16)
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

    /// The header an automatic backup carries: this vault's KDF parameters and recovery block, so
    /// the same password — or phrase — opens the file on any Mac. nil when protection is off.
    static func backupHeader(app: String, label: String? = nil, sourceID: String? = nil, backupID: String? = nil) -> Container.Header? {
        guard let m = readMeta() else { return nil }
        let rec = m.recovery.map { Container.Recovery(salt: $0.salt, wrappedKey: $0.wrappedKey, wrappedEntropy: $0.wrappedEntropy) }
        return Container.Header(mode: .auto, kdf: m.kdfName, rounds: m.kdfRounds, salt: m.salt, recovery: rec,
                                app: app, minReader: Backup.minReader, label: label, sourceID: sourceID, backupID: backupID)
    }

    /// Returns the key if the password matches, nil otherwise.
    static func unlock(password: SecureBuffer) -> SecureKey? {
        guard let meta = readMeta(), let key = deriveKey(password: password, meta: meta) else { return nil }
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
    /// `recoveryAvailable` overrides the local vault's state — a backup file carries its own recovery block.
    static func prompt(title: String, message: String, confirm: Bool = false, cancelQuits: Bool = false, offerRecovery: Bool, recoveryAvailable: Bool? = nil) -> PromptResult {
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
            // The first field leaves room for the on-screen keyboard button; the keyboard types into
            // whichever of the two fields has focus.
            let kbWidth: CGFloat = 24, kbGap: CGFloat = 4
            let f1 = SecurePasswordField(frame: NSRect(x: 0, y: boxHeight - indicatorHeight - 24, width: width - kbWidth - kbGap, height: 24))
            let f2 = SecurePasswordField(frame: NSRect(x: 0, y: 0, width: width, height: 24))
            let kb = NSButton(frame: NSRect(x: width - kbWidth, y: f1.frame.minY, width: kbWidth, height: 24))
            kb.bezelStyle = .texturedRounded
            kb.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: L("On-screen keyboard"))
            kb.imagePosition = .imageOnly
            kb.toolTip = L("On-screen keyboard: shuffled keys, no keyboard events, asks macOS to stay out of screen capture")
            kb.setButtonType(.momentaryPushIn)
            let keyboard = OnScreenKeyboard()
            kb.target = keyboard
            kb.action = #selector(OnScreenKeyboard.toggle(_:))
            keyboard.targetField = { [weak f1, weak f2] in
                (f1?.window?.firstResponder as? SecurePasswordField).flatMap { $0 === f1 || $0 === f2 ? $0 : nil } ?? f1
            }
            f2.placeholder = L("Repeat password")
            let box = NSView(frame: NSRect(x: 0, y: 0, width: width, height: boxHeight))
            let indicator = InputSourceIndicator(width: width)
            indicator.frame.origin = NSPoint(x: 0, y: boxHeight - indicatorHeight + 1)
            box.addSubview(indicator)
            box.addSubview(f1)
            box.addSubview(kb)
            var meter: PasswordStrengthView?
            if confirm {
                let m = PasswordStrengthView(frame: NSRect(x: 0, y: 24 + 6, width: width, height: meterHeight))
                box.addSubview(m)
                meter = m
                box.addSubview(f2)
                f1.onTab = { [weak f2] in f2?.window?.makeFirstResponder(f2) }
                f2.onTab = { [weak f1] in f1?.window?.makeFirstResponder(f1) }
            }
            a.accessoryView = box
            let ok = a.addButton(withTitle: L("OK"))
            a.addButton(withTitle: cancelQuits ? L("Quit") : L("Cancel"))
            if offerRecovery && (recoveryAvailable ?? hasRecovery) { a.addButton(withTitle: L("Recovery Access…")) }
            a.window.initialFirstResponder = f1

            // OK (and ↩) only once there is a password — and, when confirming, once both fields
            // agree. Checked on every change, from either keyboard; the compare is constant-time.
            let refresh: () -> Void = { [weak f1, weak f2, weak ok, weak meter] in
                guard let f1, let ok else { return }
                if let meter { meter.update(PasswordStrength.evaluate(f1.buffer)) }
                let filled = !f1.buffer.isEmpty
                ok.isEnabled = confirm ? (filled && f2.map { SecureBuffer.equal(f1.buffer, $0.buffer) } == true) : filled
            }
            f1.onChange = { _ in refresh() }
            f2.onChange = { _ in refresh() }
            refresh()

            NSApp.activate(ignoringOtherApps: true)
            let result = a.runModal()
            keyboard.close()
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
