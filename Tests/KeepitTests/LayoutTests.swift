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
        settings.trustedURLSenderIdentities = (0..<trustedCount).map { TrustedSender(identifier: "com.audit.app\($0)", teamID: "AUDIT00000", displayName: "App \($0)") }
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

    /// The Viewer's image pane: a picture larger than the pane is scaled into it, in place, with the
    /// size line at the left — not a 2x corner of it pushed to the right (3.0.1, a 1397×868 screenshot).
    func testViewerImagePaneFitsALargePicture() throws {
        _ = NSApplication.shared
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let pane = ImageFormatView(frame: .zero)
        host.addSubview(pane)
        host.pinToEdges(pane)
        let big = NSImage(size: NSSize(width: 1397, height: 868), flipped: false) { r in NSColor.red.setFill(); r.fill(); return true }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(big.tiffRepresentation))?.representation(using: .png, properties: [:]))
        pane.load(data: png)
        host.layoutSubtreeIfNeeded()
        let image = try XCTUnwrap(descendants(pane).compactMap { $0 as? NSImageView }.first)
        let info = try XCTUnwrap(descendants(pane).compactMap { $0 as? NSTextField }.first)
        XCTAssertEqual(pane.frame, host.bounds)
        XCTAssertLessThanOrEqual(image.frame.maxX, host.bounds.maxX, "image view \(image.frame) in \(host.bounds)")
        XCTAssertGreaterThanOrEqual(image.frame.width, 300, "the image view fills the pane, it is not squeezed by the picture's own size")
        XCTAssertLessThan(info.frame.minX, 20, "size line at the left: \(info.frame)")
        XCTAssertTrue(info.stringValue.hasPrefix("1397×868 px"), info.stringValue)
        // Drawn scaled to fit and centred, not a corner at natural size: the view's own policy, and the
        // picture it draws — red where the picture is, the background colour outside it.
        XCTAssertEqual(image.imageScaling, .scaleProportionallyDown)
        XCTAssertEqual(image.imageAlignment, .alignCenter)
        let drawn = try XCTUnwrap(image.bitmapImageRepForCachingDisplay(in: image.bounds))
        image.cacheDisplay(in: image.bounds, to: drawn)
        func red(_ x: CGFloat, _ y: CGFloat) -> Bool {
            let sx = CGFloat(drawn.pixelsWide) / image.bounds.width, sy = CGFloat(drawn.pixelsHigh) / image.bounds.height
            let c = drawn.colorAt(x: Int(x * sx), y: Int((image.bounds.height - y) * sy) - 1)?.usingColorSpace(.sRGB)
            return (c?.redComponent ?? 0) > 0.8 && (c?.greenComponent ?? 1) < 0.2
        }
        let b = image.bounds
        let fitted = b.width * 868 / 1397                       // the picture's height once its width fills the view
        XCTAssertLessThan(fitted, b.height - 20, "the fixture letterboxes top and bottom: \(fitted) of \(b.height)")
        XCTAssertTrue(red(b.midX, b.midY), "the middle of the view shows the picture")
        XCTAssertTrue(red(2, b.midY), "the picture reaches the left edge: the full width is used")
        XCTAssertTrue(red(b.maxX - 3, b.midY), "and the right edge")
        XCTAssertFalse(red(b.midX, 2), "but not the bottom of the view")
        XCTAssertFalse(red(b.midX, b.maxY - 3), "nor the top: centred, not a corner")
        // A tiny picture (25×119, a Parallels console icon) must not shrink the pane to its own size
        // either: on 3.0.1 it folded the whole Viewer — toolbar mid-window, both panes 150 pt tall.
        let tiny = NSImage(size: NSSize(width: 25, height: 119), flipped: false) { r in NSColor.blue.setFill(); r.fill(); return true }
        pane.load(data: try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(tiny.tiffRepresentation))?.representation(using: .png, properties: [:])))
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(pane.frame, host.bounds)
        XCTAssertGreaterThanOrEqual(image.frame.height, 200, "the image view keeps the pane's height, not the picture's: \(image.frame)")
        XCTAssertLessThan(pane.fittingSize.height, 60, "the pane asks for no size of its own: \(pane.fittingSize)")
    }

    /// The whole Viewer window with a small picture selected: toolbar at the top, split view filling the
    /// rest. On 3.0.1 a 611×49 item folded the window — split view 88 pt tall at the bottom, toolbar
    /// floating in the middle — with no constraint conflict logged: two views hugging at the same priority.
    func testViewerWindowKeepsItsShapeWithASmallPicture() throws {
        _ = NSApplication.shared
        let storage = TempStorage()
        defer { storage.restore() }
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
        let app = AppDelegate()
        app.loadStoresForTesting()
        let tiny = NSImage(size: NSSize(width: 235, height: 199), flipped: false) { r in NSColor.gray.setFill(); r.fill(); return true }
        let png = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(tiny.tiffRepresentation))?.representation(using: .png, properties: [:]))
        let item = ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.png: png], sourceApp: nil, contentHash: ClipItem.hash(of: png))
        app.history.add(item)
        let viewer = ViewerWindowController(app: app)
        let window = try XCTUnwrap(viewer.window)
        defer { window.close() }
        window.setContentSize(NSSize(width: 900, height: 560))
        viewer.reveal(historyId: item.id)
        window.layoutIfNeeded()
        let content = try XCTUnwrap(window.contentView)
        let split = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSplitView }.first)
        let pane = try XCTUnwrap(descendants(content).compactMap { $0 as? ImageFormatView }.first, "the picture pane is shown")
        XCTAssertGreaterThan(split.frame.height, 400, "the split view fills the window, not the picture: \(split.frame) in \(content.bounds)")
        XCTAssertGreaterThan(split.frame.maxY, content.bounds.maxY - 80, "the split view reaches up to the toolbar: \(split.frame)")
        // The pane covers the split view's right side exactly — the same edges in window coordinates.
        let right = try XCTUnwrap(split.arrangedSubviews.last)
        let rightRect = content.convert(right.bounds, from: right)
        let paneRect = content.convert(pane.bounds, from: pane)
        XCTAssertEqual(paneRect.minX, rightRect.minX, accuracy: 1, "left edge at the divider: \(paneRect) vs \(rightRect)")
        XCTAssertEqual(paneRect.maxX, rightRect.maxX, accuracy: 1, "right edge at the window's: \(paneRect) vs \(rightRect)")
        XCTAssertEqual(paneRect.minY, rightRect.minY, accuracy: 1, "bottom: \(paneRect) vs \(rightRect)")
        XCTAssertEqual(paneRect.maxY, rightRect.maxY, accuracy: 1, "top: \(paneRect) vs \(rightRect)")
        XCTAssertGreaterThan(paneRect.width, 500, "the right side is most of a 900 pt window: \(paneRect)")
        XCTAssertGreaterThan(paneRect.height, 400, "and reaches the toolbar: \(paneRect)")
    }
}
