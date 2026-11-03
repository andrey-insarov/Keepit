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

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url) }
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
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let q = Dictionary(uniqueKeysWithValues: (comps?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let command = url.host?.lowercased() ?? ""
        let arg = url.path.split(separator: "/").map(String.init).joined(separator: "/")
        let target = NSWorkspace.shared.frontmostApplication

        // Who asked? macOS delivers the URL as an Apple Event whose address attribute carries the
        // sender's PID. A web browser — or a sender we cannot identify — gets a confirmation for any
        // command that changes state; Shortcuts, Raycast, Alfred, Terminal and the like go straight through.
        if !Self.readOnlyCommands.contains(command) {
            let sender = URLSender.current()
            if sender.needsConfirmation, !confirmURLCommand(url, from: sender) {
                Log.system.notice("keepit:// \(command) from \(sender.description) declined")
                return
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

/// The process that asked macOS to open a `keepit://` URL, as far as the Apple Event tells us.
struct URLSender {
    let app: NSRunningApplication?
    let isBrowser: Bool

    /// True when the sender is a web browser or could not be identified at all.
    var needsConfirmation: Bool { app == nil || isBrowser }
    var description: String { app?.bundleIdentifier ?? app?.localizedName ?? "unknown sender" }
    var displayName: String { app?.localizedName ?? L("an unknown application") }

    static func current() -> URLSender {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let addr = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) else {
            return URLSender(app: nil, isBrowser: false)
        }
        var pid: pid_t = 0
        if addr.descriptorType == typeKernelProcessID, addr.data.count == MemoryLayout<pid_t>.size {
            pid = addr.data.withUnsafeBytes { $0.load(as: pid_t.self) }
        } else if let coerced = addr.coerce(toDescriptorType: typeKernelProcessID), coerced.data.count == MemoryLayout<pid_t>.size {
            pid = coerced.data.withUnsafeBytes { $0.load(as: pid_t.self) }
        }
        guard pid > 0, let app = NSRunningApplication(processIdentifier: pid) else {
            return URLSender(app: nil, isBrowser: false)
        }
        return URLSender(app: app, isBrowser: isWebBrowser(app))
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

extension AppDelegate {
    /// Modal yes/no for a state-changing URL command from a browser or an unidentified sender.
    func confirmURLCommand(_ url: URL, from sender: URLSender) -> Bool {
        let a = NSAlert()
        a.messageText = LF("“%@” wants Keepit to run a command", sender.displayName)
        a.informativeText = LF("%@\n\nA web page can open such links. Allow it only if you expect this.", url.absoluteString)
        a.alertStyle = .warning
        a.icon = NSImage(systemSymbolName: "link.badge.plus", accessibilityDescription: nil)
        a.addButton(withTitle: L("Allow"))
        a.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return a.runModal() == .alertFirstButtonReturn
    }
}
