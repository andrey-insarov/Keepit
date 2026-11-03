import XCTest
@testable import Keepit
@testable import KeepitCore

/// The automatic backup engine against docs/BACKUP.md, with a plain folder, an injected clock and
/// a vault in a temporary data directory.
final class BackupEngineTests: XCTestCase {
    var tmp: TempStorage!
    var folder: URL!
    var engine: BackupEngine!
    var history: HistoryStore!
    var templates: TemplateStore!
    var clock = Date(timeIntervalSince1970: 1_800_000_000)
    var key: SecureKey!

    override func setUpWithError() throws {
        tmp = TempStorage()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("keepit-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        key = try Vault.enable(password: .of("vault pw"))
        _ = try Vault.createRecovery(for: key)
        Storage.key = key
        var s = Settings(); s.historySave = false
        history = HistoryStore(settings: s)
        templates = TemplateStore()
        engine = BackupEngine(stateURL: Storage.directory.appendingPathComponent("backup.json"), sourceID: "src-a")
        engine.destination = PlainFolderDestination(folder)
        engine.keepCount = 10
        engine.now = { [unowned self] in self.clock }
        engine.snapshotProvider = { [unowned self] in self.snapshot() }
        history.onChange = { [unowned self] in self.engine.noteChange() }
        templates.onChange = { [unowned self] in self.engine.noteChange() }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        tmp.restore()
    }

    private func snapshot() -> BackupEngine.Snapshot? {
        guard let k = Storage.key, let header = Vault.backupHeader(app: "Keepit test"),
              let tree = try? Storage.encoder.encode(templates.root) else { return nil }
        return .init(history: history.items, templatesJSON: tree, settings: nil, header: header, dataKey: k,
                     credentialsStamp: BackupEngine.credentialsStamp(header))
    }

    @discardableResult
    private func run(force: Bool = false) -> Result<Void, Error> {
        let e = expectation(description: "backup")
        var out: Result<Void, Error> = .failure(BackupEngine.Failure.nothingToBackUp)
        if force { engine.backUpNow { out = $0; e.fulfill() } } else { engine.runIfDue { out = $0; e.fulfill() } }
        wait(for: [e], timeout: 30)
        return out
    }

    private func ownFiles() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasPrefix("Keepit-") && $0.hasSuffix(".keepit") }.sorted()
    }
    private func allFiles() -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() }
    private func failure(_ r: Result<Void, Error>) -> BackupEngine.Failure? { if case .failure(let e) = r { return e as? BackupEngine.Failure } else { return nil } }

    func testQuietPeriodThenOneFileThatOpensWithPasswordAndPhrase() throws {
        history.add(.text("one")); history.add(.text("two")); history.add(.text("three"))
        XCTAssertTrue(engine.state.dirty)
        XCTAssertFalse(engine.isDue(), "not before the quiet period")
        clock.addTimeInterval(BackupEngine.quietInterval)
        XCTAssertTrue(engine.isDue())
        XCTAssertNoThrow(try run().get())
        XCTAssertEqual(ownFiles().count, 1)
        XCTAssertFalse(engine.state.dirty)
        XCTAssertEqual(engine.state.records.count, 1)
        XCTAssertNotNil(engine.state.lastSuccess)
        XCTAssertNil(engine.state.lastError)
        XCTAssertTrue(allFiles().allSatisfy { !$0.hasSuffix(BackupEngine.partSuffix) }, "no .part left behind")

        let file = try Data(contentsOf: folder.appendingPathComponent(ownFiles()[0]))
        XCTAssertEqual(try Backup.decode(file, password: .of("vault pw")).history.map(\.plainText), ["three", "two", "one"])
        XCTAssertEqual(try Backup.decode(file, dataKey: key).history.count, 3)
        guard case .v2(let h, _) = try Backup.inspect(file) else { return XCTFail() }
        XCTAssertEqual(h.sourceID, "src-a"); XCTAssertNotNil(h.backupID); XCTAssertNotNil(h.recovery); XCTAssertNil(h.label)
        XCTAssertEqual(engine.state.records[0].sha256, BackupEngine.sha256(file))
    }

    func testDeadlineFiresDespiteContinuousChanges() {
        history.add(.text("a"))
        for _ in 0 ..< 10 { clock.addTimeInterval(3 * 60); history.add(.text("still typing \(clock)")) }   // never 5 min quiet
        XCTAssertFalse(engine.isDue())
        clock.addTimeInterval(BackupEngine.deadline)
        XCTAssertTrue(engine.isDue(), "24 h after the first unsaved change")
        XCTAssertNoThrow(try run().get())
    }

    func testUnchangedContentMakesNoFileButClearsDirty() {
        history.add(.text("x")); clock.addTimeInterval(BackupEngine.quietInterval)
        XCTAssertNoThrow(try run().get())
        templates.changed()                                           // "changed" with identical content (reload-style)
        clock.addTimeInterval(BackupEngine.quietInterval)
        XCTAssertEqual(failure(run()), .nothingToBackUp)
        XCTAssertEqual(ownFiles().count, 1)
        XCTAssertFalse(engine.state.dirty)
        // forceNext (password / phrase / folder changed) → a new file with the same content
        engine.forceNext(); clock.addTimeInterval(BackupEngine.quietInterval)
        XCTAssertNoThrow(try run().get())
        XCTAssertEqual(ownFiles().count, 2)
        // Back Up Now ignores timers and fingerprint
        XCTAssertNoThrow(try run(force: true).get())
        XCTAssertEqual(ownFiles().count, 3)
    }

    func testLockedIsNotAFailureAndKeepsDirty() {
        history.add(.text("x")); clock.addTimeInterval(BackupEngine.quietInterval)
        engine.snapshotProvider = { nil }                              // locked / no vault
        XCTAssertEqual(failure(run()), .locked)
        XCTAssertTrue(engine.state.dirty)
        XCTAssertNil(engine.state.nextRetryAt, "no backoff for a locked app")
        XCTAssertEqual(engine.state.failures, 0)
        engine.snapshotProvider = { [unowned self] in self.snapshot() }
        XCTAssertNoThrow(try run().get())                               // runs right after "unlock"
    }

    func testFolderGoneIsRetriedWithBackoffAndLeavesNothing() throws {
        history.add(.text("x")); clock.addTimeInterval(BackupEngine.quietInterval)
        try FileManager.default.removeItem(at: folder)
        guard case .writeFailed = failure(run()) else { return XCTFail("expected writeFailed") }
        XCTAssertTrue(engine.state.dirty)
        XCTAssertEqual(engine.state.failures, 1)
        XCTAssertNotNil(engine.state.lastError)
        XCTAssertEqual(engine.state.nextRetryAt, clock.addingTimeInterval(BackupEngine.retryDelays[0]))
        XCTAssertFalse(engine.isDue(), "not before the retry time")
        clock.addTimeInterval(BackupEngine.retryDelays[0])
        XCTAssertTrue(engine.isDue())
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertNoThrow(try run().get())
        XCTAssertEqual(engine.state.failures, 0); XCTAssertNil(engine.state.lastError)
    }

    func testRotationKeepsOwnSeriesOnlyAndSparesEverythingElse() throws {
        engine.keepCount = 2
        try Data("foreign".utf8).write(to: folder.appendingPathComponent("Keepit-20200101T000000Z-src-b-other.keepit"))
        try Data("rollback".utf8).write(to: folder.appendingPathComponent(BackupEngine.beforeRestorePrefix + "x.keepit"))
        try Data("note".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        for i in 0 ..< 4 {
            history.add(.text("item \(i)")); clock.addTimeInterval(BackupEngine.quietInterval)
            XCTAssertNoThrow(try run().get())
        }
        XCTAssertEqual(engine.state.records.count, 2)
        let own = ownFiles().filter { $0.contains("-src-a-") }
        XCTAssertEqual(own.count, 2)
        XCTAssertEqual(Set(own), Set(engine.state.records.map(\.name)))
        XCTAssertTrue(allFiles().contains("Keepit-20200101T000000Z-src-b-other.keepit"))
        XCTAssertTrue(allFiles().contains(BackupEngine.beforeRestorePrefix + "x.keepit"))
        XCTAssertTrue(allFiles().contains("notes.txt"))
        // A file deleted by hand: no error, nothing else touched.
        try FileManager.default.removeItem(at: folder.appendingPathComponent(own[0]))
        history.add(.text("more")); clock.addTimeInterval(BackupEngine.quietInterval)
        XCTAssertNoThrow(try run().get())
        XCTAssertTrue(allFiles().contains("notes.txt"))
    }

    func testStatePersistsAcrossRelaunch() {
        history.add(.text("x"))
        let again = BackupEngine(stateURL: Storage.directory.appendingPathComponent("backup.json"), sourceID: "src-a")
        XCTAssertTrue(again.state.dirty)
        XCTAssertEqual(again.state.firstDirtyAt, clock)
        again.now = { [unowned self] in self.clock }
        XCTAssertTrue(again.isDue(), "dirty from a previous run, no change since launch → due now")
    }

    /// Lock must not wait for a slow destination: the key is wiped while the write is still going.
    func testLockDoesNotWaitForTheWrite() {
        final class Slow: BackupDestination {
            let url: URL; init(_ u: URL) { url = u }
            var displayPath: String { url.path }
            func withFolder<T>(_ body: (URL) throws -> T) throws -> T { Thread.sleep(forTimeInterval: 2); return try body(url) }
        }
        engine.destination = Slow(folder)
        history.add(.text("x")); clock.addTimeInterval(BackupEngine.quietInterval)
        let done = expectation(description: "backup")
        var result: Result<Void, Error>?
        engine.runIfDue { result = $0; done.fulfill() }
        let t0 = Date()
        Storage.clearKey()                                             // waits for ioQueue (seal), not for the write
        XCTAssertLessThan(Date().timeIntervalSince(t0), 1.0)
        XCTAssertTrue(key.isZeroed)
        wait(for: [done], timeout: 30)
        XCTAssertNoThrow(try result!.get(), "the bytes were sealed and verified before the key went away")
        XCTAssertEqual(ownFiles().count, 1)
    }

    func testFileNameAndFingerprintRules() {
        let n = BackupEngine.fileName(created: Date(timeIntervalSince1970: 1_762_164_765), sourceID: "s", backupID: "b")
        XCTAssertEqual(n, "Keepit-20251103T101245Z-s-b.keepit")
        let t = Data("{}".utf8)
        XCTAssertEqual(BackupEngine.fingerprint(history: [], templates: t, settings: nil), BackupEngine.fingerprint(history: [], templates: t, settings: nil))
        XCTAssertNotEqual(BackupEngine.fingerprint(history: [.text("a")], templates: t, settings: nil), BackupEngine.fingerprint(history: [], templates: t, settings: nil))
    }
}
