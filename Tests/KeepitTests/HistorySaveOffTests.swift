import XCTest
@testable import Keepit

/// SEC11 — with *Save history* off the file is removed when the setting is turned off, at every lock
/// and at quit; a removal that fails is reported, retried, and never pretends to have succeeded
/// (`DESIGN-3.0.7.md`, SEC11). No vault: the paths under test are the same with or without one.
final class HistorySaveOffTests: XCTestCase {
    var tmp: TempStorage!
    var off = Settings()

    override func setUpWithError() throws {
        tmp = TempStorage()
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        off.historySave = false
    }

    override func tearDown() {
        chmod(Storage.directory.path, 0o755)
        Vault.errorSinkForTesting = nil
        tmp.restore()
    }

    private var fileExists: Bool { FileManager.default.fileExists(atPath: Storage.historyURL.path) }

    /// A store with one item saved to disk, saving on.
    private func storeWithFile() -> HistoryStore {
        let h = HistoryStore(settings: Settings())
        h.add(.text("kept"))
        h.flush()
        XCTAssertTrue(fileExists)
        return h
    }

    private func makeDirectoryReadOnly() throws {
        guard getuid() != 0 else { throw XCTSkip("root deletes from a read-only directory") }
        XCTAssertEqual(chmod(Storage.directory.path, 0o500), 0)
    }

    // MARK: the toggle

    func testTurningSavingOffRemovesTheFileNow() {
        let h = storeWithFile()
        h.updateSettings(off)
        XCTAssertFalse(fileExists)
        XCTAssertEqual(h.items.map(\.plainText), ["kept"], "history itself stays, in memory")
    }

    func testTurningSavingOffWhileADebouncedWriteIsPendingRemovesNowAndThePendingItemIsANoOp() {
        let h = storeWithFile()
        h.add(.text("pending"))                               // schedules a save 1.5 s out
        h.updateSettings(off)
        XCTAssertFalse(fileExists, "removed at once, not after the debounce")
        let later = expectation(description: "debounce elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { later.fulfill() }
        wait(for: [later], timeout: 5)
        Storage.waitUntilSaved()
        XCTAssertFalse(fileExists, "the pending item, with the setting off, removes again — nothing to remove")
    }

    private struct DelayedHistory: Encodable {
        let started: DispatchSemaphore, resume: DispatchSemaphore
        func encode(to encoder: Encoder) throws {
            started.signal()
            guard resume.wait(timeout: .now() + 5) == .success else { throw CocoaError(.userCancelled) }
            try [ClipItem.text("in-flight write")].encode(to: encoder)
        }
    }

    func testTurningSavingOffWhileAWriteIsOnTheQueueRemovesAfterIt() {
        let h = storeWithFile()
        let started = DispatchSemaphore(value: 0), resume = DispatchSemaphore(value: 0)
        Storage.save(DelayedHistory(started: started, resume: resume), to: Storage.historyURL, background: true)
        XCTAssertEqual(started.wait(timeout: .now() + 3), .success)

        let toggled = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { h.updateSettings(self.off); toggled.signal() }   // removeNow is ioQueue.sync: queued behind the write
        XCTAssertEqual(toggled.wait(timeout: .now() + 0.5), .timedOut, "the removal waits for the write")
        XCTAssertTrue(fileExists)
        resume.signal()
        XCTAssertEqual(toggled.wait(timeout: .now() + 5), .success)
        Storage.waitUntilSaved()
        XCTAssertFalse(fileExists, "the write landed, then the removal: nothing revives the file")
    }

    func testAHeldFileIsNotRemovedAndTheFailureIsReportedAsHeld() throws {
        _ = storeWithFile()
        try Data("{".utf8).write(to: Storage.historyURL)      // unreadable → held on the next read
        let before = try Data(contentsOf: Storage.historyURL)
        let h = HistoryStore(settings: Settings())
        XCTAssertNotNil(h.loadFailure)
        var reported: (Error, HistoryStore.RemovalOccasion)?
        h.onSavedFileRemovalFailed = { reported = ($0, $1) }
        h.updateSettings(off)
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), before)
        guard let r = reported else { return XCTFail("not reported") }
        XCTAssertEqual(r.1, .settingChanged)
        guard case Storage.Failure.held = r.0 else { return XCTFail("\(r.0)") }
    }

    // MARK: failure, report, retry

    func testAFailedRemovalIsReportedTheSettingStaysOffAndFlushRetriesIt() throws {
        let h = storeWithFile()
        try makeDirectoryReadOnly()
        var occasions: [HistoryStore.RemovalOccasion] = []
        h.onSavedFileRemovalFailed = { _, o in occasions.append(o) }
        h.updateSettings(off)
        XCTAssertTrue(fileExists, "the unlink failed")
        XCTAssertEqual(occasions, [.settingChanged])
        XCTAssertFalse(h.settings.historySave, "the setting is what the user chose")

        // The file system comes back; nothing else changes in the history; quit → flush().
        XCTAssertEqual(chmod(Storage.directory.path, 0o755), 0)
        h.flush()
        XCTAssertFalse(fileExists, "the retry at quit removes it")
        XCTAssertEqual(occasions, [.settingChanged], "a success reports nothing")
    }

    func testALockRemovesTheFileAndAFailureThereIsReportedAsLock() throws {
        let h = storeWithFile()
        var occasions: [HistoryStore.RemovalOccasion] = []
        h.onSavedFileRemovalFailed = { _, o in occasions.append(o) }
        // Setting off while the directory is read-only: the toggle fails, the file is still there.
        try makeDirectoryReadOnly()
        h.updateSettings(off)
        XCTAssertTrue(fileExists)
        h.purge()                                              // lock: tries again, fails again
        XCTAssertTrue(fileExists)
        XCTAssertEqual(occasions, [.settingChanged, .lock])
        XCTAssertTrue(h.isPurged)
        XCTAssertEqual(chmod(Storage.directory.path, 0o755), 0)
        h.purge()                                              // the next lock succeeds
        XCTAssertFalse(fileExists)
    }

    func testRemovalRunsWhilePurgedAndSavesNothing() throws {
        let h = storeWithFile()
        h.purge()                                              // locked: memory empty, file on disk
        XCTAssertTrue(h.isPurged)
        XCTAssertTrue(fileExists)
        h.updateSettings(off)                                  // unreachable through the UI while locked; guarded anyway
        XCTAssertFalse(fileExists)
        XCTAssertTrue(h.items.isEmpty, "nothing was written: a purged store never saves")
        h.saveNow()
        XCTAssertFalse(fileExists)
    }

    func testTurningSavingOnAgainWritesTheFileAtTheNextSave() {
        let h = storeWithFile()
        h.updateSettings(off)
        XCTAssertFalse(fileExists)
        h.updateSettings(Settings())
        h.add(.text("again")); h.flush()
        XCTAssertTrue(fileExists)
    }

    // MARK: the app's side — who is told, and when

    func testTheAppTellsTheUserAboutAFailedToggleAfterApplyReturns() throws {
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        app.history.add(.text("x")); app.history.flush()
        XCTAssertTrue(fileExists)
        var errors: [String] = []
        Vault.errorSinkForTesting = { errors.append($0) }
        try makeDirectoryReadOnly()
        var s = app.settings; s.historySave = false
        app.apply(settings: s)
        XCTAssertTrue(errors.isEmpty, "not inside apply(settings:)")
        let shown = expectation(description: "alert on the next main-queue turn")
        DispatchQueue.main.async { shown.fulfill() }
        wait(for: [shown], timeout: 2)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("could not be removed"), errors[0])
        XCTAssertTrue(fileExists)
        XCTAssertFalse(app.settings.historySave)
    }

    func testAFailureDuringALockWaitsForTheUnlockAndAHeldFileIsNotRepeated() throws {
        let app = AppDelegate()
        app.loadStoresForTesting()
        var errors: [String] = []
        Vault.errorSinkForTesting = { errors.append($0) }
        // The wiring: a lock-time failure is kept, a held file is not (the SEC10 report covers it).
        app.history.onSavedFileRemovalFailed?(Storage.Failure.held("history.json"), .lock)
        XCTAssertNil(app.historyRemovalToReport)
        app.history.onSavedFileRemovalFailed?(CocoaError(.fileWriteNoPermission), .lock)
        XCTAssertNotNil(app.historyRemovalToReport)
        // Nothing is shown until the app asks, after the unlock has finished.
        XCTAssertTrue(errors.isEmpty)
        app.reportHistoryRemovalLater()
        let shown = expectation(description: "deferred report")
        DispatchQueue.main.async { shown.fulfill() }
        wait(for: [shown], timeout: 2)
        XCTAssertEqual(errors.count, 1)
        XCTAssertNil(app.historyRemovalToReport, "told once")
        // Quit and other flushes only log.
        app.history.onSavedFileRemovalFailed?(CocoaError(.fileWriteNoPermission), .flush)
        XCTAssertNil(app.historyRemovalToReport)
        XCTAssertEqual(errors.count, 1)
    }
}
