import AppKit
#if !APPSTORE
import Sparkle
#endif

/// Update checks. Direct-download builds use Sparkle 2 (feed on GitHub Releases, EdDSA-verified);
/// the Mac App Store build has no updater at all — the store handles updates.
///
/// The check is optional (Settings → General → *Check for updates automatically*). Sparkle is not
/// started until the setting is on, and turning it off switches its scheduler off, so with the
/// option off Keepit makes no network request at all and the menu item is not shown.
final class Updater {
#if APPSTORE
    var isConfigured: Bool { false }
    var isEnabled = false
    @objc func checkForUpdates(_ sender: Any?) {}
#else
    private let controller: SPUStandardUpdaterController
    private var started = false

    init() {
        // Never started here: `isEnabled` starts it when the setting says so
        // (and never in --selftest, so CI runs don't phone home).
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var isConfigured: Bool {
        let key = Bundle.main.infoDictionary?["SUPublicEDKey"] as? String ?? ""
        return !key.isEmpty && !key.hasPrefix("__")
    }

    /// Mirrors `Settings.checkForUpdates`. Sparkle persists `automaticallyChecksForUpdates` in
    /// user defaults, so it is set explicitly on every change rather than left to the Info.plist default.
    var isEnabled = false {
        didSet {
            guard isConfigured, !SelfTest.isActive else { return }
            if isEnabled {
                if !started {
                    do { try controller.startUpdater(); started = true } catch {
                        NSLog("Keepit: Sparkle did not start: \(error)")
                        return
                    }
                }
                controller.updater.automaticallyChecksForUpdates = true
            } else if started {
                controller.updater.automaticallyChecksForUpdates = false
            }
        }
    }

    /// Menu-driven check; a no-op while the option is off (the item is hidden then anyway).
    @objc func checkForUpdates(_ sender: Any?) {
        guard isEnabled, started else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(sender)
    }
#endif
}
