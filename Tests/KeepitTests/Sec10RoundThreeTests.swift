import AppKit
import XCTest
@testable import Keepit

/// The auditor's probes against 7b36361 (3.0.6 audit of SEC10, round 3), inverted; the
/// restart probe kept as written.
final class Sec10RoundThreeTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() {
        Storage.releaseAll()
        tmp.restore()
    }

    private func plan(_ app: AppDelegate, mode: RestorePlan.Mode = .replace) throws -> RestorePlan {
        let backup = Backup.Payload(history: [.text("from backup")], templates: TemplateNode(name: "Template"), settings: nil)
        return try RestorePlan.make(mode: mode, payload: backup, currentHistory: app.history.items,
                                    currentTemplates: app.templates.root, currentSettings: Settings(),
                                    restorePreferences: false, folderName: "Imported")
    }

    private func asides(_ prefix: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: tmp.dir.path).filter { $0.hasPrefix(prefix) }
    }

    /// P1: with only settings.json unreadable, the healthy history is loaded, so Start Fresh saves
    /// the file's items together with the session's, not the session's over them.
    func testSettingsOnlyStartFreshKeepsTheHealthyHistory() throws {
        Storage.save([ClipItem.text("on disk before failure")], to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        XCTAssertEqual(app.unreadableDataFiles.map(\.url), [Storage.settingsURL])
        XCTAssertTrue(Storage.isHeld(Storage.historyURL))
        XCTAssertEqual(app.history.items.map(\.plainText), ["on disk before failure"], "read, although pinned")

        app.history.add(.text("captured in safe mode"))
        app.startFresh()
        app.history.flush()

        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["captured in safe mode", "on disk before failure"])
        XCTAssertTrue(try asides("history.json.corrupt-").isEmpty, "nothing to set aside: the file was readable")
        XCTAssertEqual(try asides("settings.json.corrupt-").count, 1)
    }

    /// P1: the same for Replace — the healthy history counts as data to lose, so the rollback copy
    /// holds it; the commit itself replaces it as any Replace does.
    func testSettingsOnlyReplaceSeesTheHealthyHistoryAsDataToLose() throws {
        _ = NSApplication.shared
        Storage.save([ClipItem.text("on disk before failure")], to: Storage.historyURL)
        try Data("{".utf8).write(to: Storage.settingsURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.hotKeyFailureForTesting = { _ in }
        XCTAssertTrue(app.hasDataToLose, "the rollback copy is asked for")
        XCTAssertEqual(app.history.items.map(\.plainText), ["on disk before failure"])
        XCTAssertEqual(app.unreadableDataFiles.map(\.url), [Storage.settingsURL])

        try app.commit(plan(app))

        XCTAssertEqual(HistoryStore(settings: Settings()).items.map(\.plainText), ["from backup"])
        XCTAssertEqual(try asides("settings.json.corrupt-").count, 1)
        XCTAssertFalse(Storage.isHeld(Storage.historyURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: RestoreCommit.journalDirectory.path))
    }

    /// P2: a Replace whose write fails leaves safe mode as it was — no defaults applied.
    func testFailedReplaceKeepsSafeMode() throws {
        let junk = Data("{".utf8)
        try junk.write(to: Storage.settingsURL)
        Storage.save([ClipItem.text("healthy")], to: Storage.historyURL)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.hotKeyFailureForTesting = { _ in }
        XCTAssertEqual(app.unreadableDataFiles.map(\.url), [Storage.settingsURL])
        XCTAssertEqual(app.settings.lockAfterScreenLock, 0)
        let historyBytes = try Data(contentsOf: Storage.historyURL)
        let path = Storage.templatesURL.path
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: path) }

        XCTAssertThrowsError(try app.commit(plan(app))) {
            guard case RestoreCommit.Failure.writeFailed("templates.json", _)? = $0 as? RestoreCommit.Failure else {
                return XCTFail("unexpected error: \($0)")
            }
        }
        XCTAssertFalse(RestoreCommit.hasArmedJournal)
        XCTAssertEqual(app.settingsLoadFailure, .malformed, "still in safe mode")
        XCTAssertEqual(app.settings.lockAfterScreenLock, 0)
        XCTAssertTrue(Storage.isHeld(Storage.historyURL), "history.json pinned again")
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), historyBytes, "and put back by the undo")
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.settingsURL.path), "the unreadable one is beside it")
        XCTAssertEqual(try asides("settings.json.corrupt-").count, 1)
        app.history.add(.text("later")); app.history.flush()
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), historyBytes, "nothing writes it meanwhile")
    }

    private struct DelayedHistory: Encodable {
        let started: DispatchSemaphore
        let resume: DispatchSemaphore

        func encode(to encoder: Encoder) throws {
            started.signal()
            guard resume.wait(timeout: .now() + 3) == .success else { throw CocoaError(.userCancelled) }
            try [ClipItem.text("in-flight write")].encode(to: encoder)
        }
    }

    /// P2: a read and a write of one file never overlap. A read that arrives while a write is in
    /// flight waits for it and sees the new file — it neither holds it nor loses to it.
    func testReadWaitsForAnInFlightWrite() throws {
        let original = Data("{".utf8)
        let url = Storage.historyURL
        try original.write(to: url)
        let started = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        Storage.save(DelayedHistory(started: started, resume: resume), to: url, background: true)
        XCTAssertEqual(started.wait(timeout: .now() + 3), .success)

        var result: Storage.LoadResult<[ClipItem]>?
        let readDone = expectation(description: "read")
        DispatchQueue.global().async {
            result = Storage.read([ClipItem].self, from: url)      // blocks behind the write
            readDone.fulfill()
        }
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertNil(result, "still waiting")
        resume.signal()
        wait(for: [readDone], timeout: 5)
        Storage.waitUntilSaved()

        XCTAssertEqual(result?.value?.map(\.plainText), ["in-flight write"])
        XCTAssertFalse(Storage.isHeld(url))
        XCTAssertNotEqual(try Data(contentsOf: url), original)
    }

    /// Kept as the auditor wrote it: the disk state between Start Fresh's two renames loses nothing.
    func testRestartWithOnlyFirstRenameDoneKeepsBothOriginals() throws {
        let history = Data("first".utf8)
        let templates = Data("second".utf8)
        try history.write(to: Storage.historyURL)
        try templates.write(to: Storage.templatesURL)
        let aside = Storage.historyURL.appendingPathExtension("corrupt-123")
        try FileManager.default.moveItem(at: Storage.historyURL, to: aside)
        let restarted = AppDelegate()
        restarted.loadStoresForTesting()

        XCTAssertEqual(restarted.unreadableDataFiles.map(\.url), [Storage.templatesURL])
        XCTAssertTrue(restarted.history.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: aside), history)
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), templates)
    }
}
