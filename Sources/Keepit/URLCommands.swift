import AppKit

/// `keepit://` URL scheme — automation hooks for Shortcuts ("Open URL"), Alfred, Raycast, `open` in the shell.
/// Off unless *Settings → Advanced → Allow keepit:// URL commands* is on: any process or web page can
/// open a URL, and `add` / `paste` act on the clipboard and the front app without confirmation.
///
///     keepit://paste/1            paste history item N (1 = latest, 2 = previous) into the front app
///     keepit://paste/latest       keepit://paste/previous
///     keepit://copy/2             put item N on the clipboard without pasting
///     keepit://template/Name      paste the template called Name (folder path allowed: Work/Signature)
///     keepit://template/Name?copy=1
///     keepit://add?text=…         add text to the history (and the clipboard)
///     keepit://add-template?text=…&name=…
///     keepit://history  keepit://templates  keepit://viewer  keepit://settings
///     keepit://pause    keepit://resume
extension AppDelegate {
    static let urlScheme = "keepit"

    /// A double-clicked file or a keepit:// URL can arrive before `applicationDidFinishLaunching`
    /// (Apple documents that order), or during the welcome dialogs, or while a restore is running.
    /// In all those cases the URLs wait in `pendingOpenURLs`; `openPendingURLs()` runs them, in
    /// order, once the app is ready and no restore is in progress — never a restore inside another.
    func application(_ application: NSApplication, open urls: [URL]) {
        pendingOpenURLs += urls
        openPendingURLs()
    }

    private func open(_ url: URL) {
        openInProgress = true                         // covers the unlock dialog too: nothing re-enters meanwhile
        defer { openInProgress = false }
        if url.isFileURL, url.pathExtension.lowercased() == Backup.fileExtension {
            if isLocked, !unlock() { return }         // a backup opened while locked: ask for the password first
            restore(from: url)
        } else {
            handle(url)
        }
    }

    /// The welcome step on a first run: the `.keepit` the user double-clicked is restored now, in
    /// place of the generic "Restore from a backup?" offer and before the password offer — while
    /// everything else that arrived stays queued until the welcome dialogs are over.
    func openPendingBackupFileAtWelcome() {
        guard let i = pendingOpenURLs.firstIndex(where: { $0.isFileURL && $0.pathExtension.lowercased() == Backup.fileExtension }) else { return }
        open(pendingOpenURLs.remove(at: i))
    }

    /// Runs what is queued when nothing stands in the way; a no-op otherwise (called again when
    /// the welcome dialogs finish and when a restore ends). A `.keepit` among the pending URLs at
    /// first run is the restore the user asked for, so the generic offer is skipped in its favour.
    func openPendingURLs() {
        // An unlock prompt on screen is a barrier too: `open` would call `unlock()`, get the busy
        // answer, read it as a cancel and drop the URL. The queue waits; `unlock()` calls back here.
        guard isReadyForOpens, !openInProgress, !restoreInProgress, !unlockInProgress else { return }
        while !pendingOpenURLs.isEmpty, !openInProgress, !restoreInProgress, !unlockInProgress {
            open(pendingOpenURLs.removeFirst())
        }
    }

    var hasPendingBackupFile: Bool {
        pendingOpenURLs.contains { $0.isFileURL && $0.pathExtension.lowercased() == Backup.fileExtension }
    }

    /// Commands that only show Keepit's own UI. Everything else changes the clipboard, the history,
    /// the templates, recording, or types into another app — and needs a trusted sender.
    private static let readOnlyCommands: Set<String> = ["history", "templates", "viewer", "settings"]

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme else { return }
        guard settings.allowURLCommands else {
            Log.system.notice("keepit:// command ignored: URL commands are off (Settings → Advanced)")
            NSSound.beep()
            return
        }
        guard !isLocked else { NSSound.beep(); return }
        guard let parsed = URLCommand.parse(url) else {
            Log.system.notice("keepit:// URL rejected: malformed or duplicate query parameter")
            NSSound.beep()
            return
        }
        let command = parsed.command, arg = parsed.argument, q = parsed.params
        let target = NSWorkspace.shared.frontmostApplication

        // Who asked? macOS delivers the URL as an Apple Event that carries the sender's PID. For a
        // command that changes state, the sender must be on the user's list of trusted apps
        // (Settings → Advanced); anything else gets a dialog. A web browser, or a sender we cannot
        // identify, is asked every time and is never added to the list — a web page could be behind it.
        if !Self.readOnlyCommands.contains(command) {
            let sender = URLSender.current()
            // A browser or an unidentified sender is never trusted, even if its bundle id made the list
            // before the app registered itself as an https:// handler.
            let trusted = !sender.needsConfirmation
                && (sender.app?.bundleIdentifier.map { settings.trustedURLSenders.contains($0) } ?? false)
            if !trusted {
                switch confirmURLCommand(url, from: sender) {
                case .deny:
                    Log.system.notice("keepit:// \(command) from \(sender.description) declined")
                    return
                case .allowOnce:
                    break
                case .allowAlways:
                    if let id = sender.app?.bundleIdentifier, !sender.needsConfirmation {
                        var s = settings
                        s.trustedURLSenders.append(id)
                        apply(settings: s)
                    }
                }
            }
        }

        switch command {
        case "paste", "copy":
            let n: Int
            switch arg.lowercased() {
            case "", "latest": n = 1
            case "previous":   n = 2
            default:           n = Int(arg) ?? 0
            }
            guard n >= 1, n <= history.items.count else { NSSound.beep(); return }
            let item = history.items[n - 1]
            Paster.paste(item, into: target, monitor: monitor, settings: settings,
                         sendKey: command == "paste" && settings.pasteAfterSelect)
        case "template":
            let name = arg.removingPercentEncoding ?? arg
            guard let node = templateNode(named: name), let clip = node.clip else { NSSound.beep(); return }
            if q["copy"] == "1" {
                Paster.paste(clip, into: nil, monitor: monitor, settings: settings, sendKey: false)
            } else {
                pasteTemplate(clip, named: node.displayName, into: target)
            }
        case "add":
            guard let text = q["text"], !text.isEmpty else { return }
            let item = ClipItem.text(text)
            history.add(item)
            monitor.performIgnoringChange { item.write(to: NSPasteboard.general) }
            viewer?.refresh()
        case "add-template":
            guard let text = q["text"], !text.isEmpty else { return }
            let node = TemplateNode(name: q["name"] ?? "", clip: .text(text))
            guard templates.canInsert(node, under: templates.root) else { NSSound.beep(); return }
            templates.root.insert(node)
            templates.changed()
            registerHotKeys()
            viewer?.refresh()
        case "history":      showHistoryPopup()
        case "templates":    showTemplatePopup()
        case "viewer":       openViewer()
        case "settings":     openPreferences()
        case "pause":        pauseRecording()
        case "resume":       resumeRecording()
        default:             NSSound.beep()
        }
    }

    /// Template by name, or by `Folder/Sub/Name` path; case-insensitive. First match wins.
    private func templateNode(named name: String) -> TemplateNode? {
        let want = name.lowercased()
        func path(_ n: TemplateNode) -> String {
            var parts: [String] = []
            var cur: TemplateNode? = n
            while let c = cur, c !== templates.root { parts.insert(c.displayName, at: 0); cur = c.parent }
            return parts.joined(separator: "/").lowercased()
        }
        let items = templates.allItems()
        return items.first { path($0) == want } ?? items.first { $0.displayName.lowercased() == want }
    }
}

/// A `keepit://` URL taken apart: host = command, path = argument, query = parameters.
/// Kept free of AppKit so the parser can be tested; `parse` returns nil for anything it will not run.
struct URLCommand: Equatable {
    let command: String
    let argument: String
    let params: [String: String]

    static func parse(_ url: URL) -> URLCommand? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var params: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            // A repeated name is ambiguous (keepit://add?text=a&text=b): refuse rather than guess.
            guard params[item.name] == nil else { return nil }
            params[item.name] = item.value ?? ""
        }
        return URLCommand(command: url.host?.lowercased() ?? "",
                          argument: url.path.split(separator: "/").map(String.init).joined(separator: "/"),
                          params: params)
    }
}

/// The process that asked macOS to open a `keepit://` URL, as far as the Apple Event tells us.
struct URLSender {
    let app: NSRunningApplication?
    let isBrowser: Bool

    /// True when the sender is a web browser or could not be identified at all: such a sender is
    /// asked every time and can never be added to the trusted list.
    var needsConfirmation: Bool { app == nil || isBrowser }
    var description: String { app?.bundleIdentifier ?? app?.localizedName ?? "unknown sender" }
    var displayName: String { app?.localizedName ?? L("an unknown application") }

    static func current() -> URLSender {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return URLSender(app: nil, isBrowser: false)
        }
        guard let pid = senderPID(of: event), pid > 0, let app = NSRunningApplication(processIdentifier: pid) else {
            return URLSender(app: nil, isBrowser: false)
        }
        return URLSender(app: app, isBrowser: isWebBrowser(app))
    }

    /// keySenderPIDAttr is the attribute meant for this; the address attribute is the fallback.
    private static func senderPID(of event: NSAppleEventDescriptor) -> pid_t? {
        func pid(_ d: NSAppleEventDescriptor?) -> pid_t? {
            guard let d else { return nil }
            let k = d.descriptorType == typeKernelProcessID ? d : d.coerce(toDescriptorType: typeKernelProcessID)
            guard let k, k.data.count == MemoryLayout<pid_t>.size else { return nil }
            return k.data.withUnsafeBytes { $0.load(as: pid_t.self) }
        }
        return pid(event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr)))
            ?? pid(event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)))
    }

    /// A browser is anything registered to open https:// links — asked of Launch Services, so the
    /// list is whatever is installed, not a hard-coded set of names.
    private static func isWebBrowser(_ app: NSRunningApplication) -> Bool {
        guard let appURL = app.bundleURL, let https = URL(string: "https://example.com") else { return false }
        let handlers = NSWorkspace.shared.urlsForApplications(toOpen: https)
        let path = appURL.standardizedFileURL.path
        return handlers.contains { $0.standardizedFileURL.path == path }
    }
}

enum URLConfirmation { case allowOnce, allowAlways, deny }

extension AppDelegate {
    /// Modal dialog for a state-changing URL command from a sender that is not yet trusted.
    /// *Always Allow* is offered only to an identified, non-browser app.
    func confirmURLCommand(_ url: URL, from sender: URLSender) -> URLConfirmation {
        let a = NSAlert()
        a.messageText = LF("“%@” wants Keepit to run a command", sender.displayName)
        a.informativeText = sender.needsConfirmation
            ? LF("%@\n\nA web page can open such links. Allow it only if you expect this.", url.absoluteString)
            : LF("%@\n\nAlways Allow adds this app to the trusted list (Settings → Advanced → Automation).", url.absoluteString)
        a.alertStyle = .warning
        a.icon = NSImage(systemSymbolName: "link.badge.plus", accessibilityDescription: nil)
        a.addButton(withTitle: L("Allow"))
        a.addButton(withTitle: L("Cancel"))
        if !sender.needsConfirmation { a.addButton(withTitle: L("Always Allow")) }
        NSApp.activate(ignoringOtherApps: true)
        switch a.runModal() {
        case .alertFirstButtonReturn: return .allowOnce
        case .alertThirdButtonReturn: return .allowAlways
        default: return .deny
        }
    }
}
