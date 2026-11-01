import AppKit
import ServiceManagement

/// Preferences → "Delete Keepit and All Data…": authenticate, make the user type DELETE and tick the
/// acknowledgement, then wipe everything Keepit ever wrote and move the app to the Trash.
extension AppDelegate {
    func uninstallRequested() {
        if Vault.isEnabled {
            guard authenticateForChange(reasonKey: "delete Keepit and all its data") else { return }
        }
        guard UninstallDialog.confirm() else { return }
        performUninstall()
    }

    private func performUninstall() {
        uninstalling = true
        closeAllWindows()
        monitor.stop()
        hotKeys.unregisterAll()
        history.purge()
        templates.purge()
        Storage.clearKey()
        BiometricUnlock.remove()
        try? SMAppService.mainApp.unregister()

        let fm = FileManager.default
        let bundleID = Bundle.main.bundleIdentifier ?? "com.it.keep"
        let home = fm.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        var leftovers: [URL] = [
            Storage.directory,
            library.appendingPathComponent("Application Support/\(bundleID)"),
            library.appendingPathComponent("Caches/\(bundleID)"),
            library.appendingPathComponent("HTTPStorages/\(bundleID)"),
            library.appendingPathComponent("Saved Application State/\(bundleID).savedState"),
            library.appendingPathComponent("WebKit/\(bundleID)"),
        ]
        // Sparkle keeps its state in the app's defaults domain; drop the whole domain.
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
        leftovers.append(library.appendingPathComponent("Preferences/\(bundleID).plist"))
        for url in leftovers { try? fm.removeItem(at: url) }

        // Accessibility grant. TCC entries follow the bundle (even into the Trash, under a renamed
        // copy), so reset it *before* recycling. `tccutil reset` for Accessibility needs admin rights:
        // try plainly first, then through the standard administrator prompt. Not possible from the
        // sandboxed App Store build; a failure is not fatal.
        resetAccessibilityGrant(bundleID: bundleID)

        // Installed through Homebrew? Then brew still has a record of this version.
        let viaBrew = ["/opt/homebrew/Caskroom/keepit", "/usr/local/Caskroom/keepit"].contains { fm.fileExists(atPath: $0) }

        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            DispatchQueue.main.async {
                let a = NSAlert()
                a.alertStyle = .informational
                if error == nil {
                    a.messageText = L("Keepit and all its data have been deleted.")
                    a.informativeText = L("The app has been moved to the Trash. If an Accessibility entry for Keepit remains in System Settings, you can remove it there.")
                } else {
                    a.messageText = L("All Keepit data has been deleted.")
                    a.informativeText = L("Finish by dragging Keepit from the Applications folder to the Trash.")
                }
                if viaBrew {
                    a.informativeText += "\n\n" + L("Keepit was installed with Homebrew; to clear its record run: brew uninstall --cask --force keepit")
                }
                a.addButton(withTitle: L("Quit"))
                a.runModal()
                NSApp.terminate(nil)
            }
        }
    }
}

extension AppDelegate {
    fileprivate func resetAccessibilityGrant(bundleID: String) {
        func run(_ exe: String, _ args: [String]) -> Int32 {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { return -1 }
            p.waitUntilExit()
            return p.terminationStatus
        }
        if run("/usr/bin/tccutil", ["reset", "Accessibility", bundleID]) == 0 { return }
        let prompt = L("Keepit removes its Accessibility permission.").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"/usr/bin/tccutil reset Accessibility \(bundleID)\" with administrator privileges with prompt \"\(prompt)\""
        _ = run("/usr/bin/osascript", ["-e", script])
    }
}

enum UninstallDialog {
    private static let token = "DELETE"

    /// Critical alert; the destructive button is enabled only once "DELETE" is typed and the box ticked.
    static func confirm() -> Bool {
        let a = NSAlert()
        a.alertStyle = .critical
        a.messageText = L("Delete Keepit and all its data?")
        a.informativeText = L("This removes the app, your clipboard history, templates, settings, the Touch ID key and Keepit's permissions. There is no undo. If you have not exported a backup, the data cannot be recovered.")

        // NSAlert wants a frame-based accessory view: lay it out by hand (top → bottom).
        let width: CGFloat = 300
        let ack = NSButton(checkboxWithTitle: L("I understand that Keepit's data will be deleted forever and, without a backup, cannot be recovered."), target: nil, action: nil)
        ack.lineBreakMode = .byWordWrapping
        ack.frame = NSRect(x: 0, y: 0, width: width, height: 10)
        let ackHeight = max(ack.sizeThatFits(NSSize(width: width, height: 200)).height, 34)
        ack.frame = NSRect(x: 0, y: 0, width: width, height: ackHeight)
        let field = NSTextField(frame: NSRect(x: 0, y: ackHeight + 8, width: width, height: 24))
        field.placeholderString = token
        let prompt = NSTextField(labelWithString: LF("Type %@ (in capitals) to confirm:", token))
        prompt.frame = NSRect(x: 0, y: ackHeight + 8 + 24 + 6, width: width, height: 18)
        let box = NSView(frame: NSRect(x: 0, y: 0, width: width, height: ackHeight + 8 + 24 + 6 + 18))
        box.addSubview(prompt)
        box.addSubview(field)
        box.addSubview(ack)
        a.accessoryView = box

        let delete = a.addButton(withTitle: L("Delete Everything"))
        delete.hasDestructiveAction = true
        delete.keyEquivalent = ""              // never the default button
        let cancel = a.addButton(withTitle: L("Cancel"))
        cancel.keyEquivalent = "\r"
        delete.isEnabled = false

        let gate = Gate(field: field, ack: ack, button: delete)
        field.delegate = gate
        ack.target = gate
        ack.action = #selector(Gate.changed)
        a.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        let r = a.runModal()
        return r == .alertFirstButtonReturn && gate.satisfied
    }

    private final class Gate: NSObject, NSTextFieldDelegate {
        let field: NSTextField, ack: NSButton, button: NSButton
        init(field: NSTextField, ack: NSButton, button: NSButton) {
            self.field = field; self.ack = ack; self.button = button
        }
        var satisfied: Bool { field.stringValue == token && ack.state == .on }   // exact, case-sensitive
        func controlTextDidChange(_ obj: Notification) { changed() }
        @objc func changed() { button.isEnabled = satisfied }
    }
}
