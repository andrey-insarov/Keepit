import XCTest
@testable import Keepit

final class MonitorTests: XCTestCase {
    func testPasswordManagersAreBuiltIn() {
        for id in ["org.keepassxc.keepassxc", "com.1password.1password", "com.bitwarden.desktop", "com.apple.Passwords"] {
            XCTAssertTrue(ClipboardMonitor.builtInIgnoredApps.contains(id), id)
        }
    }
}
