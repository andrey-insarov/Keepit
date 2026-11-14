import Carbon
import XCTest
@testable import Keepit

/// Stage 4 of claude/keepit-hotkey-layouts-design.md (H-6): key names and menu key equivalents follow the
/// current layout. Hand-built layouts through `KeyCodes.currentLayoutForTesting`; nothing here reads the
/// machine's layouts.
final class KeyCodesLayoutTests: XCTestCase {
    struct Fake {
        struct Key: Hashable { let code: UInt16; let mods: UInt32; let dead: UInt32 }
        var id: String
        var map: [Key: KeyOutput] = [:]
        mutating func set(_ code: Int, dead: UInt32 = 0, _ out: KeyOutput) { map[Key(code: UInt16(code), mods: 0, dead: dead)] = out }
        var info: LayoutInfo {
            let map = self.map
            return LayoutInfo(id: id, name: id, languages: ["xx"], translate: { map[Key(code: $0, mods: $1, dead: $2)] ?? .nothing })
        }
    }

    override func tearDown() {
        KeyCodes.currentLayoutForTesting = nil
        KeyCodes.invalidateLayoutCache()
    }

    func use(_ f: Fake) {
        let info = f.info
        KeyCodes.currentLayoutForTesting = { info }
        KeyCodes.invalidateLayoutCache()
    }

    func azerty() -> Fake {
        var f = Fake(id: "fr")
        f.set(kVK_ANSI_A, .characters("q")); f.set(kVK_ANSI_Q, .characters("a"))
        f.set(kVK_ANSI_W, .characters("z")); f.set(kVK_ANSI_Z, .characters("w"))
        f.set(kVK_ANSI_M, .characters(",")); f.set(kVK_ANSI_Semicolon, .characters("m"))
        f.set(kVK_ANSI_1, .characters("&")); f.set(kVK_ANSI_2, .characters("é"))
        f.set(kVK_ANSI_V, .characters("v"))
        return f
    }
    func qwertz() -> Fake {
        var f = Fake(id: "de")
        f.set(kVK_ANSI_Y, .characters("z")); f.set(kVK_ANSI_Z, .characters("y"))
        f.set(kVK_ANSI_Minus, .characters("ß"))
        f.set(kVK_ANSI_LeftBracket, .deadKey(5)); f.set(kVK_Space, dead: 5, .characters("^"))   // the ^ dead key
        f.set(kVK_ANSI_L, .characters("l"))
        return f
    }

    func testNamesFollowTheLayout() {
        use(azerty())
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_A)), "Q")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_W)), "Z")
        XCTAssertEqual(HotKey.option(kVK_ANSI_M).displayString, "⌥,")
        XCTAssertEqual(HotKey.option(kVK_ANSI_Semicolon).displayString, "⌥M")
        use(qwertz())
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_Y)), "Z")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_Z)), "Y")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_Minus)), "ß", "uppercasing ß gives SS, two characters: the label stays ß")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_LeftBracket)), "^", "a dead key is named by its own character")
    }

    func testMenuKeyEquivalentsFollowTheLayoutAndStayLowercase() {
        use(azerty())
        XCTAssertEqual(KeyCodes.menuCharacter(for: UInt16(kVK_ANSI_A)), "q")
        XCTAssertEqual(KeyCodes.menuCharacter(for: UInt16(kVK_ANSI_M)), ",")
        XCTAssertEqual(KeyCodes.menuCharacter(for: UInt16(kVK_ANSI_1)), "&")
        XCTAssertEqual(HotKey.option(kVK_ANSI_M).menuKeyEquivalent?.key, ",")
        XCTAssertEqual(HotKey.LatestAction.trim.keyChar, "z", "⌃⌥W is on the physical W key, which types z on AZERTY")
        XCTAssertEqual(HotKey.LatestAction.plain.keyChar, "v")
        XCTAssertEqual(HotKey.LatestAction.delete.keyChar, "\u{8}", "⌫ is not a character key")
        use(qwertz())
        XCTAssertEqual(KeyCodes.menuCharacter(for: UInt16(kVK_ANSI_Minus)), "ß")
    }

    func testKeysWithoutACharacterAndUnansweredKeysKeepTheirUSNames() {
        var f = azerty()
        f.set(kVK_Space, .characters(" "))
        f.set(kVK_ANSI_B, .characters("\u{1B}"))            // a control character is no name
        f.set(kVK_ANSI_C, .characters("ab"))                // two characters are no name
        f.set(kVK_ANSI_D, .error)
        use(f)
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_Space)), "Space")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_F5)), "F5")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_LeftArrow)), "←")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_Delete)), "⌫")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_B)), "B")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_C)), "C")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_D)), "D")
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_E)), "E", "a key the layout says nothing about")
        XCTAssertEqual(KeyCodes.menuCharacter(for: UInt16(kVK_F5)), String(UnicodeScalar(NSF5FunctionKey)!))
        XCTAssertEqual(KeyCodes.menuCharacter(for: UInt16(kVK_ANSI_E)), "e")
    }

    func testUSTableWhenThereIsNoLayout() {
        KeyCodes.currentLayoutForTesting = { KeyCodes.usTable }
        KeyCodes.invalidateLayoutCache()
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_A)), "A")
        XCTAssertEqual(HotKey.optionM.displayString, "⌥M")
        XCTAssertEqual(HotKey.LatestAction.trim.keyChar, "w")
    }

    func testCacheIsPerLayoutAndDroppedOnChange() {
        use(azerty())
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_A)), "Q")
        var changed = azerty(); changed.set(kVK_ANSI_A, .characters("x"))
        let info = changed.info
        KeyCodes.currentLayoutForTesting = { info }      // same id, no invalidation: the cache answers
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_A)), "Q")
        KeyCodes.invalidateLayoutCache()                 // what selectedLayoutDidChange() does
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_A)), "X")
        use(qwertz())                                    // another id: a fresh cache
        XCTAssertEqual(KeyCodes.name(for: UInt16(kVK_ANSI_A)), "A", "QWERTZ says nothing about A here: US fallback")
    }

    func testMenusCarryTheLayoutCharacterAndKeepAppKitFromMovingIt() throws {
        use(azerty())
        let builder = MenuBuilder(settings: Settings())
        let item = ClipItem.text("hello")
        let menu = builder.contextMenu(for: item, target: self, actions: MenuBuilder.ContextActions(
            paste: #selector(noop), pastePlain: #selector(noop), copyOnly: #selector(noop), transform: #selector(noop),
            pin: #selector(noop), reveal: #selector(noop), delete: #selector(noop)), latestMods: HotKey.controlOption)
        let trim = try XCTUnwrap(menu.items.first { $0.title.contains(TextTransform.trim.title) && !$0.isHidden })
        XCTAssertEqual(trim.keyEquivalent, "z")
        XCTAssertFalse(trim.allowsAutomaticKeyEquivalentLocalization)
        XCTAssertEqual(trim.keyEquivalentModifierMask, [.control, .option])
        var s = Settings(); s.numberItems = true
        let rows = MenuBuilder(settings: s).historyItems([item, .text("two")], target: self, action: #selector(noop), numberMods: HotKey.controlOption)
        XCTAssertEqual(rows[0].keyEquivalent, "&", "the physical 1 key types & on AZERTY")
        XCTAssertEqual(rows[1].keyEquivalent, "é")
        XCTAssertTrue(rows[0].title.hasPrefix("1  "), "the prefix is the index, not the key")
        XCTAssertFalse(rows[0].allowsAutomaticKeyEquivalentLocalization)
        // Menu-only ⌘1 accelerators (no global hot key) are left to AppKit as before.
        let local = MenuBuilder(settings: s).historyItems([item], target: self, action: #selector(noop), numberMods: nil, commandAccelerators: true)
        XCTAssertEqual(local[0].keyEquivalent, "1")
        XCTAssertTrue(local[0].allowsAutomaticKeyEquivalentLocalization)
    }

    @objc func noop() {}
}
