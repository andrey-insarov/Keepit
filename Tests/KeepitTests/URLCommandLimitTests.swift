import AppKit
import XCTest
@testable import Keepit

/// keepit:// is parsed against an allowlist with size limits before any dialog, model object or
/// store is touched (auditor, 5 Nov 2026: a 1 MiB `text`, unknown parameters and unknown commands
/// passed `parse`; 10 001 URLs queued before the app was ready).
final class URLCommandLimitTests: XCTestCase {
    private func url(_ s: String) -> URL { URL(string: s)! }

    func testUnknownCommandsAndParametersAreRefused() {
        XCTAssertNil(URLCommand.parse(url("keepit://nope")))
        XCTAssertNil(URLCommand.parse(url("keepit://paste/1?x=1")))
        XCTAssertNil(URLCommand.parse(url("keepit://add?text=a&bogus=1")))
        XCTAssertNil(URLCommand.parse(url("keepit://add?name=a")))
        XCTAssertNil(URLCommand.parse(url("keepit://template/x?copy=1&text=a")))
        XCTAssertNil(URLCommand.parse(url("keepit://")))
    }

    func testEveryListedCommandStillParses() {
        for c in URLCommand.allowed.keys {
            XCTAssertEqual(URLCommand.parse(url("keepit://\(c)"))?.command, c, c)
        }
        XCTAssertEqual(URLCommand.parse(url("keepit://add-template?text=hi&name=n"))?.params, ["text": "hi", "name": "n"])
        XCTAssertEqual(URLCommand.parse(url("keepit://template/Work/Reply?copy=1"))?.argument, "Work/Reply")
    }

    func testSizeLimitsApplyBeforeAnythingElse() {
        let okText = String(repeating: "a", count: Limits.urlCommandTextMaxBytes)
        XCTAssertNotNil(URLCommand.parse(url("keepit://add?text=\(okText)")))
        XCTAssertNil(URLCommand.parse(url("keepit://add?text=\(okText)a")))
        let longName = String(repeating: "n", count: Limits.templateNameMaxChars + 1)
        XCTAssertNil(URLCommand.parse(url("keepit://add-template?text=a&name=\(longName)")))
        let longArg = String(repeating: "p", count: Limits.urlCommandArgumentMaxChars + 1)
        XCTAssertNil(URLCommand.parse(url("keepit://template/\(longArg)")))
        let huge = "keepit://add?text=" + String(repeating: "x", count: Limits.urlCommandMaxChars)
        XCTAssertNil(URLCommand.parse(url(huge)))
        XCTAssertNil(URLCommand.parse(url("keepit://template/x?copy=123456789")))
    }

    func testPendingOpenQueueIsBounded() throws {
        _ = NSApplication.shared
        let storage = TempStorage()
        defer { storage.restore() }
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
        let app = AppDelegate()                      // not ready for opens: everything queues
        let urls = (0..<(Limits.pendingOpenURLsMax * 3 + 1)).map { url("keepit://history?\($0)") }
        app.application(NSApp, open: urls)
        XCTAssertEqual(app.pendingOpenURLs.count, Limits.pendingOpenURLsMax)
        app.application(NSApp, open: [url("keepit://viewer")])
        XCTAssertEqual(app.pendingOpenURLs.count, Limits.pendingOpenURLsMax, "a full queue takes nothing more")
    }
}
