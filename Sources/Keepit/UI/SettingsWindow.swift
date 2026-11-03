import AppKit
import Carbon.HIToolbox
import UniformTypeIdentifiers

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

/// Settings window, laid out the way macOS does it: a toolbar of panes, the window resizes to the
/// pane, every change applies the moment it is made (no Save / Cancel), ⌘W or Esc closes.
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate,
                                      NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private unowned let app: AppDelegate
    /// True while controls are being filled from the settings, so their actions do not write back.
    private var loading = false

    // MARK: Controls

    private let loginItem    = NSButton(checkboxWithTitle: L("Launch at login"), target: nil, action: nil)
    private let updateCheck  = NSButton(checkboxWithTitle: L("Check for updates automatically"), target: nil, action: nil)
    private let saveHistory  = NSButton(checkboxWithTitle: L("Save history on quit, restore on start"), target: nil, action: nil)
    private let pasteAfter   = NSButton(checkboxWithTitle: L("Paste into the active app after choosing"), target: nil, action: nil)
    private let showAtCaret  = NSButton(checkboxWithTitle: L("Open menu at text cursor when possible"), target: nil, action: nil)
    private let pasteDelay   = NSTextField()

    private let historyHK    = HotKeyRecorderView(frame: .zero)
    private let templateHK   = HotKeyRecorderView(frame: .zero)
    private let previousHK   = HotKeyRecorderView(frame: .zero)
    private let numbersHK    = HotKeyRecorderView(frame: .zero)
    private let latestHK     = HotKeyRecorderView(frame: .zero)
    private let viewerHK     = HotKeyRecorderView(frame: .zero)
    private let prefsHK      = HotKeyRecorderView(frame: .zero)
    private let clearHK      = HotKeyRecorderView(frame: .zero)
    private let pauseHK      = HotKeyRecorderView(frame: .zero)
    private let lockHK       = HotKeyRecorderView(frame: .zero)
    private let quitHK       = HotKeyRecorderView(frame: .zero)
    private let shortcutStatus = NSTextField(wrappingLabelWithString: "")

    private let queueHK      = HotKeyRecorderView(frame: .zero)
    private let queuePasteHK = HotKeyRecorderView(frame: .zero)
    private let queueAllHK   = HotKeyRecorderView(frame: .zero)
    private let queueTimeout = NSTextField()
    private let queueSep     = NSPopUpButton(frame: .zero, pullsDown: false)
    private let queueStatus  = NSTextField(wrappingLabelWithString: "")
    private static let separators: [(String, String)] = [("\n", L("New line")), ("\t", L("Tab")), (" ", L("Space")), ("", L("Nothing"))]

    private let historyMax   = NSTextField()
    private let imageMax     = NSTextField()
    private let maxAge       = NSPopUpButton(frame: .zero, pullsDown: false)
    private static let ages: [(TimeInterval, String)] = [
        (0, L("Never")), (3600, L("1 hour")), (6 * 3600, L("6 hours")), (86400, L("1 day")),
        (7 * 86400, L("1 week")), (30 * 86400, L("30 days")),
    ]
    private let overlap      = NSButton(checkboxWithTitle: L("Remove duplicates"), target: nil, action: nil)
    private let concealed    = NSButton(checkboxWithTitle: L("Ignore concealed clipboard data"), target: nil, action: nil)
    private let ignoredTable = NSTableView()
    private var ignoredApps: [String] = []

    private let searchMenu   = NSButton(checkboxWithTitle: L("Search field in the history menu"), target: nil, action: nil)
    private let numberItems  = NSButton(checkboxWithTitle: L("Number items (1–9, 0, A–Z)"), target: nil, action: nil)
    private let showPreview  = NSButton(checkboxWithTitle: L("Show preview panel"), target: nil, action: nil)
    private let showTips     = NSButton(checkboxWithTitle: L("Show tooltips with item contents"), target: nil, action: nil)
    private let showSource   = NSButton(checkboxWithTitle: L("Show source app icons"), target: nil, action: nil)
    private let showThumbs   = NSButton(checkboxWithTitle: L("Show image thumbnails in menu"), target: nil, action: nil)
    private let titleLength  = NSTextField()
    private let thumbSize    = NSTextField()

    private let protect      = NSButton(checkboxWithTitle: L("Require password at launch"), target: nil, action: nil)
    private let changePw     = NSButton(title: L("Change…"), target: nil, action: nil)
    private let touchID      = NSButton(checkboxWithTitle: L("Unlock with Touch ID"), target: nil, action: nil)
    private let touchIDChange = NSButton(checkboxWithTitle: L("Allow changing the password with Touch ID"), target: nil, action: nil)
    private let lockScreen   = NSButton(checkboxWithTitle: L("Lock when the screen locks or the Mac sleeps"), target: nil, action: nil)
    private let newPhrase    = NSButton(title: L("Create New…"), target: nil, action: nil)

    private let pollInterval = NSTextField()
    private let resetAll     = NSButton(title: L("Reset…"), target: nil, action: nil)
    private let uninstall    = NSButton(title: L("Uninstall…"), target: nil, action: nil)

    // MARK: Panes

    private struct Pane {
        let id: NSToolbarItem.Identifier
        let title: String
        let symbol: String
        let view: NSView
    }
    private var panes: [Pane] = []
    private let container = NSView()
    private var shownPane: NSView?
    /// One label column and one window width for all panes, measured from the real (localized) labels.
    private var windowWidth: CGFloat = 0
    /// One width for every field, pop-up and button, so nothing is ever stretched or truncated:
    /// the widest button title in the current language decides, never less than 150 pt.
    private var controlWidth: CGFloat = 150
    private var sizedControls: [NSView] = []
    private static let lastPaneKey = "SettingsWindow.pane"

    init(app: AppDelegate) {
        self.app = app
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.titlebarAppearsTransparent = false
        if #available(macOS 11, *) { w.toolbarStyle = .preference }
        super.init(window: w)
        w.delegate = self
        buildPanes()
        buildToolbar()
        load()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, e.keyCode == kVK_Escape, e.window === self.window,
                  !(self.window?.firstResponder is HotKeyRecorderView) else { return e }
            self.window?.close()
            return nil
        }
        let remembered = UserDefaults.standard.string(forKey: Self.lastPaneKey)
        show(pane: panes.first { $0.id.rawValue == remembered } ?? panes[0], animate: false)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        load()
        if window?.isVisible != true { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Esc closes, like every settings window on the Mac (unless a shortcut field is recording).
    private var escMonitor: Any?
    deinit { if let m = escMonitor { NSEvent.removeMonitor(m) } }

    // MARK: Building blocks

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    private func row(_ text: String, _ view: NSView) -> [NSView] { [label(text), view] }

    /// Group title: bold, in the label column, on the same axis as the labels — so a pane without
    /// labelled fields still has something on the left and every pane reads "what / controls".
    private func header(_ text: String) -> [NSView] {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        l.alignment = .right
        return [l, NSView()]
    }

    private func status(_ field: NSTextField) -> [NSView] {
        field.textColor = .systemRed
        field.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        field.preferredMaxLayoutWidth = 400
        field.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true
        field.isHidden = true
        return [NSView(), field]
    }

    private func setStatus(_ field: NSTextField, _ text: String) {
        field.stringValue = text
        field.isHidden = text.isEmpty
        if let pane = panes.first(where: { $0.view === shownPane }) { show(pane: pane, animate: true) }
    }

    /// `[ 0.08 ] ⇕ seconds` — a number field with a formatter, a stepper and the unit as a word.
    private func number(_ field: NSTextField, unit: String, min: Double, max: Double, step: Double, decimals: Int = 0) -> NSView {
        let f = NumberFormatter()
        f.minimum = NSNumber(value: min); f.maximum = NSNumber(value: max)
        f.minimumFractionDigits = decimals; f.maximumFractionDigits = decimals
        f.allowsFloats = decimals > 0
        field.formatter = f
        field.alignment = .right
        field.delegate = self
        field.target = self; field.action = #selector(numberEdited(_:))
        field.widthAnchor.constraint(equalToConstant: 72).isActive = true
        let stepper = NSStepper()
        stepper.minValue = min; stepper.maxValue = max; stepper.increment = step
        stepper.valueWraps = false
        stepper.target = self; stepper.action = #selector(stepperChanged(_:))
        steppers[ObjectIdentifier(field)] = stepper
        fieldsByStepper[ObjectIdentifier(stepper)] = field
        let u = NSTextField(labelWithString: unit)
        u.textColor = .secondaryLabelColor
        let s = NSStackView(views: [field, stepper, u])
        s.orientation = .horizontal
        s.alignment = .firstBaseline
        s.spacing = 4
        s.setCustomSpacing(8, after: stepper)
        return s
    }
    private var steppers: [ObjectIdentifier: NSStepper] = [:]
    private var fieldsByStepper: [ObjectIdentifier: NSTextField] = [:]

    private func grid(_ rows: [[NSView]]) -> NSGridView {
        let g = NSGridView(views: rows)
        g.rowSpacing = 8
        g.columnSpacing = 10
        g.xPlacement = .leading
        g.column(at: 0).xPlacement = .trailing
        g.column(at: 1).xPlacement = .leading
        // Hug the content: an empty label column must not be handed half of the window.
        g.yPlacement = .center
        for r in 0..<g.numberOfRows { g.cell(atColumnIndex: 1, rowIndex: r).xPlacement = .leading }
        g.translatesAutoresizingMaskIntoConstraints = false
        return g
    }

    /// `view` followed by a small (?) button that opens a popover with `text`.
    private var helpPopover: NSPopover?

    private func help(_ view: NSView, _ text: String) -> NSView {
        let b = NSButton(title: "", target: self, action: #selector(helpTapped(_:)))
        b.bezelStyle = .helpButton
        b.controlSize = .small
        b.toolTip = text
        b.identifier = NSUserInterfaceItemIdentifier(text)
        b.translatesAutoresizingMaskIntoConstraints = false
        let side = b.intrinsicContentSize.height
        NSLayoutConstraint.activate([b.widthAnchor.constraint(equalToConstant: side), b.heightAnchor.constraint(equalToConstant: side)])
        for axis in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            b.setContentHuggingPriority(.required, for: axis)
            b.setContentCompressionResistancePriority(.required, for: axis)
        }
        let row = NSStackView(views: [view, b])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        return row
    }

    @objc private func helpTapped(_ sender: NSButton) {
        guard let text = sender.identifier?.rawValue else { return }
        if let open = helpPopover, open.isShown { open.close() }
        let pop = NSPopover()
        helpPopover = pop
        pop.behavior = .transient
        let vc = NSViewController()
        let label = NSTextField(wrappingLabelWithString: text)
        label.preferredMaxLayoutWidth = 320
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -10),
            v.widthAnchor.constraint(equalToConstant: 344),
        ])
        v.layoutSubtreeIfNeeded()
        let h = label.sizeThatFits(NSSize(width: 320, height: 1000)).height
        vc.view = v
        pop.contentSize = NSSize(width: 344, height: h + 20)
        pop.contentViewController = vc
        pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }

    private func button(_ b: NSButton) -> NSButton {
        b.translatesAutoresizingMaskIntoConstraints = false
        sizedControls.append(b)
        return b
    }

    private func check(_ b: NSButton) -> NSButton {
        b.target = self; b.action = #selector(controlChanged(_:))
        return b
    }

    private func recorder(_ r: HotKeyRecorderView, clear: Bool = true, modifiersOnly: Bool = false, suffix: String? = nil) -> HotKeyRecorderView {
        r.allowsClear = clear
        r.modifiersOnly = modifiersOnly
        if let suffix { r.modifiersSuffix = suffix }
        r.onChange = { [weak self, weak r] hk in guard let self, let r else { return }; self.hotKeyChanged(r, hk) }
        r.translatesAutoresizingMaskIntoConstraints = false
        sizedControls.append(r)
        return r
    }

    // MARK: Panes

    private func buildPanes() {
        let exportBtn = NSButton(title: L("Export…"), target: self, action: #selector(exportTapped))
        let importBtn = NSButton(title: L("Import…"), target: self, action: #selector(importTapped))
        let backupRow = NSStackView(views: [button(exportBtn), button(importBtn)])
        backupRow.orientation = .horizontal; backupRow.spacing = 8
        var generalRows: [[NSView]] = [
            header(L("Startup")),
            [NSView(), check(loginItem)],
            [NSView(), check(saveHistory)],
            header(L("Paste")),
            [NSView(), check(pasteAfter)],
            row(L("Paste delay:"), help(number(pasteDelay, unit: L("seconds"), min: 0, max: 5, step: 0.02, decimals: 2),
                                         L("Time between bringing the app you were in back to the front and sending ⌘V. Raise it for apps that are slow to come forward."))),
            [NSView(), check(showAtCaret)],
            header(L("Backup")),
            [NSView(), help(backupRow, L("One password-encrypted .keepit file with history, templates and preferences — for moving to another Mac or between the App Store and direct editions."))],
        ]
        generalRows += updatesRows()
        let general = grid(generalRows)

        let resetHK = NSButton(title: L("Reset to Defaults"), target: self, action: #selector(resetShortcuts))
        let shortcuts = grid([
            header(L("Menus")),
            row(L("History menu:"), recorder(historyHK, clear: false)),
            row(L("Template menu:"), recorder(templateHK, clear: false)),
            header(L("Paste without the menu")),
            row(L("Paste previous item:"), help(recorder(previousHK), L("Pastes the second item of the history straight away, without the menu — handy for swapping between the two latest clips. Click the field and press ⌫ to turn it off."))),
            row(L("Paste item by number:"), help(recorder(numbersHK, modifiersOnly: true), L("Modifiers that, together with 1–9 and 0, paste history item 1–10 directly. Click the field and press the modifiers with any digit; ⌫ turns it off."))),
            row(L("Actions on the latest item:"), help(recorder(latestHK, modifiersOnly: true, suffix: L("letter")), L("Modifiers that act on the latest item (the clipboard) with a letter: V plain text, U UPPERCASE, L lowercase, T Title Case, S Sentence case, W trim, J single line, A add to Templates, ⌫ delete. The same keys are shown in the item's extended menu."))),
            header(L("Other")),
            row(L("Viewer:"), recorder(viewerHK)),
            row(L("Settings:"), recorder(prefsHK)),
            row(L("Clear History:"), recorder(clearHK)),
            row(L("Pause recording:"), recorder(pauseHK)),
            row(L("Lock Keepit:"), recorder(lockHK)),
            row(L("Quit Keepit:"), recorder(quitHK)),
            status(shortcutStatus),
            [NSView(), help(resetHK, L("Shortcuts set here and on the Paste Queue pane work from any app and are shown next to their commands in the menu. ⌫ in a field switches the shortcut off. Reset to Defaults restores every shortcut, including the paste queue's."))],
        ])

        let queue = grid([
            header(L("Shortcuts")),
            row(L("Start / stop the queue:"), help(recorder(queueHK), L("Serial copy-and-paste. Start the queue, copy several things in a row (the menu bar icon counts them), then paste them back one by one in the same order with the key below. The queue ends when the last item has been pasted or after the idle time; ⌘V keeps working as usual."))),
            row(L("Paste next item:"), recorder(queuePasteHK)),
            row(L("Paste all remaining:"), help(recorder(queueAllHK), L("Pastes everything still in the queue as one text, items joined with the separator below, and ends the queue."))),
            status(queueStatus),
            header(L("Behaviour")),
            row(L("Idle time:"), help(number(queueTimeout, unit: L("seconds"), min: 0, max: 3600, step: 10),
                                        L("Seconds without a copy or a paste after which the queue switches itself off. 0 keeps it on until you stop it."))),
            row(L("Join items with:"), popup(queueSep, Self.separators.map { $0.1 })),
        ])

        let tableScroll = buildIgnoredTable()
        let tableButtons = NSSegmentedControl(images: [NSImage(systemSymbolName: "plus", accessibilityDescription: L("Add application"))!,
                                                       NSImage(systemSymbolName: "minus", accessibilityDescription: L("Remove"))!],
                                              trackingMode: .momentary, target: self, action: #selector(ignoredSegmentTapped(_:)))
        tableButtons.segmentStyle = .smallSquare
        for i in 0..<2 { tableButtons.setWidth(28, forSegment: i) }
        let tableBlock = NSStackView(views: [tableScroll, tableButtons])
        tableBlock.orientation = .vertical; tableBlock.alignment = .leading; tableBlock.spacing = 4
        let ignoredLabel = label(L("Ignored apps:"))
        let history = grid([
            row(L("Text and file items:"), number(historyMax, unit: L("items"), min: 1, max: Double(Limits.historyMaxCeiling), step: 100)),
            row(L("Image items:"), number(imageMax, unit: L("items"), min: 1, max: Double(Limits.historyMaxCeiling), step: 10)),
            row(L("Forget items older than:"), popup(maxAge, Self.ages.map { $0.1 })),
            [NSView(), help(check(overlap), L("When the same content is copied again, the older copy is removed and the new one goes to the top."))],
            [NSView(), help(check(concealed), L("Password managers mark what they copy as concealed; such items are never recorded. Known password managers are ignored in any case."))],
            [ignoredLabel, help(tableBlock, L("Nothing copied in these apps is recorded. Double-click an entry to type a bundle identifier by hand. Known password managers are always ignored."))],
        ])
        history.cell(for: ignoredLabel)?.yPlacement = .top
        (tableBlock.superview as? NSStackView)?.alignment = .top

        let menu = grid([
            header(L("History menu")),
            [NSView(), help(check(searchMenu), L("A search field at the top of the history menu: typing filters the list in place, Return pastes the first match. Item shortcuts then become ⌘1–⌘0 instead of 1-9/0/A-Z."))],
            [NSView(), help(check(numberItems), L("Prefix items with 1-9, 0, A-Z; pressing the key pastes the item without the mouse. Hold ⇧ while the menu is open for the extended menu: every history item gets a submenu with all actions — paste as plain text, UPPERCASE, single line, copy only, add to Templates, delete. For the latest item the submenu also shows the global shortcuts that do the same without the menu."))],
            [NSView(), help(check(showPreview), L("Hovering a history item shows the full image or the first lines of text in a panel beside the menu. Tooltips are not shown while this is on."))],
            [NSView(), check(showTips)],
            [NSView(), check(showSource)],
            [NSView(), check(showThumbs)],
            row(L("Title length:"), number(titleLength, unit: L("characters"), min: 10, max: 500, step: 10)),
            row(L("Thumbnail height:"), number(thumbSize, unit: L("pixels"), min: 16, max: 128, step: 8)),
        ])

        protect.target = self; protect.action = #selector(protectToggled)
        changePw.target = self; changePw.action = #selector(changePasswordTapped)
        newPhrase.target = self; newPhrase.action = #selector(newPhraseTapped)
        let security = grid([
            header(L("Password")),
            [NSView(), help(protect, L("History and templates are stored AES-256 encrypted; the key is derived from the password and asked for every time Keepit starts."))],
            [NSView(), button(changePw)],
            [NSView(), help(check(touchID), L("Unlock with a fingerprint instead of typing the password. The password always remains as fallback."))],
            [NSView(), help(check(touchIDChange), L("Let Touch ID stand in for the current password when changing it. Off = always type the current password first."))],
            [NSView(), help(check(lockScreen), L("Wipes the key from memory and unloads history and templates when the screen locks or the Mac sleeps; unlock with Touch ID or the password afterwards."))],
            header(L("Recovery phrase")),
            [NSView(), help(button(newPhrase), L("Issues a new 24-word phrase and invalidates the old one. Use it if the printed sheet was lost or seen by someone; you will then be offered to change the password too."))],
        ])

        let reveal = NSButton(title: L("Open Folder"), target: self, action: #selector(revealData))
        uninstall.target = self; uninstall.action = #selector(uninstallTapped)
        resetAll.target = self; resetAll.action = #selector(resetTapped)
        // The App Store build is sandboxed: it cannot move itself to the Trash or reset the
        // Accessibility grant, and store apps are removed from Launchpad anyway — Reset only.
        #if APPSTORE
        let dangerRow = NSStackView(views: [button(resetAll)])
        let dangerTitle = L("Reset")
        let dangerHelp = L("Clipboard history, templates, settings, the password and the Touch ID key are deleted; the example templates come back. The app, its permissions and Launch at login stay. There is no undo — export a backup first if you may want the data back.")
        #else
        let dangerRow = NSStackView(views: [button(resetAll), button(uninstall)])
        let dangerTitle = L("Reset and uninstall")
        let dangerHelp = L("Reset puts Keepit back to a fresh install — history, templates, settings, password and Touch ID key are deleted and the example templates return; the app and its permissions stay. Uninstall does the same and then removes the app, Launch at login, the keychain entry and the Accessibility permission. Both ask for your password or Touch ID; Uninstall also for a typed confirmation. Export a backup first if you may want the data back.")
        #endif
        dangerRow.orientation = .horizontal; dangerRow.spacing = 8
        let advanced = grid([
            header(L("Clipboard")),
            row(L("Poll interval:"), help(number(pollInterval, unit: L("seconds"), min: 0.1, max: 5, step: 0.1, decimals: 2),
                                           L("How often Keepit looks at the clipboard. macOS sends no notification when it changes, so every clipboard manager polls; 0.3 s is unnoticeable and cheap."))),
            header(L("Data")),
            [NSView(), button(reveal)],
            header(dangerTitle),
            [NSView(), help(dangerRow, dangerHelp)],
        ])

        panes = [
            Pane(id: .init("general"), title: L("General"), symbol: "gearshape", view: general),
            Pane(id: .init("shortcuts"), title: L("Shortcuts"), symbol: "keyboard", view: shortcuts),
            Pane(id: .init("queue"), title: L("Paste Queue"), symbol: "list.number", view: queue),
            Pane(id: .init("history"), title: L("History"), symbol: "clock", view: history),
            Pane(id: .init("menu"), title: L("Menu"), symbol: "filemenu.and.selection", view: menu),
            Pane(id: .init("security"), title: L("Security"), symbol: "lock", view: security),
            Pane(id: .init("advanced"), title: L("Advanced"), symbol: "wrench.and.screwdriver", view: advanced),
        ]
        // Measure once, in the current language:
        //  • every button, field and pop-up gets the same width — the widest button title decides;
        //  • the widest pane fixes the window width; every pane is centred in it.
        let widestTitle = sizedControls.compactMap { ($0 as? NSButton)?.fittingSize.width }.max() ?? 0
        controlWidth = max(150, ceil(widestTitle) + 16)
        for c in sizedControls { c.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true }
        for p in panes { (p.view as? NSGridView)?.layoutSubtreeIfNeeded() }
        let widest = ceil(panes.map { $0.view.fittingSize.width }.max() ?? 480)
        windowWidth = max(560, widest + 2 * 28)

        container.translatesAutoresizingMaskIntoConstraints = false
        let guide = NSButton(title: "", target: self, action: #selector(openGuide))
        guide.bezelStyle = .helpButton
        guide.toolTip = L("User guide (keep.it.com)")
        guide.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            guide.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])
        window?.contentView = container
    }

    private func popup(_ p: NSPopUpButton, _ titles: [String]) -> NSPopUpButton {
        p.removeAllItems()
        for t in titles { p.addItem(withTitle: t) }
        p.target = self; p.action = #selector(controlChanged(_:))
        p.translatesAutoresizingMaskIntoConstraints = false
        sizedControls.append(p)
        return p
    }

    private func buildIgnoredTable() -> NSScrollView {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        col.resizingMask = .autoresizingMask
        ignoredTable.addTableColumn(col)
        ignoredTable.headerView = nil
        ignoredTable.rowHeight = 24
        ignoredTable.dataSource = self
        ignoredTable.delegate = self
        ignoredTable.allowsEmptySelection = true
        ignoredTable.usesAlternatingRowBackgroundColors = true
        ignoredTable.doubleAction = #selector(editIgnoredApp)
        ignoredTable.target = self
        let scroll = NSScrollView()
        scroll.documentView = ignoredTable
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6
        scroll.layer?.borderWidth = 1
        scroll.layer?.borderColor = NSColor.separatorColor.cgColor
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 300).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 120).isActive = true
        return scroll
    }

    // MARK: Toolbar / pane switching

    private func buildToolbar() {
        let tb = NSToolbar(identifier: "settings")
        tb.delegate = self
        tb.allowsUserCustomization = false
        tb.displayMode = .iconAndLabel
        window?.toolbar = tb
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { panes.map(\.id) }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { panes.map(\.id) }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { panes.map(\.id) }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = panes.first(where: { $0.id == id }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = pane.title
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
        item.target = self
        item.action = #selector(paneTapped(_:))
        return item
    }

    @objc private func paneTapped(_ sender: NSToolbarItem) {
        guard let pane = panes.first(where: { $0.id == sender.itemIdentifier }) else { return }
        window?.makeFirstResponder(nil)
        show(pane: pane, animate: true)
    }

    private func show(pane: Pane, animate: Bool) {
        guard let window else { return }
        shownPane?.removeFromSuperview()
        let v = pane.view
        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            v.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        ])
        shownPane = v
        window.toolbar?.selectedItemIdentifier = pane.id
        window.title = pane.title
        UserDefaults.standard.set(pane.id.rawValue, forKey: Self.lastPaneKey)

        let fit = v.fittingSize
        let size = NSSize(width: windowWidth, height: ceil(fit.height) + 20 + 16 + 21 + 14)   // margins + help button
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        let old = window.frame
        frame.origin = NSPoint(x: old.minX, y: old.maxY - frame.height)   // keep the title bar where it is
        window.setFrame(frame, display: true, animate: animate && window.isVisible)
    }

    /// The App Store edition has no updater (the store updates it), so the option is not shown there.
    private func updatesRows() -> [[NSView]] {
        #if APPSTORE
        return []
        #else
        return [
            header(L("Updates")),
            [NSView(), help(check(updateCheck), L("Once a day Keepit asks GitHub Releases whether a newer version exists — the only network request it makes; the download itself is signed and verified. Off = no request is ever made and Check for Updates… leaves the menus; you update by downloading from keep.it.com."))],
        ]
        #endif
    }

    // MARK: Load

    private func load() {
        loading = true
        defer { loading = false }
        let s = app.settings
        loginItem.state = s.launchAtLogin ? .on : .off
        updateCheck.state = s.checkForUpdates ? .on : .off
        saveHistory.state = s.historySave ? .on : .off
        pasteAfter.state = s.pasteAfterSelect ? .on : .off
        showAtCaret.state = s.showAtCaret ? .on : .off
        setNumber(pasteDelay, s.pasteDelay)

        historyHK.hotKey = s.historyHotKey
        templateHK.hotKey = s.templateHotKey
        previousHK.hotKey = s.previousHotKey
        numbersHK.hotKey = s.numberPasteModifiers.map { HotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: $0) }
        latestHK.hotKey = s.latestActionModifiers.map { HotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: $0) }
        viewerHK.hotKey = s.viewerHotKey; prefsHK.hotKey = s.preferencesHotKey
        clearHK.hotKey = s.clearHistoryHotKey; pauseHK.hotKey = s.pauseHotKey
        lockHK.hotKey = s.lockHotKey; quitHK.hotKey = s.quitHotKey
        setStatus(shortcutStatus, "")

        queueHK.hotKey = s.queueHotKey; queuePasteHK.hotKey = s.queuePasteHotKey; queueAllHK.hotKey = s.queuePasteAllHotKey
        setNumber(queueTimeout, s.queueTimeout)
        queueSep.selectItem(at: Self.separators.firstIndex { $0.0 == s.queueSeparator } ?? 0)
        setStatus(queueStatus, "")

        setNumber(historyMax, Double(s.historyMax))
        setNumber(imageMax, Double(s.historyImageMax))
        maxAge.selectItem(at: Self.ages.firstIndex { $0.0 == s.historyMaxAge } ?? 0)
        overlap.state = s.overlapCheck ? .on : .off
        concealed.state = s.ignoreConcealed ? .on : .off
        ignoredApps = s.ignoreApps
        ignoredTable.reloadData()

        searchMenu.state = s.searchInMenu ? .on : .off
        numberItems.state = s.numberItems ? .on : .off
        showPreview.state = s.showPreview ? .on : .off
        showTips.state = s.showTooltips ? .on : .off
        showSource.state = s.showSourceIcons ? .on : .off
        showThumbs.state = s.showThumbnails ? .on : .off
        setNumber(titleLength, Double(s.titleLength))
        setNumber(thumbSize, Double(s.thumbnailSize))

        protect.state = Vault.isEnabled ? .on : .off
        changePw.isEnabled = Vault.isEnabled
        touchID.state = s.biometricUnlock ? .on : .off
        touchID.isEnabled = Vault.isEnabled && BiometricUnlock.hasSensor
        if !BiometricUnlock.hasSensor { touchID.title = L("Unlock with Touch ID (no Touch ID on this Mac)") }
        touchIDChange.state = s.biometricPasswordChange ? .on : .off
        touchIDChange.isEnabled = touchID.isEnabled
        lockScreen.state = s.lockWithScreen ? .on : .off
        lockScreen.isEnabled = Vault.isEnabled
        newPhrase.isEnabled = Vault.isEnabled

        setNumber(pollInterval, s.pollInterval)
    }

    private func setNumber(_ field: NSTextField, _ value: Double) {
        field.doubleValue = value
        steppers[ObjectIdentifier(field)]?.doubleValue = value
    }

    // MARK: Apply (every change is written straight away)

    private func apply(_ change: (inout Settings) -> Void) {
        guard !loading else { return }
        var s = app.settings
        change(&s)
        s.clamp()
        if s != app.settings { app.apply(settings: s) }
    }

    @objc private func controlChanged(_ sender: Any?) {
        apply { s in
            s.launchAtLogin = loginItem.state == .on
            s.checkForUpdates = updateCheck.state == .on
            s.historySave = saveHistory.state == .on
            s.pasteAfterSelect = pasteAfter.state == .on
            s.showAtCaret = showAtCaret.state == .on
            s.queueSeparator = Self.separators[max(0, queueSep.indexOfSelectedItem)].0
            s.historyMaxAge = Self.ages[max(0, maxAge.indexOfSelectedItem)].0
            s.overlapCheck = overlap.state == .on
            s.ignoreConcealed = concealed.state == .on
            s.searchInMenu = searchMenu.state == .on
            s.numberItems = numberItems.state == .on
            s.showPreview = showPreview.state == .on
            s.showTooltips = showTips.state == .on
            s.showSourceIcons = showSource.state == .on
            s.showThumbnails = showThumbs.state == .on
            s.biometricUnlock = touchID.state == .on && Vault.isEnabled
            s.biometricPasswordChange = touchIDChange.state == .on
            s.lockWithScreen = lockScreen.state == .on
        }
    }

    @objc private func numberEdited(_ sender: NSTextField) { commitNumbers(from: sender) }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let f = obj.object as? NSTextField { commitNumbers(from: f) }
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        guard let field = fieldsByStepper[ObjectIdentifier(sender)] else { return }
        field.doubleValue = sender.doubleValue
        commitNumbers(from: field)
    }

    private func commitNumbers(from field: NSTextField) {
        // The formatter already refuses out-of-range input; mirror the field into its stepper and apply.
        steppers[ObjectIdentifier(field)]?.doubleValue = field.doubleValue
        apply { s in
            s.pasteDelay = pasteDelay.doubleValue
            s.queueTimeout = queueTimeout.doubleValue
            s.historyMax = historyMax.integerValue
            s.historyImageMax = imageMax.integerValue
            s.titleLength = titleLength.integerValue
            s.thumbnailSize = thumbSize.integerValue
            s.pollInterval = pollInterval.doubleValue
        }
        // clamp() may have adjusted something — show what was actually stored
        let s = app.settings
        setNumber(pasteDelay, s.pasteDelay); setNumber(queueTimeout, s.queueTimeout)
        setNumber(historyMax, Double(s.historyMax)); setNumber(imageMax, Double(s.historyImageMax))
        setNumber(titleLength, Double(s.titleLength)); setNumber(thumbSize, Double(s.thumbnailSize))
        setNumber(pollInterval, s.pollInterval)
    }

    // MARK: Shortcuts

    private func hotKeyChanged(_ r: HotKeyRecorderView, _ hk: HotKey?) {
        guard !loading else { return }
        var s = app.settings
        switch r {
        case historyHK:  if let hk { s.historyHotKey = hk }
        case templateHK: if let hk { s.templateHotKey = hk }
        case previousHK: s.previousHotKey = hk
        case numbersHK:  s.numberPasteModifiers = hk?.modifiers
        case latestHK:   s.latestActionModifiers = hk?.modifiers
        case viewerHK:   s.viewerHotKey = hk
        case prefsHK:    s.preferencesHotKey = hk
        case clearHK:    s.clearHistoryHotKey = hk
        case pauseHK:    s.pauseHotKey = hk
        case lockHK:     s.lockHotKey = hk
        case quitHK:     s.quitHotKey = hk
        case queueHK:    s.queueHotKey = hk
        case queuePasteHK: s.queuePasteHotKey = hk
        case queueAllHK: s.queuePasteAllHotKey = hk
        default: return
        }
        let statusField = [queueHK, queuePasteHK, queueAllHK].contains(r) ? queueStatus : shortcutStatus
        if let conflict = conflict(in: s) {
            NSSound.beep()
            load()                      // put the old value back into the recorder
            setStatus(statusField, conflict)
            return
        }
        setStatus(statusField, "")
        app.apply(settings: s)
    }

    @objc private func resetShortcuts() {
        let d = Settings()
        apply { s in
            s.historyHotKey = d.historyHotKey; s.templateHotKey = d.templateHotKey
            s.previousHotKey = d.previousHotKey; s.numberPasteModifiers = d.numberPasteModifiers
            s.latestActionModifiers = d.latestActionModifiers
            s.viewerHotKey = d.viewerHotKey; s.preferencesHotKey = d.preferencesHotKey
            s.clearHistoryHotKey = d.clearHistoryHotKey; s.pauseHotKey = d.pauseHotKey
            s.lockHotKey = d.lockHotKey; s.quitHotKey = d.quitHotKey
            s.queueHotKey = d.queueHotKey; s.queuePasteHotKey = d.queuePasteHotKey; s.queuePasteAllHotKey = d.queuePasteAllHotKey
        }
        load()
    }

    /// Two of our own shortcuts on the same combination would silently shadow each other.
    private func conflict(in s: Settings) -> String? {
        var all: [(String, HotKey)] = [(L("History menu"), s.historyHotKey), (L("Template menu"), s.templateHotKey)]
        if let h = s.previousHotKey { all.append((L("Paste previous item"), h)) }
        if let m = s.latestActionModifiers {
            for la in HotKey.LatestAction.allCases { all.append((L("Actions on the latest item"), HotKey(keyCode: la.keyCode, modifiers: m))) }
        }
        if let m = s.numberPasteModifiers {
            for c in HotKey.digitKeyCodes { all.append((L("Paste item by number"), HotKey(keyCode: c, modifiers: m))) }
        }
        if let h = s.viewerHotKey { all.append((L("Viewer"), h)) }
        if let h = s.preferencesHotKey { all.append((L("Settings"), h)) }
        if let h = s.clearHistoryHotKey { all.append((L("Clear History"), h)) }
        if let h = s.pauseHotKey { all.append((L("Pause recording"), h)) }
        if let h = s.lockHotKey { all.append((L("Lock Keepit"), h)) }
        if let h = s.quitHotKey { all.append((L("Quit Keepit"), h)) }
        if let h = s.queueHotKey { all.append((L("Start / stop the queue"), h)) }
        if let h = s.queuePasteHotKey { all.append((L("Paste next item"), h)) }
        if let h = s.queuePasteAllHotKey { all.append((L("Paste all remaining"), h)) }
        for t in app.templates.allItems() where t.hotKey != nil {
            all.append((LF("Template “%@”", t.displayName), t.hotKey!))
        }
        for i in all.indices {
            for j in all.indices where j > i && all[i].1 == all[j].1 {
                return LF("%@ is already used by %@.", all[j].1.displayString, all[i].0)
            }
        }
        return nil
    }

    // MARK: Security

    @objc private func protectToggled() {
        let wantOn = protect.state == .on
        guard wantOn != Vault.isEnabled else { return }
        let ok = wantOn ? app.enableProtection() : app.disableProtection()
        if ok && wantOn && BiometricUnlock.hasSensor {
            // Turning protection on should let the user pick Touch ID in the same go.
            apply { s in s.biometricUnlock = true; s.biometricPasswordChange = true }
        }
        load()
    }

    @objc private func changePasswordTapped() { app.changePassword() }
    @objc private func newPhraseTapped() { app.regenerateRecoveryPhrase() }
    @objc private func exportTapped() { app.exportBackup() }
    @objc private func importTapped() { app.importBackup() }
    @objc private func uninstallTapped() { app.uninstallRequested() }
    @objc private func resetTapped() { app.resetRequested() }
    @objc private func revealData() { NSWorkspace.shared.activateFileViewerSelecting([Storage.settingsURL]) }

    // MARK: Ignored apps

    func numberOfRows(in tableView: NSTableView) -> Int { ignoredApps.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = ignoredApps[row]
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: nil) as? NSTableCellView ?? {
            let c = NSTableCellView()
            c.identifier = NSUserInterfaceItemIdentifier("cell")
            let iv = NSImageView(); iv.translatesAutoresizingMaskIntoConstraints = false
            let tf = NSTextField(labelWithString: ""); tf.translatesAutoresizingMaskIntoConstraints = false
            tf.lineBreakMode = .byTruncatingMiddle
            c.addSubview(iv); c.addSubview(tf); c.imageView = iv; c.textField = tf
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4), iv.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 18), iv.heightAnchor.constraint(equalToConstant: 18),
                tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 6), tf.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            return c
        }()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            cell.imageView?.image = NSWorkspace.shared.icon(forFile: url.path)
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            cell.textField?.attributedStringValue = NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
            cell.toolTip = id
        } else {
            cell.imageView?.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
            cell.textField?.attributedStringValue = NSAttributedString(string: id, attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
            cell.toolTip = nil
        }
        return cell
    }

    @objc private func ignoredSegmentTapped(_ sender: NSSegmentedControl) {
        sender.selectedSegment == 0 ? addIgnoredApp() : removeIgnoredApp()
    }

    @objc private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.title = L("Choose an app whose copies Keepit should ignore")
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window!) { [weak self] resp in
            guard let self, resp == .OK else { return }
            let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            for id in ids where !self.ignoredApps.contains(id) { self.ignoredApps.append(id) }
            self.storeIgnoredApps()
        }
    }

    @objc private func removeIgnoredApp() {
        let rows = ignoredTable.selectedRowIndexes
        guard !rows.isEmpty else { NSSound.beep(); return }
        ignoredApps = ignoredApps.enumerated().filter { !rows.contains($0.offset) }.map(\.element)
        storeIgnoredApps()
    }

    /// Double-click: edit the identifier by hand (apps outside /Applications, helper processes).
    @objc private func editIgnoredApp() {
        let row = ignoredTable.clickedRow
        let a = NSAlert()
        a.messageText = L("Bundle identifier")
        a.informativeText = L("For example com.example.app. Nothing copied in this app is recorded.")
        let f = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        f.stringValue = row >= 0 ? ignoredApps[row] : ""
        a.accessoryView = f
        a.addButton(withTitle: L("OK")); a.addButton(withTitle: L("Cancel"))
        a.window.initialFirstResponder = f
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let id = f.stringValue.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        if row >= 0 { ignoredApps[row] = id } else if !ignoredApps.contains(id) { ignoredApps.append(id) }
        storeIgnoredApps()
    }

    private func storeIgnoredApps() {
        ignoredTable.reloadData()
        apply { s in s.ignoreApps = ignoredApps }
    }

    @objc private func openGuide() { NSWorkspace.shared.open(AppInfo.guideURL) }
}
