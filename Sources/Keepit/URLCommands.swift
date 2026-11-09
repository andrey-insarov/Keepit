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
        // Who sent these: read now, while this Apple Event is the current one. A URL that waits in
        // the queue is run later, inside another event's dispatch, and must not be checked as that
        // event's sender (SEC07).
        let sender = urls.contains { !$0.isFileURL } ? (urlCommandSenderForTesting ?? URLSender.current()) : nil
        // The queue is bounded: what does not fit is dropped with a beep, never silently kept.
        let room = max(0, Limits.pendingOpenURLsMax - pendingOpens.count)
        if urls.count > room {
            Log.system.notice("open: \(urls.count - room) URL(s) dropped — \(Limits.pendingOpenURLsMax) may wait")
            NSSound.beep()
        }
        pendingOpens += urls.prefix(room).map { PendingOpen(url: $0, sender: $0.isFileURL ? nil : sender) }
        openPendingURLs()
    }

    private func open(_ pending: PendingOpen) {
        openInProgress = true                         // covers the unlock dialog too: nothing re-enters meanwhile
        defer { openInProgress = false }
        let url = pending.url
        if url.isFileURL, url.pathExtension.lowercased() == Backup.fileExtension {
            if isLocked, !unlock() { return }         // a backup opened while locked: ask for the password first
            restore(from: url)
        } else {
            handle(url, from: pending.sender ?? URLSender(app: nil, isBrowser: false))   // no record of the sender → unidentified → asked
        }
    }

    /// The welcome step on a first run: the `.keepit` the user double-clicked is restored now, in
    /// place of the generic "Restore from a backup?" offer and before the password offer — while
    /// everything else that arrived stays queued until the welcome dialogs are over.
    func openPendingBackupFileAtWelcome() {
        guard let i = pendingOpens.firstIndex(where: { $0.url.isFileURL && $0.url.pathExtension.lowercased() == Backup.fileExtension }) else { return }
        open(pendingOpens.remove(at: i))
    }

    /// Runs what is queued when nothing stands in the way; a no-op otherwise (called again when
    /// the welcome dialogs finish and when a restore ends). A `.keepit` among the pending URLs at
    /// first run is the restore the user asked for, so the generic offer is skipped in its favour.
    func openPendingURLs() {
        // An unlock prompt on screen is a barrier too: `open` would call `unlock()`, get the busy
        // answer, read it as a cancel and drop the URL. The queue waits; `unlock()` calls back here.
        guard isReadyForOpens, !openInProgress, !restoreInProgress, !unlockInProgress else { return }
        while !pendingOpens.isEmpty, !openInProgress, !restoreInProgress, !unlockInProgress {
            open(pendingOpens.removeFirst())
        }
    }

    var hasPendingBackupFile: Bool {
        pendingOpenURLs.contains { $0.isFileURL && $0.pathExtension.lowercased() == Backup.fileExtension }
    }

    /// Commands that only show Keepit's own UI. Everything else changes the clipboard, the history,
    /// the templates, recording, or types into another app — and needs a trusted sender.
    private static let readOnlyCommands: Set<String> = ["history", "templates", "viewer", "settings"]

    /// A URL handled now, as the current Apple Event's sender (tests: `urlCommandSenderForTesting`).
    /// The queue never calls this: it passes the sender it recorded when the URL arrived.
    func handle(_ url: URL) {
        handle(url, from: urlCommandSenderForTesting ?? URLSender.current())
    }

    func handle(_ url: URL, from sender: URLSender) {
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
        let target = urlCommandSenderForTesting == nil ? NSWorkspace.shared.frontmostApplication : nil
        // The confirmation below is modal; Keepit can be locked (and unlocked again) while it is on
        // screen. The command was admitted in this lock generation and runs only in it.
        let generation = lockCount

        // Who asked? macOS delivers the URL as an Apple Event that carries the sender's PID. For a
        // command that changes state, the sender must be on the user's list of trusted apps
        // (Settings → Advanced); anything else gets a dialog. A web browser, or a sender we cannot
        // identify, is asked every time and is never added to the list — a web page could be behind it.
        if !Self.readOnlyCommands.contains(command) {
            // Trust is by code-signing identity (SEC07): one of the stored (identifier, Team ID) pairs
            // must validate against the live sender through the Security framework. A browser, an
            // unidentified sender or an Apple script host is never trusted; the legacy bundle-id list
            // is ignored (and emptied at launch).
            let trusted = sender.isTrusted(by: settings.trustedURLSenderIdentities)
            if !trusted {
                let answer = confirmURLCommand(url, from: sender)
                guard !isLocked, lockCount == generation, settings.allowURLCommands else {
                    Log.system.notice("keepit:// \(command) from \(sender.description) dropped: Keepit was locked while the dialog was open")
                    NSSound.beep()
                    return
                }
                switch answer {
                case .deny:
                    Log.system.notice("keepit:// \(command) from \(sender.description) declined")
                    return
                case .allowOnce:
                    break
                case .allowAlways:
                    if let entry = sender.trustedEntry, !settings.trustedURLSenderIdentities.contains(entry) {
                        var s = settings
                        s.trustedURLSenderIdentities.append(entry)
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
            guard (try? Backup.validate(item: item)) != nil else { NSSound.beep(); return }
            history.add(item)
            monitor.performIgnoringChange { item.write(to: NSPasteboard.general) }
            viewer?.refresh()
        case "add-template":
            guard let text = q["text"], !text.isEmpty else { return }
            let clip = ClipItem.text(text)
            guard (try? Backup.validate(item: clip)) != nil else { NSSound.beep(); return }
            let node = TemplateNode(name: String((q["name"] ?? "").prefix(Limits.templateNameMaxChars)), clip: clip)
            guard templates.insert(node, under: templates.root) else { NSSound.beep(); return }
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
/// Kept free of AppKit so the parser can be tested; `parse` returns nil for anything it will not run:
/// a command outside the list, a parameter the command does not take, a repeated parameter, or any
/// part over its size limit. Sizes are checked here, before any dialog or model object exists — the
/// sender's trust (checked later) is not a substitute for a bound.
struct URLCommand: Equatable {
    let command: String
    let argument: String
    let params: [String: String]

    /// Every command Keepit runs and the query parameters each one accepts.
    static let allowed: [String: Set<String>] = [
        "paste": [], "copy": [], "template": ["copy"], "add": ["text"], "add-template": ["text", "name"],
        "history": [], "templates": [], "viewer": [], "settings": [], "pause": [], "resume": [],
    ]

    static func parse(_ url: URL) -> URLCommand? {
        guard url.absoluteString.count <= Limits.urlCommandMaxChars,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let command = url.host?.lowercased() ?? ""
        guard let accepted = allowed[command] else { return nil }
        var params: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            // A repeated name is ambiguous (keepit://add?text=a&text=b): refuse rather than guess.
            guard accepted.contains(item.name), params[item.name] == nil else { return nil }
            let value = item.value ?? ""
            switch item.name {
            case "text": guard value.utf8.count <= Limits.urlCommandTextMaxBytes else { return nil }
            case "name": guard value.count <= Limits.templateNameMaxChars else { return nil }
            case "copy": guard value.count <= 8 else { return nil }
            default: return nil
            }
            params[item.name] = value
        }
        let argument = url.path.split(separator: "/").map(String.init).joined(separator: "/")
        guard argument.count <= Limits.urlCommandArgumentMaxChars else { return nil }
        return URLCommand(command: command, argument: argument, params: params)
    }
}

/// The process that asked macOS to open a `keepit://` URL, as far as the Apple Event tells us.
struct URLSender {
    /// The sending process as Launch Services sees it (name, bundle URL) — for display and for the
    /// browser check. Looked up by the PID *inside the audit token*, so it is the same process the
    /// identity was read from.
    let app: NSRunningApplication?
    /// The sender's code-signing identity, read from the Apple Event's audit token; nil when the
    /// sender is unsigned, ad-hoc, tampered, gone, or when what Launch Services says about the
    /// process (its bundle identifier) does not match what it is signed as.
    let identity: CodeIdentity?
    let isBrowser: Bool

    init(app: NSRunningApplication?, identity: CodeIdentity? = nil, isBrowser: Bool) {
        self.app = app; self.identity = identity; self.isBrowser = isBrowser
    }

    /// Asked every time, never offered *Always Allow*: a browser (a web page may be behind it), an
    /// unidentified sender, or an Apple script host (any shortcut or script can speak through it).
    var needsConfirmation: Bool { identity == nil || isBrowser || identity?.isAppleHost == true }
    /// *Always Allow* is for a third-party application with a Team ID only.
    var canBeTrusted: Bool { !needsConfirmation }
    var isAppleHost: Bool { identity?.isAppleHost == true }

    var description: String {
        if let i = identity { return i.teamID.map { "\(i.identifier) (\($0))" } ?? i.identifier }
        return app?.bundleIdentifier ?? app?.localizedName ?? "unknown sender"
    }
    var displayName: String {
        let name = app?.localizedName ?? identity?.identifier ?? L("an unknown application")
        if let team = identity?.teamID { return "\(name) (Team ID \(team))" }
        return name
    }

    /// The entry *Always Allow* stores for this sender, or nil when it cannot be trusted.
    var trustedEntry: TrustedSender? {
        guard canBeTrusted, let i = identity, let team = i.teamID else { return nil }
        let entry = TrustedSender(identifier: i.identifier, teamID: team, displayName: app?.localizedName ?? i.identifier)
        return entry.requirementString == nil ? nil : entry       // refused syntax → never trusted
    }

    /// Whether one of the stored entries validates against this live sender — evaluated by the
    /// Security framework against the code object, not by comparing strings.
    func isTrusted(by entries: [TrustedSender]) -> Bool {
        guard canBeTrusted, let i = identity else { return false }
        return entries.contains { i.validates($0) }
    }

    static func current() -> URLSender {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return URLSender(app: nil, isBrowser: false)
        }
        // The audit token names the process the kernel delivered the event from; its PID field is
        // what Launch Services is asked about, so both views are of one sender.
        guard let token = senderAuditToken(of: event) else {
            return URLSender(app: nil, isBrowser: false)                 // no token → unidentified, asked every time
        }
        let pid = Self.pid(of: token)
        let app = pid > 0 ? NSRunningApplication(processIdentifier: pid) : nil
        var identity = CodeIdentity.read(auditToken: token)
        if let i = identity, let claimed = app?.bundleIdentifier, claimed != i.identifier {
            Log.system.notice("keepit:// sender's bundle identifier does not match its signing identifier; treated as unidentified")
            identity = nil
        }
        return URLSender(app: app, identity: identity, isBrowser: app.map(isWebBrowser) ?? false)
    }

    /// `keySenderAuditTokenAttr`: the kernel-supplied audit token of the sending process.
    private static func senderAuditToken(of event: NSAppleEventDescriptor) -> Data? {
        guard let d = event.attributeDescriptor(forKeyword: AEKeyword(keySenderAuditTokenAttr)) else { return nil }
        let t = d.descriptorType == typeAuditToken ? d : d.coerce(toDescriptorType: typeAuditToken)
        guard let t, t.data.count == MemoryLayout<audit_token_t>.size else { return nil }
        return t.data
    }

    /// The PID field of an audit token (`val[5]`), as `audit_token_to_pid` returns it.
    static func pid(of token: Data) -> pid_t {
        token.withUnsafeBytes { raw -> pid_t in
            let t = raw.load(as: audit_token_t.self)
            return pid_t(bitPattern: t.val.5)
        }
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
        if let test = confirmURLCommandForTesting { return test(self) }
        let a = NSAlert()
        a.messageText = LF("“%@” wants Keepit to run a command", sender.displayName)
        if sender.isAppleHost {
            a.informativeText = LF("%@\n\nAny shortcut or script can call Keepit through %@, so it is asked each time.", url.absoluteString, sender.displayName)
        } else if sender.needsConfirmation {
            a.informativeText = LF("%@\n\nA web page can open such links. Allow it only if you expect this.", url.absoluteString)
        } else {
            a.informativeText = LF("%@\n\nAlways Allow adds this app to the trusted list (Settings → Advanced → Automation). Anything it runs — extensions, scripts — will be allowed too.", url.absoluteString)
        }
        a.alertStyle = .warning
        a.icon = NSImage(systemSymbolName: "link.badge.plus", accessibilityDescription: nil)
        a.addButton(withTitle: L("Allow"))
        a.addButton(withTitle: L("Cancel"))
        if sender.canBeTrusted { a.addButton(withTitle: L("Always Allow")) }
        NSApp.activate(ignoringOtherApps: true)
        switch AbortableModal.run(a) {
        case .alertFirstButtonReturn: return .allowOnce
        case .alertThirdButtonReturn: return .allowAlways
        default: return .deny
        }
    }
}
