import AppKit
import Foundation

/// Version info, read from the bundle (filled in by the Makefile from the VERSION file).
enum AppInfo {
    static let name = "Keepit"
    static let fullName = "Keepit – Clipboard Manager"
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    static var versionLine: String { "\(name) \(version) (\(build))" }
    static let homepage = "https://keep.it.com"

    /// Accent for everything "Template": navy in light mode, a readable lighter navy in dark mode.
    static let templateColor = NSColor(name: "keepit.template") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.56, green: 0.66, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.0, green: 0.0, blue: 0.50, alpha: 1)
    }
    static let copyright = "© 2026 UK Intis Telecom LTD (Andrey Insarov)"
}
