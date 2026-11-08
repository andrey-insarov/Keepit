import AppKit
import UniformTypeIdentifiers

extension Backup.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notABackup: return L("This is not a Keepit backup file.")
        case .unsupportedVersion, .unsupportedPayloadVersion: return L("The backup was made with a newer version of Keepit.")
        case .needsNewerKeepit(let v): return LF("This backup needs Keepit %@ or newer.", v)
        case .tooLarge: return L("The backup file is too large.")
        case .wrongPassword: return L("Wrong password.")
        case .corrupt: return L("The backup file is damaged.")
        case .invalidContent(let what): return LF("The backup contains invalid data (%@).", what)
        }
    }
}

/// Settings → Backup → Save to Archive… (Restore… is in RestoreActions.swift).
extension AppDelegate {
    static let backupType: UTType = UTType("com.it.keep.backup") ?? UTType(filenameExtension: Backup.fileExtension) ?? .data

    @objc func exportBackup() {
        guard !isLocked else { NSSound.beep(); return }
        if refuseWhileUnreadable() { return }               // an archive of what is in memory would be empty in its place
        let g = lockCount
        let panel = NSSavePanel()
        panel.title = L("Save to Archive")
        panel.nameFieldStringValue = Backup.suggestedFileName()
        panel.allowedContentTypes = [Self.backupType]
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportBackup(to: url, generation: g)
    }

    /// After the file is chosen: the password, then the snapshot. `generation` is the lock count
    /// read before the panel. A lock during the panel or the password prompt purges the stores,
    /// and an archive sealed afterwards would be a valid, empty one announced as saved (3.0.6
    /// candidate review, P2) — so the checks from the top run again after each dialog, and a
    /// lock-and-unlock in between is refused like any other answer given in an earlier generation.
    /// Tests enter here.
    func exportBackup(to url: URL, generation: Int) {
        guard stillExportable(generation) else { return }
        guard let pw = Vault.askPassword(title: L("Archive password"),
                                         message: L("This password locks the archive. You will need it to restore from the file; it is not stored anywhere."),
                                         confirm: true) else { return }
        defer { pw.zero() }
        guard stillExportable(generation) else { return }
        history.flush()
        templates.flush()
        let payload = Backup.Payload(history: history.items, templates: templates.root, settings: settings.forBackup)   // preferences, not this Mac's trust or backup setup
        do {
            let data = try Backup.encode(payload, password: pw)
            try data.write(to: url, options: .atomic)
            info(LF("Archive saved: %d history item(s), %d template item(s).", history.items.count, templates.root.subtreeCount - 1))
        } catch {
            Vault.error(LF("Could not save the archive: %@", error.localizedDescription))
        }
    }

    private func stillExportable(_ generation: Int) -> Bool {
        if isLocked { return false }                                   // nothing to say over a locked app
        guard lockCount == generation else { Vault.error(L("Archive not saved: Keepit was locked meanwhile.")); return false }
        return !refuseWhileUnreadable()                                // an armed journal included
    }

    func info(_ text: String) {
        if let sink = infoSinkForTesting { sink(text); return }
        let a = NSAlert()
        a.messageText = text
        a.alertStyle = .informational
        a.runModal()
    }
}
