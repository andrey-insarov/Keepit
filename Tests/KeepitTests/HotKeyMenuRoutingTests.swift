import Carbon
import XCTest
@testable import Keepit

/// H-9 of claude/keepit-hotkey-layouts-design.md: a hot key pressed while a menu of ours is open goes
/// to the item that shows the combination; the menu closes and the action runs once. The matcher is
/// pure; the routing is exercised on an AppDelegate with a built history menu "open" through the
/// delegate calls, the paste caught by `Paster.pasteSinkForTesting`.
final class HotKeyMenuRoutingTests: XCTestCase {
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
    private func spin(_ s: TimeInterval = 0.1) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
    private let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]

    // MARK: The matcher (pure)

    func testMatcherFindsTheItemWithExactlyThatEquivalentDeepestMenuFirst() throws {
        let builder = MenuBuilder(settings: Settings())
        let item = ClipItem.text("hello")
        let actions = builder.contextMenu(for: item, target: self, actions: MenuBuilder.ContextActions(
            paste: #selector(noop), pastePlain: #selector(noop), copyOnly: #selector(noop), transform: #selector(noop),
            pin: #selector(noop), reveal: #selector(noop), delete: #selector(noop)), latestMods: HotKey.controlOption)
        let trim = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "w", flags: ctrlOpt, in: [actions]))
        XCTAssertTrue(trim.title.contains(TextTransform.trim.title))
        XCTAssertFalse(trim.isHidden)
        let shifted = try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "w", flags: [.control, .option, .shift], in: [actions]))
        XCTAssertTrue(shifted.isHidden, "the hidden ⇧ copy is an item like any other")
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "w", flags: [.option], in: [actions]), "the modifiers must match exactly")
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "q", flags: ctrlOpt, in: [actions]))

        // Attached submenus are searched; an outer menu is searched after the deeper one passed first.
        let root = NSMenu()
        let row = NSMenuItem(title: "row", action: #selector(noop), keyEquivalent: "w")
        row.keyEquivalentModifierMask = ctrlOpt
        row.target = self
        root.addItem(row)
        let holder = NSMenuItem(title: "holder", action: nil, keyEquivalent: "")
        holder.submenu = actions
        root.addItem(holder)
        XCTAssertTrue(try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "w", flags: ctrlOpt, in: [actions, root])) === trim)
        XCTAssertTrue(try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "w", flags: ctrlOpt, in: [root])) === row)
        XCTAssertTrue(try XCTUnwrap(MenuBuilder.item(forKeyEquivalent: "u", flags: ctrlOpt, in: [root])).title.contains(TextTransform.upper.title), "found through the attached submenu")

        let disabled = NSMenuItem(title: "off", action: #selector(noop), keyEquivalent: "x")
        disabled.keyEquivalentModifierMask = ctrlOpt
        disabled.isEnabled = false
        root.addItem(disabled)
        XCTAssertNil(MenuBuilder.item(forKeyEquivalent: "x", flags: ctrlOpt, in: [root]), "a disabled item does not answer")
    }

    // MARK: The routing

    func testNoMenuOpenMeansTheHotKeyRunsAsUsual() {
        let a = app()
        XCTAssertFalse(a.routeHotKeyWhileMenuOpen(HotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: HotKey.controlOption)))
        XCTAssertFalse(a.routeHotKeyWhileMenuOpen(.optionM))
    }

    func testDigitWithTheHistoryMenuOpenPastesThatRowOnce() {
        let a = app()
        a.history.add(.text("older"))
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)
        defer { a.menuDidClose(menu) }

        XCTAssertTrue(a.routeHotKeyWhileMenuOpen(HotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: HotKey.controlOption)))
        spin()
        XCTAssertEqual(pasted.map(\.plainText), ["older"], "⌃⌥2 is row 2, pasted once")
    }

    func testLatestActionWithTheHistoryMenuOpenAndNoSubmenuActsOnTheLatestItem() {
        let a = app()
        a.history.add(.text("older"))
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        XCTAssertTrue(menu.items.allSatisfy { $0.submenu == nil || $0.tag != MenuBuilder.historyTag }, "no extended menu attached (⇧ not held)")
        a.menuWillOpen(menu)
        defer { a.menuDidClose(menu) }

        XCTAssertTrue(a.routeHotKeyWhileMenuOpen(HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: HotKey.controlOption)))
        spin()
        XCTAssertEqual(pasted.map(\.plainText), ["latest"], "⌃⌥V: the latest item as plain text, once")
    }

    func testTheOpeningCombinationClosesTheMenuAndUnknownOnesAreDropped() {
        let a = app()
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)

        XCTAssertTrue(a.routeHotKeyWhileMenuOpen(.optionM), "handled: the menu closes")
        XCTAssertTrue(a.routeHotKeyWhileMenuOpen(HotKey.option(kVK_ANSI_S)), "Settings is not in the popup menu: dropped, not run")
        spin()
        XCTAssertEqual(pasted.count, 0)
        XCTAssertNil(a.settingsWindowForTesting)

        a.menuDidClose(menu)
        XCTAssertFalse(a.routeHotKeyWhileMenuOpen(.optionM), "closed: back to the global behaviour")
    }

    func testTheDeepestOpenMenuAnswersFirst() throws {
        let a = app()
        a.history.add(.text("older"))
        a.history.add(.text("latest"))
        let menu = a.buildHistoryMenu(includeTemplates: false, includeApp: false)
        a.menuWillOpen(menu)
        // The extended menu of the *older* row is open (⇧ held, then hovered): its entries show no
        // shortcuts (not the latest item), so ⌃⌥U falls through to the latest item's actions.
        let olderRow = try XCTUnwrap(menu.items.first { $0.tag == MenuBuilder.historyTag && ($0.representedObject as? UUID) == a.history.items[1].id })
        let olderId = try XCTUnwrap(olderRow.representedObject as? UUID)
        let sub = try XCTUnwrap(a.actionMenu(for: olderId))
        olderRow.submenu = sub
        a.menuWillOpen(sub)
        defer { a.menuDidClose(sub); a.menuDidClose(menu) }

        XCTAssertTrue(a.routeHotKeyWhileMenuOpen(HotKey(keyCode: UInt32(kVK_ANSI_U), modifiers: HotKey.controlOption)))
        spin()
        XCTAssertEqual(pasted.map(\.plainText), ["LATEST"], "UPPERCASE of the latest item, once")
    }

    @objc func noop() {}
}
