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

    private func keyDown(_ chars: String, _ flags: NSEvent.ModifierFlags, keyCode: Int) -> NSEvent {
        try! XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                                        characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: UInt16(keyCode)))
    }

    func testTheSearchFieldHandsAMenuKeyEquivalentToTheMenuAndKeepsTheRest() throws {
        let a = app()
        a.history.add(.text("older"))
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        let search = try XCTUnwrap(menu.items.first as? MenuSearchItem, "search in the menu is on by default")

        let editor = try XCTUnwrap(search.field.fieldEditorForTesting as? MenuSearchFieldEditor, "the cell hands out our editor")
        editor.keyDown(with: keyDown("v", ctrlOpt, keyCode: kVK_ANSI_V))          // what the tracking menu sends the focused field
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(pasted.map(\.plainText), ["latest"], "⌃⌥V names the hidden plain-paste item: run once")

        XCTAssertTrue(search.handleMenuKeyEquivalent(keyDown("2", ctrlOpt, keyCode: kVK_ANSI_2)))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(pasted.last?.plainText, "older")

        XCTAssertFalse(search.handleMenuKeyEquivalent(keyDown("v", [], keyCode: kVK_ANSI_V)), "a bare letter is typed into the field")
        XCTAssertFalse(search.handleMenuKeyEquivalent(keyDown("z", [.command], keyCode: kVK_ANSI_Z)), "⌘Z names no item: the field keeps it")
        XCTAssertFalse(search.handleMenuKeyEquivalent(keyDown("v", [.option], keyCode: kVK_ANSI_V)), "⌥V alone names no item here")
        XCTAssertEqual(pasted.count, 2)
    }

    func testAnEmptyHistoryMenuHasNoHiddenItems() {
        let a = app()
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "v", flags: ctrlOpt, in: [menu]))
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

    @objc func noop() {}
}
