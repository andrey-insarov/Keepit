import AppKit
import XCTest
@testable import Keepit

/// 3.0.6, the last group from the review of 3.0.5: what a lock has to take off the screen and out
/// of memory (SEC05), Secure Event Input where a secret is typed (SEC03), the `.corrupt-…`
/// copies and the vault (SEC02), and the self-test's data folder (SEC04).
final class LockSurfacesTests: XCTestCase {
    private var tmp: TempStorage!
    private var infos: [String] = []

    override func setUp() {
        tmp = TempStorage()
        infos = []
        _ = NSApplication.shared
        Vault.errorSinkForTesting = { _ in }
        SecureEventInput.suppressSystemCallsForTesting = true
        SecureEventInput.callsForTesting = []
    }
    override func tearDown() {
        Vault.errorSinkForTesting = nil
        Vault.askPasswordForTesting = nil
        Vault.promptForTesting = nil
        RecoveryDialogs.presentSinkForTesting = nil
        RecoveryDialogs.presentResultForTesting = true
        AbortableModal.responseForTesting = nil
        PreviewPanel.shared.purge()
        Storage.releaseAll()
        tmp.restore()
    }

    private func app(protected: Bool = true) throws -> AppDelegate {
        if protected { Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000) }
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.createBackupEngine()
        a.hotKeyFailureForTesting = { _ in }
        a.infoSinkForTesting = { [weak self] in self?.infos.append($0) }
        a.authenticateForTesting = { true }
        a.history.add(.text("secret item")); a.history.flush()
        return a
    }

    private func spinMainQueue() {
        let e = expectation(description: "main queue turn")
        DispatchQueue.main.async { e.fulfill() }
        wait(for: [e], timeout: 2)
    }

    private func unlock(_ a: AppDelegate, password: String = "pw") {
        Vault.promptForTesting = { _ in .password(.of(password)) }
        XCTAssertTrue(a.unlock())
    }
    private func after(_ seconds: TimeInterval, _ body: @escaping () -> Void) -> Timer {
        let t = Timer(timeInterval: seconds, repeats: false) { _ in body() }
        RunLoop.main.add(t, forMode: .common)
        return t
    }

    // MARK: SEC05 — the paste queue keeps no copies

    func testAnExhaustedQueueKeepsNoCopies() {
        let q = PasteQueue(); q.timeout = 0
        q.start(); q.record(.text("a")); q.record(.text("b"))
        _ = q.take(); _ = q.take()
        XCTAssertFalse(q.isActive)
        XCTAssertTrue(q.items.isEmpty, "the copies went with the queue")
        XCTAssertEqual(q.remaining, 0)
    }

    func testTakeAllKeepsNoCopies() {
        let q = PasteQueue(); q.timeout = 0
        q.start(); q.record(.text("a")); q.record(.text("b"))
        XCTAssertEqual(q.takeAll(separator: ","), "a,b")
        XCTAssertTrue(q.items.isEmpty)
    }

    func testStopOnAnEndedQueueClearsWithoutAChangeEvent() {
        let q = PasteQueue(); q.timeout = 0
        var changes = 0
        q.start(); q.record(.text("a"))
        q.onChange = { changes += 1 }
        _ = q.take()                                   // ends by itself → one change
        XCTAssertEqual(changes, 1)
        q.stop()                                       // nothing to announce, nothing left
        XCTAssertEqual(changes, 1)
        XCTAssertTrue(q.items.isEmpty)
    }

    func testLockEmptiesTheAppsQueue() throws {
        let a = try app()
        a.queue.start(); a.queue.record(.text("queued copy"))
        XCTAssertEqual(a.queue.remaining, 1)
        a.lock()
        XCTAssertFalse(a.queue.isActive)
        XCTAssertTrue(a.queue.items.isEmpty)
    }

    // MARK: SEC05 — the preview beside the menu

    func testLockCancelsAPendingPreviewAndEmptiesTheLastOne() throws {
        let a = try app()
        let panel = PreviewPanel.shared
        panel.showNowForTesting(.text("shown before the lock"))
        XCTAssertEqual(panel.shownTextForTesting, "shown before the lock")
        panel.schedule(.text("scheduled just before the lock"), besides: NSRect(x: 0, y: 0, width: 100, height: 100), delay: 60)
        XCTAssertTrue(panel.hasPendingShowForTesting)

        a.lock()
        XCTAssertFalse(panel.hasPendingShowForTesting, "the scheduled show never comes")
        XCTAssertEqual(panel.shownTextForTesting, "", "nothing of the last item in the views")
        XCTAssertNil(panel.shownImageForTesting)
        XCTAssertFalse(panel.isVisibleForTesting)
    }

    // MARK: SEC05 — the Viewer

    func testLockDropsTheViewerAndEverythingItShowed() throws {
        let a = try app()
        a.openViewer()
        let viewer = try XCTUnwrap(a.viewer)
        viewer.loadTextForTesting("secret item")
        viewer.typeForTesting("edited ")
        XCTAssertTrue(viewer.canUndoForTesting, "an edit on the undo stack")
        XCTAssertGreaterThan(viewer.nodeCountForTesting, 3, "the tree holds the items")

        a.lock()
        XCTAssertNil(a.viewer, "the controller is let go")
        XCTAssertTrue(viewer.discarded)
        XCTAssertEqual(viewer.nodeCountForTesting, 3, "the three roots, nothing under them")
        XCTAssertEqual(viewer.shownTextForTesting, "")
        XCTAssertFalse(viewer.canUndoForTesting, "the undo stack is gone too")
        XCTAssertFalse(viewer.window?.isVisible ?? false)
    }

    func testTheViewerOpensAgainAfterAnUnlock() throws {
        let a = try app()
        a.openViewer()
        let first = try XCTUnwrap(a.viewer)
        a.lock()
        unlock(a)
        a.openViewer()
        let second = try XCTUnwrap(a.viewer)
        XCTAssertFalse(first === second, "a fresh one, built from the stores")
        XCTAssertGreaterThan(second.nodeCountForTesting, 3)
        a.lock()
    }

    // MARK: SEC05 — the recovery phrase and a lock

    func testALockClosesTheRecoveryPhraseAndTheNextUnlockSaysWhereItIs() throws {
        let a = try app()
        _ = try Vault.createRecovery(for: try XCTUnwrap(Storage.key))
        RecoveryDialogs.presentSinkForTesting = { _ in a.lock() }   // the lock lands while the sheet is up
        RecoveryDialogs.presentResultForTesting = false            // what AbortableModal returns then
        a.showRecoveryPhrase()
        XCTAssertTrue(a.isLocked)
        XCTAssertTrue(a.phraseNotConfirmedForTesting)
        XCTAssertTrue(infos.isEmpty, "nothing while locked")

        unlock(a)
        spinMainQueue()
        XCTAssertEqual(infos.count, 1)
        XCTAssertTrue(try XCTUnwrap(infos.first).contains("Show…"))
        XCTAssertFalse(a.phraseNotConfirmedForTesting)
        a.lock(); unlock(a); spinMainQueue()
        XCTAssertEqual(infos.count, 1, "said once")
        a.lock()
    }

    func testAConfirmedPhraseLeavesNoNote() throws {
        let a = try app()
        _ = try Vault.createRecovery(for: try XCTUnwrap(Storage.key))
        RecoveryDialogs.presentSinkForTesting = { _ in }
        a.showRecoveryPhrase()
        XCTAssertFalse(a.phraseNotConfirmedForTesting)
        a.lock(); unlock(a); spinMainQueue()
        XCTAssertTrue(infos.isEmpty)
        a.lock()
    }

    func testAPhraseNeverShownBecauseOfALockGetsTheSameNote() throws {
        // Enable: the lock lands in the Touch ID / backup step, before the dialog (SEC01 round 1
        // skipped the dialog; now the note points at Show… afterwards).
        let a = try app(protected: false)
        var shown = 0
        RecoveryDialogs.presentSinkForTesting = { _ in shown += 1 }
        a.backup.onStateChange = { _ in a.lock() }
        defer { a.backup.onStateChange = nil }
        XCTAssertTrue(a.enableProtection(with: .of("pw")))
        XCTAssertEqual(shown, 0)
        XCTAssertTrue(a.phraseNotConfirmedForTesting)
        a.backup.onStateChange = nil
        unlock(a)
        spinMainQueue()
        XCTAssertEqual(infos.count, 1)
        a.lock()
    }

    func testTheRecoveryPhraseDialogIsAbortable() throws {
        // The real dialog goes through AbortableModal: an abort (what lock() delivers) is "not confirmed".
        AbortableModal.responseForTesting = { _ in .abort }
        XCTAssertFalse(RecoveryDialogs.present(words: Array(repeating: "abandon", count: 24)))
        AbortableModal.responseForTesting = { _ in .alertFirstButtonReturn }
        XCTAssertTrue(RecoveryDialogs.present(words: Array(repeating: "abandon", count: 24)))
    }

    /// Print… runs the print panel as its own app-modal session over the phrase sheet
    /// (`NSPrintOperation.run()`), and its preview is the phrase (audit round 1: a lock then left
    /// both on screen). Stand-in for the panel: a bare window run modally inside `runForeign`.
    /// A lock while it is up ends the panel's session, and the sheet's as soon as control is back
    /// in its loop — the sheet returns `.abort`, "not confirmed".
    func testALockDuringThePrintPanelEndsItAndThePhraseSheetUnderIt() throws {
        let a = try app()
        let sheet = NSAlert(); sheet.messageText = "phrase"; sheet.addButton(withTitle: "I've saved it")
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        var panelResponse: NSApplication.ModalResponse?
        var lockedOverThePanel = false
        let endSheet = after(3.0) { NSApp.stopModal(withCode: .OK) }
        let pressPrint = after(0.05) {
            let lockTimer = self.after(0.05) {
                lockedOverThePanel = NSApp.modalWindow === panel
                a.lock()
            }
            let endPanel = self.after(0.5) { NSApp.stopModal(withCode: .OK) }
            AbortableModal.runForeign { panelResponse = NSApp.runModal(for: panel) }
            lockTimer.invalidate(); endPanel.invalidate(); panel.orderOut(nil)
        }
        let sheetResponse = AbortableModal.run(sheet)
        pressPrint.invalidate(); endSheet.invalidate(); sheet.window.orderOut(nil)
        XCTAssertTrue(lockedOverThePanel, "the lock landed while the panel was the session")
        XCTAssertTrue(a.isLocked)
        XCTAssertEqual(panelResponse, .abort, "the panel's session ends with the lock")
        XCTAssertEqual(sheetResponse, .abort, "and the sheet's as soon as control is back in its loop")
        XCTAssertEqual(AbortableModal.depth, 0)
    }

    /// Audit round 2: a third session over the print panel (a save panel from the panel's PDF menu,
    /// say). `abortModal` ends only that one and the panel — its preview is the phrase — would be
    /// the session again. The request is chased down: the save panel goes, then the panel on the
    /// next tick, then the sheet when control is back in its loop.
    func testALockUnderANestedSessionOverThePrintPanelEndsAllThree() throws {
        let a = try app()
        let sheet = NSAlert(); sheet.messageText = "phrase"; sheet.addButton(withTitle: "I've saved it")
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        let save = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        var panelResponse: NSApplication.ModalResponse?
        var saveResponse: NSApplication.ModalResponse?
        var lockedOverTheSavePanel = false
        var panelWasTheSessionAgain = false
        let endSheet = after(4.0) { NSApp.stopModal(withCode: .OK) }
        let pressPrint = after(0.05) {
            let pressSave = self.after(0.05) {
                let lockTimer = self.after(0.05) {
                    lockedOverTheSavePanel = NSApp.modalWindow === save
                    a.lock()
                }
                let endSave = self.after(0.5) { NSApp.stopModal(withCode: .OK) }
                saveResponse = NSApp.runModal(for: save)      // the third session, over the panel
                lockTimer.invalidate(); endSave.invalidate(); save.orderOut(nil)
                panelWasTheSessionAgain = NSApp.modalWindow === panel
            }
            let endPanel = self.after(1.5) { NSApp.stopModal(withCode: .OK) }
            AbortableModal.runForeign { panelResponse = NSApp.runModal(for: panel) }
            pressSave.invalidate(); endPanel.invalidate(); panel.orderOut(nil)
        }
        let sheetResponse = AbortableModal.run(sheet)
        pressPrint.invalidate(); endSheet.invalidate(); sheet.window.orderOut(nil)
        XCTAssertTrue(lockedOverTheSavePanel)
        XCTAssertTrue(panelWasTheSessionAgain, "abortModal ended the innermost session only")
        XCTAssertTrue(a.isLocked)
        XCTAssertEqual(saveResponse, .abort)
        XCTAssertEqual(panelResponse, .abort, "the panel's session is ended on the next tick")
        XCTAssertEqual(sheetResponse, .abort, "and the sheet's when control is back in its loop")
        XCTAssertEqual(AbortableModal.depth, 0)
    }

    /// Without a lock the foreign panel completes on its own and the sheet stays — Print… then
    /// "I've saved it" is still one confirmation.
    func testThePrintPanelWithoutALockLeavesTheSheetRunning() throws {
        let sheet = NSAlert(); sheet.messageText = "phrase"; sheet.addButton(withTitle: "I've saved it")
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: .titled, backing: .buffered, defer: false)
        var panelResponse: NSApplication.ModalResponse?
        var sheetStillUp = false
        let endSheet = after(3.0) { NSApp.stopModal(withCode: .OK) }
        let pressPrint = after(0.05) {
            let endPanel = self.after(0.05) { NSApp.stopModal(withCode: .OK) }
            AbortableModal.runForeign { panelResponse = NSApp.runModal(for: panel) }
            endPanel.invalidate(); panel.orderOut(nil)
            sheetStillUp = NSApp.modalWindow === sheet.window
            NSApp.stopModal(withCode: .alertFirstButtonReturn)
        }
        let sheetResponse = AbortableModal.run(sheet)
        pressPrint.invalidate(); endSheet.invalidate(); sheet.window.orderOut(nil)
        XCTAssertEqual(panelResponse, .OK)
        XCTAssertTrue(sheetStillUp)
        XCTAssertEqual(sheetResponse, .alertFirstButtonReturn)
    }

    // MARK: SEC05 — open menus

    private final class RecordingMenu: NSMenu {
        var cancelled = 0
        override func cancelTracking() { cancelled += 1; super.cancelTracking() }
    }

    func testLockClosesTheMenusTheDelegateHasOpen() throws {
        let a = try app()
        let menu = RecordingMenu(title: "test")
        menu.delegate = a
        a.menuWillOpen(menu)                           // what AppKit sends when the menu opens
        XCTAssertEqual(a.openTrackedMenusForTesting, 1)
        a.lock()
        XCTAssertEqual(menu.cancelled, 1, "the lock ends the menu's tracking")
    }

    // MARK: SEC03 — Secure Event Input

    func testSecureInputFollowsTheFocusOfAPasswordField() {
        let field = SecurePasswordField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.assumeKeyAndActiveForTesting = true
        XCTAssertFalse(field.hasSecureInputForTesting)
        _ = field.becomeFirstResponder()
        XCTAssertTrue(field.hasSecureInputForTesting)
        XCTAssertEqual(SecureEventInput.callsForTesting, ["enable"])
        _ = field.resignFirstResponder()
        XCTAssertFalse(field.hasSecureInputForTesting)
        XCTAssertEqual(SecureEventInput.callsForTesting, ["enable", "disable"])
        XCTAssertEqual(SecureEventInput.depth, 0)
    }

    func testSecureInputNeedsTheKeyWindowAndTheActiveApp() {
        let field = SecurePasswordField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.assumeKeyAndActiveForTesting = false     // in XCTest the window is never key, the app never active
        _ = field.becomeFirstResponder()
        XCTAssertFalse(field.hasSecureInputForTesting, "focus alone is not enough")
        XCTAssertTrue(SecureEventInput.callsForTesting.isEmpty)
    }

    func testTwoFieldsShareOneSystemState() {
        let one = SecurePasswordField(frame: .zero), two = SecurePasswordField(frame: .zero)
        one.assumeKeyAndActiveForTesting = true; two.assumeKeyAndActiveForTesting = true
        _ = one.becomeFirstResponder()
        _ = two.becomeFirstResponder()                  // the confirm field takes over
        _ = one.resignFirstResponder()
        XCTAssertEqual(SecureEventInput.depth, 1, "still on for the second field")
        XCTAssertEqual(SecureEventInput.callsForTesting, ["enable"], "not flipped off and on in between")
        _ = two.resignFirstResponder()
        XCTAssertEqual(SecureEventInput.depth, 0)
        XCTAssertEqual(SecureEventInput.callsForTesting, ["enable", "disable"])
    }

    func testATokenEndsOnceAndWhenFreed() {
        var token: SecureEventInput? = SecureEventInput()
        token?.begin(); token?.begin()
        XCTAssertEqual(SecureEventInput.depth, 1)
        token?.end(); token?.end()
        XCTAssertEqual(SecureEventInput.depth, 0)
        token?.begin()
        token = nil                                    // forgotten: deinit ends it
        XCTAssertEqual(SecureEventInput.depth, 0)
        XCTAssertEqual(SecureEventInput.callsForTesting, ["enable", "disable", "enable", "disable"])
    }

    func testThePhraseBoxRunsUnderSecureInputAndALockClosesIt() {
        // askPhrase builds its alert and hands it to AbortableModal; the token is on for the box
        // and off before anything else. An abort (a lock) is Cancel.
        AbortableModal.responseForTesting = { message in
            XCTAssertEqual(SecureEventInput.depth, 1, "on while the box is open: \(message)")
            return .abort
        }
        XCTAssertNil(RecoveryDialogs.askPhrase())
        XCTAssertEqual(SecureEventInput.depth, 0)
        XCTAssertEqual(SecureEventInput.callsForTesting, ["enable", "disable"])
    }

    // MARK: SEC02 — the .corrupt-… copies and the vault

    private func plantCopy(_ name: String, _ text: String) throws -> URL {
        let url = Storage.directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }
    private func opens(_ url: URL, with key: SecureKey) -> String? {
        guard let d = try? Data(contentsOf: url), let p = try? Vault.decrypt(d, key: key) else { return nil }
        return String(data: p, encoding: .utf8)
    }

    func testTurningProtectionOnSealsThePlainCopies() throws {
        let a = try app(protected: false)
        let h = try plantCopy("history.json.corrupt-1700000000", "old history")
        let t = try plantCopy("templates.json.corrupt-1700000000-2", "old templates")
        let s = try plantCopy("settings.json.corrupt-1700000000", "{}")
        let other = try plantCopy("notes.txt", "not a copy")
        RecoveryDialogs.presentSinkForTesting = { _ in }
        XCTAssertTrue(a.enableProtection(with: .of("pw")))
        let key = try XCTUnwrap(Storage.key)
        XCTAssertEqual(opens(h, with: key), "old history")
        XCTAssertEqual(opens(t, with: key), "old templates")
        XCTAssertEqual(try Data(contentsOf: s), Data("{}".utf8), "settings copies are never touched")
        XCTAssertEqual(try Data(contentsOf: other), Data("not a copy".utf8))
    }

    func testACopySetAsideUnderAVaultStaysAsItIs() throws {
        // A plain file found under a vault was refused (.notEncrypted) and may be planted: sealing
        // it with the vault's key would make it loadable if it were renamed back. It stays plain —
        // through Start Fresh and through an unlock.
        let a = try app()
        try Data("planted".utf8).write(to: Storage.templatesURL)
        a.templates.reload()
        XCTAssertEqual(a.templates.loadFailure, .notEncrypted)
        a.startFresh()
        let copies = Storage.setAsideCopies()
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(try Data(contentsOf: copies[0]), Data("planted".utf8), "not sealed by Start Fresh")
        a.lock(); unlock(a)
        XCTAssertEqual(try Data(contentsOf: copies[0]), Data("planted".utf8), "nor by an unlock")
        a.lock()
    }

    func testSealingSkipsSealedCopiesSymlinksAndOversizedOnes() throws {
        let a = try app(protected: false)
        let plain = try plantCopy("history.json.corrupt-1", "plain")
        let otherKey = try Vault.prepareEnable(password: .of("x"), rounds: 1000).key
        defer { otherKey.zero() }
        let sealedElsewhere = Storage.directory.appendingPathComponent("history.json.corrupt-2")
        let foreign = try Vault.encrypt(Data("foreign".utf8), key: otherKey)
        try foreign.write(to: sealedElsewhere)
        let target = try plantCopy("elsewhere.txt", "pointed at")
        let link = Storage.directory.appendingPathComponent("templates.json.corrupt-3")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        // One byte over the read limit — a sparse file, so it costs nothing on disk; BoundedFileReader
        // refuses it on its size before reading (audit round 1: the earlier test made no such file).
        let big = Storage.directory.appendingPathComponent("history.json.corrupt-4")
        XCTAssertTrue(FileManager.default.createFile(atPath: big.path, contents: nil))
        let handle = try FileHandle(forWritingTo: big)
        try handle.truncate(atOffset: UInt64(Limits.dataFileMaxBytes) + 1)
        try handle.close()
        RecoveryDialogs.presentSinkForTesting = { _ in }
        XCTAssertTrue(a.enableProtection(with: .of("pw")))
        let key = try XCTUnwrap(Storage.key)
        XCTAssertEqual(opens(plain, with: key), "plain")
        XCTAssertEqual(try Data(contentsOf: sealedElsewhere), foreign, "already sealed: left alone")
        XCTAssertEqual(try Data(contentsOf: target), Data("pointed at".utf8), "a symlink is not followed")
        XCTAssertEqual(try XCTUnwrap(try big.resourceValues(forKeys: [.fileSizeKey]).fileSize), Limits.dataFileMaxBytes + 1, "over the limit: left as it is")
        let head = try FileHandle(forReadingFrom: big)
        XCTAssertEqual(try head.read(upToCount: 64), Data(count: 64), "and not sealed: still the zeros it was")
        try head.close()
    }

    func testAPasswordChangeReSealsTheCopiesAndDisableUnsealsThem() throws {
        let a = try app(protected: false)
        let h = try plantCopy("history.json.corrupt-1", "old history")
        RecoveryDialogs.presentSinkForTesting = { _ in }
        XCTAssertTrue(a.enableProtection(with: .of("pw")))
        Vault.askPasswordForTesting = { _ in .of("new") }
        a.changePassword()
        let newKey = try XCTUnwrap(Storage.key)
        XCTAssertTrue(try XCTUnwrap(newKey.provenance).passwordDerives)
        XCTAssertEqual(opens(h, with: newKey), "old history", "re-sealed with the new key")

        Vault.askPasswordForTesting = { _ in .of("new") }
        XCTAssertTrue(a.disableProtection())
        XCTAssertEqual(try Data(contentsOf: h), Data("old history".utf8), "plain again, like the live files")
    }

    /// Audit round 1 (P2): a lock in the follow-ups of a password change — the Touch ID step or
    /// the backup's state change, after the new key is published — zeroes the new key; the
    /// re-seal of the copies then used it and the process stopped. The copies are re-sealed first,
    /// with both keys alive; the lock finds nothing left to do with them.
    func testALockInTheRekeyFollowUpFindsTheCopiesAlreadyReSealed() throws {
        let a = try app(protected: false)
        let h = try plantCopy("history.json.corrupt-1", "old history")
        RecoveryDialogs.presentSinkForTesting = { _ in }
        XCTAssertTrue(a.enableProtection(with: .of("pw")))
        Vault.askPasswordForTesting = { _ in .of("new") }
        a.backup.onStateChange = { _ in a.lock() }        // the auditor's probe: the lock lands in forceNext()
        defer { a.backup.onStateChange = nil }
        a.changePassword()
        XCTAssertTrue(a.isLocked)
        XCTAssertNil(Storage.key)
        a.backup.onStateChange = nil
        unlock(a, password: "new")
        XCTAssertEqual(opens(h, with: try XCTUnwrap(Storage.key)), "old history", "re-sealed with the new key before the lock could land")
        a.lock()
    }

    func testResetRemovesEveryCopyAndNothingElse() throws {
        _ = try app(protected: false)
        _ = try plantCopy("history.json.corrupt-1", "a")
        _ = try plantCopy("templates.json.corrupt-1", "b")
        _ = try plantCopy("settings.json.corrupt-1", "c")
        let other = try plantCopy("notes.txt", "keep")
        Storage.removeSetAsideCopies()
        XCTAssertTrue(Storage.setAsideCopies().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: Storage.directory.appendingPathComponent("settings.json.corrupt-1").path))
        XCTAssertEqual(try Data(contentsOf: other), Data("keep".utf8))
    }

    // MARK: SEC04 — the self-test's folder

    func testABareSelfTestGetsItsOwnTemporaryFolder() {
        let bare = Storage.chooseDirectory(environment: [:], selfTest: true)
        XCTAssertNotEqual(bare.standardizedFileURL.path, Storage.defaultDirectory.standardizedFileURL.path)
        XCTAssertTrue(bare.lastPathComponent.hasPrefix("keepit-selftest-"))
        let explicit = Storage.chooseDirectory(environment: ["KEEPIT_DATA_DIR": "/tmp/x"], selfTest: true)
        XCTAssertEqual(explicit.path, "/tmp/x")
        let normal = Storage.chooseDirectory(environment: [:], selfTest: false)
        XCTAssertEqual(normal, Storage.defaultDirectory)
    }
}
