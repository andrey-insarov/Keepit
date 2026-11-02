import AppKit

/// `keepit://` URL scheme — automation hooks for Shortcuts ("Open URL"), Alfred, Raycast, `open` in the shell.
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

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme else { return }
        guard !isLocked else { NSSound.beep(); return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let q = Dictionary(uniqueKeysWithValues: (comps?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let command = url.host?.lowercased() ?? ""
        let arg = url.path.split(separator: "/").map(String.init).joined(separator: "/")
        let target = NSWorkspace.shared.frontmostApplication

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
