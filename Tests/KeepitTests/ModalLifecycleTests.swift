import AppKit
import XCTest
@testable import Keepit

/// Two flows read state, open a modal dialog, and act on that state when the dialog closes: a
/// template with `{input:}`/`{choice:}` prompts, and a keepit:// command from a sender that has to be
/// confirmed. Keepit can be locked — and unlocked again — while either dialog is on screen. Seeded
/// from the auditor's final 3.0.4 review (P1: a private template's text reached the paste path after
/// the lock had purged the stores; P2: a confirmed keepit://add-template refilled the purged tree and
/// re-registered hot keys while locked). The dialogs and the paste are replaced by closures; nothing
/// touches the pasteboard, the keyboard or the system hot keys.
final class ModalLifecycleTests: XCTestCase {
    private var storage: TempStorage!
    private var pasted: [String] = []

    override func setUpWithError() throws {
        _ = NSApplication.shared
        storage = TempStorage()
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
        pasted = []
        Paster.pasteSinkForTesting = { [unowned self] in self.pasted.append($0.plainText ?? "") }
    }
    override func tearDown() {
        Paster.pasteSinkForTesting = nil
        SnippetPromptDialog.askForTesting = nil
        storage.restore()
    }

    private func makeApp() throws -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        var s = a.settings
        s.allowURLCommands = true
        s.pasteAfterSelect = false
        a.apply(settings: s)
        Storage.key = try Vault.enable(password: .of("test-only"), rounds: 1000)
        a.templates.replaceRoot(TemplateNode(name: "Root", children: [TemplateNode(name: "Private", text: "PRIVATE {input:X}")]))
        a.templates.flush()
        a.urlCommandSenderForTesting = URLSender(app: nil, isBrowser: false)   // never trusted: always asked
        return a
    }

    private func privateClip(_ a: AppDelegate) throws -> ClipItem {
        try XCTUnwrap(a.templates.root.children.first?.clip)
    }

    /// What a manual unlock does, without the password dialog.
    private func unlockQuietly(_ a: AppDelegate) {
        Storage.key = Vault.unlock(password: .of("test-only"))
        a.setLockedForTesting(false)
        a.templates.reload()
    }

    // MARK: template prompts

    func testPromptAnsweredWhileUnlockedPastes() throws {
        let a = try makeApp()
        SnippetPromptDialog.askForTesting = { _, _ in ["X": "answer"] }
        a.pasteTemplate(try privateClip(a), named: "Private", into: nil)
        XCTAssertEqual(pasted, ["PRIVATE answer"])
    }

    func testLockDuringPromptDropsTheTemplate() throws {
        let a = try makeApp()
        let clip = try privateClip(a)
        SnippetPromptDialog.askForTesting = { _, _ in a.lock(); return ["X": "answer"] }
        a.pasteTemplate(clip, named: "Private", into: nil)
        XCTAssertTrue(a.isLocked)
        XCTAssertTrue(a.templates.isPurged)
        XCTAssertNil(Storage.key)
        XCTAssertEqual(pasted, [], "text read before the lock must not leave Keepit after it")
    }

    func testLockThenUnlockDuringPromptDropsTheOldGeneration() throws {
        let a = try makeApp()
        let clip = try privateClip(a)
        let generation = a.lockCount
        SnippetPromptDialog.askForTesting = { [unowned self] _, _ in
            a.lock()
            self.unlockQuietly(a)
            return ["X": "answer"]
        }
        a.pasteTemplate(clip, named: "Private", into: nil)
        XCTAssertFalse(a.isLocked)
        XCTAssertGreaterThan(a.lockCount, generation)
        XCTAssertEqual(pasted, [], "the dialog belonged to the previous lock generation")
    }

    func testPasteTemplateWhileLockedIsRefused() throws {
        let a = try makeApp()
        let clip = try privateClip(a)
        a.lock()
        SnippetPromptDialog.askForTesting = { _, _ in XCTFail("no dialog while locked"); return nil }
        a.pasteTemplate(clip, named: "Private", into: nil)
        XCTAssertEqual(pasted, [])
    }

    // MARK: keepit:// confirmation

    func testConfirmedCommandRunsWhileUnlocked() throws {
        let a = try makeApp()
        a.confirmURLCommandForTesting = { _ in .allowOnce }
        a.handle(try XCTUnwrap(URL(string: "keepit://pause")))     // state-changing, asks, touches no pasteboard
        XCTAssertNotNil(a.pausedUntil)
    }

    func testLockDuringConfirmationDropsTheCommand() throws {
        let a = try makeApp()
        var revisionAfterLock = -1
        a.confirmURLCommandForTesting = { app in
            app.lock()
            revisionAfterLock = app.templates.revision
            return .allowOnce
        }
        a.handle(try XCTUnwrap(URL(string: "keepit://add-template?text=external&name=New")))
        XCTAssertTrue(a.isLocked)
        XCTAssertTrue(a.templates.isPurged)
        XCTAssertTrue(a.templates.root.children.isEmpty, "a purged tree stays empty")
        XCTAssertEqual(a.templates.revision, revisionAfterLock)
    }

    func testLockThenUnlockDuringConfirmationDropsTheCommand() throws {
        let a = try makeApp()
        a.confirmURLCommandForTesting = { [unowned self] app in
            app.lock()
            self.unlockQuietly(app)
            return .allowAlways
        }
        a.handle(try XCTUnwrap(URL(string: "keepit://pause")))
        XCTAssertFalse(a.isLocked)
        XCTAssertNil(a.pausedUntil, "a command admitted in an earlier generation does not run")
        XCTAssertTrue(a.settings.trustedURLSenders.isEmpty, "nor does its Always Allow change the trusted list")
    }

    func testDeniedCommandStillDoesNothing() throws {
        let a = try makeApp()
        a.confirmURLCommandForTesting = { _ in .deny }
        a.handle(try XCTUnwrap(URL(string: "keepit://pause")))
        XCTAssertNil(a.pausedUntil)
    }

    // MARK: a lock closes the dialog (3.0.5)

    /// A real NSAlert in an abortable session; a timer locks Keepit while it is up — the way a hot
    /// key or the screen-lock delay would. The dialog returns `.abort`; nothing waits for the user.
    func testLockAbortsAnAbortableDialog() throws {
        let a = try makeApp()
        let alert = NSAlert()
        alert.messageText = "abortable"
        alert.addButton(withTitle: "OK")
        RunLoop.main.add(Timer(timeInterval: 0.3, repeats: false) { _ in a.lock() }, forMode: .common)
        let r = AbortableModal.run(alert)
        XCTAssertEqual(r, .abort)
        XCTAssertTrue(a.isLocked)
        XCTAssertFalse(AbortableModal.isRunning)
    }

    /// A dialog that is not abortable (a recovery phrase, a password prompt, the restore panel)
    /// stays: the lock changes the app's state, not the session.
    func testLockLeavesAnOrdinaryDialogAlone() throws {
        let a = try makeApp()
        let alert = NSAlert()
        alert.messageText = "ordinary"
        alert.addButton(withTitle: "OK")
        RunLoop.main.add(Timer(timeInterval: 0.3, repeats: false) { _ in
            a.lock()
            XCTAssertNotNil(NSApp.modalWindow, "still up after the lock")
            NSApp.stopModal(withCode: .OK)
        }, forMode: .common)
        XCTAssertEqual(alert.runModal(), .OK)
        XCTAssertTrue(a.isLocked)
    }

    func testLockWithoutADialogAbortsNothing() throws {
        let a = try makeApp()
        a.lock()                                     // no modal session: abortModal is not called
        XCTAssertTrue(a.isLocked)
        XCTAssertFalse(AbortableModal.isRunning)
    }
}
