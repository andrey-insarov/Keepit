import AppKit

/// `Keepit --selftest`: an end-to-end smoke test that runs inside the real app on a CI runner
/// (no Accessibility, no hot keys possible there). Writes `selftest-output/report.txt` and PNG
/// snapshots of every window, then exits 0 on success / 1 on failure.
enum SelfTest {
    static let isActive = CommandLine.arguments.contains("--selftest")

    private static var outputDir: URL {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("selftest-output")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static var log: [String] = []
    private static var failures = 0

    private static func check(_ cond: Bool, _ what: String) {
        log.append((cond ? "PASS " : "FAIL ") + what)
        if !cond { failures += 1 }
        NSLog("selftest: %@ %@", cond ? "PASS" : "FAIL", what)
    }

    private static func after(_ s: Double, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: block)
    }

    static func run(app: AppDelegate) {
        log.append("Keep it \(AppInfo.version) (\(AppInfo.build)) self-test, data dir: \(Storage.directory.path)")
        let marker = "Keep it self-test \(UUID().uuidString)"

        // 1. Clipboard capture → history
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(marker, forType: .string)

        after(1.0) {
            check(app.history.items.first?.plainText == marker, "clipboard change captured into history")
            let before = app.history.items.count
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(marker, forType: .string)   // same content again → dedupe

            after(1.0) {
                check(app.history.items.count == before, "duplicate not added twice (overlap check)")

                // 2. Templates
                let node = TemplateNode(name: "&Selftest", text: "hello")
                app.templates.root.insert(node)
                app.templates.changed()
                check(app.templates.root.find(id: node.id) != nil, "template inserted and found")
                let (title, key) = MenuBuilder.parseAmpersand(node.displayName)
                check(title == "Selftest" && key == "s", "ampersand shortcut parsed")

                // 3. Menus
                let menu = app.buildHistoryMenu(includeTemplates: true, includeApp: true)
                check(menu.items.contains { $0.title.hasSuffix(marker.prefix(20)) || $0.title.contains("Keep it self-test") },
                      "history menu lists the captured item")
                check(menu.items.contains { $0.title == "Template" && $0.submenu != nil }, "history menu has Template submenu")

                // 4. Windows + snapshots
                app.openViewer()
                app.openPreferences()
                after(1.5) {
                    for (name, w) in app.openWindows {
                        check(w.isVisible, "\(name) window is visible")
                        snapshot(w, name: name)
                    }
                    // 5. Persistence round-trip
                    app.history.flush()
                    app.templates.flush()
                    check(FileManager.default.fileExists(atPath: Storage.historyURL.path), "history.json written")
                    check(FileManager.default.fileExists(atPath: Storage.templatesURL.path), "templates.json written")
                    let reloaded = TemplateStore()
                    check(reloaded.root.find(id: node.id)?.clip?.plainText == "hello", "templates reload from disk")

                    // 6. Vault round-trip in the temp dir
                    let pw = SecureBuffer()
                    "s3cret".utf8CString.dropLast().withUnsafeBytes { _ = pw.append($0) }
                    let key = try? Vault.enable(password: pw)
                    check(key != nil, "vault enabled")
                    if let k = key {
                        let sealed = try? Vault.encrypt(Data("payload".utf8), key: k)
                        let opened = sealed.flatMap { try? Vault.decrypt($0, key: k) }
                        check(opened == Data("payload".utf8), "AES-GCM round-trip")
                        check(Vault.unlock(password: pw) != nil, "vault unlock with correct password")
                        let wrong = SecureBuffer()
                        "nope".utf8CString.dropLast().withUnsafeBytes { _ = wrong.append($0) }
                        check(Vault.unlock(password: wrong) == nil, "vault rejects wrong password")
                        k.zero()
                        check(k.isZeroed, "key zeroized")
                    }
                    Vault.disable()
                    pw.zero()

                    finish()
                }
            }
        }
    }

    private static func snapshot(_ w: NSWindow, name: String) {
        guard let v = w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else {
            check(false, "snapshot \(name)"); return
        }
        v.cacheDisplay(in: v.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { check(false, "snapshot \(name) png"); return }
        let url = outputDir.appendingPathComponent("\(name).png")
        do {
            try png.write(to: url)
            check(true, "snapshot \(name) → \(url.lastPathComponent) (\(Int(v.bounds.width))×\(Int(v.bounds.height)))")
        } catch {
            check(false, "snapshot \(name): \(error)")
        }
    }

    private static func finish() {
        log.append(failures == 0 ? "RESULT: OK" : "RESULT: \(failures) failure(s)")
        let text = log.joined(separator: "\n") + "\n"
        try? text.write(to: outputDir.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
        FileHandle.standardOutput.write(Data(text.utf8))
        exit(failures == 0 ? 0 : 1)
    }
}
