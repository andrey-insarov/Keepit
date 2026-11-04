import AppKit
import XCTest
@testable import Keepit

/// Every pane must stay inside the window, also after text that arrives later (a folder path, a
/// status line, a button title with a count). After the auditor's probes on 5656a6a.
final class LayoutTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    private func withPane(_ pane: String, trustedCount: Int = 0, body: (SettingsWindowController, NSView) throws -> Void) throws {
        _ = NSApplication.shared
        let storage = TempStorage()
        defer { storage.restore() }
        let key = "SettingsWindow.pane"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { if let previous { UserDefaults.standard.set(previous, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) } }
        UserDefaults.standard.set(pane, forKey: key)
        var settings = Settings()
        settings.trustedURLSenders = (0..<trustedCount).map { "com.audit.app\($0)" }
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
        try Storage.writeNow(JSONEncoder().encode(settings), to: Storage.settingsURL, encrypt: false)
        let app = AppDelegate()
        let controller = SettingsWindowController(app: app)
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        try body(controller, XCTUnwrap(window.contentView))
    }

    private func assertPaneFits(_ view: NSView, file: StaticString = #filePath, line: UInt = #line) throws {
        view.window?.layoutIfNeeded()
        view.layoutSubtreeIfNeeded()
        let grid = try XCTUnwrap(descendants(view).compactMap { $0 as? NSGridView }.first)
        let rect = view.convert(grid.bounds, from: grid)
        XCTAssertGreaterThanOrEqual(rect.minX, -1, "left edge \(rect) in \(view.bounds)", file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxX, view.bounds.maxX + 1, "right edge \(rect) in \(view.bounds)", file: file, line: line)
        XCTAssertGreaterThanOrEqual(rect.minY, -1, "bottom \(rect) in \(view.bounds)", file: file, line: line)
        XCTAssertLessThanOrEqual(rect.maxY, view.bounds.maxY + 1, "top \(rect) in \(view.bounds)", file: file, line: line)
        // Every text field is inside the window too, and nothing is clipped on the right.
        for f in descendants(view).compactMap({ $0 as? NSTextField }) where !f.isHidden {
            let r = view.convert(f.bounds, from: f)
            XCTAssertLessThanOrEqual(r.maxX, view.bounds.maxX + 1, "\(f.stringValue.prefix(30)) \(r)", file: file, line: line)
        }
    }

    func testEveryPaneFitsAsBuilt() throws {
        for pane in ["general", "shortcuts", "queue", "history", "menu", "security", "backup", "advanced"] {
            try withPane(pane) { _, view in try assertPaneFits(view) }
        }
    }

    func testLongFolderPathTruncatesInsideTheWindow() throws {
        try withPane("backup") { _, view in
            let path = try XCTUnwrap(descendants(view).compactMap { $0 as? NSTextField }.first { $0.stringValue == L("No folder chosen") })
            path.stringValue = "/Users/intisit/Library/Mobile Documents/com~apple~CloudDocs/some/deeply/nested/folder/for/keepit/backups"
            try assertPaneFits(view)
            XCTAssertEqual(path.lineBreakMode, .byTruncatingMiddle)
        }
    }

    func testLongStatusWrapsAndTheWindowGrows() throws {
        try withPane("backup") { _, view in
            let status = try XCTUnwrap(descendants(view).compactMap { $0 as? NSTextField }.first {
                $0.stringValue == L("Set a Keepit password (Security) to enable automatic backups.")
            })
            let before = view.bounds.height
            status.stringValue = LF("Last backup failed: %@", "You don’t have permission to save the file “Keepit-20261104T080612Z-12345678-1234-1234-1234-123456789012-12345678-1234-1234-1234-123456789012.keepit” in the folder “Keepit”.")
            try assertPaneFits(view)
            XCTAssertGreaterThan(status.bounds.height, 20, "the message wraps onto more than one line")
            XCTAssertGreaterThan(view.bounds.height, before, "the window follows the wrapped lines")
        }
    }

    func testTrustedAppsCountFitsTheButton() throws {
        try withPane("advanced", trustedCount: 3) { _, view in
            view.layoutSubtreeIfNeeded()
            let button = try XCTUnwrap(descendants(view).compactMap { $0 as? NSButton }.first { $0.title == LF("Forget Trusted Apps (%d)", 3) })
            XCTAssertGreaterThanOrEqual(button.bounds.width + 1, button.intrinsicContentSize.width,
                                        "needs \(button.intrinsicContentSize.width), has \(button.bounds.width)")
        }
    }
}
