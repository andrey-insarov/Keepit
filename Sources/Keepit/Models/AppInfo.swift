import Foundation

/// Version info, read from the bundle (filled in by the Makefile from the VERSION file).
enum AppInfo {
    static let name = "Keep it"
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    static var versionLine: String { "\(name) \(version) (\(build))" }
    static let homepage = "https://keep.it.com"
    static let copyright = "© 2026 Andrey Insarov. Fork of CLCL © Ohno Tomoaki."
}
