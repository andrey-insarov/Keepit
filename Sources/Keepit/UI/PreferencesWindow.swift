import AppKit

/// Flexible empty view for NSStackView layouts.
final class Spacer: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 1), for: .horizontal)
        setContentHuggingPriority(NSLayoutConstraint.Priority(rawValue: 1), for: .vertical)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
}

/// Options window. Edits a copy of Settings and applies on "Save".
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private unowned let app: AppDelegate
    private var draft: Settings

    private let historyMax   = NSTextField()
    private let imageMax     = NSTextField()
    private let titleLength  = NSTextField()
    private let thumbSize    = NSTextField()
    private let pollInterval = NSTextField()
    private let pasteDelay   = NSTextField()
    private let showThumbs   = NSButton(checkboxWithTitle: L("Show image thumbnails in menu"), target: nil, action: nil)
    private let showPreview  = NSButton(checkboxWithTitle: L("Show preview panel"), target: nil, action: nil)
    private let showSource   = NSButton(checkboxWithTitle: L("Show source app icons"), target: nil, action: nil)
    private let showTips     = NSButton(checkboxWithTitle: L("Show tooltips with item contents"), target: nil, action: nil)
    private let numberItems  = NSButton(checkboxWithTitle: L("Number items"), target: nil, action: nil)
    private let searchMenu   = NSButton(checkboxWithTitle: L("Search field in the history menu"), target: nil, action: nil)
    private let pasteAfter   = NSButton(checkboxWithTitle: L("Paste into the active app after choosing"), target: nil, action: nil)
    private let showAtCaret  = NSButton(checkboxWithTitle: L("Open menu at text cursor when possible"), target: nil, action: nil)
    private let maxAge       = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Choices for "Forget items older than": seconds (0 = never).
    private static let ages: [(TimeInterval, String)] = [
        (0, L("Never")), (3600, L("1 hour")), (6 * 3600, L("6 hours")), (86400, L("1 day")),
        (7 * 86400, L("1 week")), (30 * 86400, L("30 days")),
    ]
    private let overlap      = NSButton(checkboxWithTitle: L("Remove duplicates"), target: nil, action: nil)
    private let saveHistory  = NSButton(checkboxWithTitle: L("Save history on quit, restore on start"), target: nil, action: nil)
    private let concealed    = NSButton(checkboxWithTitle: L("Ignore concealed clipboard data"), target: nil, action: nil)
    private let loginItem    = NSButton(checkboxWithTitle: L("Launch at login"), target: nil, action: nil)
    private let protect      = NSButton(checkboxWithTitle: L("Require password at launch"), target: nil, action: nil)
    private let changePw     = NSButton(title: L("Change Password…"), target: nil, action: nil)
    private let lockScreen   = NSButton(checkboxWithTitle: L("Lock when the screen locks or the Mac sleeps"), target: nil, action: nil)
    private let touchID      = NSButton(checkboxWithTitle: L("Unlock with Touch ID"), target: nil, action: nil)
    private let touchIDChange = NSButton(checkboxWithTitle: L("Allow changing the password with Touch ID"), target: nil, action: nil)
    private let newPhrase    = NSButton(title: L("New Recovery Phrase…"), target: nil, action: nil)
    private let uninstall    = NSButton(title: L("Delete Keepit and All Data…"), target: nil, action: nil)
    private let historyHK    = HotKeyRecorderView(frame: .zero)
    private let templateHK   = HotKeyRecorderView(frame: .zero)
    private let ignoreScroll = NSTextView.scrollableTextView()
    private var ignoreApps: NSTextView { ignoreScroll.documentView as! NSTextView }

    init(app: AppDelegate) {
        self.app = app
        self.draft = app.settings
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = LF("Keepit %@ — Preferences", AppInfo.version)
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self
        buildUI()
        load(draft)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        draft = app.settings
        load(draft)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: UI

    private func labeled(_ text: String, _ view: NSView) -> [NSView] {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return [l, view]
    }

    /// Two label/field pairs on one grid row: `label1 [field1]   label2 [field2]`.
    private func pair(_ text1: String, _ view1: NSView, _ text2: String, _ view2: NSView) -> [NSView] {
        let l1 = NSTextField(labelWithString: text1)
        l1.alignment = .right
        let l2 = NSTextField(labelWithString: text2)
        let row = NSStackView(views: [view1, l2, view2])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 6
        row.setCustomSpacing(18, after: view1)
        return [l1, row]
    }

    private func numField(_ f: NSTextField, width: CGFloat = 70) -> NSTextField {
        f.alignment = .right
        f.widthAnchor.constraint(equalToConstant: width).isActive = true
        return f
    }

    private func header(_ text: String) -> [NSView] {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        return [NSView(), l]
    }

    private func makeGrid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 160
        grid.translatesAutoresizingMaskIntoConstraints = false
        return grid
    }

    /// `view` followed by a small (?) button that opens a popover with `text`.
    private func withHelp(_ view: NSView, _ text: String) -> NSView {
        let b = NSButton(title: "", target: self, action: #selector(helpTapped(_:)))
        b.bezelStyle = .helpButton
        b.controlSize = .small
        b.toolTip = text
        b.identifier = NSUserInterfaceItemIdentifier(text)
        let row = NSStackView(views: [view, b])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        return row
    }

    @objc private func helpTapped(_ sender: NSButton) {
        guard let text = sender.identifier?.rawValue else { return }
        let pop = NSPopover()
        pop.behavior = .transient
        let vc = NSViewController()
        let label = NSTextField(wrappingLabelWithString: text)
        label.preferredMaxLayoutWidth = 320
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        let v = NSView()
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -10),
            v.widthAnchor.constraint(lessThanOrEqualToConstant: 344),
        ])
        vc.view = v
        pop.contentViewController = vc
        pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    /// Wrap a grid into a tab page with standard margins.
    private func page(_ title: String, symbol: String, grid: NSGridView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let v = NSView()
        v.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: v.topAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor, constant: -16),
        ])
        item.view = v
        return item
    }

    private let tabs = NSTabView()

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // --- General
        let general = makeGrid([
            [NSView(), loginItem],
            [NSView(), saveHistory],
            header(L("Hot keys & paste")),
            pair(L("History menu:"), historyHK, L("Template menu:"), templateHK),
            [NSView(), pasteAfter],
            labeled(L("Paste delay (s):"), numField(pasteDelay)),
            [NSView(), showAtCaret],
        ])

        // --- History
        let ignoredPlaceholder = NSView()
        let ignoredLabel = NSTextField(labelWithString: L("Ignored apps:"))
        ignoredLabel.alignment = .right
        let historyGrid = makeGrid([
            pair(L("Text & file items:"), numField(historyMax), L("Image items:"), numField(imageMax)),
            labeled(L("Forget items older than:"), maxAge),
            [NSView(), withHelp(overlap, L("When the same content is copied again, the older copy is removed and the new one goes to the top."))],
            [NSView(), withHelp(concealed, L("Password managers mark what they copy as concealed; such items are never recorded. Known password managers are ignored in any case."))],
            [ignoredLabel, withHelp(ignoredPlaceholder, L("Bundle identifiers, one per line, e.g. com.example.app. Nothing copied in these apps is recorded. Known password managers are always ignored."))],
        ])
        let scroll = ignoreScroll
        scroll.focusRingType = .none
        ignoreApps.focusRingType = .none
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        ignoreApps.isRichText = false
        ignoreApps.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 96).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 300).isActive = true
        // The placeholder sits inside the help row; swap it for the scroll view.
        if let row = ignoredPlaceholder.superview as? NSStackView {
            row.alignment = .top
            row.insertArrangedSubview(scroll, at: 0)
            row.removeArrangedSubview(ignoredPlaceholder)
            ignoredPlaceholder.removeFromSuperview()
        }
        historyGrid.cell(for: ignoredLabel)?.yPlacement = .top

        // --- Menu
        let modifiers = NSTextField(labelWithString: L("Modifier keys while choosing an item"))
        let menuGrid = makeGrid([
            [NSView(), withHelp(searchMenu, L("A search field at the top of the history menu: typing filters the list in place, Return pastes the first match. Item shortcuts then become ⌘1–⌘0 instead of 1-9/0/A-Z."))],
            [NSView(), withHelp(numberItems, L("Prefix items with 1-9, 0, A-Z; pressing the key pastes the item without the mouse."))],
            [NSView(), withHelp(showPreview, L("Hovering a history item shows the full image or the first lines of text in a panel beside the menu. Tooltips are not shown while this is on."))],
            [NSView(), showTips],
            [NSView(), showSource],
            [NSView(), showThumbs],
            pair(L("Title length (chars):"), numField(titleLength), L("Thumbnail height (px):"), numField(thumbSize)),
            [NSView(), withHelp(modifiers, L("Hold ⇧ while choosing a history item to paste it as plain text (formatting stripped), ⌥ to add it to Templates, ⌃ to delete it."))],
        ])
        modifiers.textColor = .secondaryLabelColor

        // --- Security (+ backup)
        let exportBtn = NSButton(title: L("Export Backup…"), target: self, action: #selector(exportTapped))
        let importBtn = NSButton(title: L("Import Backup…"), target: self, action: #selector(importTapped))
        let backupRow = NSStackView(views: [exportBtn, importBtn])
        backupRow.orientation = .horizontal
        backupRow.spacing = 8
        let security = makeGrid([
            [NSView(), withHelp(protect, L("History and templates are stored AES-256 encrypted; the key is derived from the password and asked for every time Keepit starts."))],
            [NSView(), changePw],
            [NSView(), withHelp(touchID, L("Unlock with a fingerprint instead of typing the password. The password always remains as fallback."))],
            [NSView(), withHelp(touchIDChange, L("Let Touch ID stand in for the current password when changing it. Off = always type the current password first."))],
            [NSView(), withHelp(lockScreen, L("Wipes the key from memory and unloads history and templates when the screen locks or the Mac sleeps; unlock with Touch ID or the password afterwards."))],
            [NSView(), withHelp(newPhrase, L("Issues a new 24-word phrase and invalidates the old one. Use it if the printed sheet was lost or seen by someone; you will then be offered to change the password too."))],
            header(L("Backup")),
            [NSView(), withHelp(backupRow, L("One password-encrypted .keepit file with history, templates and preferences — for moving to another Mac or between the App Store and direct editions."))],
        ])
        changePw.target = self
        changePw.action = #selector(changePasswordTapped)
        newPhrase.target = self
        newPhrase.action = #selector(newPhraseTapped)

        // --- Advanced
        let reveal = NSButton(title: L("Open Data Folder"), target: self, action: #selector(revealData))
        let advanced = makeGrid([
            labeled(L("Poll interval (s):"), numField(pollInterval)),
            [NSView(), reveal],
            header(L("Danger zone")),
            [NSView(), withHelp(uninstall, L("⚠️ Removes the app together with its history, templates, settings, Touch ID key and permissions. Asks for your password or Touch ID and a typed confirmation. Export a backup first if you may want the data back."))],
        ])
        uninstall.target = self
        uninstall.action = #selector(uninstallTapped)
        uninstall.contentTintColor = .systemRed

        tabs.tabViewType = .topTabsBezelBorder
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.addTabViewItem(page(L("General"), symbol: "gearshape", grid: general))
        tabs.addTabViewItem(page(L("History"), symbol: "clock", grid: historyGrid))
        tabs.addTabViewItem(page(L("Menu"), symbol: "filemenu.and.selection", grid: menuGrid))
        tabs.addTabViewItem(page(L("Security"), symbol: "lock", grid: security))
        tabs.addTabViewItem(page(L("Advanced"), symbol: "wrench.and.screwdriver", grid: advanced))

        let save = NSButton(title: L("Save"), target: self, action: #selector(saveTapped))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancelTapped))
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [Spacer(), cancel, save])
        buttons.orientation = .horizontal
        buttons.distribution = .fill
        buttons.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(tabs)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            tabs.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        historyHK.onChange = { [weak self] hk in self?.draft.historyHotKey = hk }
        templateHK.onChange = { [weak self] hk in self?.draft.templateHotKey = hk }

        // One fixed size for all tabs: the tallest page decides.
        let tallest = [general, historyGrid, menuGrid, security, advanced].map { $0.fittingSize.height }.max() ?? 300
        let height = tallest + 32 + 40 /* tab bar */ + 12 + buttons.fittingSize.height + 12 + 16
        window?.setContentSize(NSSize(width: 540, height: height))
    }

    // MARK: Load / collect

    private func load(_ s: Settings) {
        historyMax.integerValue = s.historyMax
        imageMax.integerValue = s.historyImageMax
        titleLength.integerValue = s.titleLength
        thumbSize.integerValue = s.thumbnailSize
        pollInterval.stringValue = String(format: "%.2f", s.pollInterval)
        pasteDelay.stringValue = String(format: "%.2f", s.pasteDelay)
        showThumbs.state = s.showThumbnails ? .on : .off
        showTips.state = s.showTooltips ? .on : .off
        showPreview.state = s.showPreview ? .on : .off
        showSource.state = s.showSourceIcons ? .on : .off
        numberItems.state = s.numberItems ? .on : .off
        searchMenu.state = s.searchInMenu ? .on : .off
        pasteAfter.state = s.pasteAfterSelect ? .on : .off
        showAtCaret.state = s.showAtCaret ? .on : .off
        overlap.state = s.overlapCheck ? .on : .off
        if maxAge.numberOfItems == 0 { for (_, title) in Self.ages { maxAge.addItem(withTitle: title) } }
        maxAge.selectItem(at: Self.ages.firstIndex { $0.0 == s.historyMaxAge } ?? 0)
        saveHistory.state = s.historySave ? .on : .off
        concealed.state = s.ignoreConcealed ? .on : .off
        loginItem.state = s.launchAtLogin ? .on : .off
        protect.state = Vault.isEnabled ? .on : .off
        changePw.isEnabled = Vault.isEnabled
        lockScreen.state = s.lockWithScreen ? .on : .off
        touchID.state = s.biometricUnlock ? .on : .off
        touchID.isEnabled = Vault.isEnabled
        protect.target = self
        protect.action = #selector(protectToggled)
        touchIDChange.state = s.biometricPasswordChange ? .on : .off
        touchIDChange.isEnabled = touchID.isEnabled
        newPhrase.isEnabled = Vault.isEnabled
        if !BiometricUnlock.hasSensor { touchID.title = L("Unlock with Touch ID (no Touch ID on this Mac)") }
        historyHK.hotKey = s.historyHotKey
        templateHK.hotKey = s.templateHotKey
        ignoreApps.string = s.ignoreApps.joined(separator: "\n")
    }

    private func collect() -> Settings {
        var s = draft
        s.historyMax = max(1, historyMax.integerValue)
        s.historyImageMax = max(1, imageMax.integerValue)
        s.titleLength = max(10, titleLength.integerValue)
        s.thumbnailSize = max(16, min(128, thumbSize.integerValue))
        s.pollInterval = max(0.1, Double(pollInterval.stringValue.replacingOccurrences(of: ",", with: ".")) ?? s.pollInterval)
        s.pasteDelay = max(0, Double(pasteDelay.stringValue.replacingOccurrences(of: ",", with: ".")) ?? s.pasteDelay)
        s.showThumbnails = showThumbs.state == .on
        s.showTooltips = showTips.state == .on
        s.showPreview = showPreview.state == .on
        s.showSourceIcons = showSource.state == .on
        s.numberItems = numberItems.state == .on
        s.searchInMenu = searchMenu.state == .on
        s.pasteAfterSelect = pasteAfter.state == .on
        s.showAtCaret = showAtCaret.state == .on
        s.overlapCheck = overlap.state == .on
        s.historyMaxAge = Self.ages[max(0, maxAge.indexOfSelectedItem)].0
        s.historySave = saveHistory.state == .on
        s.ignoreConcealed = concealed.state == .on
        s.launchAtLogin = loginItem.state == .on
        s.lockWithScreen = lockScreen.state == .on
        s.biometricUnlock = touchID.state == .on && (Vault.isEnabled || protect.state == .on)
        s.biometricPasswordChange = touchIDChange.state == .on
        s.ignoreApps = ignoreApps.string
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        s.clamp()
        return s
    }

    // MARK: Actions

    @objc private func saveTapped() {
        window?.makeFirstResponder(nil)   // commit any text field being edited
        app.apply(settings: collect())

        let wantProtection = protect.state == .on
        if wantProtection != Vault.isEnabled {
            let ok = wantProtection ? app.enableProtection() : app.disableProtection()
            if !ok {
                protect.state = Vault.isEnabled ? .on : .off
                changePw.isEnabled = Vault.isEnabled
                return   // keep the window open so the user sees the state didn't change
            }
        }
        window?.close()
    }

    /// Turning protection on in this window should let the user pick Touch ID in the same go.
    @objc private func protectToggled() {
        let turningOn = protect.state == .on && !Vault.isEnabled
        touchID.isEnabled = Vault.isEnabled || protect.state == .on
        touchIDChange.isEnabled = touchID.isEnabled
        if turningOn && touchID.isEnabled { touchID.state = .on; touchIDChange.state = .on }
    }

    @objc private func changePasswordTapped() {
        app.changePassword()
    }

    @objc private func newPhraseTapped() {
        app.regenerateRecoveryPhrase()
    }

    @objc private func uninstallTapped() {
        app.uninstallRequested()
    }

    @objc private func cancelTapped() {
        window?.close()
    }

    @objc private func exportTapped() { app.exportBackup() }
    @objc private func importTapped() { app.importBackup() }

    @objc private func revealData() {
        NSWorkspace.shared.activateFileViewerSelecting([Storage.settingsURL])
    }
}
