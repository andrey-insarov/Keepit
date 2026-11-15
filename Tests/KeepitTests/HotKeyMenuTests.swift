import Carbon
import XCTest
@testable import Keepit

/// H-9 of claude/keepit-hotkey-layouts-design.md: while a menu of ours tracks, the Carbon registrations are
/// lifted so the keys reach the menu, and the history menu carries hidden items with the latest-item key
/// equivalents so those combinations work with the menu open. The paste is caught by
/// `Paster.pasteSinkForTesting`; the delegate calls stand in for AppKit's menu tracking.
final class HotKeyMenuTests: XCTestCase {
    private var tmp: TempStorage!
    private var pasted: [ClipItem] = []

    override func setUpWithError() throws {
        tmp = TempStorage()
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        KeyCodes.currentLayoutForTesting = { KeyCodes.usTable }
        KeyCodes.invalidateLayoutCache()
        pasted = []
        Paster.pasteSinkForTesting = { [weak self] in self?.pasted.append($0) }
    }
    override func tearDown() {
        Paster.pasteSinkForTesting = nil
        KeyCodes.currentLayoutForTesting = nil
        KeyCodes.invalidateLayoutCache()
        tmp.restore()
    }

    private func app() -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.hotKeyFailureForTesting = { _ in }
        a.hotKeys.registrationOverrideForTesting = { _ in true }
        a.layoutReaderForTesting = HotKeyStatusTests.Fake.latin(id: "us", name: "U.S.", lang: "en")
        a.registerHotKeys()
        return a
    }
    private let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
    private func perform(_ mi: NSMenuItem) {
        NSApp.sendAction(try! XCTUnwrap(mi.action), to: mi.target, from: mi)
    }

    // MARK: The lookup helper (pure)

    func testItemLookupMatchesTheExactEquivalentAndMaskThroughAttachedSubmenus() throws {
        let builder = MenuBuilder(settings: Settings())
        let item = ClipItem.text("hello")
        let actions = builder.contextMenu(for: item, target: self, actions: MenuBuilder.ContextActions(
            paste: #selector(noop), pastePlain: #selector(noop), copyOnly: #selector(noop), transform: #selector(noop),
            pin: #selector(noop), reveal: #selector(noop), delete: #selector(noop)), latestMods: HotKey.controlOption)
        let trim = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "w", flags: ctrlOpt, in: [actions]))
        XCTAssertTrue(trim.title.contains(TextTransform.trim.title))
        XCTAssertFalse(trim.isHidden)
        XCTAssertTrue(try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "w", flags: [.control, .option, .shift], in: [actions])).isHidden, "the hidden ⇧ copy")
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "w", flags: [.option], in: [actions]), "the modifiers must match exactly")
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "q", flags: ctrlOpt, in: [actions]))

        let root = NSMenu()
        let holder = NSMenuItem(title: "holder", action: nil, keyEquivalent: "")
        holder.submenu = actions
        root.addItem(holder)
        XCTAssertTrue(try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "u", flags: ctrlOpt, in: [root])).title.contains(TextTransform.upper.title), "found through the attached submenu")
        let disabled = NSMenuItem(title: "off", action: #selector(noop), keyEquivalent: "b")
        disabled.keyEquivalentModifierMask = ctrlOpt
        disabled.isEnabled = false
        root.addItem(disabled)
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "b", flags: ctrlOpt, in: [root]), "a disabled item does not answer")
    }

    // MARK: The history menu answers the latest-item combinations itself

    func testHistoryMenuCarriesHiddenItemsWithTheLatestItemKeyEquivalents() throws {
        let a = app()
        a.history.add(.text("older"))
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        XCTAssertTrue(menu.items.allSatisfy { $0.submenu == nil || $0.tag != MenuBuilder.historyTag }, "no extended menu attached (⇧ not held)")

        let plain = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "v", flags: ctrlOpt, in: [menu]), "⌃⌥V is in the menu")
        XCTAssertTrue(plain.isHidden)
        XCTAssertFalse(plain.allowsAutomaticKeyEquivalentLocalization)
        perform(plain)
        XCTAssertEqual(pasted.map(\.plainText), ["latest"], "⌃⌥V: the latest item as plain text, once")

        let upper = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "u", flags: ctrlOpt, in: [menu]))
        perform(upper)
        XCTAssertEqual(pasted.map(\.plainText), ["latest", "LATEST"], "⌃⌥U: UPPERCASE of the latest item")

        XCTAssertNotNil(MenuBuilder.item(forKeyEquivalent: "v", flags: [.control, .option, .shift], in: [menu]), "the ⇧ copies travel with them")
        let row2 = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "2", flags: ctrlOpt, in: [menu]))
        XCTAssertFalse(row2.isHidden, "the numbered rows keep their visible equivalents")
        perform(row2)
        XCTAssertEqual(pasted.last?.plainText, "older")
    }

    func testAnEmptyHistoryMenuHasNoHiddenItems() {
        let a = app()
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "v", flags: ctrlOpt, in: [menu]))
    }

    // MARK: The focused search field runs a matching combination (typed into it as a character)

    private func keyDown(_ chars: String, unmodified: String, flags: NSEvent.ModifierFlags, keyCode: Int = kVK_ANSI_U) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                                       context: nil, characters: chars, charactersIgnoringModifiers: unmodified,
                                       isARepeat: false, keyCode: UInt16(keyCode)))
    }
    private func nextTurn() {
        let ran = expectation(description: "the action runs on the next turn")
        DispatchQueue.main.async { ran.fulfill() }
        wait(for: [ran], timeout: 1)
    }

    /// The whole path: a query is typed, then the combination lands in the field as a character (⌃⌥U on
    /// German is the dead key "¨"); the query is restored, the filter never sees the character, the item runs once.
    func testTheSearchFieldRunsTheMatchingItemAndTakesTheTypedCharacterBack() throws {
        let a = app()
        a.history.add(.text("older"))
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        let search = try XCTUnwrap(menu.items.first as? MenuSearchItem, "the search field is the first item (searchInMenu defaults to on)")
        var queries: [String] = []
        search.onChange = { queries.append($0) }
        var event: NSEvent?
        search.currentEvent = { event }

        search.field.stringValue = "la"
        event = try keyDown("a", unmodified: "a", flags: [], keyCode: kVK_ANSI_A)
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
        XCTAssertEqual(queries, ["la"])

        search.field.stringValue = "la¨"
        event = try keyDown("¨", unmodified: "u", flags: ctrlOpt)
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
        XCTAssertEqual(search.field.stringValue, "la", "the typed character is taken back")
        // Taking it back posts the notification once more, with the same current event (seen on a Mac).
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
        XCTAssertEqual(queries, ["la"], "the filter never saw the character")
        nextTurn()
        XCTAssertEqual(pasted.map(\.plainText), ["LATEST"], "UPPERCASE of the latest item, once")

        XCTAssertFalse(search.handleMenuKeyEquivalent(try keyDown("u", unmodified: "u", flags: [])), "a bare letter is typed, never taken")
        XCTAssertFalse(search.handleMenuKeyEquivalent(try keyDown("U", unmodified: "u", flags: [.shift])), "⇧ alone is typing too")
        XCTAssertFalse(search.handleMenuKeyEquivalent(try keyDown("q", unmodified: "q", flags: ctrlOpt, keyCode: kVK_ANSI_Q)), "no item for ⌃⌥Q")
        nextTurn()
        XCTAssertEqual(pasted.count, 1)
    }

    /// The match is by physical key, as the items' equivalents are (H-6): on Russian the U key arrives as "г".
    func testTheSearchFieldMatchesThePhysicalKeyNotTheTypedLetter() throws {
        let a = app()
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        let search = try XCTUnwrap(menu.items.first as? MenuSearchItem)
        XCTAssertTrue(search.handleMenuKeyEquivalent(try keyDown("г", unmodified: "г", flags: ctrlOpt, keyCode: kVK_ANSI_U)))
        nextTurn()
        XCTAssertEqual(pasted.map(\.plainText), ["LATEST"])
        XCTAssertFalse(search.handleMenuKeyEquivalent(try keyDown("u", unmodified: "u", flags: ctrlOpt, keyCode: kVK_ANSI_Q)),
                       "the typed letter alone does not name the item when the key is another")
    }

    /// A ⇧ combination on a symbol key, French: the Viewer shows `⌥⇧,` (physical M), the event carries "?".
    func testTheSearchFieldMatchesAShiftedSymbolKeyThroughTheLayout() throws {
        var fr = KeyCodesLayoutTests.Fake(id: "fr")
        fr.set(kVK_ANSI_M, .characters(","))
        let info = fr.info
        KeyCodes.currentLayoutForTesting = { info }
        KeyCodes.invalidateLayoutCache()
        let menu = NSMenu()
        let search = MenuSearchItem()
        menu.addItem(search)
        let viewer = NSMenuItem(title: "Viewer", action: #selector(count), keyEquivalent: try XCTUnwrap(KeyCodes.menuCharacter(for: UInt16(kVK_ANSI_M))))
        XCTAssertEqual(viewer.keyEquivalent, ",")
        viewer.keyEquivalentModifierMask = [.option, .shift]
        viewer.target = self
        menu.addItem(viewer)
        counted = 0
        XCTAssertTrue(search.handleMenuKeyEquivalent(try keyDown("?", unmodified: "?", flags: [.option, .shift], keyCode: kVK_ANSI_M)))
        nextTurn()
        XCTAssertEqual(counted, 1)
        XCTAssertFalse(search.handleMenuKeyEquivalent(try keyDown(",", unmodified: ",", flags: [.option], keyCode: kVK_ANSI_M)), "the mask must match")
    }
    private var counted = 0
    @objc private func count() { counted += 1 }

    // MARK: The lock combination over a popup (SEC05)

    func testAPopupMenuCarriesTheLockCombinationHiddenOnce() throws {
        let a = app()
        a.history.add(.text("latest"))
        let lockKey = try XCTUnwrap(a.activeHotKey(.lock))
        let eq = try XCTUnwrap(lockKey.menuKeyEquivalent)
        let popup = a.buildHistoryMenu(includeTemplates: true, includeApp: false)
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: eq.key, flags: eq.mask, in: [popup]))
        a.addLockKeyEquivalent(to: popup)
        let hidden = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: eq.key, flags: eq.mask, in: [popup]))
        XCTAssertTrue(hidden.isHidden)
        XCTAssertEqual(hidden.action, #selector(AppDelegate.lock))
        XCTAssertFalse(hidden.allowsAutomaticKeyEquivalentLocalization)

        // The status-bar menu shows the Lock item itself when a vault exists (none in this test); either way
        // the combination is answered by exactly one item, however often the helper runs.
        let statusBar = a.buildHistoryMenu(includeTemplates: true, includeApp: true)
        a.addLockKeyEquivalent(to: statusBar)
        a.addLockKeyEquivalent(to: statusBar)
        XCTAssertEqual(statusBar.items.filter { $0.keyEquivalent == eq.key && $0.keyEquivalentModifierMask == eq.mask }.count, 1, "not added twice")
    }

    // MARK: The registrations are lifted while a menu tracks

    func testHotKeysAreLiftedAtTheFirstMenuAndRestoredAfterTheLast() throws {
        let a = app()
        a.history.add(.text("latest"))
        XCTAssertFalse(a.hotKeys.isSuspendedForMenu)
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)
        XCTAssertTrue(a.hotKeys.isSuspendedForMenu, "lifted when the first menu opens")

        let sub = try XCTUnwrap(a.actionMenu(for: a.history.items[0].id))
        a.menuWillOpen(sub)
        a.menuDidClose(sub)
        XCTAssertTrue(a.hotKeys.isSuspendedForMenu, "a submenu closing is not the last menu")
        XCTAssertEqual(a.hotKeys.resumedCountForTesting, 0)

        a.menuDidClose(menu)
        XCTAssertFalse(a.hotKeys.isSuspendedForMenu)
        XCTAssertGreaterThan(a.hotKeys.resumedCountForTesting, 10, "every lifted registration came back (the defaults, the families)")
    }

    func testARegistrationMadeWhileAMenuTracksWaitsForTheMenuToClose() {
        let a = app()
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)
        let before = a.hotKeys.resumedCountForTesting
        a.registerHotKeys()                                  // a layout change while the menu is open
        XCTAssertTrue(a.hotKeys.isSuspendedForMenu, "re-registering does not lift the suspension")
        a.menuDidClose(menu)
        XCTAssertFalse(a.hotKeys.isSuspendedForMenu)
        XCTAssertGreaterThan(a.hotKeys.resumedCountForTesting, before, "the new registrations were resumed with the menu's close")
    }

    // MARK: A registration refused after a menu is not left shown as registered

    func testARefusalAtResumeRecomputesTheStatusesAndNamesTheCombination() throws {
        let a = app()
        a.history.add(.text("latest"))
        let viewerKey = try XCTUnwrap(a.settings.hotKey(.viewer))
        let latestU = HotKey(keyCode: UInt32(kVK_ANSI_U), modifiers: try XCTUnwrap(a.settings.latestActionModifiers))
        XCTAssertEqual(a.hotKeyStatuses[.viewer]?.registration, .registered)
        XCTAssertEqual(a.hotKeyStatuses[.latest]?.registration, .registered)
        var reported: [String] = []
        a.hotKeyFailureForTesting = { reported = $0 }
        var changes = 0
        let token = NotificationCenter.default.addObserver(forName: AppDelegate.hotKeysDidChange, object: a, queue: nil) { _ in changes += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)
        a.hotKeys.registrationOverrideForTesting = { $0 != viewerKey && $0 != latestU }   // another app took them meanwhile
        a.menuDidClose(menu)

        XCTAssertEqual(a.hotKeyStatuses[.viewer]?.registration, .failed)
        XCTAssertEqual(a.hotKeyStatuses[.latest]?.registration, .failed, "one refused member fails the family")
        XCTAssertEqual(a.hotKeyStatuses[.history]?.registration, .registered)
        XCTAssertNil(a.activeHotKey(.viewer), "the menus stop showing it")
        XCTAssertEqual(Set(reported), [viewerKey.displayString, latestU.displayString])
        XCTAssertEqual(changes, 1, "the Settings pane is told once")
        XCTAssertFalse(a.hotKeys.isSuspendedForMenu)
    }

    func testAResumeWithNoRefusalLeavesTheStatusesAlone() {
        let a = app()
        var changes = 0
        let token = NotificationCenter.default.addObserver(forName: AppDelegate.hotKeysDidChange, object: a, queue: nil) { _ in changes += 1 }
        defer { NotificationCenter.default.removeObserver(token) }
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)
        a.menuDidClose(menu)
        XCTAssertEqual(changes, 0, "no recompute when every registration came back")
    }

    @objc func noop() {}
}
