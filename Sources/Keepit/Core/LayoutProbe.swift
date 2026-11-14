// Which of Keepit's hot keys would take away a character the user's keyboard layouts need.
//
// A Carbon hot key is bound to a key position and swallows the keystroke system-wide. On US
// English ⌥ + a letter types a rarely used symbol; on German ⌥L types @ and ⌥E types €, on Polish
// ⌥L types ł. This file decides, for one combination and the enabled layouts, whether the
// combination is "needed" by a layout (docs: claude/keepit-hotkey-layouts-design.md, H-1):
//
//   needed(c)  ⇔  c ∈ letters(L) ∪ symbols  and  c ∉ plain(L)
//
// letters(L): the exemplar characters of the layout's primary language (both cases). macOS lists
//             every language a layout can type — 98 for U.S. — with the primary one first; the union
//             of all of them would make U.S. protect ß and œ. Lone combining marks are not letters.
// symbols:    @ € ~ \ | { } [ ] $ # ^ `
// plain(L):   everything the layout types without ⌥ or ⌘ — each key alone or with Shift, and each
//             dead key reached that way followed by one such key (^ then e → ê) or by Space.
//
// Strings are NFC-normalised. Letter membership is case-insensitive, plain(L) membership exact:
// a layout with é on a plain key but É only on ⌥⇧V needs ⌥⇧V — the capital would be lost.
//
// Stage 1 of the feature: the rule and a TIS reader, used by nothing yet. No AppKit, so the same
// file compiles into a command-line harness that runs it over every installed layout.

import Carbon
import Foundation

/// What a key with modifiers (and an incoming dead-key state) produces on a layout.
enum KeyOutput: Equatable {
    case nothing
    /// Printable output, NFC-normalised.
    case characters(String)
    /// A dead key: the state to pass to the next key.
    case deadKey(UInt32)
}

/// One keyboard layout as the probe sees it.
struct LayoutInfo {
    let id: String
    let name: String
    let languages: [String]
    /// keyCode, Carbon modifier bits (optionKey, shiftKey, …), incoming dead-key state → output.
    /// nil when the layout has no readable key data: the probe reports it as unchecked.
    let translate: ((UInt16, UInt32, UInt32) -> KeyOutput)?
}

protocol LayoutReading {
    func enabledLayouts() -> [LayoutInfo]
}

/// The verdict of the enabled layouts on one combination.
enum LayoutVerdict: Equatable {
    case notNeeded
    /// The first layout that needs the combination, and the character it types there.
    case needed(layout: String, types: String)
    /// No readable layout needs it, but these layouts could not be read.
    case unchecked(failed: [String])
}

struct LayoutCheck: Equatable {
    var verdict: LayoutVerdict
    /// Dead-key compositions that ended in another dead state and were not expanded. Never
    /// evidence that a combination is safe — only a measure of what the analysis did not see.
    var incomplete: Int
}

/// The letters a layout protects: those of its languages, or a–z when it declares none.
struct LetterSet {
    let contains: (String) -> Bool

    /// The union of the exemplar character sets of the given languages (the probe passes one); Latin a–z when empty.
    static func exemplar(_ languages: [String]) -> LetterSet {
        if languages.isEmpty { return .latin }
        var set = CharacterSet()
        for lang in languages { set.formUnion(NSLocale(localeIdentifier: lang).exemplarCharacterSet) }
        return LetterSet(characterSet: set)
    }

    static let latin = LetterSet(characterSet: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz"))

    init(characterSet: CharacterSet) {
        contains = { s in
            // One scalar after NFC. A capital counts through its lowercase (É through é), but never
            // the other way round: ı uppercases to I, and that does not make it an English letter.
            for variant in [s, s.lowercased()] {
                let scalars = variant.unicodeScalars
                if scalars.count == 1, characterSet.contains(scalars.first!) { return true }
            }
            return false
        }
    }
}

struct LayoutProbe {
    static let protectedSymbols: Set<String> = ["@", "€", "~", "\\", "|", "{", "}", "[", "]", "$", "#", "^", "`"]

    let reader: LayoutReading
    /// Injected by tests; the app uses the exemplar sets.
    var letters: ([String]) -> LetterSet = LetterSet.exemplar

    init(reader: LayoutReading) { self.reader = reader }

    /// The verdict of all enabled layouts on one combination.
    func check(keyCode: UInt16, modifiers: UInt32) -> LayoutCheck {
        checkAll([(keyCode, modifiers)])[0]
    }

    /// One verdict per combination, reading each layout once.
    func checkAll(_ combos: [(keyCode: UInt16, modifiers: UInt32)]) -> [LayoutCheck] {
        var results = combos.map { _ in LayoutCheck(verdict: .notNeeded, incomplete: 0) }
        var failed: [String] = []
        for layout in reader.enabledLayouts() {
            guard let prepared = Prepared(layout, letters: letters(Array(layout.languages.prefix(1)))) else {
                failed.append(layout.id)
                continue
            }
            for (i, combo) in combos.enumerated() {
                let r = prepared.check(keyCode: combo.keyCode, modifiers: combo.modifiers)
                results[i].incomplete += r.incomplete
                if case .notNeeded = results[i].verdict, let c = r.needed {
                    results[i].verdict = .needed(layout: layout.name, types: c)
                }
            }
        }
        if !failed.isEmpty {
            for i in results.indices where results[i].verdict == .notNeeded {
                results[i].verdict = .unchecked(failed: failed)
            }
        }
        return results
    }

    /// The rule for one combination on one layout. nil when the layout cannot be read.
    func check(keyCode: UInt16, modifiers: UInt32, on layout: LayoutInfo) -> (needed: String?, incomplete: Int)? {
        Prepared(layout, letters: letters(Array(layout.languages.prefix(1))))?.check(keyCode: keyCode, modifiers: modifiers)
    }

    /// A layout with its plain(L) built.
    struct Prepared {
        static let keyCodes: [UInt16] = Array(0..<128)   // every position UCKeyTranslate knows
        static let spaceKey = UInt16(kVK_Space)
        static let plainModifiers: [UInt32] = [0, UInt32(shiftKey)]

        let translate: (UInt16, UInt32, UInt32) -> KeyOutput
        let letters: LetterSet
        let plain: Set<String>

        init?(_ layout: LayoutInfo, letters: LetterSet) {
            guard let t = layout.translate else { return nil }
            translate = t
            self.letters = letters
            var plain = Set<String>()
            var deadStates = Set<UInt32>()
            for code in Prepared.keyCodes {
                for mods in Prepared.plainModifiers {
                    switch t(code, mods, 0) {
                    case .characters(let c): plain.insert(c)
                    case .deadKey(let state): deadStates.insert(state)
                    case .nothing: break
                    }
                }
            }
            for state in deadStates {
                for code in Prepared.keyCodes {
                    for mods in Prepared.plainModifiers {
                        if case .characters(let c) = t(code, mods, state) { plain.insert(c) }
                    }
                }
            }
            self.plain = plain
        }

        func needs(_ c: String) -> Bool {
            // A lone combining mark (ABC – Extended types one on ⌥⇧V) is not a character anyone needs.
            if let first = c.unicodeScalars.first, first.properties.generalCategory == .nonspacingMark
                || first.properties.generalCategory == .enclosingMark { return false }
            return (letters.contains(c) || LayoutProbe.protectedSymbols.contains(c)) && !plain.contains(c)
        }

        func check(keyCode: UInt16, modifiers: UInt32) -> (needed: String?, incomplete: Int) {
            switch translate(keyCode, modifiers, 0) {
            case .nothing:
                return (nil, 0)
            case .characters(let c):
                return (needs(c) ? c : nil, 0)
            case .deadKey(let state):
                // The dead key's own character (the one Space produces) wins; otherwise the first
                // composition with a plain key that the layout needs. Every composition is visited
                // so that `incomplete` counts what was not expanded.
                var incomplete = 0
                var found: String?
                for code in Prepared.keyCodes {
                    for mods in Prepared.plainModifiers {
                        switch translate(code, mods, state) {
                        case .characters(let c): if found == nil, needs(c) { found = c }
                        case .deadKey: incomplete += 1
                        case .nothing: break
                        }
                    }
                }
                if case .characters(let rest) = translate(Prepared.spaceKey, 0, state), needs(rest) { found = rest }
                return (found, incomplete)
            }
        }
    }
}

/// The layouts macOS knows, through Text Input Sources and UCKeyTranslate. Read-only.
struct TISLayoutReader: LayoutReading {
    /// false: the layouts the user has enabled (the app). true: every installed layout (the harness).
    var allInstalled = false

    func enabledLayouts() -> [LayoutInfo] {
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
                      kTISPropertyInputSourceType: kTISTypeKeyboardLayout] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, allInstalled)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return list.compactMap { source in
            guard let id = Self.property(source, kTISPropertyInputSourceID) as? String else { return nil }
            let name = Self.property(source, kTISPropertyLocalizedName) as? String ?? id
            let languages = Self.property(source, kTISPropertyInputSourceLanguages) as? [String] ?? []
            let data = Self.property(source, kTISPropertyUnicodeKeyLayoutData) as? Data
            return LayoutInfo(id: id, name: name, languages: languages, translate: data.map(Self.translator))
        }
    }

    private static func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let p = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue()
    }

    static func translator(_ data: Data) -> (UInt16, UInt32, UInt32) -> KeyOutput {
        let keyboardType = UInt32(LMGetKbdType())
        return { keyCode, carbonModifiers, deadIn in
            data.withUnsafeBytes { raw -> KeyOutput in
                guard let base = raw.baseAddress else { return .nothing }
                let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
                var dead = deadIn
                var length = 0
                var chars = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), (carbonModifiers >> 8) & 0xFF,
                                            keyboardType, 0, &dead, chars.count, &length, &chars)
                guard status == noErr else { return .nothing }
                if length == 0 { return dead != 0 ? .deadKey(dead) : .nothing }
                let s = String(utf16CodeUnits: chars, count: length).precomposedStringWithCanonicalMapping
                // Control characters and the like are not something a user types.
                guard let scalar = s.unicodeScalars.first, scalar.value >= 0x20, scalar.value != 0x7F else { return .nothing }
                return .characters(s)
            }
        }
    }
}
