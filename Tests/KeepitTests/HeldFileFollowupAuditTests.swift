import AppKit
import XCTest
@testable import Keepit

/// The auditor's counterexamples for 63e5ef8 (3.0.6 audit of SEC10, round 2), inverted.
final class HeldFileFollowupAuditTests: XCTestCase {
    private var tmp: TempStorage!

    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    private func app() -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.hotKeyFailureForTesting = { _ in }
        return a
    }

    /// P1: Start Fresh touches only the store whose file was unreadable.
    func testStartFreshKeepsNewItemsInHealthyHistory() throws {
        Storage.save([ClipItem.text("already on disk")], to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.templatesURL)
        let app = app()
        XCTAssertEqual(app.unreadableDataFiles.map(\.url), [Storage.templatesURL])
        app.history.add(.text("copied just now"))

        app.startFresh()
        XCTAssertFalse(app.hasUnreadableData)
        XCTAssertEqual(app.history.items.map(\.plainText), ["copied just now", "already on disk"])
        app.history.flush()
        XCTAssertEqual(HistoryStore(settings: app.settings).items.map(\.plainText), ["copied just now", "already on disk"])
        XCTAssertFalse(app.templates.root.children.isEmpty, "templates started over with the examples")
    }

    func testStartFreshKeepsHealthyHistoryWhenSavingIsOff() throws {
        var settings = Settings()
        settings.historySave = false
        Storage.save(settings, to: Storage.settingsURL, encrypt: false)
        try Data("{".utf8).write(to: Storage.templatesURL)
        let app = app()
        app.history.add(.text("kept in memory only"))
        XCTAssertEqual(app.unreadableDataFiles.map(\.url), [Storage.templatesURL])

        app.startFresh()
        XCTAssertFalse(app.hasUnreadableData)
        XCTAssertEqual(app.history.items.map(\.plainText), ["kept in memory only"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path), "saving is still off")
    }

    /// P2: nothing about an unreadable settings.json changes before the restore commit; the commit
    /// sets it aside and makes the plan's settings live in one go.
    func testReplaceChangesSettingsOnlyAtCommit() throws {
        _ = NSApplication.shared
        let badSettings = Data("{".utf8)
        try badSettings.write(to: Storage.settingsURL)
        let app = app()
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        XCTAssertEqual(app.settings.lockAfterScreenLock, 0)
        app.history.add(.text("in memory while settings were unreadable"))

        // Everything the restore does before its commit: the plan, on the defaults rather than the stand-in.
        let payload = Backup.Payload(history: [.text("from backup")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: app.history.items,
                                        currentTemplates: app.templates.root, currentSettings: Settings(),
                                        restorePreferences: false, folderName: "Imported")
        XCTAssertTrue(plan.settings.historySave)
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), badSettings, "untouched: the user can still cancel")
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path))

        try app.commit(plan)
        XCTAssertNil(app.settingsLoadFailure)
        XCTAssertTrue(app.settings.historySave)
        XCTAssertNil(app.settings.lockAfterScreenLock)
        let live = try XCTUnwrap(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertTrue(live.historySave)
        let copies = try FileManager.default.contentsOfDirectory(at: tmp.dir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("settings.json.corrupt-") }
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(copies.first)), badSettings)
        XCTAssertEqual(HistoryStore(settings: app.settings).items.map(\.plainText), ["from backup"])
        XCTAssertFalse(Storage.isHeld(Storage.historyURL))
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
    }

    /// P2: a save already queued when the read fails does not run.
    func testQueuedSaveRespectsAHoldSetAfterEnqueue() throws {
        let url = Storage.historyURL
        let original = Data("{".utf8)
        try original.write(to: url)
        let releaseQueue = DispatchSemaphore(value: 0)
        Storage.ioQueue.async { releaseQueue.wait() }

        Storage.save([ClipItem.text("queued write")], to: url, background: true)
        let failure = Storage.read([ClipItem].self, from: url).failure
        let held = Storage.isHeld(url)
        releaseQueue.signal()
        Storage.waitUntilSaved()

        XCTAssertEqual(failure, .malformed)
        XCTAssertTrue(held)
        XCTAssertTrue(Storage.isHeld(url))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
}
