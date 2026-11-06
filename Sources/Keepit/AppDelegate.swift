import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private(set) var settings: Settings
    private(set) var history: HistoryStore!
    private(set) var templates: TemplateStore!
    private(set) var monitor: ClipboardMonitor!
    private(set) var backup: BackupEngine!
    let hotKeys = HotKeyManager()
    private lazy var menuBuilder = MenuBuilder(settings: settings)

    private var statusItem: NSStatusItem!
    private lazy var updater = Updater()
    private var checkForUpdatesItem: NSMenuItem?
    private var preferencesWindow: SettingsWindowController?
    private(set) var viewer: ViewerWindowController?
    /// Set by the uninstaller: nothing may be written to disk any more (see Uninstall.swift).
    var uninstalling = false
    /// Recording paused until this moment (Pause for 10 Minutes); nil = recording.
    private(set) var pausedUntil: Date?
    private var pauseTimer: Timer?

    /// Most recently active app other than us — the Viewer pastes into it (the original remembered the previous window).
    private(set) var lastExternalApp: NSRunningApplication?

    /// App that was frontmost when a popup menu opened — paste goes back there.
    private var pasteTarget: NSRunningApplication?
    /// Serial copy-and-paste; see PasteQueue.
    let queue = PasteQueue()
    private var menuSelectionMade = false
    private var popupActive = false
    /// How the history menu was last opened, so Delete can put it straight back (NSMenu closes on
    /// any choice; reopening the same way, at the same place, with the search kept, is the one
    /// case where that is wrong — the user is tidying the list, not leaving it).
    private enum HistoryMenuOrigin { case statusItem, popup(NSPoint) }
    private var historyMenuOrigin: HistoryMenuOrigin?
    private var lastClosedWasHistoryMenu = false
    /// Menus of ours currently tracking (history, template, action submenus); global hot keys pause meanwhile.
    private var openMenus = 0

    /// True while the vault key is wiped and data is unloaded (password set, not yet entered).
    private(set) var isLocked = false
    /// Bumped by every `lock()`. A flow that ran a modal dialog compares it before touching the
    /// stores: a lock meanwhile purged them, and whatever the flow computed is stale.
    private(set) var lockCount = 0
    /// Bumped by every `apply(settings:)`, for the same reason.
    private(set) var settingsRevision = 0
    /// Set once launch *and* the deferred welcome dialogs are over; file and URL opens before that are
    /// queued (`pendingOpenURLs`) and run after, in order. A restore in progress queues them too.
    private(set) var isReadyForOpens = false
    var pendingOpenURLs: [URL] = []
    /// Locking after the Mac has been locked or asleep for a while (Settings → Security).
    private(set) var screenLockPolicy = ScreenLockPolicy(delay: nil)
    private(set) var screenLockTimer: Timer?
    /// What macOS last told us about the screen; `sessionDidBecomeActive` alone does not mean the screen is usable.
    private(set) var screenIsLocked = false
    /// The one automatic Touch ID prompt that may be waiting after the Mac came back; cancelled by any
    /// new absence, lock, settings change or a second "back" event.
    private(set) var autoUnlockJob: DispatchWorkItem?
    /// Tests replace the modal unlock with a counter; nil in the app.
    var autoUnlockForTesting: (() -> Void)?
    /// Tests only: stand in for a successful manual unlock without the dialog.
    func setLockedForTesting(_ v: Bool) { isLocked = v }
    /// Tests only: an unlock prompt "on screen", and the app past its welcome dialogs.
    func setUnlockInProgressForTesting(_ v: Bool) { unlockInProgress = v }
    func setReadyForOpensForTesting(_ v: Bool) { isReadyForOpens = v }
    /// `unlock()` is modal and re-entrant from several places (menu, keepit://, the automatic prompt): one at a time.
    private(set) var unlockInProgress = false
    /// What macOS says about the screen right now (`CGSessionCopyCurrentDictionary`); nil = unknown.
    /// Tests replace it. Used where a notification alone does not say whether the desktop is usable.
    var screenLockedProbe: () -> Bool? = { ScreenState.isLocked() }
    /// Whether our session is on the console (`kCGSessionOnConsoleKey`); nil = unknown. Tests replace it.
    var sessionActiveProbe: () -> Bool? = { ScreenState.isSessionActive() }
    /// Tests only: receives the hot keys that could not be registered instead of the alert.
    var hotKeyFailureForTesting: (([String]) -> Void)?
    /// Tests only: the sender of a keepit:// URL (no Apple Event in a test) and the answer to its
    /// confirmation dialog, which may lock Keepit the way a user could while the dialog is open.
    var urlCommandSenderForTesting: URLSender?
    var confirmURLCommandForTesting: ((AppDelegate) -> URLConfirmation)?
    /// One open at a time, the unlock dialog included; a restore from Settings sets the second.
    var openInProgress = false
    var restoreInProgress = false

    /// No settings file yet → first launch (onboarding, login item).
    private let isFirstRun: Bool

    /// A restore journal that could not be replayed at launch. The files are a mix of before and
    /// after; working on them would write that mix back and the journal would be the only intact
    /// copy. So the app explains and quits before any store is created (the journal stays on disk;
    /// the next launch tries again).
    private var recoveryError: Error?

    override init() {
        // A restore interrupted between its three file writes is put right before anything is read.
        do { if try RestoreCommit.recoverIfNeeded() { Log.storage.notice("replayed an interrupted restore") } }
        catch { recoveryError = error; Log.storage.error("restore journal could not be replayed: \(error.localizedDescription)") }
        let stored = Storage.load(Settings.self, from: Storage.settingsURL)
        isFirstRun = stored == nil
        settings = stored ?? Settings()
        super.init()
    }

    /// Tests only: the two stores without the rest of the launch (no password gate, monitor, timers,
    /// hot keys or dialogs). The app itself creates them in `applicationDidFinishLaunching`, after the vault.
    func loadStoresForTesting() {
        history = HistoryStore(settings: settings)
        templates = TemplateStore()
        if monitor == nil { monitor = ClipboardMonitor(settings: settings) }   // idle: never started
        sessionActiveProbe = { nil }                 // a test says so when the session matters; a CI session must not decide
    }

    /// An undo of a restore did not finish — at launch, or during a restore just now: the files
    /// are a mix of before and after and the armed journal is their only intact copy. Working on
    /// would save over that mix (and the next launch's replay would then discard whatever was
    /// saved), so: explain, change nothing, leave. `exit`, not `terminate()`: the latter runs
    /// `applicationWillTerminate`, which saves; and no `defer` on the way restarts the watcher.
    func stopForUnfinishedUndo(_ error: Error) -> Never {
        Log.storage.error("unfinished restore undo; quitting without saving: \(error.localizedDescription)")
        Vault.error(LF("Keepit could not finish undoing an interrupted restore: %@\n\nNothing will be changed. Fix the file named above (permissions, a locked flag, disk space) and launch Keepit again.", error.localizedDescription))
        exit(1)
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let e = recoveryError { stopForUnfinishedUndo(e) }
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()

        // Password gate: nothing is loaded until the vault is unlocked.
        if Vault.isEnabled && !unlockVault(quitOnFailure: true) {
            NSApp.terminate(nil)
            return
        }
        history = HistoryStore(settings: settings)
        // Age-based expiry also runs on a timer, so items disappear without waiting for the next copy.
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, !self.isLocked else { return }
            if self.history.expire() > 0 { self.viewer?.refresh() }
        }
        templates = TemplateStore()
        monitor = ClipboardMonitor(settings: settings)
        setUpBackup()                                  // before completeRecovery(): rekey() tells the engine about the new key
        if needsPasswordReset { completeRecovery() }

        buildStatusItem()

        monitor.onCapture = { [weak self] item in
            self?.history.add(item)
            self?.queue.record(item)
            self?.viewer?.refresh()
        }
        monitor.start()
        queue.timeout = settings.queueTimeout
        queue.onChange = { [weak self] in self?.updateStatusIcon() }
        queue.onAutoStop = { [weak self] in self?.queueBlink(times: 1) }

        lastExternalApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self?.lastExternalApp = app
        }

        hotKeys.isSuppressed = { [weak self] in (self?.openMenus ?? 0) > 0 }
        registerHotKeys()
        Storage.save(settings, to: Storage.settingsURL, encrypt: false, pretty: true)
        // Last, with everything in place that a lock stops: where the user is right now. Launched
        // behind a locked screen or in another user's session (a relaunch after an update, a login
        // item on a second account), the absence starts here and the policy applies to it as to any
        // other — nothing above this line restarts what a lock stopped.
        observeScreenLock()
        updater.isEnabled = settings.checkForUpdates   // starts Sparkle's scheduled checks, if allowed

        if SelfTest.isActive {
            SelfTest.run(app: self)
            return
        }

        // The welcome dialogs run from a Timer, not a GCD block: they open modal loops, and work
        // other code hands to the main queue (a progress panel's completion, a bookmark refresh)
        // would otherwise wait until this block returned.
        if isFirstRun {
            if settings.launchAtLogin { setLaunchAtLogin(true) }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self else { return }
                if self.hasPendingBackupFile { self.openPendingBackupFileAtWelcome() }   // the double-clicked backup is the answer
                else { _ = self.offerRestoreOnFirstRun() }
                if !Vault.isEnabled { self.offerPasswordOnFirstRun() }   // a restore may have set the password already
                if !Paster.isTrusted() { self.showAccessibilityAlert() }
                self.isReadyForOpens = true
                self.openPendingURLs()
            }
        } else {
            Timer.scheduledTimer(withTimeInterval: Paster.isTrusted() ? 0.1 : 1.0, repeats: false) { [weak self] _ in
                guard let self else { return }
                if !Paster.isTrusted() { self.showAccessibilityAlert() }
                self.isReadyForOpens = true
                self.openPendingURLs()
            }
        }
    }

    /// First launch: suggest turning protection on; be explicit about what "no" means.
    func offerPasswordOnFirstRun() {
        guard !Vault.isEnabled else { return }
        let a = NSAlert()
        a.alertStyle = .informational
        a.icon = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: nil)
        a.messageText = L("Protect your clipboard history with a password?")
        a.informativeText = L("Keepit can encrypt your history and templates (AES-256) and ask for the password — or Touch ID — when it starts.")
        let touchID = NSButton(checkboxWithTitle: L("Also unlock with Touch ID"), target: nil, action: nil)
        // Always offered: Touch ID on a closed MacBook or a sleeping Magic Keyboard reports "not available"
        // for a moment, and the key is simply stored later, at the next password unlock.
        touchID.state = BiometricUnlock.hasSensor ? .on : .off
        touchID.sizeToFit()
        a.accessoryView = touchID
        a.addButton(withTitle: L("Set Password…"))
        a.addButton(withTitle: L("Not Now"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            // Decide Touch ID before enabling: enableProtection() stores the key for it right away.
            var s = settings
            s.biometricUnlock = touchID.state == .on
            s.biometricPasswordChange = s.biometricUnlock
            apply(settings: s)
            if enableProtection() {
                updateStatusIcon()
                return
            }
        }
        let b = NSAlert()
        b.alertStyle = .warning
        b.messageText = L("Your data will not be encrypted")
        b.informativeText = L("Without a password Keepit stores history and templates unencrypted in your user Library. You can turn protection on at any time in Settings → Security.")
        b.addButton(withTitle: L("OK"))
        b.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        if !uninstalling {
            history?.flush()
            templates?.flush()
            Storage.save(settings, to: Storage.settingsURL, encrypt: false, pretty: true)
        }
        Storage.waitUntilSaved()    // a debounced write may still be in flight
        Storage.clearKey()          // wipe key bytes before the process goes away
    }

    /// Close all windows (used by lock and uninstall).
    func closeAllWindows() {
        viewer?.close()
        preferencesWindow?.close()
    }

    // MARK: - Lock / unlock (key zeroization)

    private func observeScreenLock() {
        let dnc = DistributedNotificationCenter.default()
        let wnc = NSWorkspace.shared.notificationCenter
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenLocked(true)
        }
        dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenLocked(false)
        }
        wnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.macWentAway()
        }
        wnc.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.macWentAway()
        }
        // Another user's session ended; ours is in front again — but the screen may still be locked.
        wnc.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if let locked = self.screenLockedProbe() { self.screenIsLocked = locked }
            guard !self.screenIsLocked else { return }
            self.macCameBack()
        }
        seedScreenState()
        // Waking is not being back: the login window usually follows. Only the deadline is checked —
        // the absence and its timer stay, because a timer does not run while the Mac sleeps.
        wnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.macWoke()
        }
    }

    /// The state once, at start: launched behind a locked screen or in an inactive session, the
    /// notification that would have started the absence has already gone by (Apple documents this
    /// for sessionDidResignActive), so the absence starts now — the policy then locks at once or
    /// after its delay, exactly as for an absence that began with a notification. An unknown answer
    /// (nil) changes nothing: the notifications take over from here.
    func seedScreenState() {
        let locked = screenLockedProbe()
        if let locked { screenIsLocked = locked }
        if locked == true || sessionActiveProbe() == false { macWentAway() }
    }

    /// The screen-lock notifications: the one "away" / "back" pair macOS reports explicitly.
    func screenLocked(_ locked: Bool) {
        screenIsLocked = locked
        if locked { macWentAway() } else { macCameBack() }
    }

    /// Screen locked, Mac going to sleep, or another user's session in front.
    func macWentAway() {
        cancelAutoUnlock()
        guard Vault.isEnabled, !isLocked else { return }
        screenLockPolicy.delay = settings.lockAfterScreenLock
        if screenLockPolicy.wentAway(at: Date()) { lock(); return }
        armScreenLockTimer()
    }

    private func armScreenLockTimer() {
        screenLockTimer?.invalidate(); screenLockTimer = nil
        guard let deadline = screenLockPolicy.deadline else { return }
        let t = Timer(fire: deadline, interval: 0, repeats: false) { [weak self] _ in
            guard let self, self.screenLockPolicy.timerFired(at: Date()), !self.isLocked else { return }
            self.lock()
        }
        t.tolerance = 30
        RunLoop.main.add(t, forMode: .common)
        screenLockTimer = t
    }

    /// Woke from sleep. If macOS says the screen is locked (or cannot say), the absence goes on:
    /// lock if it already lasted the delay, otherwise keep waiting for `screenIsUnlocked`. If the
    /// screen is not locked — a Mac that sleeps without asking for a password — the user is back at
    /// the desktop and no `screenIsUnlocked` will ever come: this wake ends the absence.
    func macWoke() {
        // One reading, one meaning: only an explicit "not locked" ends the absence. nil keeps the
        // stored state and the absence (the auditor's probe that answered nil, then true, must not
        // be read as "back" because the stored flag was still false).
        let state = screenLockedProbe()
        if let state { screenIsLocked = state }
        // An unlocked screen is the user's only if the session is ours: a Mac waking into another
        // user's session (fast user switching) is not "back", and sessionDidBecomeActive will say
        // when it is (auditor's P2 on PR #25: the wake ended an absence the seed had started).
        if state == false, sessionActiveProbe() != false {
            macCameBack()
            return
        }
        if screenLockPolicy.timerFired(at: Date()) {
            if !isLocked { lock() }
        } else if screenLockPolicy.deadline != nil {
            armScreenLockTimer()
        }
    }

    /// The user is back: screen unlocked, or our session active again with the screen unlocked.
    /// Not while our session is known to be off the console — nothing the user could see is back.
    func macCameBack() {
        guard sessionActiveProbe() != false else { return }
        screenLockTimer?.invalidate(); screenLockTimer = nil
        if screenLockPolicy.cameBack(at: Date()), Vault.isEnabled, !isLocked { lock() }
        scheduleAutoUnlock()
    }

    /// One automatic Touch ID prompt, 0.8 s after the Mac came back, tied to this lock generation: the
    /// hand is on the keyboard now, and finding Keepit locked at the first ⌥M is the annoyance the delay
    /// exists to avoid. Re-checked when it fires; dropped by any new absence, lock or settings change.
    private func scheduleAutoUnlock() {
        cancelAutoUnlock()
        guard isLocked, settings.biometricUnlock, Vault.isEnabled, !unlockInProgress, !openInProgress, !restoreInProgress else { return }
        let generation = lockCount
        let job = DispatchWorkItem { [weak self] in
            guard let self, self.autoUnlockJob != nil else { return }
            self.autoUnlockJob = nil
            guard self.isLocked, self.lockCount == generation, !self.screenIsLocked, self.settings.biometricUnlock,
                  Vault.isEnabled, !self.unlockInProgress, !self.openInProgress, !self.restoreInProgress else { return }
            if let test = self.autoUnlockForTesting { test() } else { _ = self.unlock() }
        }
        autoUnlockJob = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: job)
    }

    private func cancelAutoUnlock() {
        autoUnlockJob?.cancel()
        autoUnlockJob = nil
    }

    /// Wipe the key, unload history/templates from memory, stop watching the clipboard, drop hot keys.
    @objc func lock() {
        guard Vault.isEnabled, !isLocked else { return }
        cancelAutoUnlock()
        isLocked = true
        lockCount += 1
        AbortableModal.abortIfRunning()      // a template prompt or a keepit:// confirmation does not outlive the lock
        queue.stop()
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
        guard !unlockInProgress else { return false }      // a prompt is already on screen; the queue waits (openPendingURLs)
        unlockInProgress = true
        defer {
            unlockInProgress = false
            DispatchQueue.main.async { [weak self] in self?.openPendingURLs() }   // whatever arrived during the prompt
        }
        cancelAutoUnlock()
        guard unlockVault(quitOnFailure: false) else { return false }
        isLocked = false
        history.reload()
        templates.reload()
        if needsPasswordReset { completeRecovery() }
        if !(pausedUntil.map { $0 > Date() } ?? false) { monitor.start() }   // keep a running pause
        registerHotKeys()
        backup.runIfDue()
        updateStatusIcon()
        return true
    }

    private func updateStatusIcon() {
        guard let b = statusItem?.button else { return }
        let paused = pausedUntil.map { $0 > Date() } ?? false
        let symbol = isLocked ? "lock.fill" : (paused ? "pause.circle" : "paperclip")
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Keepit")
        b.image?.isTemplate = true
        b.toolTip = isLocked ? L("Keepit — locked, click to unlock")
                  : paused ? L("Keepit — recording paused")
                  : queue.isActive ? LF("Keepit — paste queue on: %d to paste (%@ next, %@ stop)", queue.remaining,
                                        settings.queuePasteHotKey?.displayString ?? "–", settings.queueHotKey?.displayString ?? "–")
                  : LF("Keepit — %@ history, %@ templates", settings.historyHotKey.displayString, settings.templateHotKey.displayString)
        // Paste queue: a red dot and the number of items still to paste next to the icon.
        if queue.isActive, !isLocked {
            b.imagePosition = .imageLeading
            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .semibold)
            let t = NSMutableAttributedString(string: "●", attributes: [.foregroundColor: queueDotDimmed ? NSColor.tertiaryLabelColor : NSColor.systemRed, .font: font, .baselineOffset: 1])
            t.append(NSAttributedString(string: " \(queue.remaining)", attributes: [.foregroundColor: NSColor.labelColor, .font: font]))
            b.attributedTitle = t
            statusItem.length = NSStatusItem.variableLength
        } else {
            b.attributedTitle = NSAttributedString(string: "")
            b.title = ""
            b.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.squareLength
        }
    }

    // MARK: - Paste queue

    private var queueDotDimmed = false

    /// Blink the red dot a few times (on start, and once when the queue ends by itself).
    private func queueBlink(times: Int) {
        var left = times * 2
        Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            left -= 1
            self.queueDotDimmed = left % 2 == 1
            self.updateStatusIcon()
            if left <= 0 { t.invalidate(); self.queueDotDimmed = false; self.updateStatusIcon() }
        }
    }

    @objc func toggleQueue() {
        guard !isLocked else { NSSound.beep(); return }
        queue.toggle()
        if queue.isActive { queueBlink(times: 3) }
    }

    /// ⌥V by default: paste the next queued item into the front app.
    func pasteFromQueue() {
        guard !isLocked, queue.isActive else { NSSound.beep(); return }
        guard let item = queue.take() else { NSSound.beep(); queue.stop(); return }
        let target = NSWorkspace.shared.frontmostApplication
        Paster.paste(item, into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
    }

    /// ⌥⇧R by default: paste everything still queued as one text, items joined with the chosen separator.
    func pasteAllFromQueue() {
        guard !isLocked, queue.isActive else { NSSound.beep(); return }
        guard let text = queue.takeAll(separator: settings.queueSeparator) else { NSSound.beep(); return }
        let target = NSWorkspace.shared.frontmostApplication
        Paster.paste(ClipItem.text(text), into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
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
                Log.vault.notice("Touch ID key does not open the vault (password changed elsewhere?)")
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
                    if settings.biometricUnlock && !BiometricUnlock.isConfigured { syncBiometricKey(quiet: true) }
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
        backup?.forceNext()                           // the next copy must open with the new password
    }

    /// Confirm identity for sensitive changes: Touch ID (if allowed) or the current password.
    func authenticateForChange(reasonKey: String) -> Bool {
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

    /// Settings → Security → Recovery phrase → Create New…: invalidates the old sheet.
    func regenerateRecoveryPhrase() {
        guard Vault.isEnabled, let key = Storage.key else { return }
        guard authenticateForChange(reasonKey: "generate a new recovery phrase") else { return }
        do {
            let words = try Vault.createRecovery(for: key)
            backup?.forceNext()                       // a copy with the new phrase in its header
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
            guard let pw = Vault.askPassword(title: L("New password"), message: L("Enter the new password twice. Backups made so far still open with the old password."), confirm: true) else { return }
            rekey(with: pw)
            pw.zero()
        }
    }

    /// Turn protection on: set a password, re-save data encrypted.
    func enableProtection() -> Bool {
        guard let pw = Vault.askPassword(title: L("Set Keepit password"),
                                         message: L("You'll be asked for it every time Keepit starts. A recovery phrase for it is shown next."),
                                         confirm: true) else { return false }
        defer { pw.zero() }
        return enableProtection(with: pw)
    }

    /// Turn protection on with a password already in hand (a restored backup's). The caller wipes `pw`.
    /// `recoveryEntropy`: keep a phrase the user already holds (the one that opened a restored
    /// backup) instead of showing a new one.
    func enableProtection(with pw: SecureBuffer, recoveryEntropy: [UInt8]? = nil) -> Bool {
        do {
            Storage.key = try Vault.enable(password: pw)
        } catch {
            Vault.error(LF("Could not enable protection: %@", error.localizedDescription))
            return false
        }
        history.saveNow()
        templates.saveNow()
        syncBiometricKey()
        configureBackup()                             // a folder kept in settings becomes a destination again
        if let key = Storage.key {
            do {
                let words = try Vault.createRecovery(for: key, entropy: recoveryEntropy)
                backup?.forceNext()
                if recoveryEntropy == nil { RecoveryDialogs.present(words: words) }
                else { info(L("Protection is on. The recovery phrase from the backup also opens Keepit on this Mac.")) }
            } catch {
                Vault.error(LF("Could not set up the recovery phrase: %@", error.localizedDescription))
            }
        }
        return true
    }

    /// Store / refresh / remove the Touch ID copy of the key according to settings.
    /// Store (or remove) the vault key for Touch ID according to the setting. If biometry is not usable
    /// at this moment (lid closed, keyboard asleep, nothing enrolled yet) the setting is kept and the key
    /// is stored at the next password unlock; `quiet` suppresses the dialog for those retries.
    func syncBiometricKey(quiet: Bool = false) {
        guard Vault.isEnabled, let key = Storage.key else { BiometricUnlock.remove(); return }
        if settings.biometricUnlock {
            do { try BiometricUnlock.store(key) } catch BiometricUnlock.Failure.notAvailable {
                Log.vault.notice("Touch ID not usable right now; will store the key at the next password unlock")
                if !quiet {
                    Vault.error(L("Touch ID is not usable right now (closed lid, keyboard asleep, or no fingerprint enrolled). Keepit will enable it automatically the next time you unlock with the password."))
                }
            } catch {
                Vault.error(LF("Touch ID could not be set up: %@", error.localizedDescription))
                settings.biometricUnlock = false
                Storage.save(settings, to: Storage.settingsURL, encrypt: false, pretty: true)
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
        if settings.backupEnabled {                   // automatic backup needs the vault: off together, visibly
            var s = settings; s.backupEnabled = false
            apply(settings: s)                        // → configureBackup(): destination nil
        }
        return true
    }

    func changePassword() {
        guard Vault.isEnabled, Storage.key != nil else { return }
        guard authenticateForChange(reasonKey: "change the Keepit password") else { return }
        guard let pw = Vault.askPassword(title: L("New password"), message: L("Enter the new password twice. Backups made so far still open with the old password."), confirm: true) else { return }
        defer { pw.zero() }
        rekey(with: pw)
    }

    // MARK: - Settings

    func apply(settings new: Settings) {
        let old = settings
        settings = new
        settingsRevision += 1
        Storage.save(new, to: Storage.settingsURL, encrypt: false, pretty: true)
        history.updateSettings(new)
        if old.backupEnabled != new.backupEnabled || old.backupBookmark != new.backupBookmark
            || old.backupKeepCount != new.backupKeepCount || old.backupLabel != new.backupLabel {
            configureBackup()
            if old.backupBookmark != new.backupBookmark { backup.resetRegistry(); backup?.forceNext() }   // a new folder starts a new series
        }
        monitor.updateSettings(new)
        menuBuilder.settings = new
        if !new.biometricUnlock || new.lockAfterScreenLock != old.lockAfterScreenLock { cancelAutoUnlock() }
        if new.lockAfterScreenLock == nil { screenLockTimer?.invalidate(); screenLockTimer = nil; screenLockPolicy = ScreenLockPolicy(delay: nil) }
        menuBuilder.invalidateThumbnails()
        if old.checkForUpdates != new.checkForUpdates {
            updater.isEnabled = new.checkForUpdates
            checkForUpdatesItem?.isHidden = !new.checkForUpdates
        }
        if old.historyHotKey != new.historyHotKey || old.templateHotKey != new.templateHotKey || old.previousHotKey != new.previousHotKey
            || old.latestActionModifiers != new.latestActionModifiers || old.numberPasteModifiers != new.numberPasteModifiers
            || old.lockHotKey != new.lockHotKey || old.pauseHotKey != new.pauseHotKey
            || old.viewerHotKey != new.viewerHotKey || old.preferencesHotKey != new.preferencesHotKey
            || old.clearHistoryHotKey != new.clearHistoryHotKey || old.quitHotKey != new.quitHotKey
            || old.queueHotKey != new.queueHotKey || old.queuePasteHotKey != new.queuePasteHotKey
            || old.queuePasteAllHotKey != new.queuePasteAllHotKey {
            registerHotKeys()
        }
        queue.timeout = new.queueTimeout
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
            Log.system.error("launch at login change failed: \(error.localizedDescription)")
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
        if let prev = settings.previousHotKey,
           !hotKeys.register(prev, handler: { [weak self] in self?.pastePreviousItem() }) {
            failed.append(prev.displayString)
        }
        if let mods = settings.latestActionModifiers {
            for la in HotKey.LatestAction.allCases {
                let hk = HotKey(keyCode: la.keyCode, modifiers: mods)
                if !hotKeys.register(hk, handler: { [weak self] in self?.performOnLatest(la) }) { failed.append(hk.displayString) }
            }
        }
        if let mods = settings.numberPasteModifiers {
            for (i, code) in HotKey.digitKeyCodes.enumerated() {
                let hk = HotKey(keyCode: code, modifiers: mods)
                if !hotKeys.register(hk, handler: { [weak self] in self?.pasteItem(at: i, plainText: false) }) {
                    failed.append(hk.displayString)
                }
            }
        }
        if let hk = settings.lockHotKey, !hotKeys.register(hk, immediate: true, handler: { [weak self] in self?.lock() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.viewerHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.openViewer() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.preferencesHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.openPreferences() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.clearHistoryHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.clearHistory() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.queueHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.toggleQueue() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.queuePasteHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.pasteFromQueue() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.queuePasteAllHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.pasteAllFromQueue() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.quitHotKey, !hotKeys.register(hk, handler: { [weak self] in self?.quit() }) {
            failed.append(hk.displayString)
        }
        if let hk = settings.pauseHotKey, !hotKeys.register(hk, handler: { [weak self] in
            guard let self else { return }
            if let until = self.pausedUntil, until > Date() { self.resumeRecording() } else { self.pauseRecording() }
        }) {
            failed.append(hk.displayString)
        }
        // Per-template hot keys: paste the item directly, no menu ("Set Hot Key" on a template item).
        for t in templates.allItems().filter({ $0.hotKey != nil }).prefix(Limits.templateHotKeysMax) {
            guard let hk = t.hotKey, t.clip != nil else { continue }
            let id = t.id
            if !hotKeys.register(hk, handler: { [weak self] in
                guard let self = self, let node = self.templates.root.find(id: id), let clip = node.clip else { return }
                let target = NSWorkspace.shared.frontmostApplication
                self.pasteTemplate(clip, named: node.displayName, into: target)
            }) {
                failed.append("\(hk.displayString) (\(t.displayName))")
            }
        }
        if let test = hotKeyFailureForTesting { if !failed.isEmpty { test(failed) }; return }
        if !failed.isEmpty, !SelfTest.isActive {
            // Report hot keys that could not be registered — after the caller is done, never inside
            // it: registerHotKeys runs from apply(settings:) in the middle of a restore commit, and a
            // modal loop there let a lock happen between the files and the models (auditor's P2 on PR #28).
            DispatchQueue.main.async {
                let a = NSAlert()
                a.messageText = L("Hot key unavailable")
                a.informativeText = LF("Could not register: %@. Another app or macOS is using it. Change it in Settings → Shortcuts.", failed.joined(separator: ", "))
                a.runModal()
            }
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
            let item = appMenu.addItem(withTitle: L("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
            item.isHidden = !settings.checkForUpdates
            checkForUpdatesItem = item
        }
        appMenu.addItem(withTitle: L("Viewer…"), action: #selector(openViewer), keyEquivalent: "l")
        appMenu.addItem(withTitle: L("Settings…"), action: #selector(openPreferences), keyEquivalent: ",")
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
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Find…"), action: #selector(ViewerWindowController.focusSearch(_:)), keyEquivalent: "f")
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
        showStatusItemMenu()
    }

    /// The history menu under the menu-bar icon. `pasteTarget` is the caller's business: a click
    /// sets it to the app in front, a reopen after Delete keeps the one from before.
    private func showStatusItemMenu(query: String = "") {
        let menu = buildHistoryMenu(includeTemplates: true, includeApp: true, query: query)
        menu.delegate = self
        menuSelectionMade = false
        popupActive = false
        historyMenuOrigin = .statusItem
        // Attach temporarily so NSStatusItem positions/highlights it, then detach in menuDidClose.
        if let b = statusItem.button, let w = b.window {
            let f = w.convertToScreen(b.convert(b.bounds, to: nil))
            menuTopLeft = NSPoint(x: f.minX, y: f.minY)
        }
        statusItem.menu = menu
        // Key equivalents (⌘1, ⇧U in the extended menu, …) only reach the menu while we are the active app.
        NSApp.activate(ignoringOtherApps: true)
        statusItem.button?.performClick(nil)
    }

    // MARK: - Popups on hot key

    func showHistoryPopup() {
        popUp(buildHistoryMenu(includeTemplates: true, includeApp: false), isHistory: true)
    }

    func showTemplatePopup() {
        let menu = menuBuilder.templateMenu(templates.root, target: self, action: #selector(templateChosen(_:)))
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Viewer…"), action: #selector(openViewer), keyEquivalent: "").target = self
        popUp(menu)
    }

    private func popUp(_ menu: NSMenu, isHistory: Bool = false, at fixed: NSPoint? = nil) {
        if popupActive || isLocked { return }
        if fixed == nil { pasteTarget = NSWorkspace.shared.frontmostApplication }   // a reopen keeps the original target
        menuSelectionMade = false
        popupActive = true
        menu.delegate = self

        var point = fixed ?? NSEvent.mouseLocation
        if fixed == nil, settings.showAtCaret, let caret = Paster.caretScreenPoint() {
            point = caret
        }
        if isHistory { historyMenuOrigin = .popup(point) }
        // Menus need a key window to get keyboard navigation; activating us is the price.
        NSApp.activate(ignoringOtherApps: true)
        menuTopLeft = point
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    /// After Delete in the history menu: the same menu again, the same way, with the search kept.
    /// The query goes into the build, not after the show: `popUp(…)` and `performClick` run the
    /// menu's tracking loop and return only when it has closed, so anything set after them is seen
    /// on the next opening, not this one (3.0.2 showed the full list).
    private func reopenHistoryMenu(query: String) {
        guard !isLocked, let origin = historyMenuOrigin else { return }
        switch origin {
        case .statusItem:
            showStatusItemMenu(query: query)
        case .popup(let point):
            popUp(buildHistoryMenu(includeTemplates: true, includeApp: false, query: query), isHistory: true, at: point)
        }
    }

    /// Top-left corner of the menu on screen (for the preview panel); set just before it opens.
    private var menuTopLeft = NSPoint.zero

    // NSMenuDelegate
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard settings.showPreview, !isLocked else { return }
        guard let mi = item, mi.tag == MenuBuilder.historyTag, let id = mi.representedObject as? UUID,
              let clip = history.item(id: id), !clip.fitsInTitle(maxLength: settings.titleLength) else {
            PreviewPanel.shared.hide()
            return
        }
        let size = menu.size
        let frame = NSRect(x: menuTopLeft.x, y: menuTopLeft.y - size.height, width: size.width, height: size.height)
        PreviewPanel.shared.schedule(clip, besides: frame)
    }

    func menuWillOpen(_ menu: NSMenu) {
        openMenus += 1
        if let s = historySearchItem, menu.items.first === s { s.focus() }
        if menu.items.contains(where: { $0.tag == MenuBuilder.historyTag }) {
            ExtendedMenuWatch.shared.watch(menu) { [weak self] mi in
                guard let id = mi.representedObject as? UUID else { return nil }
                return self?.actionMenu(for: id)
            }
        }
        if menu.title == Self.actionMenuTitle { ExtendedMenuWatch.shared.submenuOpened() }
    }

    func menuDidClose(_ menu: NSMenu) {
        openMenus = max(0, openMenus - 1)
        if menu.title == Self.actionMenuTitle { ExtendedMenuWatch.shared.submenuClosed(); return }
        ExtendedMenuWatch.shared.stop(menu)
        PreviewPanel.shared.hide()
        if statusItem.menu === menu { statusItem.menu = nil }
        lastClosedWasHistoryMenu = menu.items.contains { $0.tag == MenuBuilder.historyTag }
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

    /// `query` pre-fills the search field and filters the rows before the menu is shown (a reopen
    /// after Delete); it does nothing when the search field is off.
    func buildHistoryMenu(includeTemplates: Bool, includeApp: Bool, query: String = "") -> NSMenu {
        let menu = NSMenu(title: L("History"))
        menu.autoenablesItems = false

        let searching = settings.searchInMenu && !history.items.isEmpty
        if searching {
            let search = MenuSearchItem()
            search.onChange = { [weak self, weak menu] q in
                guard let self, let menu else { return }
                self.refilterHistoryMenu(menu, query: q)
            }
            search.onReturn = { [weak self, weak menu] in
                guard let self, let menu else { return }
                if let first = menu.items.first(where: { $0.tag == MenuBuilder.historyTag && $0.isEnabled && $0.action != nil && !$0.isAlternate }) {
                    menu.cancelTracking()
                    self.historyChosen(first)
                }
            }
            menu.addItem(search)
            historySearchItem = search
        } else {
            historySearchItem = nil
        }

        let items = menuBuilder.historyItems(history.items, target: self, action: #selector(historyChosen(_:)),
                                             numberMods: settings.numberPasteModifiers, commandAccelerators: searching)
        markQueue(items)
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
        if searching, !query.isEmpty, let s = historySearchItem {
            s.field.stringValue = query
            refilterHistoryMenu(menu, query: query)
        }
        return menu
    }

    private var historySearchItem: MenuSearchItem?

    /// While the paste queue is on, show where it stands: ▶ next to paste, ○ still queued, ✓ already pasted.
    private func markQueue(_ items: [NSMenuItem]) {
        guard queue.isActive else { return }
        for mi in items {
            guard let id = mi.representedObject as? UUID else { continue }
            let mark = queue.isNext(id) ? "▶ " : queue.isQueued(id) ? "○ " : queue.wasPasted(id) ? "✓ " : nil
            guard let mark else { continue }
            if let at = mi.attributedTitle {
                let m = NSMutableAttributedString(attributedString: at)
                m.insert(NSAttributedString(string: mark, attributes: at.attributes(at: 0, effectiveRange: nil)), at: 0)
                mi.attributedTitle = m
            } else {
                mi.title = mark + mi.title
            }
        }
    }

    /// Swap the history entries of an open menu for the ones matching `query` (the rest of the menu stays).
    private func refilterHistoryMenu(_ menu: NSMenu, query: String) {
        let firstIndex = menu.items.firstIndex { $0.tag == MenuBuilder.historyTag } ?? 1
        for mi in menu.items where mi.tag == MenuBuilder.historyTag { menu.removeItem(mi) }
        let matches = MenuBuilder.filter(history.items, query: query)
        var fresh = menuBuilder.historyItems(matches, target: self, action: #selector(historyChosen(_:)),
                                             numberMods: settings.numberPasteModifiers, commandAccelerators: true)
        if fresh.isEmpty {
            let none = NSMenuItem(title: L("(no matches)"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            none.tag = MenuBuilder.historyTag
            fresh = [none]
        }
        for (i, mi) in fresh.enumerated() { menu.insertItem(mi, at: firstIndex + i) }
    }

    private func appMenuItems() -> [NSMenuItem] {
        /// A command with its global hot key shown (and usable) in the menu — the same key works everywhere.
        func item(_ title: String, _ sel: Selector, hotKey: HotKey? = nil) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            mi.target = self
            if let eq = hotKey?.menuKeyEquivalent {
                mi.keyEquivalent = eq.key
                mi.keyEquivalentModifierMask = eq.mask
            }
            return mi
        }
        var out: [NSMenuItem] = [
            item(L("Viewer…"), #selector(openViewer), hotKey: settings.viewerHotKey),
            item(L("Add Clipboard to Templates"), #selector(addClipboardToTemplates), hotKey: settings.latestActionModifiers.map { HotKey(keyCode: HotKey.LatestAction.addToTemplates.keyCode, modifiers: $0) }),
            item(L("Settings…"), #selector(openPreferences), hotKey: settings.preferencesHotKey),
            .separator(),
            item(L("Clear History"), #selector(clearHistory), hotKey: settings.clearHistoryHotKey),
        ]
        if let until = pausedUntil, until > Date() {
            let f = DateFormatter(); f.timeStyle = .short
            out.append(item(LF("Resume Recording (paused until %@)", f.string(from: until)), #selector(resumeRecording), hotKey: settings.pauseHotKey))
        } else {
            out.append(item(L("Pause Recording for 10 Minutes"), #selector(pauseRecording), hotKey: settings.pauseHotKey))
        }
        if queue.isActive {
            out.append(item(LF("Stop Paste Queue (%d to paste)", queue.remaining), #selector(toggleQueue), hotKey: settings.queueHotKey))
        } else {
            out.append(item(L("Start Paste Queue"), #selector(toggleQueue), hotKey: settings.queueHotKey))
        }
        if Vault.isEnabled {
            out.append(item(L("Lock Keepit"), #selector(lock), hotKey: settings.lockHotKey))
        }
        out.append(.separator())
        if updater.isConfigured, settings.checkForUpdates {
            out.append(item(L("Check for Updates…"), #selector(checkForUpdates)))
        }
        out.append(item(L("About Keepit"), #selector(showAbout)))
        if !Paster.isTrusted() {
            out.append(item(L("Grant Accessibility Permission…"), #selector(grantAccessibility)))
        }
        out.append(.separator())
        let quitItem = item(L("Quit Keepit"), #selector(quit), hotKey: settings.quitHotKey)
        if settings.quitHotKey == nil { quitItem.keyEquivalent = "q" }   // ⌘Q inside the menu, as everywhere on the Mac
        out.append(quitItem)
        return out
    }

    // MARK: - Actions

    /// ⌥⇧V by default: paste history item #2 without opening the menu. The pasted content is recorded
    /// again and goes to the top, so pressing the key repeatedly swaps between the two latest clips.
    func pastePreviousItem() {
        guard !history.items.isEmpty else { NSSound.beep(); return }
        pasteItem(at: history.items.count > 1 ? 1 : 0, plainText: false)
    }

    /// Global "actions on the latest item" hot keys (<mods>+V/U/L/…): act on history item #1 = the clipboard.
    func performOnLatest(_ action: HotKey.LatestAction) {
        guard !isLocked, let item = history.items.first else { NSSound.beep(); return }
        let target = NSWorkspace.shared.frontmostApplication
        let isText = item.kind == .text && item.plainText != nil
        switch action {
        case .plain:
            guard isText else { NSSound.beep(); return }
            Paster.paste(item, into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect, plainText: true)
        case .addToTemplates:
            let node = TemplateNode(name: "", clip: item)
            guard templates.insert(node, under: templates.root) else { NSSound.beep(); return }
            viewer?.refresh()
        case .delete:
            history.remove(id: item.id)
            viewer?.refresh()
        default:
            guard isText, let t = action.transform, let out = item.transformed(t) else { NSSound.beep(); return }
            Paster.paste(out, into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
        }
    }

    /// Global hot keys: paste history item at `index` into the front app without the menu.
    func pasteItem(at index: Int, plainText: Bool) {
        guard !isLocked, index >= 0, index < history.items.count else { NSSound.beep(); return }
        let item = history.items[index]
        let target = NSWorkspace.shared.frontmostApplication
        Paster.paste(item, into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect, plainText: plainText)
    }

    @objc private func historyChosen(_ sender: NSMenuItem) {
        chooseHistoryItem(sender, plainText: false)
    }

    /// ⇧ alternate: paste the text without RTF/HTML formatting.
    @objc private func historyChosenPlain(_ sender: NSMenuItem) {
        chooseHistoryItem(sender, plainText: true)
    }

    /// ⌥ alternate: keep the item permanently — copy it into the Template tree (root level).
    @objc private func historyPinned(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID,
              let item = history.items.first(where: { $0.id == id }) else { return }
        let node = TemplateNode(name: "", clip: item)
        guard templates.insert(node, under: templates.root) else {
            Vault.error(LF("Limit reached: at most %d template items, %d levels deep.", Limits.templateMaxCount, Limits.templateMaxDepth))
            return
        }
        viewer?.refresh()
    }

    /// ⌃ alternate: remove the item from the history without pasting anything.
    @objc private func historyDeleted(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID else { return }
        let query = historySearchItem?.field.stringValue ?? ""
        let fromMenu = lastClosedWasHistoryMenu          // not the Viewer's context menu
        lastClosedWasHistoryMenu = false
        history.remove(id: id)
        viewer?.refresh()
        if fromMenu {
            // The menu has just closed (NSMenu closes before the action runs); put it back once
            // this event is over, so the user can keep tidying without reopening it by hand.
            DispatchQueue.main.async { [weak self] in self?.reopenHistoryMenu(query: query) }
        }
    }

    // MARK: - Right-click action menu

    /// Action menu for a history entry (right click on its row).
    func actionMenu(for id: UUID) -> NSMenu? {
        guard let item = history.item(id: id) else { return nil }
        PreviewPanel.shared.hide()
        let isLatest = history.items.first?.id == id
        let m = menuBuilder.contextMenu(for: item, target: self, actions: .init(
            paste: #selector(historyChosen(_:)), pastePlain: #selector(historyChosenPlain(_:)),
            copyOnly: #selector(historyCopied(_:)), transform: #selector(historyTransformed(_:)),
            pin: #selector(historyPinned(_:)), reveal: #selector(historyRevealed(_:)), delete: #selector(historyDeleted(_:))),
            latestMods: isLatest ? settings.latestActionModifiers : nil)
        m.delegate = self
        m.title = Self.actionMenuTitle
        return m
    }
    private static let actionMenuTitle = "keepit.actions"

    /// Context menu: put the item on the clipboard without pasting.
    @objc private func historyCopied(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID, let item = history.item(id: id) else { return }
        history.touch(item)
        Paster.paste(item, into: nil, monitor: monitor, settings: settings, sendKey: false)
    }

    /// Context menu: open the Viewer with the item selected.
    @objc private func historyRevealed(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        openViewer()
        viewer?.reveal(historyId: id)
    }

    /// Context menu "Paste as": paste a transformed copy of the item (UPPERCASE, single line, …).
    @objc private func historyTransformed(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let choice = sender.representedObject as? MenuBuilder.TransformChoice,
              let item = history.items.first(where: { $0.id == choice.id }),
              let out = item.transformed(choice.transform) else { return }
        Paster.paste(out, into: pasteTarget, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
        nudgeAccessibilityIfNeeded()
    }

    private func chooseHistoryItem(_ sender: NSMenuItem, plainText: Bool) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID,
              let item = history.items.first(where: { $0.id == id }) else { return }
        history.touch(item)
        Paster.paste(item, into: pasteTarget, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect, plainText: plainText)
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
                Paster.openAccessibilitySettings()
            }
            self?.pasteTarget?.activate(options: [])
        }
    }

    @objc private func templateChosen(_ sender: NSMenuItem) {
        menuSelectionMade = true
        guard let id = sender.representedObject as? UUID,
              let node = templates.root.find(id: id), let clip = node.clip else { return }
        pasteTemplate(clip, named: node.displayName, into: pasteTarget)
        nudgeAccessibilityIfNeeded()
    }


    /// Paste a template; text templates with `{placeholders}` are expanded first (asking for `{input:…}` values).
    func pasteTemplate(_ clip: ClipItem, named name: String, into target: NSRunningApplication?) {
        guard !isLocked else { NSSound.beep(); return }
        let text: String, prompts: [Snippets.Prompt]
        switch Snippets.pasteRoute(for: clip) {
        case .verbatim:
            Paster.paste(clip, into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
            return
        case .unescapeOnly(let unescaped):
            // Only the plain text changes; RTF/HTML and every other format go with it (not setText, which drops them).
            var out = clip
            out.setData(Data(unescaped.utf8), for: ClipItem.Format.text)
            Paster.paste(out, into: target, monitor: monitor, settings: settings, sendKey: settings.pasteAfterSelect)
            return
        case .expand(let t, let p):
            text = t; prompts = p
        }
        // The template's text is in hand before the {input:}/{choice:} dialog opens, and the dialog
        // runs a modal loop in which Keepit can be locked (hot key, screen-lock delay, lock →
        // unlock). The text belongs to the lock generation it was read in: after the dialog, a
        // different generation — or a lock — means it must not reach the clipboard.
        let generation = lockCount
        var ctx = Snippets.Context()
        ctx.clipboard = { [weak self] n in
            guard let items = self?.history.items, n >= 1, n <= items.count else { return nil }
            return items[n - 1].plainText
        }
        var extra: TimeInterval = 0
        if !prompts.isEmpty {
            guard let answers = SnippetPromptDialog.ask(prompts, templateName: MenuBuilder.parseAmpersand(name).title) else { return }
            guard !isLocked, lockCount == generation, !templates.isPurged else { return }
            ctx.answers = answers
            extra = 0.35      // the modal dialog took the focus; the target app needs a moment to get it back
        }
        let exp = Snippets.expand(text, context: ctx)
        let out = ClipItem.text(exp.text)
        let sendKey = settings.pasteAfterSelect
        Paster.paste(out, into: target, monitor: monitor, settings: settings, sendKey: sendKey, extraDelay: extra)
        if sendKey, Paster.isTrusted(), let back = exp.charsAfterCursor, back > 0 {
            // Move the caret to the {cursor} mark once the paste has landed.
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.pasteDelay + extra + 0.25) {
                Paster.sendKeyStroke(PasteKey(keyCode: UInt16(kVK_LeftArrow), command: false), times: back)
            }
        }
    }

    /// Stop watching the clipboard for a while (typing something sensitive); the icon shows it.
    @objc func pauseRecording() {
        menuSelectionMade = true
        let until = Date().addingTimeInterval(10 * 60)
        pausedUntil = until
        monitor.stop()
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: false) { [weak self] _ in self?.resumeRecording() }
        updateStatusIcon()
    }

    @objc func resumeRecording() {
        menuSelectionMade = true
        pauseTimer?.invalidate()
        pauseTimer = nil
        pausedUntil = nil
        if !isLocked { monitor.start() }
        updateStatusIcon()
    }

    @objc private func clearHistory() {
        menuSelectionMade = true
        let a = NSAlert()
        a.messageText = L("Clear clipboard history?")
        a.informativeText = LF("%d item(s) will be removed. Templates are not affected.", history.items.count)
        a.addButton(withTitle: L("Clear"))
        a.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if AbortableModal.run(a) == .alertFirstButtonReturn, !isLocked { history.clear() }
    }

    @objc private func addClipboardToTemplates() {
        menuSelectionMade = true
        guard let s = NSPasteboard.general.string(forType: .string), !s.isEmpty else {
            NSSound.beep()
            return
        }
        // The pasteboard is read directly here, not through the monitor's size checks: the store's
        // validator is the limit (text ceiling, tree ceilings).
        guard templates.insert(TemplateNode(name: "", text: s), under: templates.root) else {
            Vault.error(LF("Limit reached: at most %d template items, %d levels deep.", Limits.templateMaxCount, Limits.templateMaxDepth))
            return
        }
        viewer?.refresh()
    }

    @objc func openPreferences() {
        menuSelectionMade = true
        if preferencesWindow == nil {
            preferencesWindow = SettingsWindowController(app: self)
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
        Paster.openAccessibilitySettings()
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

    func showAccessibilityAlert() {
        let a = NSAlert()
        a.messageText = L("Keepit needs the Accessibility permission to paste")
        a.informativeText = L("Without it Keepit can still record history and copy items to the clipboard, but it cannot send ⌘V to the active app or place the menu at the text cursor.\n\nSystem Settings → Privacy & Security → Accessibility → enable Keepit.")
        a.addButton(withTitle: L("Open System Settings"))
        a.addButton(withTitle: L("Later"))
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            Paster.openAccessibilitySettings()
        }
    }
}


// MARK: - Automatic backup (docs/BACKUP.md)

extension AppDelegate {
    func setUpBackup() {
        createBackupEngine()
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.backup.runIfDue() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.backup.runIfDue()
        }
        backup.runIfDue()
    }

    /// New engine for the current data directory and settings (launch, and again after Reset…).
    func createBackupEngine() {
        if settings.backupSourceID == nil {
            settings.backupSourceID = UUID().uuidString.lowercased()
            Storage.save(settings, to: Storage.settingsURL, encrypt: false, pretty: true)
        }
        backup = BackupEngine(stateURL: Storage.directory.appendingPathComponent("backup.json"), sourceID: settings.backupSourceID ?? "")
        backup.snapshotProvider = { [weak self] in self?.backupSnapshot() }
        backup.onStateChange = { [weak self] _ in self?.preferencesWindow?.backupStateChanged() }
        history.onChange = { [weak self] in self?.backup.noteChange() }
        templates.onChange = { [weak self] in self?.backup.noteChange() }
        configureBackup()
    }

    func configureBackup() {
        backup.keepCount = settings.backupKeepCount
        backup.label = settings.backupLabel
        backup.sourceID = settings.backupSourceID ?? ""
        if settings.backupEnabled, Vault.isEnabled, let bm = settings.backupBookmark {
            let dest = BookmarkDestination(bookmark: bm)
            dest.onBookmarkRefreshed = { [weak self, weak dest] fresh in
                DispatchQueue.main.async {                   // settings are main-thread state
                    guard let self, let dest, self.backup.destination === dest else { return }   // still the current folder?
                    var s = self.settings; s.backupBookmark = fresh
                    self.settings = s                       // no apply(): nothing else changed, avoid a reconfigure loop
                    Storage.save(s, to: Storage.settingsURL, encrypt: false, pretty: true)
                }
            }
            backup.destination = dest
        } else {
            backup.destination = nil
        }
    }

    /// One consistent state for a backup, or nil when there is nothing to back up with (locked, no vault).
    func backupSnapshot() -> BackupEngine.Snapshot? {
        guard !isLocked, Vault.isEnabled, let key = Storage.key,
              let header = Vault.backupHeader(app: "Keepit \(AppInfo.version)"),
              let tree = try? Storage.encoder.encode(templates.root) else { return nil }
        return BackupEngine.Snapshot(history: history.items, templatesJSON: tree, settings: settings.forBackup,
                                     header: header, dataKey: key, credentialsStamp: BackupEngine.credentialsStamp(header))
    }
}
