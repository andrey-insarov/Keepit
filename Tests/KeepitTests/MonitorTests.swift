import XCTest
@testable import Keepit

final class MonitorTests: XCTestCase {
    func testPasswordManagersAreBuiltIn() {
        for id in ["org.keepassxc.keepassxc", "com.1password.1password", "com.bitwarden.desktop", "com.apple.Passwords"] {
            XCTAssertTrue(ClipboardMonitor.builtInIgnoredApps.contains(id), id)
        }
    }

    /// Copy in a password manager, ⌘Tab to the browser before the next poll: the browser is frontmost
    /// when the change is noticed, but the manager was in front during the interval → excluded.
    func testCopyThenImmediateAppSwitchIsStillExcluded() {
        let own = "com.it.keep"
        XCTAssertTrue(ClipboardMonitor.isExcludedSource(["org.keepassxc.keepassxc", "com.apple.Safari"], userIgnored: [], ownBundleId: own))
        XCTAssertTrue(ClipboardMonitor.isExcludedSource(["com.apple.Safari", "org.keepassxc.keepassxc"], userIgnored: [], ownBundleId: own),
                      "order of activation does not matter")
        XCTAssertFalse(ClipboardMonitor.isExcludedSource(["com.apple.Safari"], userIgnored: [], ownBundleId: own))
        XCTAssertFalse(ClipboardMonitor.isExcludedSource(["com.apple.Safari", "com.apple.Terminal"], userIgnored: [], ownBundleId: own))
    }

    func testUserIgnoreListAndOwnBundleApplyToTheWholeInterval() {
        let own = "com.it.keep"
        XCTAssertTrue(ClipboardMonitor.isExcludedSource(["com.example.secrets", "com.apple.Safari"], userIgnored: ["com.example.secrets"], ownBundleId: own))
        XCTAssertFalse(ClipboardMonitor.isExcludedSource(["com.example.secrets"], userIgnored: ["com.other"], ownBundleId: own))
        XCTAssertTrue(ClipboardMonitor.isExcludedSource(["com.apple.Safari", own], userIgnored: [], ownBundleId: own))
        XCTAssertFalse(ClipboardMonitor.isExcludedSource([], userIgnored: [], ownBundleId: own), "no attribution at all → recorded (the concealed-type check still runs)")
    }
}
