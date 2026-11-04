import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Touch ID unlock: the vault's data key is stored in the data-protection keychain behind a
/// biometry-only access control (Secure Enclave backed, invalidated when fingerprints change).
/// The password remains the fallback; this only adds a second way to obtain the same key.
enum BiometricUnlock {
    private static let service = "com.it.keep.vault"
    /// The keychain item belongs to a data directory: a normal installation keeps the historical
    /// name, while a test, self-test or KEEPIT_DATA_DIR run gets its own item — so Reset in one of
    /// those cannot remove the real installation's Touch ID key.
    private static var account: String {
        if Storage.isDefaultDirectory { return "data-key" }
        let digest = SHA256.hash(data: Data(Storage.directory.standardizedFileURL.path.utf8))
        return "data-key@" + digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    enum Failure: Error, LocalizedError {
        case notAvailable
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return L("Touch ID is not available on this Mac.")
            case .keychain(let s):
                if s == -34018 {   // errSecMissingEntitlement
                    return L("This build is not signed with a Team ID, so it cannot use the protected keychain. Touch ID works in the signed release build.")
                }
                return "Keychain error \(s): \(SecCopyErrorMessageString(s, nil) as String? ?? "")"
            }
        }
    }

    /// Hardware + enrolled fingerprints present (and usable right now).
    static var isAvailable: Bool {
        var err: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    /// The Mac has a biometric sensor, even if it cannot be used this second (no fingerprint enrolled
    /// yet, temporarily locked out). Used to decide whether to *offer* Touch ID at all.
    static var hasSensor: Bool {
        var err: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) { return true }
        guard let code = err.map({ LAError.Code(rawValue: $0.code) }) ?? nil else { return false }
        return code == .biometryNotEnrolled || code == .biometryLockout
    }

    /// A key is stored for this app (checked without prompting).
    static var isConfigured: Bool {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationContext as String: silentContext(),
            kSecReturnData as String: false,
        ]
        let st = SecItemCopyMatching(q as CFDictionary, nil)
        return st == errSecSuccess || st == errSecInteractionNotAllowed
    }

    private static func silentContext() -> LAContext {
        let ctx = LAContext()
        ctx.interactionNotAllowed = true
        return ctx
    }

    /// Store the data key behind Touch ID (replaces any previous entry).
    static func store(_ key: SecureKey) throws {
        guard isAvailable else { throw Failure.notAvailable }
        remove()
        var cfErr: Unmanaged<CFError>?
        guard let acl = SecAccessControlCreateWithFlags(nil,
                                                        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                        .biometryCurrentSet,
                                                        &cfErr) else {
            throw Failure.keychain(errSecParam)
        }
        var data = key.withBytes { Data($0) }
        defer { data.resetBytes(in: 0..<data.count) }
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "Keepit vault key (Touch ID)",
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessControl as String: acl,
            kSecValueData as String: data,
        ]
        let st = SecItemAdd(q as CFDictionary, nil)
        guard st == errSecSuccess else { throw Failure.keychain(st) }
    }

    /// Prompt for Touch ID and return the key; nil if the user cancelled, failed, or nothing is stored.
    /// `reasonKey` is a Localizable.strings key; it is shown in the system language (see `LSys`).
    static func retrieve(reasonKey: String) -> SecureKey? {
        let ctx = LAContext()
        ctx.localizedReason = LSys(reasonKey)
        ctx.localizedCancelTitle = LSys("Use Password")
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationContext as String: ctx,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        let st = SecItemCopyMatching(q as CFDictionary, &out)
        guard st == errSecSuccess, var d = out as? Data, d.count == SecureKey.size else {
            if st != errSecUserCanceled && st != errSecItemNotFound { Log.vault.error("Touch ID unlock failed: \(st)") }
            return nil
        }
        let key = d.withUnsafeBytes { SecureKey(bytes: $0) }
        d.resetBytes(in: 0..<d.count)
        return key
    }

    static func remove() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
