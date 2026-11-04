import XCTest
import AppKit
@testable import Keepit

/// The restore transaction is planned before anything changes (docs/BACKUP.md "Restore", 5–6).
/// These tests pin the plan's rules; `AppDelegate.apply(_:)` is a handful of assignments on top.
final class RestorePlanTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    private func settings(historyMax: Int = 1000) -> Settings {
        var s = Settings()
        s.historySave = false
        s.historyMax = historyMax
        return s
    }

    private func tree(_ items: [TemplateNode]) -> TemplateNode { TemplateNode(name: "Template", children: items) }

    // The auditor's chain: Export → open → Merge into the same store → Export again must open.
    // Imported templates and items come back under fresh ids, so nothing is duplicated.
    func testMergingOwnBackupKeepsTheNextBackupValid() throws {
        let a = ClipItem.text("alpha"), b = ClipItem.text("beta")
        let store = TemplateStore()
        store.replaceRoot(tree([TemplateNode(name: "F", children: [TemplateNode(name: "One", text: "1")]), TemplateNode(name: "Two", text: "2")]))
        let exported = Backup.Payload(history: [a, b], templates: store.root, settings: nil)
        let bytes = try Backup.encode(exported, password: SecureBuffer.of("pw"))
        let opened = try Backup.decode(bytes, password: SecureBuffer.of("pw"))

        // Meanwhile item `b` was edited here: same id, different content.
        var edited = b
        edited.formats[ClipItem.Format.text] = Data("beta v2".utf8)
        edited.contentHash = ClipItem.hash(of: Data("beta v2".utf8))
        let current = [edited, a]

        let plan = try RestorePlan.make(mode: .merge, payload: opened, currentHistory: current, currentTemplates: store.root,
                                        currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(plan.historyAdded, 1)                       // only the old "beta"
        XCTAssertEqual(plan.history.map(\.plainText), ["beta v2", "alpha", "beta"])
        XCTAssertEqual(Set(plan.history.map(\.id)).count, 3)         // the merged "beta" has a new id
        XCTAssertFalse(plan.templates === store.root)                // the plan's tree shares nothing with the live one
        XCTAssertEqual(store.root.subtreeCount, 4)                   // and the live one did not move
        store.replaceRoot(plan.templates)
        let again = Backup.Payload(history: plan.history, templates: store.root, settings: nil)
        XCTAssertNoThrow(try Backup.validate(again))
        let bytes2 = try Backup.encode(again, password: SecureBuffer.of("pw"))
        XCTAssertNoThrow(try Backup.decode(bytes2, password: SecureBuffer.of("pw")))
        XCTAssertEqual(store.root.subtreeCount, 1 + 3 + 4)          // root + original 3 + folder with 3
    }

    func testMergeDropsImportedHotKeysReplaceKeepsThem() throws {
        let hk = HotKey(keyCode: 9, modifiers: 256)
        let item = TemplateNode(name: "Hot", text: "h"); item.hotKey = hk
        let payload = Backup.Payload(history: [], templates: tree([item]), settings: nil)
        let merge = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: [], currentTemplates: tree([]),
                                         currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        let folder = merge.templates.children.last!
        XCTAssertTrue(folder.isFolder)
        XCTAssertNil(folder.children[0].hotKey)
        XCTAssertNotEqual(folder.children[0].id, item.id)
        XCTAssertEqual(merge.templatesAdded, 2)                     // the folder and the item
        let replace = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [], currentTemplates: tree([]),
                                           currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        let root = replace.templates
        XCTAssertEqual(root.children[0].hotKey, hk)
        XCTAssertEqual(root.children[0].id, item.id)
        XCTAssertEqual(replace.templatesAdded, 1)
    }

    // The limits in force after the restore decide what fits — not the ones before it.
    func testRestoredSettingsGovernTheHistoryLimit() throws {
        var backupSettings = Settings()
        backupSettings.historyMax = 3
        let three = [ClipItem.text("1"), ClipItem.text("2"), ClipItem.text("3")]
        let payload = Backup.Payload(history: three, templates: tree([]), settings: backupSettings)
        let withPrefs = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [ClipItem.text("old")], currentTemplates: tree([]),
                                             currentSettings: settings(historyMax: 1), restorePreferences: true, folderName: "Imported")
        XCTAssertEqual(withPrefs.history.count, 3)
        XCTAssertEqual(withPrefs.settings.historyMax, 3)
        XCTAssertEqual(withPrefs.historyDropped, 0)
        let withoutPrefs = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [ClipItem.text("old")], currentTemplates: tree([]),
                                                currentSettings: settings(historyMax: 1), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(withoutPrefs.history.count, 1)
        XCTAssertEqual(withoutPrefs.historyDropped, 2)
        XCTAssertEqual(withoutPrefs.settings.historyMax, 1)
        // Merge counts only the new items that survived the trim.
        let merged = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: [ClipItem.text("old")], currentTemplates: tree([]),
                                          currentSettings: settings(historyMax: 2), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(merged.history.map(\.plainText), ["old", "1"])
        XCTAssertEqual(merged.historyAdded, 1)
        XCTAssertEqual(merged.historyDropped, 2)
    }

    func testRestoredSettingsNeverCarryTrustOrBackupSetup() throws {
        var backupSettings = Settings()
        backupSettings.allowURLCommands = true
        backupSettings.backupEnabled = true
        backupSettings.historyMax = Limits.historyMaxCeiling * 10     // clamped when applied
        let payload = Backup.Payload(history: [], templates: tree([]), settings: backupSettings)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [], currentTemplates: tree([]),
                                        currentSettings: settings(), restorePreferences: true, folderName: "Imported")
        XCTAssertFalse(plan.settings.allowURLCommands)
        XCTAssertFalse(plan.settings.backupEnabled)
        XCTAssertEqual(plan.settings.historyMax, Limits.historyMaxCeiling)
    }

    // A Merge that would exceed the template ceilings is refused as a whole; a plan is never partial.
    func testMergeRefusesWhenTheFolderWouldNotFit() throws {
        // Depth: the backup's deepest node is at depth templateMaxDepth; under the new folder it would be one deeper.
        var deep = TemplateNode(name: "leaf", text: "x")
        for i in 0..<(Limits.templateMaxDepth - 1) { deep = TemplateNode(name: "d\(i)", children: [deep]) }
        let tooDeep = Backup.Payload(history: [], templates: tree([deep]), settings: nil)
        XCTAssertNoThrow(try Backup.validate(tooDeep))               // fine as a backup on its own
        XCTAssertThrowsError(try RestorePlan.make(mode: .merge, payload: tooDeep, currentHistory: [], currentTemplates: tree([]),
                                                  currentSettings: settings(), restorePreferences: false, folderName: "Imported"))
        XCTAssertNoThrow(try RestorePlan.make(mode: .replace, payload: tooDeep, currentHistory: [], currentTemplates: tree([]),
                                              currentSettings: settings(), restorePreferences: false, folderName: "Imported"))
        // Count: current + folder + imported must stay within the ceiling.
        let many = tree((0..<10).map { TemplateNode(name: "t\($0)", text: "t") })
        let current = tree((0..<(Limits.templateMaxCount - 11)).map { TemplateNode(name: "c\($0)", text: "c") })
        XCTAssertThrowsError(try RestorePlan.make(mode: .merge, payload: Backup.Payload(history: [], templates: many, settings: nil),
                                                  currentHistory: [], currentTemplates: current,
                                                  currentSettings: settings(), restorePreferences: false, folderName: "Imported")) {
            XCTAssertEqual($0 as? RestorePlan.Failure, .templateLimit)
        }
        let smaller = tree((0..<(Limits.templateMaxCount - 12)).map { TemplateNode(name: "c\($0)", text: "c") })
        XCTAssertNoThrow(try RestorePlan.make(mode: .merge, payload: Backup.Payload(history: [], templates: many, settings: nil),
                                              currentHistory: [], currentTemplates: smaller,
                                              currentSettings: settings(), restorePreferences: false, folderName: "Imported"))
    }

    func testMergeSkipsDuplicateContentAndKeepsCurrentNewest() throws {
        let shared = ClipItem.text("same")
        let payload = Backup.Payload(history: [ClipItem.text("same"), ClipItem.text("new")], templates: tree([]), settings: nil)
        let plan = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: [ClipItem.text("mine"), shared], currentTemplates: tree([]),
                                        currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(plan.history.map(\.plainText), ["mine", "same", "new"])
        XCTAssertEqual(plan.history[1].id, shared.id)                // the current copy stays, untouched
        XCTAssertEqual(plan.historyAdded, 1)
    }

    // A plan is a snapshot: the stores' revisions say whether it still describes them.
    func testStoreRevisionsMoveWithEveryChange() {
        var s = Settings(); s.historySave = false
        let h = HistoryStore(settings: s)
        let r0 = h.revision
        h.add(.text("x"))
        XCTAssertEqual(h.revision, r0 + 1)
        h.replaceAll([])
        XCTAssertEqual(h.revision, r0 + 2)
        let t = TemplateStore()
        let t0 = t.revision
        t.root.insert(TemplateNode(name: "n", text: "n")); t.changed()
        XCTAssertEqual(t.revision, t0 + 1)
        t.replaceRoot(TemplateNode(name: "Template"))
        XCTAssertEqual(t.revision, t0 + 2)
    }

    // The disk half of a commit: all three files or none. Here history.json cannot be replaced
    // (it is immutable); templates.json, already written, must come back as it was.
    func testCommitWritesAllFilesOrPutsThePreviousOnesBack() throws {
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        try Data("old-templates".utf8).write(to: Storage.templatesURL)
        try Data("old-settings".utf8).write(to: Storage.settingsURL)
        try Data("old-history".utf8).write(to: Storage.historyURL)
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: Storage.historyURL.path)
        defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: Storage.historyURL.path) }
        XCTAssertThrowsError(try RestoreCommit.writeFiles(templatesJSON: Data("new-templates".utf8), historyJSON: Data("new-history".utf8),
                                                          settingsJSON: Data("new-settings".utf8))) {
            guard case RestoreCommit.Failure.writeFailed(let name, _)? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
            XCTAssertEqual(name, "history.json")
        }
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("old-templates".utf8))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("old-settings".utf8))
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), Data("old-history".utf8))
        // An existing file that cannot be read is not a missing file: the commit is refused before
        // the first write, so the undo can never "put back" nothing over it.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: Storage.templatesURL.path)
        XCTAssertThrowsError(try RestoreCommit.writeFiles(templatesJSON: Data("new-templates".utf8), historyJSON: Data("new-history".utf8),
                                                          settingsJSON: Data("new-settings".utf8))) {
            guard case RestoreCommit.Failure.cannotReadPrevious(let name, _)? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
            XCTAssertEqual(name, "templates.json")
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: Storage.templatesURL.path)
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("old-templates".utf8))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("old-settings".utf8))
        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: Storage.historyURL.path)
        // With the obstacle gone the same commit lands whole; nil history removes the file.
        XCTAssertNoThrow(try RestoreCommit.writeFiles(templatesJSON: Data("new-templates".utf8), historyJSON: nil, settingsJSON: Data("new-settings".utf8)))
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("new-templates".utf8))
        XCTAssertEqual(try Data(contentsOf: Storage.settingsURL), Data("new-settings".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.historyURL.path))
        // Locked (password set, no key in memory): refused before touching anything.
        try Vault.enable(password: SecureBuffer.of("pw")).zero()
        Storage.clearKey()
        XCTAssertThrowsError(try RestoreCommit.writeFiles(templatesJSON: Data("x".utf8), historyJSON: nil, settingsJSON: Data("y".utf8))) {
            guard case RestoreCommit.Failure.writeFailed(let name, let e)? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
            XCTAssertEqual(name, "templates.json")
            XCTAssertEqual(e as? Storage.Failure, .locked)
        }
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("new-templates".utf8))
    }

    // A process killed anywhere between arming the journal and clearing it: the next launch puts
    // every file back — whatever number of the three writes had landed — and does so again if
    // the replay itself is interrupted.
    func testInterruptedCommitIsReplayedAtLaunch() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        let steps = RestoreCommit.steps(templatesJSON: Data("new-templates".utf8), historyJSON: Data("new-history".utf8), settingsJSON: Data("new-settings".utf8))
        func resetLive() throws {
            try Data("old-templates".utf8).write(to: Storage.templatesURL)
            try Data("old-settings".utf8).write(to: Storage.settingsURL)
            try Storage.removeNow(Storage.historyURL)                  // history was not kept on disk
            try RestoreCommit.clearJournal()
        }
        func assertLiveIsOld(_ line: UInt = #line) {
            XCTAssertEqual(try? Data(contentsOf: Storage.templatesURL), Data("old-templates".utf8), line: line)
            XCTAssertEqual(try? Data(contentsOf: Storage.settingsURL), Data("old-settings".utf8), line: line)
            XCTAssertFalse(fm.fileExists(atPath: Storage.historyURL.path), line: line)
            XCTAssertFalse(fm.fileExists(atPath: RestoreCommit.journalDirectory.path), line: line)
        }
        for written in 0...3 {
            try resetLive()
            try RestoreCommit.writeJournal()
            for s in steps.prefix(written) { try Storage.writeNow(s.data!, to: s.url, encrypt: s.encrypt) }
            // "crash" here; next launch:
            XCTAssertTrue(try RestoreCommit.recoverIfNeeded(), "\(written) writes")
            assertLiveIsOld()
            XCTAssertFalse(try RestoreCommit.recoverIfNeeded())            // nothing left to do
        }
        // Killed while the journal was being written (no marker): the commit never started, the
        // live files are whatever they are, the half-journal is just removed.
        try resetLive()
        try fm.createDirectory(at: RestoreCommit.journalDirectory, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: RestoreCommit.journalDirectory.appendingPathComponent("templates.json"))
        XCTAssertFalse(try RestoreCommit.recoverIfNeeded())
        assertLiveIsOld()
        // Replay interrupted or failing on one file: the journal stays armed and the next attempt
        // finishes the job. Here history.json cannot be removed (immutable) on the first attempt.
        try resetLive()
        try RestoreCommit.writeJournal()
        for s in steps { try Storage.writeNow(s.data!, to: s.url, encrypt: s.encrypt) }
        try fm.setAttributes([.immutable: true], ofItemAtPath: Storage.historyURL.path)
        XCTAssertThrowsError(try RestoreCommit.recoverIfNeeded()) {
            guard case RestoreCommit.Failure.undoFailed(_, _, let undo)? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
            XCTAssertEqual(undo.map(\.0), ["history.json"])
        }
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("old-templates".utf8))   // the rest was put back
        XCTAssertTrue(fm.fileExists(atPath: RestoreCommit.journalMarker.path))                      // still armed
        try fm.setAttributes([.immutable: false], ofItemAtPath: Storage.historyURL.path)
        XCTAssertTrue(try RestoreCommit.recoverIfNeeded())
        assertLiveIsOld()
        // A completed commit leaves no journal behind.
        try resetLive()
        try RestoreCommit.writeFiles(steps)
        XCTAssertEqual(try Data(contentsOf: Storage.historyURL), Data("new-history".utf8))
        XCTAssertFalse(fm.fileExists(atPath: RestoreCommit.journalDirectory.path))
        XCTAssertFalse(try RestoreCommit.recoverIfNeeded())
    }

    // The journal is taken behind every save already queued on Storage.ioQueue: what the stores
    // last wrote, not what happened to be on disk a moment earlier.
    func testJournalWaitsForQueuedSaves() throws {
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        try Data("older".utf8).write(to: Storage.templatesURL)
        try Data("older".utf8).write(to: Storage.settingsURL)
        Storage.saveEncoded(Data("latest".utf8), to: Storage.templatesURL, encrypt: false, background: true)   // queued, not yet landed
        try RestoreCommit.writeJournal()
        XCTAssertEqual(try Data(contentsOf: RestoreCommit.journalDirectory.appendingPathComponent("templates.json")), Data("latest".utf8))
        try RestoreCommit.clearJournal()
    }

    // An armed journal belongs to the launch replay: a new commit never discards it.
    func testArmedJournalIsNeverReplacedByANewCommit() throws {
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        try Data("precious".utf8).write(to: Storage.templatesURL)
        try Data("s".utf8).write(to: Storage.settingsURL)
        try RestoreCommit.writeJournal()                                     // armed, as if a replay had failed
        try Data("mixed".utf8).write(to: Storage.templatesURL)
        XCTAssertThrowsError(try RestoreCommit.writeFiles(templatesJSON: Data("new".utf8), historyJSON: nil, settingsJSON: Data("new".utf8))) {
            guard case RestoreCommit.Failure.journalArmed? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
        }
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("mixed".utf8))                 // nothing written
        XCTAssertEqual(try Data(contentsOf: RestoreCommit.journalDirectory.appendingPathComponent("templates.json")), Data("precious".utf8))
        XCTAssertTrue(try RestoreCommit.recoverIfNeeded())                                              // the replay still can
        XCTAssertEqual(try Data(contentsOf: Storage.templatesURL), Data("precious".utf8))
    }

    func testTrimmedIsTheStoreRule() {
        var s = settings(historyMax: 2)
        s.historyImageMax = 1
        let items = [ClipItem.text("a"), ClipItem.text("b"), ClipItem.text("c")]
        XCTAssertEqual(HistoryStore.trimmed(items, settings: s).map(\.plainText), ["a", "b"])
        s.historyMaxAge = 60
        let old = ClipItem(id: UUID(), date: Date(timeIntervalSinceNow: -120), formats: [ClipItem.Format.text: Data("z".utf8)],
                           sourceApp: nil, contentHash: ClipItem.hash(of: Data("z".utf8)))
        XCTAssertEqual(HistoryStore.trimmed([old] + items, settings: s).map(\.plainText), ["a", "b"])
    }

    // The progress panel's wait must end when the work ends — also when the wait was entered from
    // a main-queue block (the launch sequence is one): a completion sent with
    // DispatchQueue.main.async would not run until that block returned, which it cannot.
    func testModalWaitCompletesFromInsideAMainQueueBlock() {
        _ = NSApplication.shared
        let done = expectation(description: "both waits returned")
        done.expectedFulfillmentCount = 2
        var ok: Result<Void, Error>?, failed: Result<Void, Error>?
        struct Boom: Error {}
        DispatchQueue.main.async {
            ok = AppDelegate.sealAndWriteOffMain(message: "test", seal: { Data("x".utf8) }, write: { _ in })
            done.fulfill()
            failed = AppDelegate.sealAndWriteOffMain(message: "test", seal: { throw Boom() }, write: { _ in XCTFail("no write after a failed seal") })
            done.fulfill()
        }
        wait(for: [done], timeout: 15)
        guard case .success? = ok else { return XCTFail("\(String(describing: ok))") }
        guard case .failure(let e)? = failed, e is Boom else { return XCTFail("\(String(describing: failed))") }
    }

    // A seal still running after the wait ended keeps its own secret (the caller zeroes the
    // original on its way out) and its late completion leaves the next modal session alone.
    func testLateSealCompletionOwnsItsSecretAndStopsNoOtherModal() throws {
        _ = NSApplication.shared
        let original = SecureBuffer.of("chosen password")
        let own = original.copy()
        original.zero()
        XCTAssertEqual(own.withBytes { Data($0) }, Data("chosen password".utf8))     // the copy is independent
        XCTAssertEqual(original.count, 0)

        let gate = DispatchSemaphore(value: 0)
        let sealed = expectation(description: "seal ran to the end")
        var sealedWith: Data?
        var early: Result<Void, Error>?
        var second: NSApplication.ModalResponse?
        let done = expectation(description: "both waits returned")
        DispatchQueue.main.async {
            // Something stops the panel while the seal is still blocked (Lock, say).
            // Timers must be in the common modes to fire inside a modal loop.
            RunLoop.main.add(Timer(timeInterval: 0.3, repeats: false) { _ in NSApp.stopModal() }, forMode: .common)
            early = AppDelegate.sealAndWriteOffMain(message: "test", seal: {
                gate.wait()
                sealedWith = own.withBytes { Data($0) }     // still the chosen password, not zeroes
                own.zero()
                sealed.fulfill()
                return Data("x".utf8)
            }, write: { _ in })
            // The next dialog is modal when the late completion arrives: it must stay up until *we* stop it.
            let next = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 40), styleMask: [.titled], backing: .buffered, defer: false)
            next.isReleasedWhenClosed = false
            gate.signal()
            RunLoop.main.add(Timer(timeInterval: 1.0, repeats: false) { _ in NSApp.stopModal(withCode: .OK) }, forMode: .common)
            second = NSApp.runModal(for: next)
            next.orderOut(nil)
            done.fulfill()
        }
        wait(for: [sealed, done], timeout: 15)
        guard case .failure(let e)? = early, e as? BackupEngine.Failure == .notFinished else { return XCTFail("\(String(describing: early))") }
        XCTAssertEqual(sealedWith, Data("chosen password".utf8))
        XCTAssertEqual(second, .OK)                                          // ours, not the stale completion's .stop
    }
}
