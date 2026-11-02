import AppKit
import Foundation

/// Version info, read from the bundle (filled in by the Makefile from the VERSION file).
enum AppInfo {
    static let name = "Keepit"
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    /// Short git commit of the build (Makefile → Info.plist); "dev" for a bare `swift build`.
    static var gitSHA: String {
        let s = Bundle.main.infoDictionary?["KeepitGitSHA"] as? String ?? ""
        return s.isEmpty || s.hasPrefix("__") ? "dev" : s
    }
    /// Build time (UTC ISO-8601 from the Makefile), nil when unknown.
    static var buildDate: Date? {
        guard let s = Bundle.main.infoDictionary?["KeepitBuildDate"] as? String else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }
    static let supportURL = "https://keep.it.com/support"
    static let homepage = "https://keep.it.com"
    static let guideURL = URL(string: "https://keep.it.com/guide.html")!

    /// Accent for everything "Template": navy in light mode, a readable lighter navy in dark mode.
    static let templateColor = NSColor(name: "keepit.template") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.56, green: 0.66, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.0, green: 0.0, blue: 0.50, alpha: 1)
    }
    static let copyright = "© 2026 UK Intis Telecom LTD (Andrey Insarov)"
    static let tagline = L("Free and open source. Made by the team behind the it.com domain zone.")
    static let sourceURL = "https://github.com/andrey-insarov/Keepit"

}
