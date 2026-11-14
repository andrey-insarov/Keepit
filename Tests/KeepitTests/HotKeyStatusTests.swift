import Carbon
import XCTest
@testable import Keepit

/// Stage 2 of claude/keepit-hotkey-layouts-design.md: the filter in registerHotKeys(), the per-shortcut
/// status, the user's recorded choice, and the layout-change observer's guards. Hand-built layouts and a
/// registration override: the test process never holds a system hot key.
final class HotKeyStatusTests: XCTestCase {
    var tmp: TempStorage!
    let OPT = UInt32(optionKey)

    override func setUpWithError() throws {
        tmp = TempStorage()
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
    }
    override func tearDown() {
        tmp.restore()
    }

    // MARK: Fixtures

    struct Fake: LayoutReading {
        struct Key: Hashable { let code: UInt16; let mods: UInt32; let dead: UInt32 }
        var id: String, name: String, languages: [String]
        var map: [Key: KeyOutput] = [:]
        func enabledLayouts() -> [LayoutInfo] {
            let map = self.map
            return [LayoutInfo(id: id, name: name, languages: languages, translate: { map[Key(code: $0, mods: $1, dead: $2)] ?? .nothing })]
        }
        mutating func set(_ code: Int, mods: UInt32 = 0, dead: UInt32 = 0, _ out: KeyOutput) {
            map[Key(code: UInt16(code), mods: mods, dead: dead)] = out
        }
        /// a–z on their US positions.
        static func latin(id: String, name: String, lang: String) -> Fake {
            var f = Fake(id: id, name: name, languages: [lang])
            for (i, c) in "abcdefghijklmnopqrstuvwxyz".enumerated() {
                let codes = [kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I,
                             kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R,
                             kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y, kVK_ANSI_Z]
                f.set(codes[i], .characters(String(c)))
                f.set(codes[i], mods: UInt32(shiftKey), .characters(String(c).uppercased()))
            }
            f.set(kVK_Space, .characters(" "))
            return f
        }
    }

    /// German as the probe sees it: ⌥L @, ⌥E €, ⌥N dead ~ with no plain ~; ⌥M µ, ⌥P π are harmless.
    func german() -> Fake {
        var f = Fake.latin(id: "de", name: "German", lang: "de")
        f.set(kVK_ANSI_L, mods: OPT, .characters("@"))
        f.set(kVK_ANSI_E, mods: OPT, .characters("€"))
        f.set(kVK_ANSI_N, mods: OPT, .deadKey(1))
        f.set(kVK_Space, dead: 1, .characters("~"))
        f.set(kVK_ANSI_M, mods: OPT, .characters("µ"))
        f.set(kVK_ANSI_P, mods: OPT, .characters("π"))
        return f
    }
    /// Russian as the probe sees it for the one thing that matters here: ⌥M types ~ and nothing else does.
    func russian() -> Fake {
        var f = Fake.latin(id: "ru", name: "Russian", lang: "ru")
        f.set(kVK_ANSI_M, mods: OPT, .characters("~"))
        return f
    }
    func us() -> Fake { Fake.latin(id: "us", name: "U.S.", lang: "en") }

    func makeApp(_ layout: Fake, register: @escaping (HotKey) -> Bool = { _ in true }) -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.hotKeyFailureForTesting = { _ in }
        a.hotKeys.registrationOverrideForTesting = register
        a.layoutReaderForTesting = layout
        return a
    }

    func status(_ a: AppDelegate, _ id: HotKeyID) throws -> HotKeyStatus { try XCTUnwrap(a.hotKeyStatuses[id]) }

    // MARK: The decision (pure)

    func testDefaultsALayoutNeedsAreSkippedUnlessChosenOrChanged() {
        let probe = LayoutProbe(reader: german())
        var s = Settings()
        var d = HotKeyStatus.decide(s, probe: probe)
        XCTAssertEqual(d[.lock], .init(layout: .needed(layout: "German", types: "@"), incomplete: 0, errors: 0, skip: true))
        XCTAssertEqual(d[.viewer]?.skip, true)      // ⌥E = €
        XCTAssertEqual(d[.queue]?.skip, true)       // ⌥N = dead ~
        XCTAssertEqual(d[.pause], .init(layout: .notNeeded, incomplete: 0, errors: 0, skip: false))
        XCTAssertEqual(d[.history]?.skip, false)
        XCTAssertNil(d[.numbers]); XCTAssertNil(d[.latest])   // families are not checked

        s.chosenHotKeys = ["lock"]                                     // recorded, even though equal to the default
        d = HotKeyStatus.decide(s, probe: probe)
        XCTAssertEqual(d[.lock], .init(layout: .needed(layout: "German", types: "@"), incomplete: 0, errors: 0, skip: false))

        s = Settings(); s.lockHotKey = HotKey.option(kVK_ANSI_E)       // the user's own value happens to type €
        d = HotKeyStatus.decide(s, probe: probe)
        XCTAssertEqual(d[.lock]?.skip, false, "a changed value is the user's, whatever it types")
        XCTAssertEqual(d[.lock]?.layout, .needed(layout: "German", types: "€"))

        s = Settings(); s.lockHotKey = nil
        XCTAssertNil(HotKeyStatus.decide(s, probe: probe)[.lock])
    }

    func testRequiredDefaultIsNeverSkippedButItsVerdictIsKept() {
        let d = HotKeyStatus.decide(Settings(), probe: LayoutProbe(reader: russian()))
        XCTAssertEqual(d[.history], .init(layout: .needed(layout: "Russian", types: "~"), incomplete: 0, errors: 0, skip: false))
        XCTAssertEqual(d[.template]?.skip, false)
    }

    func testUncheckedLayoutDoesNotSkip() {
        let d = HotKeyStatus.decide(Settings(), probe: LayoutProbe(reader: Unreadable()))
        XCTAssertEqual(d[.lock], .init(layout: .unchecked(failed: ["x"]), incomplete: 0, errors: 0, skip: false))
    }

    func testControlOrCommandCombinationsAreNotALayoutQuestion() throws {
        // German ⌥E types €; the user's ⌃⌥E or ⌘⌥E do not, whatever the layout table says for them.
        var f = german()
        f.set(kVK_ANSI_E, mods: OPT | UInt32(controlKey), .characters("€"))      // what UCKeyTranslate would answer
        f.set(kVK_ANSI_E, mods: OPT | UInt32(cmdKey), .characters("€"))
        var s = Settings()
        XCTAssertEqual(HotKeyStatus.decide(s, probe: LayoutProbe(reader: f))[.viewer]?.layout, .needed(layout: "German", types: "€"))
        s.viewerHotKey = HotKey(keyCode: UInt32(kVK_ANSI_E), modifiers: OPT | UInt32(controlKey))
        XCTAssertEqual(HotKeyStatus.decide(s, probe: LayoutProbe(reader: f))[.viewer], .init(layout: .notApplicable, incomplete: 0, errors: 0, skip: false))
        s.viewerHotKey = HotKey(keyCode: UInt32(kVK_ANSI_E), modifiers: OPT | UInt32(cmdKey))
        XCTAssertEqual(HotKeyStatus.decide(s, probe: LayoutProbe(reader: f))[.viewer]?.layout, .notApplicable)
        let a = makeApp(f)
        a.apply(settings: s)
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .viewer), HotKeyStatus(layout: .notApplicable, registration: .registered))
        XCTAssertEqual(try status(a, .numbers).layout, .notApplicable)
    }

    func testAFailedLayoutReadIsKeptNextToTheVerdict() throws {
        // One plain key could not be read, and ⌥L still types @: the default is skipped and the error travels
        // with the status, so the log can say the verdict may have missed an alternative route.
        var f = german()
        f.set(kVK_ANSI_X, .error)
        let d = HotKeyStatus.decide(Settings(), probe: LayoutProbe(reader: f))
        XCTAssertEqual(d[.lock], .init(layout: .needed(layout: "German", types: "@"), incomplete: 0, errors: 1, skip: true))
        XCTAssertEqual(d[.pause], .init(layout: .unchecked(failed: ["de"]), incomplete: 0, errors: 1, skip: false))
        let a = makeApp(f)
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .lock), HotKeyStatus(layout: .needed(layout: "German", types: "@"), errors: 1, registration: .skipped))
        XCTAssertEqual(try status(a, .pause), HotKeyStatus(layout: .unchecked(failed: ["de"]), errors: 1, registration: .registered))
    }
    private struct Unreadable: LayoutReading {
        func enabledLayouts() -> [LayoutInfo] { [LayoutInfo(id: "x", name: "Broken", languages: ["en"], translate: nil)] }
    }

    // MARK: Settings

    func testChosenHotKeysIsAbsentInOldFilesAndRoundTrips() throws {
        let old = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        XCTAssertEqual(old.chosenHotKeys, [])
        var s = Settings(); s.chosenHotKeys = ["lock", "queue"]
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.chosenHotKeys, ["lock", "queue"])
        var junk = Settings(); junk.chosenHotKeys = ["lock", "not-a-shortcut"]
        junk.clamp()
        XCTAssertEqual(junk.chosenHotKeys, ["lock"])
    }

    func testChosenHotKeysTravelsWithABackup() {
        var s = Settings(); s.chosenHotKeys = ["lock"]
        XCTAssertEqual(s.forBackup.chosenHotKeys, ["lock"])
        XCTAssertEqual(Settings().applyingRestorable(from: s).chosenHotKeys, ["lock"])
    }

    // MARK: registerHotKeys()

    func testStatusesAfterRegistrationOnGerman() throws {
        let a = makeApp(german())
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .lock), HotKeyStatus(layout: .needed(layout: "German", types: "@"), registration: .skipped))
        XCTAssertEqual(try status(a, .viewer).registration, .skipped)
        XCTAssertEqual(try status(a, .queue).registration, .skipped)
        XCTAssertEqual(try status(a, .history), .registered)
        XCTAssertEqual(try status(a, .pause), .registered)
        XCTAssertEqual(try status(a, .numbers), HotKeyStatus(layout: .notApplicable, registration: .registered))
        XCTAssertEqual(try status(a, .latest), HotKeyStatus(layout: .notApplicable, registration: .registered))
        XCTAssertNil(a.activeHotKey(.lock), "a skipped shortcut shows in no menu")
        XCTAssertEqual(a.activeHotKey(.pause), HotKey.option(kVK_ANSI_P))
        XCTAssertEqual(a.activeModifiers(.numbers), HotKey.controlOption)
    }

    func testRecordingTheDefaultAgainRegistersItInTheSameApply() throws {
        let a = makeApp(german())
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .lock).registration, .skipped)
        var s = a.settings
        s.chosenHotKeys.insert("lock")          // what hotKeyChanged does after the conflict check; no other field moves
        a.apply(settings: s)
        XCTAssertEqual(try status(a, .lock), HotKeyStatus(layout: .needed(layout: "German", types: "@"), registration: .registered))
        XCTAssertEqual(a.activeHotKey(.lock), HotKey.option(kVK_ANSI_L))
        s.chosenHotKeys.remove("lock")
        a.apply(settings: s)
        XCTAssertEqual(try status(a, .lock).registration, .skipped)
    }

    func testOffAndChangedAndRequired() throws {
        var a = makeApp(german())
        var s = a.settings
        s.lockHotKey = nil
        s.viewerHotKey = HotKey.option(kVK_ANSI_K)
        a.apply(settings: s)
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .lock), .off)
        XCTAssertEqual(try status(a, .viewer), .registered)
        a = makeApp(russian())
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .history), HotKeyStatus(layout: .needed(layout: "Russian", types: "~"), registration: .registered))
        XCTAssertEqual(a.activeHotKey(.history), HotKey.optionM)
    }

    func testAFailedRegistrationIsItsOwnStateAndStillReported() throws {
        var failed: [String] = []
        let a = makeApp(us()) { $0 != HotKey.option(kVK_ANSI_P) && $0 != HotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: HotKey.controlOption) }
        a.hotKeyFailureForTesting = { failed = $0 }
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .pause), HotKeyStatus(layout: .notNeeded, registration: .failed))
        XCTAssertNil(a.activeHotKey(.pause))
        XCTAssertEqual(try status(a, .numbers).registration, .failed, "a family is live only when every member is")
        XCTAssertNil(a.activeModifiers(.numbers))
        XCTAssertEqual(try status(a, .lock), .registered)
        XCTAssertTrue(failed.contains(HotKey.option(kVK_ANSI_P).displayString))
        XCTAssertTrue(failed.contains(HotKey(keyCode: UInt32(kVK_ANSI_1), modifiers: HotKey.controlOption).displayString))
    }

    func testNothingIsSkippedOnUS() throws {
        let a = makeApp(us())
        a.registerHotKeys()
        for id in HotKeyID.checked { XCTAssertEqual(try status(a, id), .registered, "\(id)") }
        XCTAssertEqual(try status(a, .numbers).registration, .registered)
    }

    // MARK: Lock and the observer

    func testLockSuspendsAndMenusShowNothing() throws {
        let a = makeApp(german())
        a.createBackupEngine()
        Storage.key = try Vault.enable(password: .of("test-only"), rounds: 1000)
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .pause).registration, .registered)
        a.lock()
        XCTAssertEqual(try status(a, .pause).registration, .suspended)
        XCTAssertEqual(try status(a, .lock).registration, .skipped, "a skipped one stays skipped")
        XCTAssertNil(a.activeHotKey(.pause)); XCTAssertNil(a.activeModifiers(.numbers))
        // A layout change while locked is held back: unlock() re-registers afresh.
        a.applyLayoutChange()
        XCTAssertTrue(a.layoutsChangedWhileBusy)
        XCTAssertEqual(try status(a, .pause).registration, .suspended)
    }

    func testLayoutChangeDuringARestoreIsAppliedAtItsExit() throws {
        var registrations = 0
        let a = makeApp(german()) { _ in registrations += 1; return true }
        a.registerHotKeys()
        let before = registrations
        a.restoreInProgress = true
        a.applyLayoutChange()
        XCTAssertTrue(a.layoutsChangedWhileBusy)
        XCTAssertEqual(registrations, before, "nothing re-registered while the restore runs")
        a.restoreInProgress = false
        a.recheckLayoutsIfChanged()          // what restore(from:)'s defer calls, committed or not
        XCTAssertFalse(a.layoutsChangedWhileBusy)
        XCTAssertGreaterThan(registrations, before)
        a.recheckLayoutsIfChanged()
        XCTAssertEqual(a.layoutsChangedWhileBusy, false, "nothing pending, nothing to do")
    }

    func testLayoutChangeWithNothingInTheWayReRegistersAtOnce() throws {
        var registrations = 0
        let a = makeApp(german()) { _ in registrations += 1; return true }
        a.registerHotKeys()
        let before = registrations
        a.applyLayoutChange()
        XCTAssertGreaterThan(registrations, before)
        XCTAssertFalse(a.layoutsChangedWhileBusy)
        a.uninstalling = true
        a.applyLayoutChange()
        XCTAssertFalse(a.layoutsChangedWhileBusy, "an uninstall tears everything down; nothing is remembered")
    }

    // MARK: Settings → Shortcuts (stage 3)

    func testNotesSayWhyAShortcutIsLeftFreeOrWhatItTakes() throws {
        let a = makeApp(german())
        a.registerHotKeys()
        let w = SettingsWindowController(app: a)
        defer { w.window?.close() }
        let lock = w.hotKeyNoteText(.lock)
        XCTAssertTrue(lock.contains("@") && lock.contains("German") && lock.contains(HotKey.option(kVK_ANSI_L).displayString), lock)
        XCTAssertTrue(lock.contains("leaves it free"), lock)
        XCTAssertEqual(w.hotKeyNoteText(.pause), "", "nothing to say about ⌥P")
        XCTAssertEqual(w.hotKeyNoteText(.numbers), "")
        var s = a.settings; s.chosenHotKeys.insert("lock")
        a.apply(settings: s)
        XCTAssertTrue(w.hotKeyNoteText(.lock).contains("While Keepit runs"), w.hotKeyNoteText(.lock))
        let r = makeApp(russian())
        r.registerHotKeys()
        let rw = SettingsWindowController(app: r)
        defer { rw.window?.close() }
        XCTAssertTrue(rw.hotKeyNoteText(.history).contains("Keepit needs this shortcut"), rw.hotKeyNoteText(.history))
        let u = makeApp(us())
        u.registerHotKeys()
        let uw = SettingsWindowController(app: u)
        defer { uw.window?.close() }
        for id in HotKeyID.allCases { XCTAssertEqual(uw.hotKeyNoteText(id), "", "\(id)") }
    }

    func testShortcutsPaneWithNotesStaysInsideTheWindow() throws {
        let a = makeApp(german())
        a.registerHotKeys()
        let w = SettingsWindowController(app: a)
        let window = try XCTUnwrap(w.window)
        defer { window.close() }
        w.showPaneForTesting("shortcuts")
        let content = try XCTUnwrap(window.contentView)
        window.layoutIfNeeded(); content.layoutSubtreeIfNeeded()
        var shownNotes = 0
        for f in Self.descendants(content).compactMap({ $0 as? NSTextField }) where !f.isHidden && f.window != nil {
            let r = content.convert(f.bounds, from: f)
            XCTAssertLessThanOrEqual(r.maxX, content.bounds.maxX + 1, "\(f.stringValue.prefix(40)) \(r)")
            if f.stringValue.contains("leaves it free") { shownNotes += 1 }
        }
        XCTAssertEqual(shownNotes, 2, "⌥L and ⌥E on German; ⌥N is on the Paste Queue pane")
        // The layout goes away: the notes with it, and the rows collapse.
        a.layoutReaderForTesting = us()
        a.applyLayoutChange()
        XCTAssertEqual(Self.descendants(content).compactMap({ $0 as? NSTextField }).filter { !$0.isHidden && $0.stringValue.contains("leaves it free") }.count, 0)
    }

    static func descendants(_ v: NSView) -> [NSView] { v.subviews + v.subviews.flatMap(descendants) }

    func testLatestActionsHintNamesTheKeys() {
        let hint = SettingsWindowController.latestActionsHint()
        XCTAssertTrue(hint.contains("V plain text") && hint.contains("A add to Templates"), hint)
        XCTAssertFalse(hint.contains("%@"))
    }

    func testRemovingTheLayoutBringsTheDefaultBack() throws {
        let a = makeApp(german())
        a.registerHotKeys()
        XCTAssertEqual(try status(a, .lock).registration, .skipped)
        a.layoutReaderForTesting = us()      // the user removed German
        a.applyLayoutChange()
        XCTAssertEqual(try status(a, .lock), .registered)
    }
}
