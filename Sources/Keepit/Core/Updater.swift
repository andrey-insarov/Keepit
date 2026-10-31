import AppKit
#if !APPSTORE
import Sparkle
#endif

/// Update checks. Direct-download builds use Sparkle 2 (feed on GitHub Releases, EdDSA-verified);
/// the Mac App Store build has no updater at all — the store handles updates.
final class Updater {
#if APPSTORE
    var isConfigured: Bool { false }
    @objc func checkForUpdates(_ sender: Any?) {}
#else
    private let controller: SPUStandardUpdaterController

    init() {
        // startingUpdater: false in --selftest so CI runs don't phone home.
        controller = SPUStandardUpdaterController(startingUpdater: !SelfTest.isActive, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var isConfigured: Bool {
        let key = Bundle.main.infoDictionary?["SUPublicEDKey"] as? String ?? ""
        return !key.isEmpty && !key.hasPrefix("__")
    }

    @objc func checkForUpdates(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(sender)
    }
#endif
}
