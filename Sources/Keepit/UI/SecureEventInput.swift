import AppKit
import Carbon.HIToolbox

/// Secure Event Input for the moments a secret is typed: while it is on, keystrokes go to the
/// focused app only — other processes' event taps and the input-method machinery do not see them
/// (3.0.5 security review, SEC03: the password fields and the recovery-phrase box ran without it).
///
/// A token per field or dialog: `begin()` turns it on for that holder, `end()` turns it off; both
/// are idempotent, and `deinit` ends a token its holder forgot. The system state follows a
/// process-wide count — on while any token is begun — so two fields in one dialog, or a dialog
/// opened over a field, never flip it off early. The macOS call is itself balanced per process,
/// so the count also guards against an unbalanced Disable from a stray `end()`.
final class SecureEventInput {
    private(set) static var depth = 0
    /// Tests only: the Enable/Disable calls that reached the system, in order — and a switch to
    /// keep them from reaching it (a CI runner has no keyboard to protect, and the state would
    /// outlive a failed test).
    static var callsForTesting: [String] = []
    static var suppressSystemCallsForTesting = false

    private(set) var isOn = false

    func begin() {
        guard !isOn else { return }
        isOn = true
        SecureEventInput.depth += 1
        if SecureEventInput.depth == 1 { SecureEventInput.system(enable: true) }
    }

    func end() {
        guard isOn else { return }
        isOn = false
        SecureEventInput.depth -= 1
        if SecureEventInput.depth == 0 { SecureEventInput.system(enable: false) }
    }

    deinit { end() }

    private static func system(enable: Bool) {
        callsForTesting.append(enable ? "enable" : "disable")
        guard !suppressSystemCallsForTesting else { return }
        let status = enable ? EnableSecureEventInput() : DisableSecureEventInput()
        if status != noErr { Log.vault.notice("SecureEventInput \(enable ? "enable" : "disable") failed: \(status)") }
    }
}
