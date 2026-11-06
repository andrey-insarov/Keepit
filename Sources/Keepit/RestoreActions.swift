import AppKit
import KeepitCore
import UniformTypeIdentifiers

/// Restore from a `.keepit` file — docs/BACKUP.md "Restore". One flow for Restore…, a
/// double-clicked file and the first-launch offer: pick → unlock → verify → preview → Replace or
/// Merge → apply. Nothing changes until step 6.
extension AppDelegate {

    // MARK: Entry points

    /// Settings → Backup → Restore…: the file panel opens in the backup folder when there is one.
    @objc func restoreBackupTapped() {
        var start: URL?
        if let bm = settings.backupBookmark, let dest = backup.destination as? BookmarkDestination, dest.bookmark == bm {
            try? dest.withFolder { start = $0 }
        }
        chooseAndRestore(startingIn: start)
    }

    func chooseAndRestore(startingIn dir: URL?) {
        guard !isLocked else { NSSound.beep(); return }
        let panel = NSOpenPanel()
        panel.title = L("Restore from Backup")
        panel.message = L("Choose a Keepit backup (.keepit). Automatic backups are named Keepit-<date>-….keepit.")
        panel.allowedContentTypes = [Self.backupType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let dir { panel.directoryURL = dir }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        restore(from: url)
    }

    /// First launch and after Reset…: offer a restore before anything else.
    func offerRestoreOnFirstRun() -> Bool {
        let a = NSAlert()
        a.alertStyle = .informational
        a.icon = NSImage(systemSymbolName: "arrow.counterclockwise.circle", accessibilityDescription: nil)
        a.messageText = L("Restore from a backup?")
        a.informativeText = L("If you have a Keepit backup — an automatic one in iCloud Drive or another folder, or an exported .keepit file — you can bring your history and templates back now. You can also do this later from Settings → Backup.")
        a.addButton(withTitle: L("Restore from Backup…"))
        a.addButton(withTitle: L("Start Fresh"))
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return false }
        chooseAndRestore(startingIn: nil)
        return true
    }

    // MARK: The flow

    func restore(from url: URL) {
        guard !isLocked else { NSSound.beep(); return }
        guard !restoreInProgress else { pendingOpenURLs.append(url); return }   // one at a time; this one runs after
        restoreInProgress = true
        defer { restoreInProgress = false; RunLoop.main.perform { [weak self] in self?.openPendingURLs() } }   // next one, after this frame
        let lockAtStart = lockCount
        // 1–2. Read the whole file and inspect it: limits and minReader before any key work.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try BoundedFileReader.read(url, max: Limits.dataFileMaxBytes)
        } catch BoundedFileReader.Failure.tooLarge {
            Vault.error(Backup.Failure.tooLarge.localizedDescription); return
        } catch {
            Vault.error(Backup.Failure.notABackup.localizedDescription); return
        }
        let inspection: Container.Inspection
        do { inspection = try Backup.inspect(data) } catch { Vault.error(error.localizedDescription); return }

        // 3. Unlock: the current key when the salt says it is ours, else the password, else the phrase.
        guard let unlocked = unlockBackup(data, inspection) else { return }
        defer { unlocked.wipe() }
        let p = unlocked.payload

        // 4. Preview.
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var origin = p.app
        if case .v2(let h, _) = inspection, let label = h.label, !label.isEmpty { origin += " · " + label }
        let a = NSAlert()
        a.messageText = L("Restore from Backup")
        a.informativeText = LF("Created %@ with %@ — %d history item(s), %d template item(s).\n\nMerge adds what is not already there (templates go into a new folder, without their hot keys). Replace discards the current history and templates first — a copy of them is saved before that.",
                               df.string(from: p.created), origin, p.history.count, p.templates.subtreeCount - 1)
        let restorePrefs = NSButton(checkboxWithTitle: L("Also restore preferences (hot keys, limits, options)"), target: nil, action: nil)
        restorePrefs.isEnabled = p.settings != nil
        restorePrefs.sizeToFit()
        a.accessoryView = restorePrefs
        a.addButton(withTitle: L("Merge"))
        a.addButton(withTitle: L("Replace"))
        a.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let mode: RestorePlan.Mode
        switch a.runModal() {
        case .alertFirstButtonReturn: mode = .merge
        case .alertSecondButtonReturn: mode = .replace
        default: return
        }
        let restorePreferences = restorePrefs.state == .on
        let folderName = { () -> String in let f = DateFormatter(); f.dateStyle = .medium; return LF("Imported %@", f.string(from: p.created)) }()
        let makePlan = { try RestorePlan.make(mode: mode, payload: p, currentHistory: self.history.items, currentTemplates: self.templates.root,
                                              currentSettings: self.settings, restorePreferences: restorePreferences, folderName: folderName) }

        // 5. Everything that needs the user is asked now, before anything is captured or changed:
        //    the limits check, what a rollback copy needs, a password when the phrase opened the file.
        guard lockCount == lockAtStart else { Vault.error(RestoreCommit.Failure.locked.localizedDescription); return }
        let preview: RestorePlan
        do { preview = try makePlan() } catch { Vault.error(error.localizedDescription); return }
        if preview.historyDropped > 0 {
            let c = NSAlert()
            c.messageText = L("Not everything fits")
            c.informativeText = LF("%d of the backup's history items fit the current limits; %d would be left out. You can raise the limits in Settings → History first.",
                                   preview.historyAdded, preview.historyDropped)
            c.addButton(withTitle: L("Continue"))
            c.addButton(withTitle: L("Cancel"))
            guard c.runModal() == .alertFirstButtonReturn else { return }
        }
        var rollback: RollbackInputs?
        if mode == .replace {
            guard let r = askRollbackInputs() else { return }
            rollback = r
        }
        defer { rollback?.password?.zero() }
        // A backup opened with its phrase on a Mac without a password: the data must not land
        // unprotected (docs/BACKUP.md, Restore 8). Password and vault first; cancelling changes nothing.
        if !Vault.isEnabled, unlocked.viaRecovery {
            guard lockCount == lockAtStart else { Vault.error(RestoreCommit.Failure.locked.localizedDescription); return }
            guard let pw = Vault.askPassword(title: L("Set Keepit password"),
                                             message: L("This backup was opened with its recovery phrase. Choose a password for Keepit on this Mac; the restored data is protected with it."),
                                             confirm: true) else { return }
            defer { pw.zero() }
            let k = NSAlert()
            k.messageText = L("Keep the recovery phrase?")
            k.informativeText = L("The phrase you just entered can keep working for this Mac, or Keepit can make a new one and show it to you.")
            k.addButton(withTitle: L("Keep This Phrase"))
            k.addButton(withTitle: L("Make a New Phrase"))
            k.addButton(withTitle: L("Cancel"))
            let keep: Bool
            switch k.runModal() {
            case .alertFirstButtonReturn: keep = true
            case .alertSecondButtonReturn: keep = false
            default: return
            }
            guard enableProtection(with: pw, recoveryEntropy: keep ? unlocked.recoveryEntropy : nil) else { return }
        }

        // 6. Commit stage: no more questions. The clipboard watcher is paused so the stores stand
        //    still; the stores' revisions are the proof. Plan → (rollback copy of exactly that
        //    state) → files on disk → live stores. If the stores moved while the copy was being
        //    written (a paste from the menu, say), plan again and copy again; the copy on disk must
        //    be of what Replace discards.
        let wasWatching = monitor.isRunning
        monitor.stop()
        defer { if wasWatching, !isLocked, !(pausedUntil.map { $0 > Date() } ?? false) { monitor.start() } }
        var committed = false
        for _ in 1...3 {
            guard lockCount == lockAtStart else { Vault.error(RestoreCommit.Failure.locked.localizedDescription); return }
            let stamp = dataStamp
            let plan: RestorePlan
            do { plan = try makePlan() } catch { Vault.error(error.localizedDescription); return }
            if mode == .replace, hasDataToLose, let inputs = rollback {
                guard writeRollbackCopy(inputs) else { return }
                guard lockCount == lockAtStart else { Vault.error(RestoreCommit.Failure.locked.localizedDescription); return }
                if dataStamp != stamp { continue }                     // the copy is of an older state: once more
            }
            do { try commit(plan) } catch {
                // Undo done (writeFailed, cannotJournal, …): the files are as they were, work goes on.
                // Undo not done (the journal is still armed): the files are a mix and nothing may be
                // saved over them — not by the watcher the `defer` would restart, not by anything.
                if RestoreCommit.hasArmedJournal { stopForUnfinishedUndo(error) }
                Vault.error(LF("Could not save the restored data: %@", error.localizedDescription)); return
            }
            committed = true
            break
        }
        guard committed else { Vault.error(L("Restore cancelled: the data kept changing. Please try again.")); return }

        // 8. A fresh installation restored with a password: offer to keep it as the vault password.
        if !Vault.isEnabled, let pw = unlocked.password {
            let k = NSAlert()
            k.messageText = L("Protect Keepit with the same password?")
            k.informativeText = L("Use the password you just entered as this Mac's Keepit password. Automatic backup can then be switched on for this Mac in Settings → Backup. You can set a different password instead.")
            k.addButton(withTitle: L("Use This Password"))
            k.addButton(withTitle: L("Set a Different Password…"))
            k.addButton(withTitle: L("Not Now"))
            switch k.runModal() {
            case .alertFirstButtonReturn: _ = enableProtection(with: pw)
            case .alertSecondButtonReturn: _ = enableProtection()
            default: break
            }
        }
        info(LF("Restore finished — history: %d item(s), templates: %d item(s).", history.items.count, templates.root.subtreeCount - 1))
    }

    /// Where the stores stand: a plan or a rollback copy made at one stamp is valid only at the same.
    struct DataStamp: Equatable { var history: Int; var templates: Int; var settings: Int; var lock: Int }
    var dataStamp: DataStamp { DataStamp(history: history.revision, templates: templates.revision, settings: settingsRevision, lock: lockCount) }

    /// A fresh installation (or one right after Reset) holds only the example templates: nothing of
    /// the user's, so Replace needs no rollback copy there — and asks for nothing.
    var hasDataToLose: Bool { !history.items.isEmpty || !(templates.root.children.isEmpty || templates.isDefaultTree) }

    /// The transaction: the three files first, as one; the live stores only when they are on disk.
    /// A failed write leaves the files as they were and throws — nothing in memory has moved.
    func commit(_ plan: RestorePlan) throws {
        history.flush(); templates.flush()          // pending debounced saves land first; the journal copies what they wrote
        let templatesJSON = try Storage.encoder.encode(plan.templates)
        let historyJSON = plan.settings.historySave ? try Storage.encoder.encode(plan.history) : nil
        let settingsJSON = try Storage.prettyEncoder.encode(plan.settings)
        try RestoreCommit.writeFiles(templatesJSON: templatesJSON, historyJSON: historyJSON, settingsJSON: settingsJSON)
        apply(settings: plan.settings)          // trust and backup setup stayed this installation's (RestorePlan)
        history.replaceAll(plan.history)
        templates.replaceRoot(plan.templates)
        registerHotKeys()
        viewer?.refresh()
        backup?.noteChange()
    }

    final class UnlockedBackup {
        let payload: Backup.Payload
        /// The password that opened it, when one was typed (kept only to offer it as the vault password).
        let password: SecureBuffer?
        /// The phrase's entropy when the phrase opened it (kept only to offer keeping the phrase).
        private(set) var recoveryEntropy: [UInt8]?
        var viaRecovery: Bool { recoveryEntropy != nil }
        init(payload: Backup.Payload, password: SecureBuffer? = nil, recoveryEntropy: [UInt8]? = nil) {
            self.payload = payload; self.password = password; self.recoveryEntropy = recoveryEntropy
        }
        func wipe() {
            password?.zero()
            recoveryEntropy?.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) }
            recoveryEntropy = nil
        }
    }

    private func unlockBackup(_ data: Data, _ inspection: Container.Inspection) -> UnlockedBackup? {
        // Ours? Same vault salt and a key in memory → try it silently; the GCM tag decides.
        if case .v2(let h, _) = inspection, h.mode == .auto, let key = Storage.key, let mine = Vault.backupHeader(app: ""), mine.salt == h.salt,
           let p = try? Backup.decode(data, dataKey: key) {
            return UnlockedBackup(payload: p)
        }
        let hasRecovery: Bool = { if case .v2(let h, _) = inspection { return h.recovery != nil } else { return false } }()
        let isArchive: Bool = { if case .v2(let h, _) = inspection, h.mode == .auto { return false } else { return true } }()
        let title = isArchive ? L("Archive password") : L("Backup password")
        let message = isArchive ? L("Enter the password this archive was saved with.")
                                : L("Enter the Keepit password of the Mac this backup was made on.")
        for attempt in 1...3 {
            switch Vault.prompt(title: title, message: message, confirm: false, cancelQuits: false,
                                offerRecovery: hasRecovery, recoveryAvailable: hasRecovery) {
            case .cancel:
                return nil
            case .recovery:
                guard let words = RecoveryDialogs.askPhrase(), var entropy = Mnemonic.decode(words) else { Vault.error(L("That is not a valid recovery phrase.")); continue }
                defer { entropy.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) } }
                do { return UnlockedBackup(payload: try Backup.decode(data, recoveryEntropy: entropy), recoveryEntropy: entropy) }
                catch Backup.Failure.wrongPassword { Vault.error(L("This phrase does not open the backup.")) }
                catch { Vault.error(error.localizedDescription); return nil }
            case .password(let pw):
                do {
                    return UnlockedBackup(payload: try Backup.decode(data, password: pw), password: pw)
                } catch Backup.Failure.wrongPassword {
                    pw.zero()
                    if attempt < 3 { Vault.error(L("Wrong password.")) } else { Vault.error(L("Too many wrong attempts.")); return nil }
                } catch {
                    pw.zero()
                    Vault.error(error.localizedDescription)
                    return nil
                }
            }
        }
        return nil
    }

    // MARK: Rollback copy before Replace (docs/BACKUP.md)

    /// What a rollback copy needs from the user, asked before the commit stage: a password when the
    /// vault is off (the copy is a manual export), and a folder when no backup folder is configured
    /// (a file chosen in an open panel grants no right to write next to it). nil: the user declined.
    struct RollbackInputs {
        var password: SecureBuffer?
        /// nil: there was nothing to lose when the user was asked, so no folder was asked for.
        var destination: BackupDestination?
    }

    func askRollbackInputs() -> RollbackInputs? {
        var password: SecureBuffer?
        if !Vault.isEnabled, hasDataToLose {
            guard let pw = Vault.askPassword(title: L("Password for the copy of your current data"),
                                             message: L("Before replacing, Keepit saves what you have now as a .keepit file. Choose a password for that file; you will need it to go back."),
                                             confirm: true) else { return nil }
            password = pw
        }
        if let d = backup.destination { return RollbackInputs(password: password, destination: d) }
        guard hasDataToLose else { return RollbackInputs(password: nil, destination: nil) }
        let panel = NSOpenPanel()
        panel.title = L("Where to save the copy of your current data")
        panel.message = L("Choose a folder for the copy of your current history and templates.")
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let folder = panel.url else { password?.zero(); return nil }
        return RollbackInputs(password: password, destination: PlainFolderDestination(folder))
    }

    /// Secure the current data before it is replaced. Returns false when Replace must not proceed.
    /// Called in the commit stage, after every dialog: the snapshot (history, the template tree as
    /// bytes, settings) and the key are captured here and handed straight to `Storage.ioQueue`, so
    /// Lock — which drains that queue before zeroing the key — can never run between the two.
    /// Sealing runs there; writing, fsync and the read-back on a global queue; the main thread waits
    /// in a progress panel. Replace proceeds only after the read-back matched.
    func writeRollbackCopy(_ inputs: RollbackInputs) -> Bool {
        guard let destination = inputs.destination else {              // empty when asked, not any more
            Vault.error(L("Restore cancelled: the data kept changing. Please try again.")); return false
        }
        history.flush(); templates.flush()
        let created = Date()
        let name = String(BackupEngine.beforeRestorePrefix + BackupEngine.fileName(created: created, sourceID: settings.backupSourceID ?? "local",
                                                                                   backupID: UUID().uuidString.lowercased()).dropFirst("Keepit-".count))
        let items = history.items
        let forBackup = settings.forBackup
        let app = "Keepit \(AppInfo.version)"
        let templatesJSON: Data
        do { templatesJSON = try Storage.encoder.encode(templates.root) }
        catch { Vault.error(LF("Could not prepare the copy of the current data: %@", error.localizedDescription)); return false }
        let seal: () throws -> Data
        if let pw = inputs.password {
            // The task owns its own copy of the password: the caller zeroes the original on its
            // way out, and a wait that ended early (Lock, a stopped panel) must not leave a seal
            // still running with a blank password — it would write a copy that opens with one.
            let own = pw.copy()
            seal = {
                defer { own.zero() }
                return try Backup.encode(json: try Backup.payloadJSON(history: items, templatesJSON: templatesJSON, settings: forBackup, created: created, app: app),
                                         created: created, app: app, password: own)
            }
        } else {
            guard let key = Storage.key, let header = Vault.backupHeader(app: app, sourceID: settings.backupSourceID) else {
                Vault.error(RestoreCommit.Failure.locked.localizedDescription); return false
            }
            seal = { try Backup.encodeAutomatic(json: try Backup.payloadJSON(history: items, templatesJSON: templatesJSON, settings: forBackup, created: created, app: app),
                                                dataKey: key, vault: header) }
        }
        let result = Self.sealAndWriteOffMain(message: L("Saving a copy of your current data…"), seal: seal) { bytes in
            _ = try BackupEngine.write(bytes, sha: BackupEngine.sha256(bytes), name: name, to: destination)
        }
        switch result {
        case .success: return true
        case .failure(let error):
            Vault.error(LF("Could not save the copy of the current data: %@", error.localizedDescription))
            return false
        }
    }

    /// The engine's two stages for a one-off copy: `seal` on `Storage.ioQueue` (it uses the key, and
    /// Lock waits for that queue before zeroing it), `write` on a global queue (no key; a hung volume
    /// blocks nobody). The main thread waits in a modal progress panel, so its run loop keeps serving
    /// events — including the lock notification — meanwhile.
    ///
    /// The completion comes back through the run loop (`RunLoop.main.perform(inModes:)`), not
    /// `DispatchQueue.main.async`: the caller may itself be running inside a main-queue block (the
    /// launch sequence is one), and GCD does not run another main-queue block until that one
    /// returns — which it cannot, it is waiting here. The modal loop services run-loop sources in
    /// its own mode regardless. Until the completion arrives the result is `notFinished`, so a
    /// panel stopped by anything else never reads as success — and a completion that arrives after
    /// the wait ended (the task kept running) touches nothing: it stops only *its own* panel's
    /// session, never whatever dialog is modal by then.
    static func sealAndWriteOffMain(message: String, seal: @escaping () throws -> Data,
                                    write: @escaping (Data) throws -> Void) -> Result<Void, Error> {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 72), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "Keepit"
        panel.isReleasedWhenClosed = false
        let label = NSTextField(labelWithString: message)
        label.frame = NSRect(x: 20, y: 40, width: 320, height: 20)
        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 16, width: 320, height: 16))
        bar.style = .bar; bar.isIndeterminate = true; bar.startAnimation(nil)
        panel.contentView?.addSubview(label); panel.contentView?.addSubview(bar)
        panel.center()
        final class Wait { var result: Result<Void, Error> = .failure(BackupEngine.Failure.notFinished); var active = true }
        let wait = Wait()
        func finish(_ r: Result<Void, Error>) {
            RunLoop.main.perform(inModes: [.modalPanel, .default, .common]) {
                guard wait.active, NSApp.modalWindow === panel else { return }   // our wait is over; not our session
                wait.result = r
                NSApp.stopModal()
            }
        }
        Storage.ioQueue.async {
            switch Result(catching: seal) {
            case .failure(let e): finish(.failure(e))
            case .success(let bytes): DispatchQueue.global(qos: .userInitiated).async { finish(Result { try write(bytes) }) }
            }
        }
        NSApp.runModal(for: panel)
        wait.active = false
        panel.orderOut(nil)
        return wait.result
    }
}
