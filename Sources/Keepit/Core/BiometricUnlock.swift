import Foundation
import LocalAuthentication
import Security

/// Touch ID unlock: the vault's data key is stored in the data-protection keychain behind a
/// biometry-only access control (Secure Enclave backed, invalidated when fingerprints change).
/// The password remains the fallback; this only adds a second way to obtain the same key.
enum BiometricUnlock {
    private static let service = "com.it.keep.vault"
    private static let account = "data-key"

    enum Failure: Error, LocalizedError {
        case notAvailable
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Touch ID is not available on this Mac."
            case .keychain(let s):
                if s == -34018 {   // errSecMissingEntitlement
                    return "This build is not signed with a Team ID, so it cannot use the protected keychain. Touch ID works in the signed release build."
                }
                return "Keychain error \(s): \(SecCopyErrorMessageString(s, nil) as String? ?? "")"
            }
        }
    }

    /// Hardware + enrolled fingerprints present.
    static var isAvailable: Bool {
        var err: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    /// A key is stored for this app (checked without prompting).
    static var isConfigured: Bool {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
            kSecReturnData as String: false,
        ]
        let st = SecItemCopyMatching(q as CFDictionary, nil)
        return st == errSecSuccess || st == errSecInteractionNotAllowed
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
    static func retrieve(reason: String) -> SecureKey? {
        let ctx = LAContext()
        ctx.localizedReason = reason
        ctx.localizedCancelTitle = "Use Password"
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
            if st != errSecUserCanceled && st != errSecItemNotFound { NSLog("Keepit: Touch ID unlock failed: \(st)") }
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
