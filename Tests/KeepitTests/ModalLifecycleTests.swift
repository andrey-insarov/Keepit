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

    // MARK: ownership (auditor's second round on PR #28)

    private func alert(_ title: String) -> NSAlert {
        let a = NSAlert(); a.messageText = title; a.addButton(withTitle: "OK"); return a
    }
    private func after(_ seconds: TimeInterval, _ body: @escaping () -> Void) -> Timer {
        let t = Timer(timeInterval: seconds, repeats: false) { _ in body() }
        RunLoop.main.add(t, forMode: .common)
        return t
    }

    /// An ordinary dialog opened over a wrapped one is the session now: the lock leaves it, and
    /// the wrapped parent underneath, alone.
    func testOrdinaryChildOverAWrappedParentIsNotAborted() throws {
        let a = try makeApp()
        let outer = alert("wrapped parent")
        var child: NSApplication.ModalResponse?
        let endOuter = after(1.0) { NSApp.stopModal(withCode: .OK) }
        let openChild = after(0.05) {
            let inner = self.alert("ordinary child")
            let lockTimer = self.after(0.05) { a.lock() }
            let endChild = self.after(0.3) { NSApp.stopModal(withCode: .OK) }
            child = inner.runModal()
            lockTimer.invalidate(); endChild.invalidate(); inner.window.orderOut(nil)
            NSApp.stopModal(withCode: .OK)
        }
        let outerResult = AbortableModal.run(outer)
        openChild.invalidate(); endOuter.invalidate(); outer.window.orderOut(nil)
        XCTAssertTrue(a.isLocked)
        XCTAssertEqual(child, .OK, "the ordinary child completes on its own")
        XCTAssertEqual(outerResult, .OK)
        XCTAssertEqual(AbortableModal.depth, 0)
    }

    /// Two wrapped dialogs: the lock ends the inner one, and the outer one as soon as control is back in its loop.
    func testLockUnwindsNestedWrappedDialogs() throws {
        let a = try makeApp()
        let outer = alert("outer wrapped")
        var child: NSApplication.ModalResponse?
        let endOuter = after(1.0) { NSApp.stopModal(withCode: .OK) }
        let openChild = after(0.05) {
            let inner = self.alert("inner wrapped")
            let lockTimer = self.after(0.05) { a.lock() }
            let endChild = self.after(0.3) { NSApp.stopModal(withCode: .OK) }
            child = AbortableModal.run(inner)
            lockTimer.invalidate(); endChild.invalidate(); inner.window.orderOut(nil)
        }
        let outerResult = AbortableModal.run(outer)
        openChild.invalidate(); endOuter.invalidate(); outer.window.orderOut(nil)
        XCTAssertEqual(child, .abort)
        XCTAssertEqual(outerResult, .abort)
        XCTAssertEqual(AbortableModal.depth, 0)
    }

    /// The restore progress panel under a wrapped parent keeps its own completion: a lock does not stop it.
    func testRestoreWaitUnderAWrappedParentKeepsItsCompletion() throws {
        let a = try makeApp()
        let outer = alert("parent of the restore wait")
        var result: Result<Void, Error>?
        let endOuter = after(1.5) { NSApp.stopModal(withCode: .OK) }
        let openChild = after(0.05) {
            let lockTimer = self.after(0.05) { a.lock() }
            result = AppDelegate.sealAndWriteOffMain(message: "wait", seal: { Thread.sleep(forTimeInterval: 0.2); return Data("x".utf8) }, write: { _ in })
            lockTimer.invalidate()
            NSApp.stopModal(withCode: .OK)
        }
        _ = AbortableModal.run(outer)
        openChild.invalidate(); endOuter.invalidate(); outer.window.orderOut(nil)
        guard case .success? = result else { return XCTFail("the wait was ended by the lock: \(String(describing: result))") }
    }

    /// The lock key's handler is delivered inside a modal loop (RunLoop.perform in the modal mode), where
    /// a main-queue block — the route of every other hot key — would wait for the dialog to close.
    func testLockDeliveredInsideAModalOpenedFromAMainQueueBlock() throws {
        let a = try makeApp()
        let done = expectation(description: "modal returned")
        var response: NSApplication.ModalResponse?
        var lockedInside = false
        DispatchQueue.main.async {
            let dialog = self.alert("opened from a main-queue block")
            let arm = self.after(0.05) {
                RunLoop.main.perform(inModes: [.modalPanel, .default, .common]) {
                    lockedInside = NSApp.modalWindow === dialog.window
                    a.lock()
                }
            }
            let fallback = self.after(1.0) { NSApp.stopModal(withCode: .OK) }
            response = AbortableModal.run(dialog)
            arm.invalidate(); fallback.invalidate(); dialog.window.orderOut(nil)
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        XCTAssertTrue(lockedInside)
        XCTAssertEqual(response, .abort)
    }

    /// A lock between the files and the models of a restore: the stores stay purged, the files hold
    /// the restored data, and the next unlock loads them (auditor's P2 on PR #28 — before, the
    /// models were published into a locked app).
    func testLockDuringCommitDoesNotPublishModels() throws {
        let a = try makeApp()
        a.history.add(.text("before"))
        a.history.flush(); a.templates.flush()
        let payload = Backup.Payload(history: [.text("RESTORED")], templates: TemplateNode(name: "Template", children: [TemplateNode(name: "r", text: "RESTORED")]), settings: a.settings)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: a.history.items, currentTemplates: a.templates.root,
                                        currentSettings: a.settings, restorePreferences: true, folderName: "unused")
        var seen = 0
        a.history.onChange = { [unowned a] in seen += 1; if seen == 2, !a.isLocked { a.lock() } }   // 1 = replaceAll, 2 = apply(settings:) → updateSettings: the lock lands inside commit
        a.restoreInProgress = true
        XCTAssertThrowsError(try a.commit(plan)) {
            guard case RestoreCommit.Failure.lockedAfterWrite? = $0 as? RestoreCommit.Failure else { return XCTFail("\($0)") }
        }
        XCTAssertTrue(a.isLocked)
        XCTAssertTrue(a.history.isPurged)
        XCTAssertTrue(a.templates.isPurged)
        XCTAssertTrue(a.history.items.isEmpty)
        XCTAssertTrue(a.templates.root.children.isEmpty)
        a.history.onChange = nil
        unlockQuietly(a)
        a.history.reload()
        XCTAssertEqual(a.history.items.map(\.plainText), ["RESTORED"], "the files hold the restored data")
        XCTAssertEqual(a.templates.root.children.first?.name, "r")
    }
}
