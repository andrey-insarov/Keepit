import AppKit
import UniformTypeIdentifiers

extension Backup.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notABackup: return L("This is not a Keepit backup file.")
        case .unsupportedVersion: return L("The backup was made with a newer version of Keepit.")
        case .tooLarge: return L("The backup file is too large.")
        case .wrongPassword: return L("Wrong password.")
        case .corrupt: return L("The backup file is damaged.")
        }
    }
}

/// Settings → Security → Backup → Export… / Import… (see Core/Backup.swift for the file format).
extension AppDelegate {
    static let backupType: UTType = UTType("com.it.keep.backup") ?? UTType(filenameExtension: Backup.fileExtension) ?? .data

    @objc func exportBackup() {
        guard !isLocked else { NSSound.beep(); return }
        let panel = NSSavePanel()
        panel.title = L("Export Backup")
        panel.nameFieldStringValue = Backup.suggestedFileName()
        panel.allowedContentTypes = [Self.backupType]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let pw = Vault.askPassword(title: L("Backup password"),
                                         message: L("This password protects the backup file. You will need it to import the file; it is not stored anywhere."),
                                         confirm: true) else { return }
        defer { pw.zero() }
        history.flush()
        templates.flush()
        let payload = Backup.Payload(history: history.items, templates: templates.root, settings: settings)
        do {
            let data = try Backup.encode(payload, password: pw)
            try data.write(to: url, options: .atomic)
            info(LF("Backup saved: %d history item(s), %d template item(s).", history.items.count, templates.root.subtreeCount - 1))
        } catch {
            Vault.error(LF("Could not export the backup: %@", error.localizedDescription))
        }
    }

    @objc func importBackup() {
        guard !isLocked else { NSSound.beep(); return }
        let panel = NSOpenPanel()
        panel.title = L("Import Backup")
        panel.allowedContentTypes = [Self.backupType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue,
              size <= Limits.dataFileMaxBytes else { Vault.error(Backup.Failure.tooLarge.localizedDescription); return }
        guard let data = try? Data(contentsOf: url), Backup.isBackup(data) else {
            Vault.error(Backup.Failure.notABackup.localizedDescription)
            return
        }

        var payload: Backup.Payload?
        for attempt in 1...3 {
            guard let pw = Vault.askPassword(title: L("Backup password"),
                                             message: L("Enter the password this backup was exported with.")) else { return }
            defer { pw.zero() }
            do {
                payload = try Backup.decode(data, password: pw)
                break
            } catch Backup.Failure.wrongPassword {
                if attempt < 3 { Vault.error(L("Wrong password.")) } else { Vault.error(L("Too many wrong attempts.")); return }
            } catch {
                Vault.error(LF("Could not read the backup: %@", error.localizedDescription))
                return
            }
        }
        guard let p = payload else { return }

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        let a = NSAlert()
        a.messageText = L("Import Backup")
        a.informativeText = LF("Created %@ with %@ — %d history item(s), %d template item(s).\n\nMerge adds what is not already there (templates go into a new folder). Replace discards the current history and templates first.",
                               df.string(from: p.created), p.app, p.history.count, p.templates.subtreeCount - 1)
        let restorePrefs = NSButton(checkboxWithTitle: L("Also restore preferences (hot keys, limits, options)"), target: nil, action: nil)
        restorePrefs.isEnabled = p.settings != nil
        restorePrefs.sizeToFit()
        a.accessoryView = restorePrefs
        a.addButton(withTitle: L("Merge"))
        a.addButton(withTitle: L("Replace"))
        a.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let choice = a.runModal()

        switch choice {
        case .alertFirstButtonReturn:
            history.merge(p.history)
            let folder = DateFormatter()
            folder.dateStyle = .medium
            if !templates.mergeImported(p.templates, folderName: LF("Imported %@", folder.string(from: p.created))) {
                Vault.error(LF("Limit reached: at most %d template items, %d levels deep.", Limits.templateMaxCount, Limits.templateMaxDepth))
            }
        case .alertSecondButtonReturn:
            history.replaceAll(p.history)
            templates.replaceRoot(p.templates)
        default:
            return
        }
        if restorePrefs.state == .on, let s = p.settings {
            apply(settings: s)
        }
        registerHotKeys()
        info(LF("Import finished — history: %d item(s), templates: %d item(s).", history.items.count, templates.root.subtreeCount - 1))
    }

    private func info(_ text: String) {
        let a = NSAlert()
        a.messageText = text
        a.alertStyle = .informational
        a.runModal()
    }
}
