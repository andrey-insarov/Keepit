import AppKit
import Sparkle

/// Sparkle 2 wrapper. The feed lives on GitHub Releases; downloads are verified with the EdDSA
/// public key in Info.plist (SUPublicEDKey) on top of the Developer ID signature.
final class Updater {
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

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }
}
