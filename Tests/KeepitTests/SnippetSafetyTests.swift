import XCTest
@testable import Keepit

/// The snippet engine must not trap, loop or grow without bound on any template text — templates arrive
/// from files, backups, keepit:// and, in 3.1, other programs' exports. Seeded from the auditor's
/// external-input review of 5 Nov 2026 (`{date--9223372036854775808d}` → `Int.min` → trap).
final class SnippetSafetyTests: XCTestCase {
    private var ctx: Snippets.Context {
        var c = Snippets.Context()
        c.now = Date(timeIntervalSince1970: 1_700_000_000)
        c.clipboard = { n in n == 1 ? "CLIP" : nil }
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }
    private let cal = Calendar(identifier: .gregorian)
    private let d = Date(timeIntervalSince1970: 1_700_000_000)

    func testMalformedShiftsAreRefusedNotTrapped() {
        for spec in ["--9223372036854775808d", "+9223372036854775807d", "-9223372036854775808d", "+-1d", "++1d",
                     "+d", "-", "+", "+1", "+12345d", "+1dd", "+1 d", "+１d", "+1x", "line", "+0x10d", "+1e3d", "+1_000d"] {
            XCTAssertNil(Snippets.shifted(d, by: spec, calendar: cal), spec)
        }
    }

    func testWellFormedShiftsStillWork() {
        XCTAssertEqual(Snippets.shifted(d, by: "+2d", calendar: cal), cal.date(byAdding: .day, value: 2, to: d))
        XCTAssertEqual(Snippets.shifted(d, by: "-9999y", calendar: cal), cal.date(byAdding: .year, value: -9999, to: d))
        XCTAssertEqual(Snippets.shifted(d, by: "+0h", calendar: cal), d)
        XCTAssertEqual(Snippets.shifted(d, by: "", calendar: cal), d)
    }

    func testMalformedTokensExpandToThemselves() {
        for s in ["{date--9223372036854775808d}", "{date+99999d}", "{random:1-}", "{random:-5-5}", "{random:a,b}",
                  "{random:1-99999999999999999999}", "{clipboard:99999999999999999999}", "{clipboard:-1}", "{date:" + String(repeating: "y", count: 300) + "}"] {
            let e = Snippets.expand(s, context: ctx)
            XCTAssertFalse(e.truncated, s)
            if s.hasPrefix("{random") || s.hasPrefix("{clipboard") {
                XCTAssertNotEqual(e.text, "", s)     // a sane default, never a crash
            } else {
                XCTAssertEqual(e.text, s, s)         // left as text
            }
        }
    }

    func testRandomAndClipboardArgumentsAreBounded() {
        let r = Snippets.expand("{random:5-5}", context: ctx).text
        XCTAssertEqual(r, "5")
        XCTAssertEqual(Snippets.expand("{clipboard:1}", context: ctx).text, "CLIP")
        XCTAssertEqual(Snippets.expand("{clipboard:2}", context: ctx).text, "")
        let digits = Snippets.expand("{random:999999999-999999999}", context: ctx).text
        XCTAssertEqual(digits, "999999999")
    }

    func testPromptsAndChoicesAreCapped() {
        let many = (0..<(Limits.snippetPromptsMax + 10)).map { "{input:q\($0)}" }.joined()
        XCTAssertEqual(Snippets.prompts(in: many).count, Limits.snippetPromptsMax)
        let choices = (0..<(Limits.snippetChoicesMax + 10)).map(String.init).joined(separator: "|")
        let p = Snippets.prompts(in: "{choice:Pick=\(choices)}")
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p[0].choices.count, Limits.snippetChoicesMax)
    }

    func testOutputIsCappedAndReportsIt() {
        var c = ctx
        let big = String(repeating: "x", count: 1 << 20)             // 1 MiB clipboard item
        c.clipboard = { _ in big }
        let n = Limits.snippetOutputMaxBytes / big.utf8.count + 2
        let e = Snippets.expand(String(repeating: "{clipboard}", count: n), context: c)
        XCTAssertTrue(e.truncated)
        XCTAssertLessThanOrEqual(e.text.utf8.count, Limits.snippetOutputMaxBytes)
        XCTAssertFalse(Snippets.expand("{clipboard}", context: c).truncated)
    }

    func testCursorFarFromTheEndIsNotMoved() {
        let tail = String(repeating: "a", count: Limits.snippetCursorMoveMax + 1)
        XCTAssertNil(Snippets.expand("{cursor}" + tail, context: ctx).charsAfterCursor)
        XCTAssertEqual(Snippets.expand("{cursor}abc", context: ctx).charsAfterCursor, 3)
    }

    func testLiteralBracesAndUnknownNamesSurvive() {
        XCTAssertEqual(Snippets.expand("{{\"x\":1}}", context: ctx).text, "{\"x\":1}")
        XCTAssertEqual(Snippets.expand("{query}{nope:1}{", context: ctx).text, "{query}{nope:1}{")
    }

    /// Auditor's P2 on 3.0.4: `{a{a{a…` (64 000 bytes, with and without one `}` at the end) passed every
    /// size limit and then kept the main thread for longer than six seconds, because each opener that
    /// turned out not to be a token searched the rest of the text for `}`. The scan now stops at the
    /// first brace of either kind, so the whole parse is linear in the text.
    func testUnclosedOpenersParseInLinearTime() {
        let open = String(repeating: "{a", count: 32_000)
        for text in [open, open + "}"] {
            let started = Date()
            let prompts = Snippets.prompts(in: text)
            let exp = Snippets.expand(text, context: ctx)
            XCTAssertLessThan(Date().timeIntervalSince(started), 1.0, "\(text.utf8.count) bytes")
            XCTAssertTrue(prompts.isEmpty)
            XCTAssertEqual(exp.text, text, "malformed openers stay as they are")
        }
        // A literal brace storm with real tokens among it must still find the tokens.
        let mixed = String(repeating: "{{", count: 20_000) + "{clipboard}" + String(repeating: "{", count: 20_000) + "{input:X}"
        XCTAssertEqual(Snippets.prompts(in: mixed).map(\.name), ["X"])
        let out = Snippets.expand(mixed, context: ctx).text
        XCTAssertTrue(out.hasPrefix(String(repeating: "{", count: 20_000) + "CLIP"))
    }

    func testTokenGrammarIsUnchanged() {
        // One case per rule: letter first, no brace inside, `{{`/`}}` literal, empty body literal.
        XCTAssertEqual(Snippets.expand("{ab{clipboard}", context: ctx).text, "{abCLIP")
        XCTAssertEqual(Snippets.expand("{1x}{}{ clipboard}", context: ctx).text, "{1x}{}{ clipboard}")
        XCTAssertEqual(Snippets.expand("{{clipboard}}", context: ctx).text, "{clipboard}")
        XCTAssertEqual(Snippets.expand("{clipboard", context: ctx).text, "{clipboard")
        XCTAssertEqual(Snippets.expand("}{clipboard}}", context: ctx).text, "}CLIP}")
    }
}
