import XCTest
@testable import Keepit

/// The auditor's probes against 5424472 (3.0.6 audit of SEC10, round 5): the put-back suffix
/// probe as written; the two interruption probes inverted — a marker written before settings.json
/// is renamed brings the file back at the next launch, so safe mode survives a stop at any point.
final class Sec10RoundFiveAuditTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    func testPutBackStripsTheEntireCounterSuffix() throws {
        let original = Storage.settingsURL
        let aside = original.appendingPathExtension("corrupt-123-2")
        let older = original.appendingPathExtension("corrupt-123")
        let originalBytes = Data("{".utf8)
        let olderBytes = Data("older".utf8)
        try originalBytes.write(to: aside)
        try olderBytes.write(to: older)

        Storage.putBack([aside])

        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
        XCTAssertTrue(Storage.isHeld(original))
        XCTAssertFalse(FileManager.default.fileExists(atPath: aside.path))
        XCTAssertEqual(try Data(contentsOf: older), olderBytes)
    }

    /// P2: a stop right after the rename, before the new settings.json exists (Start Fresh or
    /// Replace alike). The next launch finds the marker and no settings.json, puts the file back
    /// and is in safe mode again — nothing trimmed, nothing unpinned.
    func testRestartAfterSetAsideBeforeNewSettingsPutsTheFileBack() throws {
        let originals = (0...Settings().historyMax).map { ClipItem.text("local-\($0)") }
        Storage.save(originals, to: Storage.historyURL)
        let brokenSettings = Data("{".utf8)
        try brokenSettings.write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.history.items.count, originals.count)

        // Exact disk state after the rename and before new settings are written or journalled.
        let moved = try Storage.setAside([Storage.settingsURL])
        XCTAssertTrue(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path), "written before the rename")
        Storage.releaseAll()
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(restarted.history.items.count, originals.count)
        restarted.history.flush()
        XCTAssertEqual(HistoryStore(settings: .whileUnreadable).items.count, originals.count)
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), brokenSettings, "back under its name")
        XCTAssertFalse(FileManager.default.fileExists(atPath: XCTUnwrap(moved.first).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
    }

    /// P2: a stop after the journal was armed and part of the restore written. The journal replay
    /// restores history and templates and removes the half-written settings.json; the marker then
    /// puts the unreadable one back. Safe mode again, with the local history.
    func testArmedReplaceReplayPutsUnreadableSettingsBack() throws {
        let local = ClipItem.text("local")
        Storage.save([local], to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        let aside = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        Storage.unpin(Storage.historyURL)
        try RestoreCommit.writeJournal()
        XCTAssertTrue(RestoreCommit.hasArmedJournal)
        // A partial restore wrote the new history before the process stopped.
        try Storage.writeNow(Storage.encoder.encode([ClipItem.text("from backup")]), to: Storage.historyURL)
        Storage.releaseAll()

        let restarted = AppDelegate()
        restarted.loadStoresForTesting()

        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertEqual(restarted.history.items.map(\.id), [local.id])
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("{".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: aside.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
    }

    /// A completed Start Fresh or Replace leaves no marker; a leftover marker beside an existing
    /// settings.json is removed without touching anything.
    func testMarkerIsClearedWhenTheNewSettingsExist() throws {
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.startFresh()
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
        let live = try Data(contentsOf: Storage.settingsURL)

        try Data("settings.json.corrupt-1".utf8).write(to: Storage.setAsideMarker)   // a leftover
        XCTAssertFalse(Storage.recoverSetAside())
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), live)
    }

    /// The marker names a file: anything else in it is ignored.
    func testMarkerNamingAnotherPathIsIgnored() throws {
        try Data("../other.json".utf8).write(to: Storage.setAsideMarker)
        XCTAssertFalse(Storage.recoverSetAside())
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.settingsURL.path))
    }
}
