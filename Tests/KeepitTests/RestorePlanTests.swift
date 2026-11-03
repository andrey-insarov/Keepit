import XCTest
@testable import Keepit

/// The restore transaction is planned before anything changes (docs/BACKUP.md "Restore", 5–6).
/// These tests pin the plan's rules; `AppDelegate.apply(_:)` is a handful of assignments on top.
final class RestorePlanTests: XCTestCase {
    private var tmp: TempStorage!
    override func setUp() { tmp = TempStorage() }
    override func tearDown() { tmp.restore() }

    private func settings(historyMax: Int = 1000) -> Settings {
        var s = Settings()
        s.historySave = false
        s.historyMax = historyMax
        return s
    }

    private func tree(_ items: [TemplateNode]) -> TemplateNode { TemplateNode(name: "Template", children: items) }

    // The auditor's chain: Export → open → Merge into the same store → Export again must open.
    // Imported templates and items come back under fresh ids, so nothing is duplicated.
    func testMergingOwnBackupKeepsTheNextBackupValid() throws {
        let a = ClipItem.text("alpha"), b = ClipItem.text("beta")
        let store = TemplateStore()
        store.replaceRoot(tree([TemplateNode(name: "F", children: [TemplateNode(name: "One", text: "1")]), TemplateNode(name: "Two", text: "2")]))
        let exported = Backup.Payload(history: [a, b], templates: store.root, settings: nil)
        let bytes = try Backup.encode(exported, password: SecureBuffer.of("pw"))
        let opened = try Backup.decode(bytes, password: SecureBuffer.of("pw"))

        // Meanwhile item `b` was edited here: same id, different content.
        var edited = b
        edited.formats[ClipItem.Format.text] = Data("beta v2".utf8)
        edited.contentHash = ClipItem.hash(of: Data("beta v2".utf8))
        let current = [edited, a]

        let plan = try RestorePlan.make(mode: .merge, payload: opened, currentHistory: current, currentTemplates: store.root,
                                        currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(plan.historyAdded, 1)                       // only the old "beta"
        XCTAssertEqual(plan.history.map(\.plainText), ["beta v2", "alpha", "beta"])
        XCTAssertEqual(Set(plan.history.map(\.id)).count, 3)         // the merged "beta" has a new id
        guard case .addFolder(let folder) = plan.templates else { return XCTFail("merge adds a folder") }
        XCTAssertTrue(store.insertImported(folder))
        let again = Backup.Payload(history: plan.history, templates: store.root, settings: nil)
        XCTAssertNoThrow(try Backup.validate(again))
        let bytes2 = try Backup.encode(again, password: SecureBuffer.of("pw"))
        XCTAssertNoThrow(try Backup.decode(bytes2, password: SecureBuffer.of("pw")))
        XCTAssertEqual(store.root.subtreeCount, 1 + 3 + 4)          // root + original 3 + folder with 3
    }

    func testMergeDropsImportedHotKeysReplaceKeepsThem() throws {
        let hk = HotKey(keyCode: 9, modifiers: 256)
        let item = TemplateNode(name: "Hot", text: "h"); item.hotKey = hk
        let payload = Backup.Payload(history: [], templates: tree([item]), settings: nil)
        let merge = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: [], currentTemplates: tree([]),
                                         currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        guard case .addFolder(let folder) = merge.templates else { return XCTFail() }
        XCTAssertNil(folder.children[0].hotKey)
        XCTAssertNotEqual(folder.children[0].id, item.id)
        XCTAssertEqual(merge.templatesAdded, 2)                     // the folder and the item
        let replace = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [], currentTemplates: tree([]),
                                           currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        guard case .replace(let root) = replace.templates else { return XCTFail() }
        XCTAssertEqual(root.children[0].hotKey, hk)
        XCTAssertEqual(root.children[0].id, item.id)
        XCTAssertEqual(replace.templatesAdded, 1)
    }

    // The limits in force after the restore decide what fits — not the ones before it.
    func testRestoredSettingsGovernTheHistoryLimit() throws {
        var backupSettings = Settings()
        backupSettings.historyMax = 3
        let three = [ClipItem.text("1"), ClipItem.text("2"), ClipItem.text("3")]
        let payload = Backup.Payload(history: three, templates: tree([]), settings: backupSettings)
        let withPrefs = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [ClipItem.text("old")], currentTemplates: tree([]),
                                             currentSettings: settings(historyMax: 1), restorePreferences: true, folderName: "Imported")
        XCTAssertEqual(withPrefs.history.count, 3)
        XCTAssertEqual(withPrefs.settings.historyMax, 3)
        XCTAssertEqual(withPrefs.historyDropped, 0)
        let withoutPrefs = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [ClipItem.text("old")], currentTemplates: tree([]),
                                                currentSettings: settings(historyMax: 1), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(withoutPrefs.history.count, 1)
        XCTAssertEqual(withoutPrefs.historyDropped, 2)
        XCTAssertEqual(withoutPrefs.settings.historyMax, 1)
        // Merge counts only the new items that survived the trim.
        let merged = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: [ClipItem.text("old")], currentTemplates: tree([]),
                                          currentSettings: settings(historyMax: 2), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(merged.history.map(\.plainText), ["old", "1"])
        XCTAssertEqual(merged.historyAdded, 1)
        XCTAssertEqual(merged.historyDropped, 2)
    }

    func testRestoredSettingsNeverCarryTrustOrBackupSetup() throws {
        var backupSettings = Settings()
        backupSettings.allowURLCommands = true
        backupSettings.backupEnabled = true
        backupSettings.historyMax = Limits.historyMaxCeiling * 10     // clamped when applied
        let payload = Backup.Payload(history: [], templates: tree([]), settings: backupSettings)
        let plan = try RestorePlan.make(mode: .replace, payload: payload, currentHistory: [], currentTemplates: tree([]),
                                        currentSettings: settings(), restorePreferences: true, folderName: "Imported")
        XCTAssertFalse(plan.settings.allowURLCommands)
        XCTAssertFalse(plan.settings.backupEnabled)
        XCTAssertEqual(plan.settings.historyMax, Limits.historyMaxCeiling)
    }

    // A Merge that would exceed the template ceilings is refused as a whole; a plan is never partial.
    func testMergeRefusesWhenTheFolderWouldNotFit() throws {
        // Depth: the backup's deepest node is at depth templateMaxDepth; under the new folder it would be one deeper.
        var deep = TemplateNode(name: "leaf", text: "x")
        for i in 0..<(Limits.templateMaxDepth - 1) { deep = TemplateNode(name: "d\(i)", children: [deep]) }
        let tooDeep = Backup.Payload(history: [], templates: tree([deep]), settings: nil)
        XCTAssertNoThrow(try Backup.validate(tooDeep))               // fine as a backup on its own
        XCTAssertThrowsError(try RestorePlan.make(mode: .merge, payload: tooDeep, currentHistory: [], currentTemplates: tree([]),
                                                  currentSettings: settings(), restorePreferences: false, folderName: "Imported"))
        XCTAssertNoThrow(try RestorePlan.make(mode: .replace, payload: tooDeep, currentHistory: [], currentTemplates: tree([]),
                                              currentSettings: settings(), restorePreferences: false, folderName: "Imported"))
        // Count: current + folder + imported must stay within the ceiling.
        let many = tree((0..<10).map { TemplateNode(name: "t\($0)", text: "t") })
        let current = tree((0..<(Limits.templateMaxCount - 11)).map { TemplateNode(name: "c\($0)", text: "c") })
        XCTAssertThrowsError(try RestorePlan.make(mode: .merge, payload: Backup.Payload(history: [], templates: many, settings: nil),
                                                  currentHistory: [], currentTemplates: current,
                                                  currentSettings: settings(), restorePreferences: false, folderName: "Imported")) {
            XCTAssertEqual($0 as? RestorePlan.Failure, .templateLimit)
        }
        let smaller = tree((0..<(Limits.templateMaxCount - 12)).map { TemplateNode(name: "c\($0)", text: "c") })
        XCTAssertNoThrow(try RestorePlan.make(mode: .merge, payload: Backup.Payload(history: [], templates: many, settings: nil),
                                              currentHistory: [], currentTemplates: smaller,
                                              currentSettings: settings(), restorePreferences: false, folderName: "Imported"))
    }

    func testMergeSkipsDuplicateContentAndKeepsCurrentNewest() throws {
        let shared = ClipItem.text("same")
        let payload = Backup.Payload(history: [ClipItem.text("same"), ClipItem.text("new")], templates: tree([]), settings: nil)
        let plan = try RestorePlan.make(mode: .merge, payload: payload, currentHistory: [ClipItem.text("mine"), shared], currentTemplates: tree([]),
                                        currentSettings: settings(), restorePreferences: false, folderName: "Imported")
        XCTAssertEqual(plan.history.map(\.plainText), ["mine", "same", "new"])
        XCTAssertEqual(plan.history[1].id, shared.id)                // the current copy stays, untouched
        XCTAssertEqual(plan.historyAdded, 1)
    }

    func testTrimmedIsTheStoreRule() {
        var s = settings(historyMax: 2)
        s.historyImageMax = 1
        let items = [ClipItem.text("a"), ClipItem.text("b"), ClipItem.text("c")]
        XCTAssertEqual(HistoryStore.trimmed(items, settings: s).map(\.plainText), ["a", "b"])
        s.historyMaxAge = 60
        let old = ClipItem(id: UUID(), date: Date(timeIntervalSinceNow: -120), formats: [ClipItem.Format.text: Data("z".utf8)],
                           sourceApp: nil, contentHash: ClipItem.hash(of: Data("z".utf8)))
        XCTAssertEqual(HistoryStore.trimmed([old] + items, settings: s).map(\.plainText), ["a", "b"])
    }
}
