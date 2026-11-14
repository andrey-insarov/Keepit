import Carbon
import XCTest
@testable import Keepit

/// The H-1 rule of claude/keepit-hotkey-layouts-design.md on hand-built layouts. The real TIS
/// reader is exercised once; everything else uses FakeLayout so the tests do not depend on the
/// layouts enabled on the machine that runs them.
final class LayoutProbeTests: XCTestCase {

    // MARK: Fixtures

    let OPT = UInt32(optionKey), SHIFT = UInt32(shiftKey)
    let kL = UInt16(kVK_ANSI_L), kE = UInt16(kVK_ANSI_E), kN = UInt16(kVK_ANSI_N), kV = UInt16(kVK_ANSI_V)
    let kM = UInt16(kVK_ANSI_M), kS = UInt16(kVK_ANSI_S), kA = UInt16(kVK_ANSI_A), kX = UInt16(kVK_ANSI_X)
    let kGrave = UInt16(kVK_ANSI_Grave), kLeftBracket = UInt16(kVK_ANSI_LeftBracket), kSpace = UInt16(kVK_Space)

    struct FakeLayout {
        struct Key: Hashable { let code: UInt16; let mods: UInt32; let dead: UInt32 }
        var id = "fake", name = "Fake", languages: [String] = ["en"]
        var map: [Key: KeyOutput] = [:]
        var readable = true

        /// a–z on their US positions, lowercase plain and uppercase with Shift.
        static func latinBase() -> FakeLayout {
            var l = FakeLayout()
            let codes: [(Int, String)] = [
                (kVK_ANSI_A, "a"), (kVK_ANSI_B, "b"), (kVK_ANSI_C, "c"), (kVK_ANSI_D, "d"), (kVK_ANSI_E, "e"), (kVK_ANSI_F, "f"),
                (kVK_ANSI_G, "g"), (kVK_ANSI_H, "h"), (kVK_ANSI_I, "i"), (kVK_ANSI_J, "j"), (kVK_ANSI_K, "k"), (kVK_ANSI_L, "l"),
                (kVK_ANSI_M, "m"), (kVK_ANSI_N, "n"), (kVK_ANSI_O, "o"), (kVK_ANSI_P, "p"), (kVK_ANSI_Q, "q"), (kVK_ANSI_R, "r"),
                (kVK_ANSI_S, "s"), (kVK_ANSI_T, "t"), (kVK_ANSI_U, "u"), (kVK_ANSI_V, "v"), (kVK_ANSI_W, "w"), (kVK_ANSI_X, "x"),
                (kVK_ANSI_Y, "y"), (kVK_ANSI_Z, "z"),
            ]
            for (c, s) in codes { l.plain(UInt16(c), s, shift: s.uppercased()) }
            l.plain(UInt16(kVK_Space), " ")
            return l
        }

        mutating func plain(_ code: UInt16, _ s: String, shift: String? = nil) {
            map[Key(code: code, mods: 0, dead: 0)] = .characters(s)
            if let shift { map[Key(code: code, mods: UInt32(shiftKey), dead: 0)] = .characters(shift) }
        }
        mutating func set(_ code: UInt16, mods: UInt32, dead: UInt32 = 0, _ out: KeyOutput) {
            map[Key(code: code, mods: mods, dead: dead)] = out
        }

        var info: LayoutInfo {
            let map = self.map
            return LayoutInfo(id: id, name: name, languages: languages,
                              translate: readable ? { map[Key(code: $0, mods: $1, dead: $2)] ?? .nothing } : nil)
        }
    }

    struct FakeReader: LayoutReading {
        var layouts: [FakeLayout]
        func enabledLayouts() -> [LayoutInfo] { layouts.map(\.info) }
    }

    /// Letters per language code, so the tests do not depend on the system's exemplar data.
    static let letters: [String: String] = [
        "en": "", "de": "äöüß", "fr": "àâæçéèêëîïôœùûüÿ", "pl": "ąćęłńóśźż", "it": "àèéìíòóù", "nl": "éëïóöü",
    ]
    func probe(_ layouts: FakeLayout...) -> LayoutProbe {
        var p = LayoutProbe(reader: FakeReader(layouts: layouts))
        p.letters = { langs in
            if langs.isEmpty { return .latin }
            let extra = langs.map { Self.letters[$0] ?? "" }.joined()
            return LetterSet(characterSet: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz" + extra))
        }
        return p
    }

    func german() -> FakeLayout {
        var l = FakeLayout.latinBase()
        l.id = "de"; l.name = "German"; l.languages = ["de"]
        l.set(kL, mods: OPT, .characters("@"))
        l.set(kE, mods: OPT, .characters("€"))
        l.set(kN, mods: OPT, .deadKey(1))            // dead ~, no plain ~ anywhere
        l.set(kSpace, mods: 0, dead: 1, .characters("~"))
        l.set(kN, mods: 0, dead: 1, .characters("ñ"))
        l.set(kM, mods: OPT, .characters("µ"))
        return l
    }

    func us() -> FakeLayout {
        var l = FakeLayout.latinBase()
        l.id = "us"; l.name = "U.S."; l.languages = ["en"]
        l.plain(kGrave, "`", shift: "~")              // ~ has its own key
        l.set(kN, mods: OPT, .deadKey(1))
        l.set(kSpace, mods: 0, dead: 1, .characters("~"))
        l.set(kN, mods: 0, dead: 1, .characters("ñ"))
        l.set(kA, mods: 0, dead: 1, .characters("ã"))
        l.set(kL, mods: OPT, .characters("¬"))
        return l
    }

    // MARK: The rule

    func testGermanNeedsAtEuroAndDeadTilde() {
        let p = probe(german())
        XCTAssertEqual(p.check(keyCode: kL, modifiers: OPT), LayoutCheck(verdict: .needed(layout: "German", types: "@"), incomplete: 0))
        XCTAssertEqual(p.check(keyCode: kE, modifiers: OPT), LayoutCheck(verdict: .needed(layout: "German", types: "€"), incomplete: 0))
        XCTAssertEqual(p.check(keyCode: kN, modifiers: OPT), LayoutCheck(verdict: .needed(layout: "German", types: "~"), incomplete: 0))
        XCTAssertEqual(p.check(keyCode: kM, modifiers: OPT).verdict, .notNeeded)   // µ is neither a letter nor protected
    }

    func testUSKeepsDeadTildeBecausePlainTildeExists() {
        // ñ and ã are reachable only through ⌥N, but they are not English letters: a stated compromise.
        XCTAssertEqual(probe(us()).check(keyCode: kN, modifiers: OPT).verdict, .notNeeded)
        XCTAssertEqual(probe(us()).check(keyCode: kL, modifiers: OPT).verdict, .notNeeded)
    }

    func testFrenchCircumflexEIsReachableThroughDeadKey() {
        var l = FakeLayout.latinBase()
        l.id = "fr"; l.name = "French"; l.languages = ["fr"]
        l.set(kLeftBracket, mods: 0, .deadKey(7))        // the ^ dead key
        l.set(kE, mods: 0, dead: 7, .characters("ê"))
        l.set(kSpace, mods: 0, dead: 7, .characters("^"))
        l.set(kE, mods: OPT, .characters("ê"))
        XCTAssertEqual(probe(l).check(keyCode: kE, modifiers: OPT).verdict, .notNeeded)
    }

    func testPolishLetterOnlyWithOptionIsNeeded() {
        var l = FakeLayout.latinBase()
        l.id = "pl"; l.name = "Polish"; l.languages = ["pl"]
        l.set(kL, mods: OPT, .characters("ł"))
        l.set(kS, mods: OPT, .characters("ś"))
        XCTAssertEqual(probe(l).check(keyCode: kL, modifiers: OPT).verdict, .needed(layout: "Polish", types: "ł"))
        XCTAssertEqual(probe(l).check(keyCode: kS, modifiers: OPT).verdict, .needed(layout: "Polish", types: "ś"))
    }

    func testCompositionThroughOptionDeadKeyIsNeeded() {
        // The dead key's own character is harmless, but ⌥N then a is the only route to ã, a letter here.
        var l = FakeLayout.latinBase()
        l.id = "pt"; l.name = "Portuguese"; l.languages = ["pt"]
        l.plain(kGrave, "`", shift: "~")
        l.set(kN, mods: OPT, .deadKey(1))
        l.set(kSpace, mods: 0, dead: 1, .characters("~"))
        l.set(kA, mods: 0, dead: 1, .characters("ã"))
        var p = probe(l)
        p.letters = { _ in LetterSet(characterSet: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzãõç")) }
        XCTAssertEqual(p.check(keyCode: kN, modifiers: OPT).verdict, .needed(layout: "Portuguese", types: "ã"))
    }

    func testCompositionYieldingProtectedSymbolIsNeeded() {
        var l = FakeLayout.latinBase()
        l.id = "x"; l.name = "Odd"; l.languages = ["en"]
        l.set(kN, mods: OPT, .deadKey(1))
        l.set(kSpace, mods: 0, dead: 1, .characters("¨"))
        l.set(kA, mods: 0, dead: 1, .characters("{"))
        XCTAssertEqual(probe(l).check(keyCode: kN, modifiers: OPT).verdict, .needed(layout: "Odd", types: "{"))
    }

    func testSecondDeadStateIsCountedAsIncompleteNotSafe() {
        var l = us()
        l.set(kX, mods: 0, dead: 1, .deadKey(9))       // ⌥N then x leads to another dead state
        let r = probe(l).check(keyCode: kN, modifiers: OPT)
        XCTAssertEqual(r.verdict, .notNeeded)
        XCTAssertEqual(r.incomplete, 1)
    }

    func testDecomposedAndPrecomposedAreTheSameCharacter() {
        var l = FakeLayout.latinBase()
        l.id = "fr"; l.name = "French"; l.languages = ["fr"]
        l.plain(kLeftBracket, "é")
        l.set(kE, mods: OPT, .characters("e\u{0301}".precomposedStringWithCanonicalMapping))
        XCTAssertEqual(probe(l).check(keyCode: kE, modifiers: OPT).verdict, .notNeeded)
    }

    func testCapitalLetterIsNotCoveredByItsLowercase() {
        // Italian: é on a plain key, É only on ⌥⇧V. É is a letter (through é), and plain(L) lacks it exactly.
        var l = FakeLayout.latinBase()
        l.id = "it"; l.name = "Italian"; l.languages = ["it"]
        l.plain(kLeftBracket, "é")
        l.set(kV, mods: OPT | SHIFT, .characters("É"))
        XCTAssertEqual(probe(l).check(keyCode: kV, modifiers: OPT | SHIFT).verdict, .needed(layout: "Italian", types: "É"))
        // With É on Shift of the same key, nothing is lost.
        l.plain(kLeftBracket, "é", shift: "É")
        XCTAssertEqual(probe(l).check(keyCode: kV, modifiers: OPT | SHIFT).verdict, .notNeeded)
    }

    func testLettersAreTheUnionOfDeclaredLanguages() {
        var l = FakeLayout.latinBase()
        l.id = "multi"; l.name = "Multi"; l.languages = ["de", "pl"]
        l.set(kL, mods: OPT, .characters("ł"))
        XCTAssertEqual(probe(l).check(keyCode: kL, modifiers: OPT).verdict, .needed(layout: "Multi", types: "ł"))
    }

    func testNoLanguagesProtectsLatinAndSymbolsOnly() {
        var l = FakeLayout.latinBase()
        l.id = "custom"; l.name = "Custom"; l.languages = []
        l.set(kL, mods: OPT, .characters("ł"))        // a stated limitation: not a Latin a–z letter
        l.set(kE, mods: OPT, .characters("@"))
        XCTAssertEqual(probe(l).check(keyCode: kL, modifiers: OPT).verdict, .notNeeded)
        XCTAssertEqual(probe(l).check(keyCode: kE, modifiers: OPT).verdict, .needed(layout: "Custom", types: "@"))
    }

    // MARK: Several layouts

    func testFirstLayoutThatNeedsItIsNamed() {
        var pl = FakeLayout.latinBase()
        pl.id = "pl"; pl.name = "Polish"; pl.languages = ["pl"]
        pl.set(kL, mods: OPT, .characters("ł"))
        XCTAssertEqual(probe(german(), pl).check(keyCode: kL, modifiers: OPT).verdict, .needed(layout: "German", types: "@"))
        XCTAssertEqual(probe(pl, german()).check(keyCode: kL, modifiers: OPT).verdict, .needed(layout: "Polish", types: "ł"))
    }

    func testUnreadableLayoutIsReportedNotTreatedAsSafe() {
        var broken = FakeLayout()
        broken.id = "broken"; broken.name = "Broken"; broken.readable = false
        XCTAssertEqual(probe(us(), broken).check(keyCode: kL, modifiers: OPT).verdict, .unchecked(failed: ["broken"]))
        // A layout that needs the combination is not hidden by one that could not be read.
        XCTAssertEqual(probe(broken, german()).check(keyCode: kL, modifiers: OPT).verdict, .needed(layout: "German", types: "@"))
        XCTAssertEqual(probe(german(), broken).check(keyCode: kL, modifiers: OPT).verdict, .needed(layout: "German", types: "@"))
    }

    func testIncompleteIsSummedAcrossLayouts() {
        var a = us(); a.set(kX, mods: 0, dead: 1, .deadKey(9))
        var b = us(); b.id = "us2"; b.set(kA, mods: 0, dead: 1, .deadKey(9))
        XCTAssertEqual(probe(a, b).check(keyCode: kN, modifiers: OPT).incomplete, 2)
    }

    func testCheckAllGivesOneVerdictPerCombination() {
        let r = probe(german()).checkAll([(kL, OPT), (kM, OPT), (kE, OPT)])
        XCTAssertEqual(r.map(\.verdict), [.needed(layout: "German", types: "@"), .notNeeded, .needed(layout: "German", types: "€")])
    }

    func testNoLayoutsMeansNothingNeeded() {
        XCTAssertEqual(probe().check(keyCode: kL, modifiers: OPT), LayoutCheck(verdict: .notNeeded, incomplete: 0))
    }

    // MARK: The system's own data

    func testExemplarLettersComeFromTheLocale() {
        let de = LetterSet.exemplar(["de"])
        XCTAssertTrue(de.contains("ä")); XCTAssertTrue(de.contains("Ä")); XCTAssertTrue(de.contains("ß"))
        XCTAssertFalse(de.contains("ł")); XCTAssertFalse(de.contains("@"))
        XCTAssertTrue(LetterSet.exemplar(["de", "pl"]).contains("ł"))
        XCTAssertTrue(LetterSet.exemplar([]).contains("z")); XCTAssertFalse(LetterSet.exemplar([]).contains("ä"))
    }

    func testRealReaderReturnsReadableLayouts() throws {
        // Whatever the machine has enabled: every layout has an id, and a readable one types
        // something for the plain A key. Not a test of the rule.
        let layouts = TISLayoutReader().enabledLayouts()
        try XCTSkipIf(layouts.isEmpty, "no keyboard layouts enabled")
        for l in layouts {
            XCTAssertFalse(l.id.isEmpty)
            if let t = l.translate {
                if case .nothing = t(kA, 0, 0) { XCTFail("\(l.id) types nothing for the A key") }
            }
        }
    }
}
