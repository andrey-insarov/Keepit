import AppKit
import XCTest
@testable import Keepit

/// The history menu as it is built for a reopen after Delete. Showing a menu is synchronous
/// (`popUp` returns when it has closed), so whatever the reopen wants the user to see must be in
/// the menu before the show — the auditor's P2 on 3.0.2: the search text was applied afterwards
/// and the reopened menu listed everything.
final class HistoryMenuTests: XCTestCase {
    private func app(with texts: [String]) throws -> (AppDelegate, TempStorage) {
        _ = NSApplication.shared
        let storage = TempStorage()
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
        let app = AppDelegate()
        app.loadStoresForTesting()
        for t in texts.reversed() { app.history.add(.text(t)) }
        return (app, storage)
    }

    private func rows(_ menu: NSMenu) -> [NSMenuItem] { menu.items.filter { $0.tag == MenuBuilder.historyTag } }

    func testMenuBuiltWithAQueryIsAlreadyFiltered() throws {
        let (app, storage) = try app(with: ["apple pie", "banana", "apple juice"])
        defer { storage.restore() }
        let menu = app.buildHistoryMenu(includeTemplates: true, includeApp: true, query: "apple")
        let search = try XCTUnwrap(menu.items.first as? MenuSearchItem)
        XCTAssertEqual(search.field.stringValue, "apple", "the field shows the text that was typed before Delete")
        let shown = rows(menu)
        XCTAssertEqual(shown.count, 2)
        XCTAssertTrue(shown.allSatisfy { $0.title.localizedCaseInsensitiveContains("apple") }, shown.map(\.title).description)
        XCTAssertFalse(menu.items.contains { $0.title.contains("banana") })
        // Everything below the rows is still there — the reopen is the same menu, only filtered.
        XCTAssertTrue(menu.items.contains { $0.title == L("Template") })
        XCTAssertTrue(menu.items.contains { $0.title == L("Lock Keepit") })
    }

    func testMenuBuiltWithoutAQueryListsEverything() throws {
        let (app, storage) = try app(with: ["apple pie", "banana", "apple juice"])
        defer { storage.restore() }
        let menu = app.buildHistoryMenu(includeTemplates: false, includeApp: false)
        XCTAssertEqual(rows(menu).count, 3)
        XCTAssertEqual((menu.items.first as? MenuSearchItem)?.field.stringValue, "")
    }

    func testQueryWithNoMatchShowsTheNoMatchesRow() throws {
        let (app, storage) = try app(with: ["apple pie", "banana"])
        defer { storage.restore() }
        let menu = app.buildHistoryMenu(includeTemplates: false, includeApp: false, query: "zzz")
        let shown = rows(menu)
        XCTAssertEqual(shown.count, 1)
        XCTAssertFalse(shown[0].isEnabled)
        XCTAssertEqual(shown[0].title, L("(no matches)"))
    }
}
