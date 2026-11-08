import XCTest
@testable import Keepit

/// The auditor's probes against 3600292 (3.0.6 audit of SEC10, round 6): three defects inverted,
/// two control probes as written. Safe mode now survives a settings save that does not land, a
/// put-back that fails at launch, and a journal whose undo failed.
final class Sec10RoundSixAuditTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    private func makeUnreadableSettings() throws -> AppDelegate {
        Storage.save([ClipItem.text("healthy history")], to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.settingsLoadFailure, .malformed)
        return app
    }

    /// Control: the journal first, then the marker — with every new file already written.
    func testArmedJournalWithAllNewFilesStillRestoresOldSettings() throws {
        _ = try makeUnreadableSettings()
        let oldHistory = try Data(contentsOf: Storage.historyURL)
        _ = try Storage.setAside([Storage.settingsURL])
        Storage.unpin(Storage.historyURL)
        try RestoreCommit.writeJournal()
        try Storage.writeNow(Storage.encoder.encode(TemplateNode(name: "Restored")), to: Storage.templatesURL)
        try Storage.writeNow(Storage.encoder.encode([ClipItem.text("restored")]), to: Storage.historyURL)
        try Storage.writeNow(Storage.encoder.encode(Settings()), to: Storage.settingsURL, encrypt: false)
        Storage.releaseAll()

        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), oldHistory)
    }

    /// Control: two set-asides in one process keep both originals; the marker names the second.
    func testTwoSettingsSetAsidesRetainBothOriginalsAndRecoverSecond() throws {
        _ = try makeUnreadableSettings()
        let first = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        Storage.save(Settings(), to: Storage.settingsURL, encrypt: false)
        Storage.clearSetAsideMarker()
        let secondBytes = Data("second damaged settings".utf8)
        try secondBytes.write(to: Storage.settingsURL)
        let second = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try String(contentsOf: Storage.setAsideMarker, encoding: .utf8), second.lastPathComponent)
        Storage.releaseAll()

        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertEqual(try Data(contentsOf: first), Data("{".utf8))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), secondBytes)
    }

    /// P2 (1): Start Fresh ends safe mode only once the new settings.json is on disk. If the save
    /// fails, the old file goes back under its name and nothing else changes.
    func testStartFreshKeepsSafeModeWhenSettingsSaveDoesNotLand() throws {
        let app = try makeUnreadableSettings()
        let aside = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        Storage.hold(Storage.settingsURL)                    // the save is refused: a stand-in for a disk error
        var reported: [String] = []
        Vault.errorSinkForTesting = { reported.append($0) }
        defer { Vault.errorSinkForTesting = nil }
        app.startOverAfterSetAside([Storage.settingsURL], moved: [aside])
        XCTAssertEqual(reported.count, 1, "the user is told")

        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("{".utf8), "put back")
        XCTAssertFalse(FileManager.default.fileExists(atPath: aside.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path), "no need for it: the file is home")
        XCTAssertEqual(app.settingsLoadFailure, .malformed, "still safe mode")
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(app.settings.lockAfterScreenLock, 0)

        Storage.releaseAll()
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
    }

    /// P2 (2): a put-back that fails at launch keeps the marker and safe mode; a later launch
    /// (or a later call) still knows which file to bring back.
    func testRecoveryKeepsMarkerAndSafeModeOnTransientRenameFailure() throws {
        _ = try makeUnreadableSettings()
        let aside = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        let fm = FileManager.default
        try fm.setAttributes([.immutable: true], ofItemAtPath: aside.path)
        defer { try? fm.setAttributes([.immutable: false], ofItemAtPath: aside.path) }
        Storage.releaseAll()

        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .interruptedMove)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertTrue(Storage.isHeld(Storage.settingsURL), "nothing writes the defaults under its name")
        XCTAssertTrue(fm.fileExists(atPath: Storage.setAsideMarker.path), "kept for the next try")
        XCTAssertEqual(restarted.unreadableDataFiles.map(\.url), [Storage.settingsURL], "reported, with Start Fresh on offer")
        restarted.history.add(.text("new")); restarted.history.flush()
        XCTAssertFalse(fm.fileExists(atPath: Storage.settingsURL.path))

        try fm.setAttributes([.immutable: false], ofItemAtPath: aside.path)
        XCTAssertEqual(Storage.recoverSetAside(), .restored)
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("{".utf8))
        XCTAssertFalse(fm.fileExists(atPath: aside.path))
        XCTAssertFalse(fm.fileExists(atPath: Storage.setAsideMarker.path))
    }

    /// A marker whose file is gone also keeps safe mode; Start Fresh from there writes the running
    /// settings and clears the marker.
    func testMarkerNamingAMissingFileKeepsSafeModeUntilStartFresh() throws {
        _ = try makeUnreadableSettings()
        let aside = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        try FileManager.default.removeItem(at: aside)
        Storage.releaseAll()

        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertEqual(restarted.settingsLoadFailure, .interruptedMove)
        XCTAssertTrue(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))

        restarted.startFresh()
        XCTAssertNil(restarted.settingsLoadFailure)
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertNotNil(Storage.read(Settings.self, from: Storage.settingsURL, encrypted: false).value)
        XCTAssertFalse(Storage.isHeld(Storage.historyURL))
    }

    /// P2 (3): with the journal still armed after a failed undo, nothing is put back now: the next
    /// launch replays the journal first and then brings settings.json back from the marker.
    func testFailedJournalUndoLeavesFilesAsideForTheReplay() throws {
        let app = try makeUnreadableSettings()               // the running app; a new AppDelegate would recover at init
        let aside = try XCTUnwrap(Storage.setAside([Storage.settingsURL]).first)
        Storage.unpin(Storage.historyURL)
        try RestoreCommit.writeJournal()

        try Storage.writeNow(Storage.encoder.encode(TemplateNode(name: "Partial restore")), to: Storage.templatesURL)
        let fm = FileManager.default
        let path = Storage.templatesURL.path
        try fm.setAttributes([.immutable: true], ofItemAtPath: path)
        defer { try? fm.setAttributes([.immutable: false], ofItemAtPath: path) }
        XCTAssertEqual(RestoreCommit.replayJournal().map(\.0), ["templates.json"])
        XCTAssertTrue(RestoreCommit.hasArmedJournal)

        // The catch of AppDelegate.commit after writeFiles threw undoFailed.
        app.undoSetAsideAfterFailedCommit(movedAside: [aside], unreadable: [Storage.settingsURL])
        XCTAssertFalse(fm.fileExists(atPath: Storage.settingsURL.path), "not put back under an armed journal")
        XCTAssertTrue(fm.fileExists(atPath: aside.path))
        XCTAssertTrue(fm.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertTrue(Storage.isHeld(Storage.settingsURL))
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))

        try fm.setAttributes([.immutable: false], ofItemAtPath: path)
        Storage.releaseAll()
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("{".utf8), "back after the replay")
        XCTAssertFalse(fm.fileExists(atPath: aside.path))
        XCTAssertFalse(fm.fileExists(atPath: Storage.setAsideMarker.path))
        XCTAssertEqual(restarted.settingsLoadFailure, .malformed)
        XCTAssertEqual(restarted.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(restarted.history.items.map(\.plainText), ["healthy history"])
    }
}
