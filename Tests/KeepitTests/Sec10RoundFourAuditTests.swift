import AppKit
import XCTest
@testable import Keepit

/// The auditor's probes against 61e1237 (3.0.6 audit of SEC10, round 4): the two defects
/// inverted; the two behaviours that are by design kept as they were observed, and said so.
final class Sec10RoundFourAuditTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    /// P1: Start Fresh for settings.json keeps the running limits, so a history the old file
    /// allowed is not trimmed to the defaults.
    func testSettingsOnlyStartFreshKeepsTheWholeHistory() throws {
        let count = Settings().historyMax + 1
        let originals = (0..<count).map { ClipItem.text("original-\($0)") }
        Storage.save(originals, to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.unreadableDataFiles.map(\.url), [Storage.settingsURL])
        XCTAssertEqual(app.history.items.count, count)

        app.startFresh()
        app.history.flush()

        XCTAssertEqual(app.settings.historyMax, Limits.historyMaxCeiling, "the ceilings stay until the user lowers them")
        XCTAssertEqual(app.history.items.count, count)
        let reloaded = HistoryStore(settings: app.settings)
        XCTAssertEqual(reloaded.items.count, count)
        XCTAssertTrue(reloaded.items.contains { $0.plainText == originals.last?.plainText })
        let saved = try XCTUnwrap(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertEqual(saved.historyMax, Limits.historyMaxCeiling)
        XCTAssertEqual(saved.lockAfterScreenLock, 0)
    }

    /// P2: a Replace that fails after the rename puts the unreadable settings.json back, so the
    /// next launch is in safe mode again, not a first run.
    func testFailedReplaceKeepsSafeModeAcrossARestart() throws {
        let badSettings = Data("{".utf8)
        try badSettings.write(to: Storage.settingsURL)
        Storage.save([ClipItem.text("healthy local history")], to: Storage.historyURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        let path = Storage.templatesURL.path
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: path) }
        let payload = Backup.Payload(history: [.text("from backup")], templates: TemplateNode(name: "Template"), settings: nil)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: app.history.items,
                                        currentTemplates: app.templates.root, currentSettings: Settings(),
                                        restorePreferences: false, folderName: "Imported")

        XCTAssertThrowsError(try app.commit(plan))
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        XCTAssertEqual(app.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), badSettings, "back under its name")
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).filter { $0.contains(".corrupt-") }.isEmpty)

        // The process-local holds and pins disappear on a relaunch; the file on disk is what counts.
        Storage.releaseAll()
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertTrue(restarted.hasUnreadableData)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(restarted.history.items.map(\.plainText), ["healthy local history"])
        restarted.history.add(.text("not persisted in safe mode"))
        restarted.history.flush()
        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["healthy local history"])
    }

    /// By design: safe mode restricts what Keepit persists on its own, not what the user does
    /// with their data. Pasting and Add to Templates work; templates.json is a healthy file.
    func testSafeModeLetsTheUserPasteAndFileHistory() throws {
        Storage.save([ClipItem.text("from disk")], to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        var pasted: [String] = []
        Paster.pasteSinkForTesting = { pasted.append($0.plainText ?? "") }
        defer { Paster.pasteSinkForTesting = nil }

        app.pasteItem(at: 0, plainText: false)
        XCTAssertEqual(pasted, ["from disk"])

        app.performOnLatest(.addToTemplates)
        app.templates.flush()
        XCTAssertTrue(TemplateStore().root.children.contains { $0.clip?.plainText == "from disk" })
    }

    /// By design: a setting changed in safe mode is the user's choice and takes effect in memory;
    /// it reaches settings.json only when Start Fresh writes the running settings.
    func testSettingsChangedInSafeModeStayInMemoryUntilStartFresh() throws {
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertFalse(app.settings.allowURLCommands)
        var edited = app.settings
        edited.allowURLCommands = true
        app.apply(settings: edited)
        XCTAssertTrue(app.settings.allowURLCommands)
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        XCTAssertTrue(Storage.isHeld(Storage.settingsURL))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("{".utf8))

        app.startFresh()
        let saved = try XCTUnwrap(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertTrue(saved.allowURLCommands, "the user's edit, not the defaults")
    }
}
