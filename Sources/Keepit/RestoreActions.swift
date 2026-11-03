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
        let p = unlocked.payload

        // 4. Preview.
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var origin = p.app
        if case .v2(let h, _) = inspection, let label = h.label, !label.isEmpty { origin += " · " + label }
        let a = NSAlert()
        a.messageText = L("Restore from Backup")
        a.informativeText = LF("Created %@ with %@ — %d history item(s), %d template item(s).\n\nMerge adds what is not already there (templates go into a new folder). Replace discards the current history and templates first — a copy of them is saved before that.",
                               df.string(from: p.created), origin, p.history.count, p.templates.subtreeCount - 1)
        let restorePrefs = NSButton(checkboxWithTitle: L("Also restore preferences (hot keys, limits, options)"), target: nil, action: nil)
        restorePrefs.isEnabled = p.settings != nil
        restorePrefs.sizeToFit()
        a.accessoryView = restorePrefs
        a.addButton(withTitle: L("Merge"))
        a.addButton(withTitle: L("Replace"))
        a.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let choice = a.runModal()

        // 5–6. Apply.
        switch choice {
        case .alertFirstButtonReturn:
            history.merge(p.history)
            let folder = DateFormatter(); folder.dateStyle = .medium
            if !templates.mergeImported(p.templates, folderName: LF("Imported %@", folder.string(from: p.created))) {
                Vault.error(LF("Limit reached: at most %d template items, %d levels deep.", Limits.templateMaxCount, Limits.templateMaxDepth))
            }
        case .alertSecondButtonReturn:
            guard makeRollbackCopy() else { return }
            history.replaceAll(p.history)
            templates.replaceRoot(p.templates)
        default:
            return
        }
        if restorePrefs.state == .on, let s = p.settings {
            apply(settings: settings.applyingRestorable(from: s))   // trust and backup setup stay this installation's
        }
        registerHotKeys()
        viewer?.refresh()
        backup?.noteChange()

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
            pw.zero()
        }
        info(LF("Restore finished — history: %d item(s), templates: %d item(s).", history.items.count, templates.root.subtreeCount - 1))
    }

    struct UnlockedBackup {
        var payload: Backup.Payload
        /// The password that opened it, when one was typed (kept only to offer it as the vault password).
        var password: SecureBuffer?
    }

    private func unlockBackup(_ data: Data, _ inspection: Container.Inspection) -> UnlockedBackup? {
        // Ours? Same vault salt and a key in memory → try it silently; the GCM tag decides.
        if case .v2(let h, _) = inspection, h.mode == .auto, let key = Storage.key, let mine = Vault.backupHeader(app: ""), mine.salt == h.salt,
           let p = try? Backup.decode(data, dataKey: key) {
            return UnlockedBackup(payload: p, password: nil)
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
                guard let words = RecoveryDialogs.askPhrase(), let entropy = Mnemonic.decode(words) else { Vault.error(L("That is not a valid recovery phrase.")); continue }
                do { return UnlockedBackup(payload: try Backup.decode(data, recoveryEntropy: entropy), password: nil) }
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
    func makeRollbackCopy() -> Bool {
        if history.items.isEmpty && templates.root.children.isEmpty { return true }      // nothing to lose
        history.flush(); templates.flush()
        let name = BackupEngine.beforeRestorePrefix + BackupEngine.fileName(created: Date(), sourceID: settings.backupSourceID ?? "local", backupID: UUID().uuidString.lowercased()).dropFirst("Keepit-".count)
        let payload = Backup.Payload(history: history.items, templates: templates.root, settings: settings.forBackup)
        let bytes: Data
        do {
            if Vault.isEnabled, let key = Storage.key, let header = Vault.backupHeader(app: "Keepit \(AppInfo.version)", sourceID: settings.backupSourceID) {
                bytes = try Backup.encodeAutomatic(payload, dataKey: key, vault: header)
            } else {
                guard let pw = Vault.askPassword(title: L("Password for the copy of your current data"),
                                                 message: L("Before replacing, Keepit saves what you have now as a .keepit file. Choose a password for that file; you will need it to go back."),
                                                 confirm: true) else { return false }
                defer { pw.zero() }
                bytes = try Backup.encode(payload, password: pw)
            }
        } catch {
            Vault.error(LF("Could not prepare the copy of the current data: %@", error.localizedDescription)); return false
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
        do {
            _ = try destination.withFolder { folder in
                _ = try BackupEngine.write(bytes, sha: BackupEngine.sha256(bytes), name: String(name), to: PlainFolderDestination(folder))
            }
            return true
        } catch {
            Vault.error(LF("Could not save the copy of the current data: %@", error.localizedDescription))
            return false
        }
    }
}
