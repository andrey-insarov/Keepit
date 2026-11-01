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
    private lazy var updater = Updater()
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
        if needsPasswordReset { completeRecovery() }

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
        _ = updater   // starts Sparkle's scheduled checks

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
        if needsPasswordReset { completeRecovery() }
        monitor.start()
        registerHotKeys()
        updateStatusIcon()
        return true
    }

    private func updateStatusIcon() {
        guard let b = statusItem?.button else { return }
        b.image = NSImage(systemSymbolName: isLocked ? "lock.fill" : "paperclip", accessibilityDescription: "Keepit")
        b.image?.isTemplate = true
        b.toolTip = isLocked ? L("Keepit — locked, click to unlock")
                             : LF("Keepit — %@ history, %@ templates", settings.historyHotKey.displayString, settings.templateHotKey.displayString)
    }

    // MARK: - Password / encryption

    private var lockoutUntil = Date.distantPast

    /// Touch ID first (if enabled), then up to three password attempts; returns false on cancel / failure.
    private func unlockVault(quitOnFailure: Bool = true) -> Bool {
        let wait = lockoutUntil.timeIntervalSinceNow
        if wait > 0 {
            Vault.error(LF("Too many wrong attempts. Try again in %d s.", Int(wait.rounded(.up))))
            return false
        }
        if settings.biometricUnlock, BiometricUnlock.isAvailable, BiometricUnlock.isConfigured {
            NSApp.activate(ignoringOtherApps: true)
            if let key = BiometricUnlock.retrieve(reasonKey: "unlock the clipboard history and templates") {
                if Vault.verify(key) {
                    Storage.key = key
                    return true
                }
                key.zero()
                NSLog("Keepit: Touch ID key does not open the vault (password changed elsewhere?)")
            }
            // fall through to the password prompt
        }
        for attempt in 1...3 {
            let msg = attempt == 1 ? L("Enter the Keepit password to decrypt the history and templates.")
                                   : LF("Wrong password (%d of 3 attempts used).", attempt - 1)
            switch Vault.prompt(title: L("Keepit is locked"), message: msg, cancelQuits: quitOnFailure, offerRecovery: true) {
            case .cancel:
                return false
            case .recovery:
                if recoverWithPhrase() { return true }
                continue
            case .password(let pw):
                let key = Vault.unlock(password: pw)
                pw.zero()
                if let key = key {
                    Storage.key = key
                    return true
                }
                // Slow down guessing: 1 s, 2 s, 4 s after each miss, then a 30 s lockout.
                Thread.sleep(forTimeInterval: Limits.unlockBackoffSeconds[min(attempt - 1, Limits.unlockBackoffSeconds.count - 1)])
            }
        }
        lockoutUntil = Date().addingTimeInterval(Limits.unlockLockoutSeconds)
        Vault.error(quitOnFailure ? L("Too many wrong attempts. Keepit will quit.") : L("Too many wrong attempts. Keepit stays locked."))
        return false
    }

    // MARK: Recovery phrase

    private var needsPasswordReset = false

    /// Unlock with the 24 words; a new password must be set right after (the old one is unknown).
    private func recoverWithPhrase() -> Bool {
        guard let words = RecoveryDialogs.askPhrase() else { return false }
        guard let key = Vault.unlockWithRecovery(words: words) else {
            Vault.error(L("This phrase does not match the stored recovery data."))
            return false
        }
        Storage.key = key
        needsPasswordReset = true     // completed once the stores are (re)loaded with this key
        return true
    }

    /// After a phrase recovery: force a new password, re-encrypt, keep the phrase valid.
    private func completeRecovery() {
        needsPasswordReset = false
        var newPw: SecureBuffer?
        while newPw == nil {
            newPw = Vault.askPassword(title: L("Set a new password"),
                                      message: L("You unlocked with the recovery phrase. Choose a new password now; the recovery phrase stays valid."),
                                      confirm: true)
        }
        rekey(with: newPw!)
        newPw!.zero()
    }

    /// Replace the data key with one derived from `pw`, re-encrypt everything, keep recovery + Touch ID in sync.
    private func rekey(with pw: SecureBuffer) {
        guard let oldKey = Storage.key else { return }
        let oldRecovery = Vault.currentRecovery
        do {
            let newKey = try Vault.enable(password: pw)
            try Vault.rewrapRecovery(from: oldKey, to: newKey, oldRecovery: oldRecovery)
            Storage.key = newKey                     // zeroes oldKey
        } catch {
            Vault.error(LF("Could not change the password: %@", error.localizedDescription))
            return
        }
        history.saveNow()
        templates.saveNow()
        syncBiometricKey()
    }

    /// Confirm identity for sensitive changes: Touch ID (if allowed) or the current password.
    private func authenticateForChange(reasonKey: String) -> Bool {
        if settings.biometricUnlock, settings.biometricPasswordChange, BiometricUnlock.isAvailable, BiometricUnlock.isConfigured,
           let k = BiometricUnlock.retrieve(reasonKey: reasonKey) {
            let ok = Vault.verify(k)
            k.zero()
            if ok { return true }
        }
        guard let old = Vault.askPassword(title: L("Confirm"), message: LF("Enter the current password to %@.", L(reasonKey))) else { return false }
        let check = Vault.unlock(password: old)
        old.zero()
        guard let c = check else {
            Vault.error(L("Wrong password."))
            return false
        }
        c.zero()
        return true
    }

    /// Preferences → "New Recovery Phrase…": invalidates the old sheet.
    func regenerateRecoveryPhrase() {
        guard Vault.isEnabled, let key = Storage.key else { return }
        guard authenticateForChange(reasonKey: "generate a new recovery phrase") else { return }
        do {
            let words = try Vault.createRecovery(for: key)
            RecoveryDialogs.present(words: words, title: L("Your new recovery phrase (the old one no longer works)"))
        } catch {
            Vault.error(LF("Could not create the recovery phrase: %@", error.localizedDescription))
            return
        }
        // If the old phrase leaked, whoever has it may already hold the current data key.
        let a = NSAlert()
        a.messageText = L("Was the old phrase exposed?")
        a.informativeText = L("A leaked phrase reveals the current data key, so a new phrase alone is not enough. Changing the password now re-encrypts everything with a fresh key (the new phrase stays valid; the Touch ID entry is refreshed).")
        a.addButton(withTitle: L("Change Password Now"))
        a.addButton(withTitle: L("No, Keep Password"))
        if a.runModal() == .alertFirstButtonReturn {
            guard let pw = Vault.askPassword(title: L("New password"), message: L("Enter the new password twice."), confirm: true) else { return }
            rekey(with: pw)
            pw.zero()
        }
    }

    /// Turn protection on: set a password, re-save data encrypted.
    func enableProtection() -> Bool {
        guard let pw = Vault.askPassword(title: L("Set Keepit password"),
                                         message: L("You'll be asked for it every time Keepit starts. There is no recovery if you forget it."),
                                         confirm: true) else { return false }
        defer { pw.zero() }
        do {
            Storage.key = try Vault.enable(password: pw)
        } catch {
            Vault.error(LF("Could not enable protection: %@", error.localizedDescription))
            return false
        }
        history.saveNow()
        templates.saveNow()
        syncBiometricKey()
        if let key = Storage.key, let words = try? Vault.createRecovery(for: key) {
            RecoveryDialogs.present(words: words)
        }
        return true
    }

    /// Store / refresh / remove the Touch ID copy of the key according to settings.
    func syncBiometricKey() {
        guard Vault.isEnabled, let key = Storage.key else { BiometricUnlock.remove(); return }
        if settings.biometricUnlock {
            do { try BiometricUnlock.store(key) } catch {
                Vault.error(LF("Touch ID could not be set up: %@", error.localizedDescription))
                settings.biometricUnlock = false
                Storage.save(settings, to: Storage.settingsURL, encrypt: false)
            }
        } else {
            BiometricUnlock.remove()
        }
    }

    /// Turn protection off after verifying the password; data is re-saved as plain JSON.
    func disableProtection() -> Bool {
        guard let pw = Vault.askPassword(title: L("Disable password protection"),
                                         message: L("Enter the current password. History and templates will be stored unencrypted.")) else { return false }
        let check = Vault.unlock(password: pw)
        pw.zero()
        guard check != nil else {
            Vault.error(L("Wrong password."))
            return false
        }
        check?.zero()
        Storage.key = nil
        Vault.disable()
        BiometricUnlock.remove()
        history.saveNow()
        templates.saveNow()
        return true
    }

    func changePassword() {
        guard Vault.isEnabled, Storage.key != nil else { return }
        guard authenticateForChange(reasonKey: "change the Keepit password") else { return }
        guard let pw = Vault.askPassword(title: L("New password"), message: L("Enter the new password twice."), confirm: true) else { return }
        defer { pw.zero() }
        rekey(with: pw)
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
        if old.biometricUnlock != new.biometricUnlock {
            syncBiometricKey()
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
        for t in templates.allItems().filter({ $0.hotKey != nil }).prefix(Limits.templateHotKeysMax) {
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
            a.messageText = L("Hot key unavailable")
            a.informativeText = LF("Could not register: %@. Another app or macOS is using it. Change it in Preferences.", failed.joined(separator: ", "))
            a.runModal()
        }
    }

    // MARK: - Main menu (needed so ⌘C/⌘V/⌘A work inside our own windows)

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("About Keepit"), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        if updater.isConfigured {
            appMenu.addItem(withTitle: L("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        }
        appMenu.addItem(withTitle: L("Viewer…"), action: #selector(openViewer), keyEquivalent: "l")
        appMenu.addItem(withTitle: L("Preferences…"), action: #selector(openPreferences), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Export Backup…"), action: #selector(exportBackup), keyEquivalent: "")
        appMenu.addItem(withTitle: L("Import Backup…"), action: #selector(importBackup), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quit Keepit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: L("Edit"))
        edit.addItem(withTitle: L("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let window = NSMenu(title: L("Window"))
        window.addItem(withTitle: L("Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
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
            b.toolTip = LF("Keepit — %@ history, %@ templates", settings.historyHotKey.displayString, settings.templateHotKey.displayString)
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
        if isLocked {
            let menu = NSMenu()
            menu.addItem(withTitle: L("Unlock Keepit…"), action: #selector(unlock), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: L("Quit Keepit"), action: #selector(quit), keyEquivalent: "q").target = self
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
        menu.addItem(withTitle: L("Viewer…"), action: #selector(openViewer), keyEquivalent: "").target = self
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
        let menu = NSMenu(title: L("History"))
        menu.autoenablesItems = false

        let items = menuBuilder.historyItems(history.items, target: self, action: #selector(historyChosen(_:)))
        if items.isEmpty {
            let e = NSMenuItem(title: L("(History is empty)"), action: nil, keyEquivalent: "")
            e.isEnabled = false
            menu.addItem(e)
        } else {
            for mi in items { menu.addItem(mi) }
        }

        if includeTemplates {
            menu.addItem(.separator())
            let t = NSMenuItem(title: L("Template"), action: nil, keyEquivalent: "")
            t.attributedTitle = NSAttributedString(string: L("Template"), attributes: [.foregroundColor: AppInfo.templateColor])
            t.image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [AppInfo.templateColor]))
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
        var out: [NSMenuItem] = [
            item(L("Viewer…"), #selector(openViewer)),
            item(L("Add Clipboard to Templates"), #selector(addClipboardToTemplates)),
            item(L("Preferences…"), #selector(openPreferences), ","),
            .separator(),
            item(L("Export Backup…"), #selector(exportBackup)),
            item(L("Import Backup…"), #selector(importBackup)),
            .separator(),
            item(L("Clear History"), #selector(clearHistory)),
        ]
        if Vault.isEnabled {
            out.append(item(L("Lock Keepit"), #selector(lock), "l"))
        }
        if updater.isConfigured {
            out.append(item(L("Check for Updates…"), #selector(checkForUpdates)))
        }
        out.append(item(L("About Keepit"), #selector(showAbout)))
        if !Paster.isTrusted() {
            out.append(item(L("Grant Accessibility Permission…"), #selector(grantAccessibility)))
        }
        out.append(.separator())
        out.append(item(L("Quit Keepit"), #selector(quit), "q"))
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
            a.messageText = L("Copied to the clipboard — but Keepit can't paste for you yet")
            a.informativeText = L("Press ⌘V to paste now. To paste automatically, allow Keepit in System Settings → Privacy & Security → Accessibility. If Keepit is already listed, turn it off and on again (macOS forgets the grant when the app is rebuilt with a different signature).")
            a.addButton(withTitle: L("Open System Settings"))
            a.addButton(withTitle: L("Later"))
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
        a.messageText = L("Clear clipboard history?")
        a.informativeText = LF("%d item(s) will be removed. Templates are not affected.", history.items.count)
        a.addButton(withTitle: L("Clear"))
        a.addButton(withTitle: L("Cancel"))
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
        AboutWindow.shared.show()
    }

    @objc func checkForUpdates() {
        menuSelectionMade = true
        updater.checkForUpdates(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAccessibilityAlert() {
        let a = NSAlert()
        a.messageText = L("Keepit needs the Accessibility permission to paste")
        a.informativeText = "Without it Keepit can still record history and copy items to the clipboard, but it cannot send ⌘V to the active app or place the menu at the text cursor.\n\nSystem Settings → Privacy & Security → Accessibility → enable Keepit."
        a.addButton(withTitle: L("Open System Settings"))
        a.addButton(withTitle: L("Later"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            Paster.requestTrust()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
