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
    private let showTips     = NSButton(checkboxWithTitle: L("Show tooltips with item contents"), target: nil, action: nil)
    private let numberItems  = NSButton(checkboxWithTitle: L("Number items (press 1-9, 0, A-Z to pick)"), target: nil, action: nil)
    private let plainHint    = NSTextField(wrappingLabelWithString: L("Hold ⇧ while choosing a history item to paste it as plain text (formatting stripped); hold ⌥ to add it to Templates instead."))
    private let searchMenu   = NSButton(checkboxWithTitle: L("Search field in the history menu (type to filter; shortcuts become ⌘1–⌘0)"), target: nil, action: nil)
    private let pasteAfter   = NSButton(checkboxWithTitle: L("Paste into the active app after choosing"), target: nil, action: nil)
    private let showAtCaret  = NSButton(checkboxWithTitle: L("Open menu at text cursor when possible"), target: nil, action: nil)
    private let overlap      = NSButton(checkboxWithTitle: L("Remove duplicates (keep newest)"), target: nil, action: nil)
    private let saveHistory  = NSButton(checkboxWithTitle: L("Save history on quit, restore on start"), target: nil, action: nil)
    private let concealed    = NSButton(checkboxWithTitle: L("Ignore concealed clipboard data (password managers)"), target: nil, action: nil)
    private let loginItem    = NSButton(checkboxWithTitle: L("Launch at login"), target: nil, action: nil)
    private let protect      = NSButton(checkboxWithTitle: L("Require password at launch, encrypt history & templates"), target: nil, action: nil)
    private let changePw     = NSButton(title: L("Change Password…"), target: nil, action: nil)
    private let lockScreen   = NSButton(checkboxWithTitle: L("Lock Keepit (wipe key, unload data) when the screen locks or the Mac sleeps"), target: nil, action: nil)
    private let touchID      = NSButton(checkboxWithTitle: L("Unlock with Touch ID (password remains as fallback)"), target: nil, action: nil)
    private let touchIDChange = NSButton(checkboxWithTitle: L("Allow changing the password with Touch ID (off = always require the current password)"), target: nil, action: nil)
    private let newPhrase    = NSButton(title: L("New Recovery Phrase…"), target: nil, action: nil)
    private let phraseHint   = NSTextField(wrappingLabelWithString: L("Issues a new 24-word phrase and invalidates the old one. Use it if the printed sheet was lost or seen by someone; you will then be offered to change the password too."))
    private let uninstall    = NSButton(title: L("Delete Keepit and All Data…"), target: nil, action: nil)
    private let uninstallHint = NSTextField(wrappingLabelWithString: L("⚠️ Removes the app together with its history, templates, settings, Touch ID key and permissions. Asks for your password or Touch ID and a typed confirmation. Export a backup first if you may want the data back."))
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

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let ignoredPlaceholder = NSView()

        let grid = NSGridView(views: [
            header(L("History")),
            pair(L("Text & file items:"), numField(historyMax), L("Image items:"), numField(imageMax)),
            [NSView(), overlap],
            [NSView(), saveHistory],
            [NSView(), concealed],

            header(L("Menu")),
            pair(L("Title length (chars):"), numField(titleLength), L("Thumbnail height (px):"), numField(thumbSize)),
            [NSView(), showThumbs],
            [NSView(), showTips],
            [NSView(), numberItems],
            [NSView(), searchMenu],
            [NSView(), plainHint],
            [NSView(), showAtCaret],

            header(L("Hot keys & paste")),
            pair(L("History menu:"), historyHK, L("Template menu:"), templateHK),
            [NSView(), pasteAfter],
            pair(L("Paste delay (s):"), numField(pasteDelay), L("Poll interval (s):"), numField(pollInterval)),

            header(L("Ignored apps (bundle IDs, one per line; known password managers are always ignored)")),
            [ignoredPlaceholder, NSView()],
            header(L("General")),
            [NSView(), loginItem],
            header(L("Security")),
            [NSView(), protect],
            [NSView(), changePw],
            [NSView(), lockScreen],
            [NSView(), touchID],
            [NSView(), touchIDChange],
            [NSView(), newPhrase],
            [NSView(), phraseHint],
            header(L("Danger zone")),
            [NSView(), uninstall],
            [NSView(), uninstallHint],
        ])
        uninstall.target = self
        uninstall.action = #selector(uninstallTapped)
        uninstall.contentTintColor = .systemRed
        uninstallHint.textColor = .secondaryLabelColor
        uninstallHint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        uninstallHint.preferredMaxLayoutWidth = 320
        changePw.target = self
        changePw.action = #selector(changePasswordTapped)
        newPhrase.target = self
        newPhrase.action = #selector(newPhraseTapped)
        plainHint.textColor = .secondaryLabelColor
        plainHint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        plainHint.preferredMaxLayoutWidth = 320
        phraseHint.textColor = .secondaryLabelColor
        phraseHint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        phraseHint.preferredMaxLayoutWidth = 320
        grid.rowSpacing = 6
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 170
        grid.translatesAutoresizingMaskIntoConstraints = false

        // Ignored apps text view occupies its own row spanning both columns.
        let scroll = ignoreScroll
        scroll.focusRingType = .none
        ignoreApps.focusRingType = .none
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        ignoreApps.isRichText = false
        ignoreApps.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 80).isActive = true
        // Replace the placeholder row with the scroll view spanning both columns.
        let ignoredRowIndex = grid.index(of: grid.cell(for: ignoredPlaceholder)!.row!)
        grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2), verticalRange: NSRange(location: ignoredRowIndex, length: 1))
        grid.cell(atColumnIndex: 0, rowIndex: ignoredRowIndex).contentView = scroll

        let save = NSButton(title: L("Save"), target: self, action: #selector(saveTapped))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancelTapped))
        cancel.keyEquivalent = "\u{1b}"
        let reveal = NSButton(title: L("Open Data Folder"), target: self, action: #selector(revealData))
        let buttons = NSStackView(views: [reveal, Spacer(), cancel, save])
        buttons.orientation = .horizontal
        buttons.distribution = .fill
        buttons.translatesAutoresizingMaskIntoConstraints = false

        // The grid lives in a scroll view so the window still fits small displays (the form is tall).
        let gridScroll = NSScrollView()
        gridScroll.drawsBackground = false
        gridScroll.hasVerticalScroller = true
        gridScroll.borderType = .noBorder
        gridScroll.focusRingType = .none
        gridScroll.translatesAutoresizingMaskIntoConstraints = false
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(grid)
        gridScroll.documentView = doc
        content.addSubview(gridScroll)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            gridScroll.topAnchor.constraint(equalTo: content.topAnchor),
            gridScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            gridScroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            doc.widthAnchor.constraint(equalTo: gridScroll.contentView.widthAnchor),
            grid.topAnchor.constraint(equalTo: doc.topAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -8),
            buttons.topAnchor.constraint(equalTo: gridScroll.bottomAnchor, constant: 8),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        historyHK.onChange = { [weak self] hk in self?.draft.historyHotKey = hk }
        templateHK.onChange = { [weak self] hk in self?.draft.templateHotKey = hk }

        // Size the window to its content, but never taller than the screen; the grid scrolls then.
        let wanted = grid.fittingSize.height + 24 + buttons.fittingSize.height + 8 + 16
        let maxHeight = (window?.screen ?? NSScreen.main).map { $0.visibleFrame.height - 60 } ?? wanted
        window?.setContentSize(NSSize(width: 520, height: min(wanted, maxHeight)))
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
        numberItems.state = s.numberItems ? .on : .off
        searchMenu.state = s.searchInMenu ? .on : .off
        pasteAfter.state = s.pasteAfterSelect ? .on : .off
        showAtCaret.state = s.showAtCaret ? .on : .off
        overlap.state = s.overlapCheck ? .on : .off
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
        s.numberItems = numberItems.state == .on
        s.searchInMenu = searchMenu.state == .on
        s.pasteAfterSelect = pasteAfter.state == .on
        s.showAtCaret = showAtCaret.state == .on
        s.overlapCheck = overlap.state == .on
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

    @objc private func revealData() {
        NSWorkspace.shared.activateFileViewerSelecting([Storage.settingsURL])
    }
}


/// Top-left origin so the grid starts at the top of the scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
