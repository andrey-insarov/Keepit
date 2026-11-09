import Foundation
import Security

/// Who sent a keepit:// command, as the OS can vouch for it (SEC07). A bundle identifier is a claim
/// any local program can make; the signing identity is not. Read from the Apple Event's sender
/// **audit token** — a PID can be reused between the event and the check, a token cannot.
///
/// Keepit never stores or evaluates the sender's own designated requirement (a developer may write
/// an arbitrarily wide one). Trust is a pair (`identifier`, `teamID`) from which Keepit builds its
/// own requirement in a fixed template, and the Security framework evaluates that against the live
/// code: chain, identifier and Team ID are Keepit's conditions; Keepit compares no strings itself.
struct CodeIdentity: Equatable {
    /// The signing identifier (for an app, its bundle identifier as signed).
    let identifier: String
    /// The Team ID (`subject.OU` of the leaf), nil for Apple's own code and for ad-hoc signatures.
    let teamID: String?
    /// Apple-signed with no Team ID: Shortcuts, Automator, Script Editor, `osascript`, Terminal,
    /// `open`. The signature names an Apple interpreter, not the script it runs — such a sender is
    /// asked every time and never offered *Always Allow*.
    let isAppleHost: Bool
    /// The code object, for `validates(_:)`. Not part of equality.
    private let code: SecCode?

    static func == (a: CodeIdentity, b: CodeIdentity) -> Bool {
        a.identifier == b.identifier && a.teamID == b.teamID && a.isAppleHost == b.isAppleHost
    }

    /// Tests only: an identity with no code object; `validates` then answers through `validatesForTesting`.
    init(identifier: String, teamID: String?, isAppleHost: Bool) {
        self.identifier = identifier; self.teamID = teamID; self.isAppleHost = isAppleHost; code = nil
    }
    private init(identifier: String, teamID: String?, isAppleHost: Bool, code: SecCode) {
        self.identifier = identifier; self.teamID = teamID; self.isAppleHost = isAppleHost; self.code = code
    }
    static var validatesForTesting: ((CodeIdentity, TrustedSender) -> Bool)?

    /// Why a sender has no identity. Every case is "unidentified" to the app; the distinction is
    /// for the log and the tests.
    enum ReadError: Error, Equatable {
        case noCode(OSStatus)          // no such process, or the guest could not be resolved
        case invalid(OSStatus)         // the running code does not validate against its own signature
        case noStaticCode(OSStatus)
        case noSigningInformation(OSStatus)
        case noIdentifier              // unsigned: no signing identifier at all
        case adHoc                     // no Team ID and not Apple's: `anchor apple` fails
    }

    /// The sender named by an audit token (`keySenderAuditTokenAttr`), or nil when it is unsigned,
    /// ad-hoc signed, does not validate against its own signature, or is gone.
    static func read(auditToken: Data) -> CodeIdentity? {
        guard auditToken.count == MemoryLayout<audit_token_t>.size else { return nil }
        switch read(attributes: [kSecGuestAttributeAudit: auditToken]) {
        case .success(let i): return i
        case .failure(let e): Log.system.notice("keepit:// sender has no identity: \(String(describing: e), privacy: .public)"); return nil
        }
    }

    /// By PID — for tests and diagnostics; the app uses the audit token.
    static func read(pid: pid_t) -> Result<CodeIdentity, ReadError> {
        read(attributes: [kSecGuestAttributePid: NSNumber(value: pid)])
    }

    private static func read(attributes: [CFString: Any]) -> Result<CodeIdentity, ReadError> {
        var codeRef: SecCode?
        var status = SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, [], &codeRef)
        guard status == errSecSuccess, let code = codeRef else { return .failure(.noCode(status)) }
        // The running code must validate against its own signature: a tampered binary has no identity.
        status = SecCodeCheckValidity(code, [], nil)
        guard status == errSecSuccess else { return .failure(.invalid(status)) }
        var staticRef: SecStaticCode?
        status = SecCodeCopyStaticCode(code, [], &staticRef)
        guard status == errSecSuccess, let staticCode = staticRef else { return .failure(.noStaticCode(status)) }
        var infoRef: CFDictionary?
        status = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)), &infoRef)
        guard status == errSecSuccess, let info = infoRef as? [String: Any] else { return .failure(.noSigningInformation(status)) }
        guard let identifier = info[kSecCodeInfoIdentifier as String] as? String, !identifier.isEmpty else { return .failure(.noIdentifier) }
        let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String
        // Apple's own code: no Team ID, and it satisfies `anchor apple`. Ad-hoc code has no Team ID
        // either and fails it — no identity.
        var apple = false
        if teamID == nil {
            guard let req = Self.requirement("anchor apple"), SecCodeCheckValidityWithErrors(code, [], req, nil) == errSecSuccess else { return .failure(.adHoc) }
            apple = true
        }
        return .success(CodeIdentity(identifier: identifier, teamID: teamID, isAppleHost: apple, code: code))
    }

    /// Whether this live sender satisfies the requirement Keepit builds for `trusted`. The chain
    /// (Developer ID or Mac App Store), the identifier and the Team ID are all evaluated by the
    /// Security framework against the code object; a failure of any kind is "no".
    func validates(_ trusted: TrustedSender) -> Bool {
        if let test = Self.validatesForTesting { return test(self, trusted) }
        guard let code, let text = trusted.requirementString, let req = Self.requirement(text) else { return false }
        return SecCodeCheckValidityWithErrors(code, [], req, nil) == errSecSuccess
    }

    private static func requirement(_ text: String) -> SecRequirement? {
        var ref: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &ref) == errSecSuccess else { return nil }
        return ref
    }

    /// Tests only: the requirement text Keepit would build, or nil if the pair is refused.
    static func requirementText(identifier: String, teamID: String) -> String? {
        TrustedSender(identifier: identifier, teamID: teamID, displayName: "").requirementString
    }
}

/// One *Always Allow*: a third-party application, by the two facts Keepit's requirement is built from.
struct TrustedSender: Codable, Equatable, Hashable {
    var identifier: String
    var teamID: String
    /// For the Settings list only.
    var displayName: String

    /// A bundle identifier: letters, digits, `.`, `-`, `_`, up to 255, starting with a letter or digit.
    static func isValidIdentifier(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first, s.unicodeScalars.count <= 255 else { return false }
        func alnum(_ c: Unicode.Scalar) -> Bool { (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c >= "0" && c <= "9") }
        guard alnum(first) else { return false }
        return s.unicodeScalars.allSatisfy { alnum($0) || $0 == "." || $0 == "-" || $0 == "_" }
    }
    /// A Team ID: exactly ten upper-case letters or digits.
    static func isValidTeamID(_ s: String) -> Bool {
        s.unicodeScalars.count == 10 && s.unicodeScalars.allSatisfy { ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") }
    }

    /// Keepit's requirement for this sender, in a fixed template; nil when either fact is outside
    /// the accepted syntax — nothing outside `[A-Za-z0-9._-]` and `[A-Z0-9]` can reach the string,
    /// so no literal can close a quote or inject requirement language.
    var requirementString: String? {
        guard Self.isValidIdentifier(identifier), Self.isValidTeamID(teamID) else { return nil }
        return "anchor apple generic and identifier \"\(identifier)\" and "
            + "(certificate leaf[field.1.2.840.113635.100.6.1.9] exists or "
            + "(certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists)) and "
            + "certificate leaf[subject.OU] = \"\(teamID)\""
    }
}
