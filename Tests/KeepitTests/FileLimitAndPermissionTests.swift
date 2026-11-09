import XCTest
@testable import Keepit

/// 3.0.7, the items from the 3.0.6 rounds: the history ceiling against the reader's limit, the
/// `.tooLarge` refusal in `Storage`, 0700/0600 on everything Keepit creates, `provenance` after
/// `zero()` (`DESIGN-3.0.7.md`, "Limits", "Permissions", "Also in 3.0.7").
final class FileLimitAndPermissionTests: XCTestCase {
    var tmp: TempStorage!
    var previousUmask: mode_t = 0

    override func setUpWithError() throws {
        tmp = TempStorage()
        previousUmask = umask(0)                       // the most permissive umask: the modes below are Keepit's doing
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    override func tearDown() {
        umask(previousUmask)
        Limits.historyFileBudgetForTesting = nil
        Storage.fileLimitForTesting = nil
        Storage.onWriteRefused = nil
        Storage.clearKey()
        tmp.restore()
    }

    private func mode(_ url: URL) throws -> mode_t {
        var st = stat()
        guard stat(url.path, &st) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return st.st_mode & 0o777
    }

    // MARK: limits

    func testTheHistoryByteSettingIsCappedAtWhatTheReaderAccepts() throws {
        XCTAssertLessThan(Limits.historyBytesCeiling * 4 / 3 + 16 * 1024 * 1024, Limits.dataFileMaxBytes, "Base64 of the ceiling still fits the file")
        XCTAssertGreaterThan(Limits.historyBytesCeiling, 300 * 1024 * 1024)
        let json = Data(#"{"maxHistoryBytes": 4294967296}"#.utf8)          // 4 GiB, the old ceiling and safe mode's old value
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.maxHistoryBytes, Limits.historyBytesCeiling, "clamped on decode")
        XCTAssertEqual(Settings.whileUnreadable.maxHistoryBytes, Limits.historyBytesCeiling, "safe mode's ceiling is the same")
        XCTAssertLessThanOrEqual(Settings().maxHistoryBytes, Limits.historyBytesCeiling, "the default fits")
    }

    func testSerializedEstimateIsNeverBelowTheRealSize() throws {
        let items = [ClipItem.text("hello"), ClipItem.text(String(repeating: "é", count: 10_000)), ClipItem.text("")]
        for item in items {
            let real = try Storage.encoder.encode([item]).count
            XCTAssertGreaterThanOrEqual(item.serializedEstimate, real, "estimate \(item.serializedEstimate) < real \(real)")
        }
    }

    func testTheStoreTrimsToTheFileBudgetBeforeASnapshotAndMemoryMatchesDisk() throws {
        Limits.historyFileBudgetForTesting = 64 * 1024
        var s = Settings(); s.historyMax = 1000
        let store = HistoryStore(settings: s)
        for i in 0 ..< 20 { store.add(.text(String(repeating: "x", count: 8_000) + "\(i)")) }   // ≈ 160 KB raw
        XCTAssertLessThanOrEqual(store.items.reduce(0) { $0 + $1.serializedEstimate }, 64 * 1024, "trimmed on the main thread, at the change")
        XCTAssertTrue(store.items.first!.plainText!.hasSuffix("19"), "newest survives")
        XCTAssertGreaterThan(store.items.count, 1)
        store.flush()
        let onDisk = try Storage.decoder.decode([ClipItem].self, from: Data(contentsOf: Storage.historyURL))
        XCTAssertEqual(onDisk.map(\.id), store.items.map(\.id), "disk == memory: the snapshot is the trimmed state")
        XCTAssertLessThanOrEqual(try Data(contentsOf: Storage.historyURL).count, 64 * 1024)
    }

    func testAWriteOverTheReaderLimitIsRefusedThePreviousFileStaysAndItIsReportedOnce() throws {
        let url = Storage.templatesURL
        try Storage.writeNow(Data("small".utf8), to: url, encrypt: false)
        Storage.fileLimitForTesting = 1024
        var refused: [String] = []
        Storage.onWriteRefused = { u, f in refused.append(u.lastPathComponent); XCTAssertEqual(f, .tooLarge(u.lastPathComponent)) }
        Storage.saveEncoded(Data(repeating: 0x41, count: 2048), to: url, encrypt: false)      // the fire-and-forget path
        Storage.waitUntilSaved()
        XCTAssertEqual(try Data(contentsOf: url), Data("small".utf8), "the previous file is intact")
        XCTAssertEqual(refused, ["templates.json"])
        // The throwing path a commit uses.
        XCTAssertThrowsError(try Storage.writeNow(Data(repeating: 0x41, count: 2048), to: url, encrypt: false)) {
            XCTAssertEqual($0 as? Storage.Failure, .tooLarge("templates.json"))
        }
        XCTAssertThrowsError(try Storage.writeRawNow(Data(repeating: 0x41, count: 2048), to: url))
        XCTAssertEqual(try Data(contentsOf: url), Data("small".utf8))
        // Under the limit it writes.
        Storage.fileLimitForTesting = 4096
        try Storage.writeNow(Data(repeating: 0x41, count: 2048), to: url, encrypt: false)
        XCTAssertEqual(try Data(contentsOf: url).count, 2048)
    }

    func testTheAppTellsTheUserOncePerFileAndNotWhileLocked() throws {
        let app = AppDelegate()                     // wires Storage.onWriteRefused
        app.loadStoresForTesting()
        var errors: [String] = []
        Vault.errorSinkForTesting = { errors.append($0) }
        defer { Vault.errorSinkForTesting = nil }
        Storage.onWriteRefused?(Storage.templatesURL, .tooLarge("templates.json"))
        Storage.onWriteRefused?(Storage.templatesURL, .tooLarge("templates.json"))
        let turn = expectation(description: "two main-queue turns")
        DispatchQueue.main.async { DispatchQueue.main.async { turn.fulfill() } }
        wait(for: [turn], timeout: 2)
        XCTAssertEqual(errors.count, 1, "once")
        XCTAssertTrue(errors[0].contains("templates.json"))
    }

    // MARK: permissions

    func testTheDataFolderIsCreated0700() throws {
        let fresh = FileManager.default.temporaryDirectory.appendingPathComponent("keepit-perm-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: fresh) }
        Storage.createPrivateDirectory(fresh)
        XCTAssertEqual(try mode(fresh), 0o700)
    }

    func testEveryFileKeepitCreatesIs0600FromTheFirstByte() throws {
        // A plain data file through the saver, through the throwing writer, and vault.json.
        Storage.saveEncoded(Data("h".utf8), to: Storage.historyURL, encrypt: false)
        Storage.waitUntilSaved()
        XCTAssertEqual(try mode(Storage.historyURL), 0o600)
        try Storage.writeNow(Data("t".utf8), to: Storage.templatesURL, encrypt: false)
        XCTAssertEqual(try mode(Storage.templatesURL), 0o600)
        Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000)
        XCTAssertEqual(try mode(Vault.metaURL), 0o600)
        // The temporary file is 0600 before any byte lands: no window with a wider mode.
        // (writeAtomically opens it O_CREAT|O_EXCL with 0600; a 0644 temp would be visible here.)
        for name in try FileManager.default.contentsOfDirectory(atPath: Storage.directory.path) where name.hasSuffix(".tmp") {
            XCTFail("temporary file left behind: \(name)")
        }
        // A rewrite keeps 0600 (the atomic replace is a new 0600 inode).
        try Storage.writeNow(Data("t2".utf8), to: Storage.templatesURL, encrypt: false)
        XCTAssertEqual(try mode(Storage.templatesURL), 0o600)
    }

    func testAJournalAndItsCopiesAre0600() throws {
        try Storage.writeNow(Data("live".utf8), to: Storage.historyURL, encrypt: false)
        let journal = FileJournal.restore
        try journal.write()
        defer { try? FileManager.default.removeItem(at: journal.directory) }
        XCTAssertEqual(try mode(journal.directory), 0o700)
        for name in try FileManager.default.contentsOfDirectory(atPath: journal.directory.path) {
            XCTAssertEqual(try mode(journal.directory.appendingPathComponent(name)), 0o600, name)
        }
    }

    func testARenamedFileKeepsItsModeAndAWrittenCopyGets0600() throws {
        // A pre-existing 0644 file set aside: the inode moves with its mode (documented exception).
        try Data("{".utf8).write(to: Storage.historyURL)
        chmod(Storage.historyURL.path, 0o644)
        XCTAssertEqual(try mode(Storage.historyURL), 0o644)
        let aside = try Storage.setAside([Storage.historyURL])
        XCTAssertEqual(aside.count, 1)
        XCTAssertEqual(try mode(aside[0]), 0o644, "a rename does not change the mode; stated in SECURITY.md")
        XCTAssertEqual(try mode(Storage.historyURL.deletingLastPathComponent()), 0o700)
        // A copy that Keepit *writes* (the sealed set-aside copy) is 0600.
        Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000)
        _ = Storage.sealSetAsideCopies(with: Storage.key!)
        XCTAssertEqual(try mode(aside[0]), 0o600, "rewritten by Keepit → Keepit's mode")
    }

    // MARK: SecureKey

    func testZeroingAKeyClearsItsProvenance() throws {
        let key = try Vault.enable(password: .of("pw"), rounds: 1000)
        XCTAssertNotNil(key.provenance, "set by the operation that produced the key")
        key.zero()
        XCTAssertNil(key.provenance, "a zeroed key proves nothing about any vault.json")
    }
}


// Independent audit probes for PR #48 (no production changes).
extension FileLimitAndPermissionTests {
    func testAuditViewerEditIsTrimmedBeforeSavingTheSnapshot() throws {
        Limits.historyFileBudgetForTesting = 12_000
        Storage.fileLimitForTesting = 12_000
        var s = Settings(); s.overlapCheck = false
        let store = HistoryStore(settings: s)
        store.add(.text(String(repeating: "a", count: 3_000)))
        store.add(.text(String(repeating: "b", count: 3_000)))
        store.saveNow()
        var edited = try XCTUnwrap(store.items.first)
        edited.setText(String(repeating: "c", count: 8_000))
        XCTAssertTrue(store.replace(edited), "the Viewer commits through replace")
        store.saveNow()
        XCTAssertLessThanOrEqual(store.items.reduce(0) { $0 + $1.serializedEstimate }, Limits.effectiveHistoryFileBudget, "drop older items before the snapshot; the edited item fits alone")
        let disk = try Storage.decoder.decode([ClipItem].self, from: Data(contentsOf: Storage.historyURL))
        XCTAssertEqual(disk.map(\.contentHash), store.items.map(\.contentHash), "the accepted edit must survive a reload")
    }

    func testAuditACopiedAsideFromALegacyFileIsCreated0600() throws {
        try Data("legacy clipboard contents".utf8).write(to: Storage.historyURL)
        XCTAssertEqual(chmod(Storage.historyURL.path, 0o644), 0)
        Storage.keepCopy(of: Storage.historyURL)
        let copy = try XCTUnwrap(Storage.setAsideCopies().first)
        XCTAssertEqual(try Data(contentsOf: copy), Data("legacy clipboard contents".utf8))
        XCTAssertEqual(try mode(copy), 0o600, "this is a newly created copy, not a renamed legacy inode")
    }

    func testAuditSealingAnAsideHonoursTheFinalWriteLimit() throws {
        let key = try Vault.enable(password: .of("pw"), rounds: 1000)
        let aside = Storage.historyURL.appendingPathExtension("corrupt-audit")
        let original = Data(repeating: 0x41, count: 1024)
        try Storage.writeAtomically(original, to: aside)
        Storage.fileLimitForTesting = 1024
        let rewritten = Storage.sealSetAsideCopies(with: key)
        XCTAssertTrue(rewritten.isEmpty, "the GCM overhead puts the final file over the limit")
        XCTAssertEqual(try Data(contentsOf: aside), original, "over-limit output must leave the previous file intact")
    }

    func testAuditLockDuringTheFirstRefusalDefersTheRemainingReports() throws {
        Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        var states: [Bool] = []
        Vault.errorSinkForTesting = { _ in
            states.append(app.isLocked)
            if states.count == 1 { app.lock() }
        }
        defer { Vault.errorSinkForTesting = nil }
        app.refusedWritesToReport = ["history.json", "templates.json"]
        app.reportRefusedWritesLater()
        let turn = expectation(description: "report returns")
        DispatchQueue.main.async { DispatchQueue.main.async { turn.fulfill() } }
        wait(for: [turn], timeout: 2)
        XCTAssertTrue(app.isLocked)
        XCTAssertEqual(states, [false], "no second alert may open after the first one's modal loop allowed a lock")
        XCTAssertEqual(app.refusedWritesToReport, ["templates.json"], "keep the undisplayed report for unlock")
    }
}


// Independent round-2 probes: the boundary cases around the five fixes.
extension FileLimitAndPermissionTests {
    func testAuditRoundTwoRejectsANewestEditThatCannotFitEvenAlone() throws {
        Limits.historyFileBudgetForTesting = 12_000
        Storage.fileLimitForTesting = 12_000
        var s = Settings(); s.overlapCheck = false
        let store = HistoryStore(settings: s)
        store.add(.text(String(repeating: "a", count: 3_000)))
        store.add(.text(String(repeating: "b", count: 3_000)))
        store.saveNow()
        let original = store.items
        var edited = try XCTUnwrap(original.first)
        edited.setText(String(repeating: "c", count: 12_000))
        XCTAssertGreaterThan(edited.serializedEstimate, Limits.effectiveHistoryFileBudget)
        XCTAssertFalse(store.replace(edited), "an edit that cannot fit alone must be refused")
        XCTAssertEqual(store.items.map(\.contentHash), original.map(\.contentHash), "a refused edit must not drop the other history entries")
        store.saveNow()
        let disk = try Storage.decoder.decode([ClipItem].self, from: Data(contentsOf: Storage.historyURL))
        XCTAssertEqual(disk.map(\.contentHash), store.items.map(\.contentHash), "an accepted edit must be persisted; a rejected edit must leave memory intact")
    }

    func testAuditRoundTwoRepeatedValidationDoesNotOverwriteAnEarlierAside() throws {
        // Each load strips a broken secondary RTF and keeps the original file first.
        // Model two different partly damaged files arriving in the same second.
        var first = ClipItem.text("first original worth recovering")
        first.formats[ClipItem.Format.rtf] = Data("broken first RTF".utf8)
        let firstBytes = try Storage.encoder.encode([first])
        try Storage.writeAtomically(firstBytes, to: Storage.historyURL)
        let stamp = Int(Date().timeIntervalSince1970)
        let store = HistoryStore(settings: Settings())
        let firstCopy = try XCTUnwrap(Storage.setAsideCopies().first)
        XCTAssertEqual(try Data(contentsOf: firstCopy), firstBytes)

        var second = ClipItem.text("second original worth recovering")
        second.formats[ClipItem.Format.rtf] = Data("broken second RTF".utf8)
        let secondBytes = try Storage.encoder.encode([second])
        try Storage.writeAtomically(secondBytes, to: Storage.historyURL)
        store.reload()
        guard Int(Date().timeIntervalSince1970) == stamp else { throw XCTSkip("crossed a timestamp boundary; rerun this fast probe") }
        XCTAssertEqual(try Data(contentsOf: firstCopy), firstBytes, "keeping a later original must not replace the earlier recovery copy")
    }
}


// Independent round-3 checks for a refused incoming clip and the no-replace writer.
extension FileLimitAndPermissionTests {
    func testAuditRoundThreeARefusedIncomingClipMustNotEraseSavedHistoryOnTheNextCopy() throws {
        Limits.historyFileBudgetForTesting = 12_000
        Storage.fileLimitForTesting = 12_000
        var s = Settings(); s.overlapCheck = false
        let store = HistoryStore(settings: s)
        store.add(.text("saved older item"))
        store.add(.text("saved newer item"))
        store.saveNow()
        let savedIDs = Set(store.items.map(\.id))
        let originalFile = try Data(contentsOf: Storage.historyURL)

        var tooLarge = ClipItem.text("a valid clip carrying several formats")
        tooLarge.formats["com.example.opaque-one"] = Data(repeating: 0x41, count: 6_000)
        tooLarge.formats["com.example.opaque-two"] = Data(repeating: 0x42, count: 6_000)
        XCTAssertNoThrow(try Backup.validate(item: tooLarge), "every format is individually valid")
        XCTAssertGreaterThan(tooLarge.serializedEstimate, Limits.effectiveHistoryFileBudget)
        var refused = 0
        Storage.onWriteRefused = { _, _ in refused += 1 }
        store.add(tooLarge)
        store.saveNow()
        // Auditor's probe asserted `refused == 1` here: the clip reached the write barrier. The fix
        // refuses it at `add` instead, before it displaces anything, so the barrier is never hit.
        XCTAssertEqual(refused, 0, "refused at the store, not at the write barrier")
        XCTAssertEqual(store.items.map(\.id).count, 2, "the oversized clip never entered the history")
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), originalFile, "the old file is untouched")

        store.add(.text("ordinary next copy"))
        store.saveNow()
        XCTAssertEqual(refused, 0, "the small copy is saved successfully")
        let disk = try Storage.decoder.decode([ClipItem].self, from: Data(contentsOf: Storage.historyURL))
        XCTAssertEqual(savedIDs.intersection(Set(disk.map(\.id))).count, savedIDs.count, "a clip that could never be saved must not evict previously saved history at the next ordinary copy")
    }

    func testAuditRoundThreeNoReplaceWriterProtectsExistingContentsAndCleansTemporaryFiles() throws {
        let existing = Storage.directory.appendingPathComponent("existing-copy")
        let first = Data("recover this original".utf8)
        try Storage.writeAtomically(first, to: existing)
        XCTAssertThrowsError(try Storage.writeAtomically(Data("replacement".utf8), to: existing, replacing: false)) {
            let e = $0 as NSError
            XCTAssertEqual(e.domain, NSPOSIXErrorDomain)
            XCTAssertEqual(e.code, Int(EEXIST))
        }
        XCTAssertEqual(try Data(contentsOf: existing), first)
        let fresh = Storage.directory.appendingPathComponent("fresh-copy")
        try Storage.writeAtomically(first, to: fresh, replacing: false)
        XCTAssertEqual(try Data(contentsOf: fresh), first)
        XCTAssertEqual(try mode(fresh), 0o600)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: Storage.directory.path).contains { $0.hasSuffix(".tmp") }, "no private temporary remains on either path")
    }
}
