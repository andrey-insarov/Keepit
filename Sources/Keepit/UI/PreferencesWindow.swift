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
    private let titleLength  = NSTextField()
    private let thumbSize    = NSTextField()
    private let pollInterval = NSTextField()
    private let pasteDelay   = NSTextField()
    private let showThumbs   = NSButton(checkboxWithTitle: "Show image thumbnails in menu", target: nil, action: nil)
    private let showTips     = NSButton(checkboxWithTitle: "Show tooltips with item contents", target: nil, action: nil)
    private let numberItems  = NSButton(checkboxWithTitle: "Number items (press 1-9, 0, A-Z to pick)", target: nil, action: nil)
    private let pasteAfter   = NSButton(checkboxWithTitle: "Paste into the active app after choosing", target: nil, action: nil)
    private let showAtCaret  = NSButton(checkboxWithTitle: "Open menu at text cursor when possible", target: nil, action: nil)
    private let overlap      = NSButton(checkboxWithTitle: "Remove duplicates (keep newest)", target: nil, action: nil)
    private let saveHistory  = NSButton(checkboxWithTitle: "Save history on quit, restore on start", target: nil, action: nil)
    private let concealed    = NSButton(checkboxWithTitle: "Ignore concealed clipboard data (password managers)", target: nil, action: nil)
    private let loginItem    = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let protect      = NSButton(checkboxWithTitle: "Require password at launch, encrypt history & templates", target: nil, action: nil)
    private let changePw     = NSButton(title: "Change Password…", target: nil, action: nil)
    private let lockScreen   = NSButton(checkboxWithTitle: "Lock Keepit (wipe key, unload data) when the screen locks or the Mac sleeps", target: nil, action: nil)
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
        w.title = "Keepit \(AppInfo.version) — Preferences"
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
            header("History"),
            labeled("Max items:", numField(historyMax)),
            [NSView(), overlap],
            [NSView(), saveHistory],
            [NSView(), concealed],
            labeled("Poll interval (s):", numField(pollInterval)),

            header("Menu"),
            labeled("Title length (chars):", numField(titleLength)),
            labeled("Thumbnail size (px):", numField(thumbSize)),
            [NSView(), showThumbs],
            [NSView(), showTips],
            [NSView(), numberItems],
            [NSView(), showAtCaret],

            header("Hot keys & paste"),
            labeled("History menu:", historyHK),
            labeled("Template menu:", templateHK),
            [NSView(), pasteAfter],
            labeled("Paste delay (s):", numField(pasteDelay)),

            header("Ignored apps (bundle IDs, one per line)"),
            [ignoredPlaceholder, NSView()],
            header("General"),
            [NSView(), loginItem],
            header("Security"),
            [NSView(), protect],
            [NSView(), changePw],
            [NSView(), lockScreen],
        ])
        changePw.target = self
        changePw.action = #selector(changePasswordTapped)
        grid.rowSpacing = 6
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 170
        grid.translatesAutoresizingMaskIntoConstraints = false

        // Ignored apps text view occupies its own row spanning both columns.
        let scroll = ignoreScroll
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

        let save = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancel.keyEquivalent = "\u{1b}"
        let reveal = NSButton(title: "Open Data Folder", target: self, action: #selector(revealData))
        let buttons = NSStackView(views: [reveal, Spacer(), cancel, save])
        buttons.orientation = .horizontal
        buttons.distribution = .fill
        buttons.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(grid)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: grid.bottomAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])

        historyHK.onChange = { [weak self] hk in self?.draft.historyHotKey = hk }
        templateHK.onChange = { [weak self] hk in self?.draft.templateHotKey = hk }

        // Size the window to its content.
        let height = grid.fittingSize.height + buttons.fittingSize.height + 16 * 3
        window?.setContentSize(NSSize(width: 520, height: height))
    }

    // MARK: Load / collect

    private func load(_ s: Settings) {
        historyMax.integerValue = s.historyMax
        titleLength.integerValue = s.titleLength
        thumbSize.integerValue = s.thumbnailSize
        pollInterval.stringValue = String(format: "%.2f", s.pollInterval)
        pasteDelay.stringValue = String(format: "%.2f", s.pasteDelay)
        showThumbs.state = s.showThumbnails ? .on : .off
        showTips.state = s.showTooltips ? .on : .off
        numberItems.state = s.numberItems ? .on : .off
        pasteAfter.state = s.pasteAfterSelect ? .on : .off
        showAtCaret.state = s.showAtCaret ? .on : .off
        overlap.state = s.overlapCheck ? .on : .off
        saveHistory.state = s.historySave ? .on : .off
        concealed.state = s.ignoreConcealed ? .on : .off
        loginItem.state = s.launchAtLogin ? .on : .off
        protect.state = Vault.isEnabled ? .on : .off
        changePw.isEnabled = Vault.isEnabled
        lockScreen.state = s.lockWithScreen ? .on : .off
        historyHK.hotKey = s.historyHotKey
        templateHK.hotKey = s.templateHotKey
        ignoreApps.string = s.ignoreApps.joined(separator: "\n")
    }

    private func collect() -> Settings {
        var s = draft
        s.historyMax = max(1, historyMax.integerValue)
        s.titleLength = max(10, titleLength.integerValue)
        s.thumbnailSize = max(16, min(128, thumbSize.integerValue))
        s.pollInterval = max(0.1, Double(pollInterval.stringValue.replacingOccurrences(of: ",", with: ".")) ?? s.pollInterval)
        s.pasteDelay = max(0, Double(pasteDelay.stringValue.replacingOccurrences(of: ",", with: ".")) ?? s.pasteDelay)
        s.showThumbnails = showThumbs.state == .on
        s.showTooltips = showTips.state == .on
        s.numberItems = numberItems.state == .on
        s.pasteAfterSelect = pasteAfter.state == .on
        s.showAtCaret = showAtCaret.state == .on
        s.overlapCheck = overlap.state == .on
        s.historySave = saveHistory.state == .on
        s.ignoreConcealed = concealed.state == .on
        s.launchAtLogin = loginItem.state == .on
        s.lockWithScreen = lockScreen.state == .on
        s.ignoreApps = ignoreApps.string
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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

    @objc private func changePasswordTapped() {
        app.changePassword()
    }

    @objc private func cancelTapped() {
        window?.close()
    }

    @objc private func revealData() {
        NSWorkspace.shared.activateFileViewerSelecting([Storage.settingsURL])
    }
}
