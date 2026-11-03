import AppKit
import KeepitCore
import UniformTypeIdentifiers

/// Restore from a `.keepit` file — docs/BACKUP.md "Restore". One flow for Import…, Restore…, a
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

    /// Settings → Backup → Import…: any `.keepit` file.
    @objc func importBackup() { chooseAndRestore(startingIn: nil) }

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
        a.informativeText = L("If you have a Keepit backup — an automatic one in iCloud Drive or another folder, or an exported .keepit file — you can bring your history and templates back now. You can also do this later from Settings → General → Backup.")
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
        let lockAtStart = lockCount
        // 1–2. Read the whole file and inspect it: limits and minReader before any key work.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue,
              size <= Limits.dataFileMaxBytes else { Vault.error(Backup.Failure.tooLarge.localizedDescription); return }
        guard let data = try? Data(contentsOf: url) else { Vault.error(Backup.Failure.notABackup.localizedDescription); return }
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
        guard lockCount == lockAtStart else { Vault.error(L("Restore cancelled: Keepit was locked meanwhile.")); return }

        // 5. Plan: the whole outcome, checked against the final settings and every limit, before
        //    anything changes. If the plan fails, nothing has happened.
        let folder = DateFormatter(); folder.dateStyle = .medium
        let plan: RestorePlan
        do {
            plan = try RestorePlan.make(mode: mode, payload: p, currentHistory: history.items, currentTemplates: templates.root,
                                        currentSettings: settings, restorePreferences: restorePrefs.state == .on,
                                        folderName: LF("Imported %@", folder.string(from: p.created)))
        } catch { Vault.error(error.localizedDescription); return }
        if plan.historyDropped > 0 {
            let c = NSAlert()
            c.messageText = L("Not everything fits")
            c.informativeText = LF("%d of the backup's history items fit the current limits; %d would be left out. You can raise the limits in Settings → History first.",
                                   plan.historyAdded, plan.historyDropped)
            c.addButton(withTitle: L("Continue"))
            c.addButton(withTitle: L("Cancel"))
            guard c.runModal() == .alertFirstButtonReturn, lockCount == lockAtStart else { return }
        }

        // Replace first secures the current data; the copy is sealed and written off the main thread.
        if mode == .replace {
            guard makeRollbackCopy() else { return }
            guard lockCount == lockAtStart else { Vault.error(L("Restore cancelled: Keepit was locked meanwhile.")); return }
        }

        // A backup opened with its phrase on a Mac without a password: the data must not land
        // unprotected (docs/BACKUP.md, Restore 8). Password and vault first; cancelling changes nothing.
        if !Vault.isEnabled, unlocked.viaRecovery {
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
            guard lockCount == lockAtStart else { Vault.error(L("Restore cancelled: Keepit was locked meanwhile.")); return }
        }

        // 6. Apply as one transaction: settings first (the history is trimmed by them), then the stores.
        apply(plan)

        // 8. A fresh installation restored with a password: offer to keep it as the vault password.
        if !Vault.isEnabled, let pw = unlocked.password {
            let k = NSAlert()
            k.messageText = L("Protect Keepit with the same password?")
            k.informativeText = L("Use the password you just entered as this Mac's Keepit password. Automatic backups into the same folder then continue without setup. You can set a different one instead.")
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

    /// The transaction. Nothing here can fail: every check was made when the plan was built.
    func apply(_ plan: RestorePlan) {
        apply(settings: plan.settings)          // trust and backup setup stayed this installation's (RestorePlan)
        history.replaceAll(plan.history)
        switch plan.templates {
        case .replace(let root): templates.replaceRoot(root)
        case .addFolder(let folder):
            if !templates.insertImported(folder) { Vault.error(RestorePlan.Failure.templateLimit.localizedDescription) }
        }
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
        let message: String = {
            if case .v2(let h, _) = inspection, h.mode == .auto { return L("Enter the Keepit password of the Mac this backup was made on.") }
            return L("Enter the password this backup was exported with.")
        }()
        for attempt in 1...3 {
            switch Vault.prompt(title: L("Backup password"), message: message, confirm: false, cancelQuits: false,
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

    /// Secure the current data before it is replaced. Returns false when Replace must not proceed.
    /// What needs the user (a password for a manual copy, a folder) is asked on the main thread;
    /// sealing and writing — PBKDF2, compression, fsync, the read-back — run on a background queue
    /// while a small progress panel keeps the run loop alive, so a slow or hung volume never blocks
    /// the interface or Lock. Replace proceeds only after the copy was written and read back.
    func makeRollbackCopy() -> Bool {
        if history.items.isEmpty && templates.root.children.isEmpty { return true }      // nothing to lose
        history.flush(); templates.flush()
        let name = String(BackupEngine.beforeRestorePrefix + BackupEngine.fileName(created: Date(), sourceID: settings.backupSourceID ?? "local",
                                                                                   backupID: UUID().uuidString.lowercased()).dropFirst("Keepit-".count))
        let payload = Backup.Payload(history: history.items, templates: templates.root, settings: settings.forBackup)
        // The sealing step, decided here, run there. A manual copy needs a password now.
        let seal: () throws -> Data
        if Vault.isEnabled, let key = Storage.key, let header = Vault.backupHeader(app: "Keepit \(AppInfo.version)", sourceID: settings.backupSourceID) {
            seal = { try Backup.encodeAutomatic(payload, dataKey: key, vault: header) }
        } else {
            guard let pw = Vault.askPassword(title: L("Password for the copy of your current data"),
                                             message: L("Before replacing, Keepit saves what you have now as a .keepit file. Choose a password for that file; you will need it to go back."),
                                             confirm: true) else { return false }
            seal = { defer { pw.zero() }; return try Backup.encode(payload, password: pw) }
        }
        // Where: the backup folder if there is one, otherwise a folder the user picks now
        // (a file chosen in an open panel grants no right to write next to it).
        let destination: BackupDestination
        if let d = backup.destination {
            destination = d
        } else {
            let panel = NSOpenPanel()
            panel.title = L("Where to save the copy of your current data")
            panel.message = L("Choose a folder for the copy of your current history and templates.")
            panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let folder = panel.url else { return false }
            destination = PlainFolderDestination(folder)
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
        var result: Result<Void, Error> = .success(())
        func finish(_ r: Result<Void, Error>) { DispatchQueue.main.async { result = r; NSApp.stopModal() } }
        Storage.ioQueue.async {
            switch Result(catching: seal) {
            case .failure(let e): finish(.failure(e))
            case .success(let bytes): DispatchQueue.global(qos: .userInitiated).async { finish(Result { try write(bytes) }) }
            }
        }
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return result
    }
}
