import AppKit
import XCTest
@testable import Keepit

/// The auditor's probes against db57456 (3.0.6 audit of SEC10, round 7): two defects inverted,
/// the control probe as written.
final class Sec10RoundSevenAuditTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    private func makeAppWithPendingSettings() throws -> AppDelegate {
        Storage.save([ClipItem.text("healthy")], to: Storage.historyURL)
        try Data("settings.json.corrupt-123".utf8).write(to: Storage.setAsideMarker)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.settingsLoadFailure, .interruptedMove)
        XCTAssertTrue(Storage.isHeld(Storage.settingsURL))
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        return app
    }

    private func replacePlan(for app: AppDelegate) throws -> RestorePlan {
        let backup = Backup.Payload(history: [.text("from backup")], templates: TemplateNode(name: "Template"), settings: nil)
        return try RestorePlan.make(mode: .replace, payload: backup, currentHistory: app.history.items,
                                    currentTemplates: app.templates.root, currentSettings: Settings(),
                                    restorePreferences: false, folderName: "Imported")
    }

    /// P2 (1): a Replace that fails from `.pending` — nothing was moved, so there is nothing to put
    /// back, but every protection the commit lifted comes back.
    func testFailedPendingReplaceKeepsBothProtections() throws {
        let app = try makeAppWithPendingSettings()
        let historyBefore = try Data(contentsOf: Storage.historyURL)
        let fm = FileManager.default
        let path = Storage.templatesURL.path
        try fm.setAttributes([.immutable: true], ofItemAtPath: path)
        defer { try? fm.setAttributes([.immutable: false], ofItemAtPath: path) }

        XCTAssertThrowsError(try app.commit(replacePlan(for: app))) {
            guard case RestoreCommit.Failure.writeFailed("templates.json", _)? = $0 as? RestoreCommit.Failure else {
                return XCTFail("unexpected error: \($0)")
            }
        }
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertEqual(app.settingsLoadFailure, .interruptedMove)
        XCTAssertTrue(Storage.isHeld(Storage.settingsURL))
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertTrue(fm.fileExists(atPath: Storage.setAsideMarker.path))

        app.history.add(.text("captured in safe mode"))
        app.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), historyBefore, "not written")
        XCTAssertFalse(fm.fileExists(atPath: Storage.settingsURL.path), "no defaults under its name")
        Storage.releaseAll()
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .interruptedMove, "still safe mode")
        XCTAssertTrue(fm.fileExists(atPath: Storage.setAsideMarker.path))
    }

    /// P2 (2): a launch whose journal replay fails leaves the marker alone; the launch that
    /// finishes the replay then brings settings.json back.
    func testFailedStartupReplayLeavesTheMarkerForTheRetry() throws {
        let fm = FileManager.default
        try Data("{".utf8).write(to: Storage.settingsURL)
        _ = TemplateStore()
        let aside = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        try RestoreCommit.writeJournal()
        try Storage.writeNow(Storage.encoder.encode(TemplateNode(name: "Partial restore")), to: Storage.templatesURL)
        let path = Storage.templatesURL.path
        try fm.setAttributes([.immutable: true], ofItemAtPath: path)
        defer { try? fm.setAttributes([.immutable: false], ofItemAtPath: path) }

        // The first launch's replay fails; its initializer does not touch the marker.
        let first = AppDelegate()
        XCTAssertTrue(RestoreCommit.hasArmedJournal)
        XCTAssertTrue(fm.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertTrue(fm.fileExists(atPath: aside.path))
        XCTAssertFalse(fm.fileExists(atPath: Storage.settingsURL.path))
        XCTAssertEqual(first.settingsLoadFailure, .interruptedMove, "and would quit before creating a store")

        // The next process finishes the replay, then puts the unreadable settings back.
        try fm.setAttributes([.immutable: false], ofItemAtPath: path)
        Storage.releaseAll()
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("{".utf8))
        XCTAssertFalse(fm.fileExists(atPath: aside.path))
        XCTAssertFalse(fm.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
    }

    /// Control: a Replace from `.pending` that succeeds writes the plan's settings and history.
    func testPendingReplaceCanSuccessfullyWriteSettingsAndHistory() throws {
        _ = NSApplication.shared
        let app = try makeAppWithPendingSettings()
        app.hotKeyFailureForTesting = { _ in }
        try app.commit(replacePlan(for: app))
        XCTAssertNil(app.settingsLoadFailure)
        XCTAssertFalse(Storage.isHeld(Storage.historyURL))
        XCTAssertNotNil(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertEqual(HistoryStore(settings: app.settings).items.map(\.plainText), ["from backup"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
    }
}
