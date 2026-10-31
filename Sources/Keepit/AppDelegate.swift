import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private(set) var settings: Settings
    private(set) var history: HistoryStore!
    private(set) var templates: TemplateStore!
    private(set) var monitor: ClipboardMonitor!
    let hotKeys = HotKeyManager()
    private lazy var menuBuilder = MenuBuilder(settings: settings)

    private var statusItem: NSStatusItem!
    private var preferencesWindow: PreferencesWindowController?
    private var viewer: ViewerWindowController?

    /// Most recently active app other than us — the Viewer pastes into it (the original remembered the previous window).
    private(set) var lastExternalApp: NSRunningApplication?

    /// App that was frontmost when a popup menu opened — paste goes back there.
    private var pasteTarget: NSRunningApplication?
    private var menuSelectionMade = false
    private var popupActive = false

    /// True while the vault key is wiped and data is unloaded (password set, not yet entered).
    private(set) var isLocked = false

    override init() {
        settings = Storage.load(Settings.self, from: Storage.settingsURL) ?? Settings()
        super.init()
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()

        // Password gate: nothing is loaded until the vault is unlocked.
        if Vault.isEnabled && !unlockVault(quitOnFailure: true) {
            NSApp.terminate(nil)
            return
        }
        history = HistoryStore(settings: settings)
        templates = TemplateStore()
        monitor = ClipboardMonitor(settings: settings)

        buildStatusItem()

        monitor.onCapture = { [weak self] item in
            self?.history.add(item)
            self?.viewer?.refresh()
        }
        monitor.start()

        lastExternalApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self?.lastExternalApp = app
        }

        registerHotKeys()
        Storage.save(settings, to: Storage.settingsURL, encrypt: false)
        observeScreenLock()

        if SelfTest.isActive {
            SelfTest.run(app: self)
            return
        }

        if !Paster.isTrusted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showAccessibilityAlert()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        history?.flush()
        templates?.flush()
        Storage.save(settings, to: Storage.settingsURL, encrypt: false)
        Storage.clearKey()          // wipe key bytes before the process goes away
    }

    // MARK: - Lock / unlock (key zeroization)

    private func observeScreenLock() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.autoLock()
        }
        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.autoLock()
        }
        wnc.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.autoLock()
        }
    }

    private func autoLock() {
        guard settings.lockWithScreen, Vault.isEnabled, !isLocked else { return }
        lock()
    }

    /// Wipe the key, unload history/templates from memory, stop watching the clipboard, drop hot keys.
    @objc func lock() {
        guard Vault.isEnabled, !isLocked else { return }
        isLocked = true
        viewer?.close()
        preferencesWindow?.close()
        monitor.stop()
        hotKeys.unregisterAll()
        history.purge()
        templates.purge()
        Storage.clearKey()
        menuBuilder.invalidateThumbnails()
        updateStatusIcon()
    }

    /// Ask for the password, reload data and resume. Returns false if the user cancelled.
    @discardableResult
    @objc func unlock() -> Bool {
        guard isLocked else { return true }
        guard unlockVault(quitOnFailure: false) else { return false }
        isLocked = false
        history.reload()
        templates.reload()
        monitor.start()
        registerHotKeys()
        updateStatusIcon()
        return true
    }

    private func updateStatusIcon() {
        guard let b = statusItem?.button else { return }
        b.image = NSImage(systemSymbolName: isLocked ? "lock.fill" : "paperclip", accessibilityDescription: "Keepit")
        b.image?.isTemplate = true
        b.toolTip = isLocked ? "Keepit — locked, click to unlock"
                             : "Keepit — \(settings.historyHotKey.displayString) history, \(settings.templateHotKey.displayString) templates"
    }

    // MARK: - Password / encryption

    /// Up to three attempts; returns false on cancel / failure.
    private func unlockVault(quitOnFailure: Bool = true) -> Bool {
        for attempt in 1...3 {
            let msg = attempt == 1 ? "Enter the Keepit password to decrypt the history and templates."
                                   : "Wrong password (\(attempt - 1) of 3 attempts used)."
            guard let pw = Vault.askPassword(title: "Keepit is locked", message: msg, cancelQuits: quitOnFailure) else { return false }
            let key = Vault.unlock(password: pw)
            pw.zero()
            if let key = key {
                Storage.key = key
                return true
            }
        }
        Vault.error(quitOnFailure ? "Too many wrong attempts. Keepit will quit." : "Too many wrong attempts. Keepit stays locked.")
        return false
    }

    /// Turn protection on: set a password, re-save data encrypted.
    func enableProtection() -> Bool {
        guard let pw = Vault.askPassword(title: "Set Keepit password",
                                         message: "You'll be asked for it every time Keepit starts. There is no recovery if you forget it.",
                                         confirm: true) else { return false }
        defer { pw.zero() }
        do {
            Storage.key = try Vault.enable(password: pw)
        } catch {
            Vault.error("Could not enable protection: \(error.localizedDescription)")
            return false
        }
        history.saveNow()
        templates.saveNow()
        return true
    }

    /// Turn protection off after verifying the password; data is re-saved as plain JSON.
    func disableProtection() -> Bool {
        guard let pw = Vault.askPassword(title: "Disable password protection",
                                         message: "Enter the current password. History and templates will be stored unencrypted.") else { return false }
        let check = Vault.unlock(password: pw)
        pw.zero()
        guard check != nil else {
            Vault.error("Wrong password.")
            return false
        }
        check?.zero()
        Storage.key = nil
        Vault.disable()
        history.saveNow()
        templates.saveNow()
        return true
    }

    func changePassword() {
        guard Vault.isEnabled else { return }
        guard let old = Vault.askPassword(title: "Change password", message: "Enter the current password.") else { return }
        let check = Vault.unlock(password: old)
        old.zero()
        guard check != nil else {
            Vault.error("Wrong password.")
            return
        }
        check?.zero()
        guard let pw = Vault.askPassword(title: "New password", message: "Enter the new password twice.", confirm: true) else { return }
        defer { pw.zero() }
        do {
            Storage.key = try Vault.enable(password: pw)
        } catch {
            Vault.error("Could not change password: \(error.localizedDescription)")
            return
        }
        history.saveNow()
        templates.saveNow()
    }

    // MARK: - Settings

    func apply(settings new: Settings) {
        let old = settings
        settings = new
        Storage.save(new, to: Storage.settingsURL, encrypt: false)
        history.updateSettings(new)
        monitor.updateSettings(new)
        menuBuilder.settings = new
        menuBuilder.invalidateThumbnails()
        if old.historyHotKey != new.historyHotKey || old.templateHotKey != new.templateHotKey {
            registerHotKeys()
        }
        if old.launchAtLogin != new.launchAtLogin {
            setLaunchAtLogin(new.launchAtLogin)
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Keepit: launch at login change failed: \(error)")
        }
    }

    func registerHotKeys() {
        hotKeys.unregisterAll()
        var failed: [String] = []
        if !hotKeys.register(settings.historyHotKey, handler: { [weak self] in self?.showHistoryPopup() }) {
            failed.append(settings.historyHotKey.displayString)
        }
        if !hotKeys.register(settings.templateHotKey, handler: { [weak self] in self?.showTemplatePopup() }) {
            failed.append(settings.templateHotKey.displayString)
        }
        // Per-template hot keys: paste the item directly, no menu ("Set Hot Key" on a template item).
        for t in templates.allItems() {
            guard let hk = t.hotKey, t.clip != nil else { continue }
            let id = t.id
            if !hotKeys.register(hk, handler: { [weak self] in
                guard let self = self, let node = self.templates.root.find(id: id), let clip = node.clip else { return }
                let target = NSWorkspace.shared.frontmostApplication
                Paster.paste(clip, into: target, monitor: self.monitor, settings: self.settings, sendKey: self.settings.pasteAfterSelect)
            }) {
                failed.append("\(hk.displayString) (\(t.displayName))")
            }
        }
        if !failed.isEmpty, !SelfTest.isActive {
            // Report hot keys that could not be registered
            let a = NSAlert()
            a.messageText = "Hot key unavailable"
            a.informativeText = "Could not register: \(failed.joined(separator: ", ")). Another app or macOS is using it. Change it in Preferences."
            a.runModal()
        }
    }

    // MARK: - Main menu (needed so ⌘C/⌘V/⌘A work inside our own windows)

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Keepit", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Viewer…", action: #selector(openViewer), keyEquivalent: "l")
        appMenu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Keepit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = window
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }

    // MARK: - Status item (system tray icon)

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Keepit")
            b.image?.isTemplate = true
            b.target = self
            b.action = #selector(statusItemClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.toolTip = "Keepit — \(settings.historyHotKey.displayString) history, \(settings.templateHotKey.displayString) templates"
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
        if isLocked {
            let menu = NSMenu()
            menu.addItem(withTitle: "Unlock Keepit…", action: #selector(unlock), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Keepit", action: #selector(quit), keyEquivalent: "q").target = self
            menu.delegate = self
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            return
        }
        // The status-bar click does not activate us, so the frontmost app is still the paste target.
        pasteTarget = NSWorkspace.shared.frontmostApplication
        if isRight {
            // Right-click on the menu-bar icon opens the Viewer.
            openViewer()
            return
        }
        let menu = buildHistoryMenu(includeTemplates: true, includeApp: true)
        menu.delegate = self
        menuSelectionMade = false
        popupActive = false
        // Attach temporarily so NSStatusItem positions/highlights it, then detach in menuDidClose.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    // MARK: - Popups on hot key

    private func showHistoryPopup() {
        popUp(buildHistoryMenu(includeTemplates: true, includeApp: false))
    }

    private func showTemplatePopup() {
        let menu = menuBuilder.templateMenu(templates.root, target: self, action: #selector(templateChosen(_:)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Viewer…", action: #selector(openViewer), keyEquivalent: "").target = self
        popUp(menu)
    }

    private func popUp(_ menu: NSMenu) {
        if popupActive || isLocked { return }
        pasteTarget = NSWorkspace.shared.frontmostApplication
        menuSelectionMade = false
        popupActive = true
        menu.delegate = self

        var point = NSEvent.mouseLocation
        if settings.showAtCaret, let caret = Paster.caretScreenPoint() {
            point = caret
        }
        // Menus need a key window to get keyboard navigation; activating us is the price.
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    // NSMenuDelegate
    func menuDidClose(_ menu: NSMenu) {
        if statusItem.menu === menu { statusItem.menu = nil }
        let wasPopup = popupActive
        popupActive = false
        // The chosen item's action fires right after this; check a moment later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            if wasPopup, !self.menuSelectionMade,
               let app = self.pasteTarget, !app.isTerminated {
                // Dismissed without choosing → give focus back.
                app.activate(options: [])
            }
        }
    }

    // MARK: - Menu construction

    func buildHistoryMenu(includeTemplates: Bool, includeApp: Bool) -> NSMenu {
        let menu = NSMenu(title: "History")
        menu.autoenablesItems = false

        let items = menuBuilder.historyItems(history.items, target: self, action: #selector(historyChosen(_:)))
        if items.isEmpty {
            let e = NSMenuItem(title: "(History is empty)", action: nil, keyEquivalent: "")
            e.isEnabled = false
            menu.addItem(e)
        } else {
            for mi in items { menu.addItem(mi) }
        }

        if includeTemplates {
            menu.addItem(.separator())
            let t = NSMenuItem(title: "Template", action: nil, keyEquivalent: "")
            t.image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: nil)
            t.submenu = menuBuilder.templateMenu(templates.root, target: self, action: #selector(templateChosen(_:)))
            menu.addItem(t)
        }

        if includeApp {
            menu.addItem(.separator())
            for mi in appMenuItems() { menu.addItem(mi) }
        }
        return menu
    }

    private func appMenuItems() -> [NSMenuItem] {
        func item(_ title: String, _ sel: Selector, _ key: String = "") -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            mi.target = self
            return mi
        }
        let versionItem = NSMenuItem(title: AppInfo.versionLine, action: #selector(showAbout), keyEquivalent: "")
        versionItem.target = self
        var out: [NSMenuItem] = [
            versionItem,
            .separator(),
            item("Viewer…", #selector(openViewer)),
            item("Add Clipboard to Templates", #selector(addClipboardToTemplates)),
            item("Preferences…", #selector(openPreferences), ","),
            .separator(),
            item("Clear History", #selector(clearHistory)),
        ]
        if Vault.isEnabled {
            out.append(item("Lock Keepit", #selector(lock), "l"))
        }
        if !Paster.isTrusted() {
            out.append(item("Grant Accessibility Permission…", #selector(grantAccessibility)))
        }
        out.append(.separator())
        out.append(item("Quit Keepit", #selector(quit), "q"))
        return out
    }

    // MARK: - Actions

    @objc private func historyChosen(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID,
              let item = history.items.first(where: { $0.id == id }) else { return }
        history.touch(item)
        Paster.paste(item, into: pasteTarget, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
        nudgeAccessibilityIfNeeded()
    }

    private var accessibilityNudgeShown = false

    /// The item was copied but ⌘V could not be sent: say so once per launch instead of failing silently.
    private func nudgeAccessibilityIfNeeded() {
        guard settings.pasteAfterSelect, !Paster.isTrusted(), !accessibilityNudgeShown else { return }
        accessibilityNudgeShown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let a = NSAlert()
            a.messageText = "Copied to the clipboard — but Keepit can't paste for you yet"
            a.informativeText = "Press ⌘V to paste now. To paste automatically, allow Keepit in System Settings → Privacy & Security → Accessibility. If Keepit is already listed, turn it off and on again (macOS forgets the grant when the app is rebuilt with a different signature)."
            a.addButton(withTitle: "Open System Settings")
            a.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if a.runModal() == .alertFirstButtonReturn {
                Paster.requestTrust()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            self?.pasteTarget?.activate(options: [])
        }
    }

    @objc private func templateChosen(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID,
              let node = templates.root.find(id: id), let clip = node.clip else { return }
        Paster.paste(clip, into: pasteTarget, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
        nudgeAccessibilityIfNeeded()
    }

    @objc private func clearHistory() {
        menuSelectionMade = true
        let a = NSAlert()
        a.messageText = "Clear clipboard history?"
        a.informativeText = "\(history.items.count) item(s) will be removed. Templates are not affected."
        a.addButton(withTitle: "Clear")
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn { history.clear() }
    }

    @objc private func addClipboardToTemplates() {
        menuSelectionMade = true
        guard let s = NSPasteboard.general.string(forType: .string), !s.isEmpty else {
            NSSound.beep()
            return
        }
        templates.root.insert(TemplateNode(name: "", text: s))
        templates.changed()
        viewer?.refresh()
    }

    @objc func openPreferences() {
        menuSelectionMade = true
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(app: self)
        }
        preferencesWindow?.show()
    }

    @objc func openViewer() {
        menuSelectionMade = true
        if viewer == nil {
            viewer = ViewerWindowController(app: self)
        }
        viewer?.show()
    }

    /// Windows currently open, for the self-test to snapshot.
    var openWindows: [(name: String, window: NSWindow)] {
        var out: [(String, NSWindow)] = []
        if let w = viewer?.window { out.append(("viewer", w)) }
        if let w = preferencesWindow?.window { out.append(("preferences", w)) }
        return out
    }

    @objc private func grantAccessibility() {
        menuSelectionMade = true
        Paster.requestTrust()
    }

    @objc func showAbout() {
        menuSelectionMade = true
        NSApp.activate(ignoringOtherApps: true)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.fullName,
            .applicationVersion: AppInfo.version,
            .version: AppInfo.build,
            .credits: NSAttributedString(string: "\(AppInfo.homepage)\n\(AppInfo.copyright)\nMIT License"),
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAccessibilityAlert() {
        let a = NSAlert()
        a.messageText = "Keepit needs the Accessibility permission to paste"
        a.informativeText = "Without it Keepit can still record history and copy items to the clipboard, but it cannot send ⌘V to the active app or place the menu at the text cursor.\n\nSystem Settings → Privacy & Security → Accessibility → enable Keepit."
        a.addButton(withTitle: "Open System Settings")
        a.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            Paster.requestTrust()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
