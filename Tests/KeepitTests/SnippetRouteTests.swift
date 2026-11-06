import AppKit
import XCTest
@testable import Keepit

/// The paste route and the engine additions of 3.0.5 (IMPORT.md, engine change 1 and "what is
/// converted"): `Snippets.pasteRoute` decides verbatim / unescape-only / expand in one place; a
/// template of escapes alone pastes `{{` as `{` *with* its rich formats; named date styles;
/// shifts on time and datetime; several shifts in one token. The route table is asserted on what
/// `pasteTemplate` hands the paster, not on `expand` alone — the auditor's B-2: `expand` was
/// already right on 3.0.3, the gate in front of it was not.
final class SnippetRouteTests: XCTestCase {
    private var storage: TempStorage!
    private var pasted: [ClipItem] = []

    override func setUpWithError() throws {
        _ = NSApplication.shared
        storage = TempStorage()
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
        pasted = []
        Paster.pasteSinkForTesting = { [unowned self] in self.pasted.append($0) }
        SnippetPromptDialog.askForTesting = { prompts, _ in Dictionary(uniqueKeysWithValues: prompts.map { ($0.name, "A") }) }
    }
    override func tearDown() {
        Paster.pasteSinkForTesting = nil
        SnippetPromptDialog.askForTesting = nil
        storage.restore()
    }

    private func makeApp() throws -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        var s = a.settings
        s.pasteAfterSelect = false
        a.apply(settings: s)
        a.history.add(.text("CLIP"))
        return a
    }

    private func rich(_ text: String) -> ClipItem {
        let t = Data(text.utf8)
        return ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.text: t, ClipItem.Format.rtf: Data("{\\rtf1 x}".utf8),
                                                             ClipItem.Format.html: Data("<b>x</b>".utf8)],
                        sourceApp: nil, contentHash: ClipItem.hash(of: t))
    }

    // MARK: the route table

    func testRouteTable() throws {
        let a = try makeApp()
        struct Row { let text: String; let route: Snippets.Route; let pasted: String; let keepsRich: Bool }
        let rows: [Row] = [
            Row(text: #"{{"x":1}}"#, route: .unescapeOnly(#"{"x":1}"#), pasted: #"{"x":1}"#, keepsRich: true),   // auditor's escaped JSON
            Row(text: "{{random:a,b}}", route: .unescapeOnly("{random:a,b}"), pasted: "{random:a,b}", keepsRich: true),   // his unsupported placeholder
            Row(text: "hello", route: .verbatim, pasted: "hello", keepsRich: true),
            Row(text: "a { b } c", route: .verbatim, pasted: "a { b } c", keepsRich: true),          // lone braces: nothing to do
            Row(text: "{clipboard}", route: .expand("{clipboard}", []), pasted: "CLIP", keepsRich: false),
            Row(text: "{{x}} {clipboard}", route: .expand("{{x}} {clipboard}", []), pasted: "{x} CLIP", keepsRich: false),
            Row(text: "{input:Name}!", route: .expand("{input:Name}!", [Snippets.Prompt(name: "Name", defaultValue: "", choices: [])]), pasted: "A!", keepsRich: false),
            Row(text: "}}{{", route: .unescapeOnly("}{"), pasted: "}{", keepsRich: true),
            // PR #30 auditor's P2: an uppercase-start placeholder is text, as it was before the route
            // existed — never a prompt that silently answers itself with its default.
            Row(text: "{INPUT:Name}", route: .verbatim, pasted: "{INPUT:Name}", keepsRich: true),
            Row(text: "{Input:Name=Default}", route: .verbatim, pasted: "{Input:Name=Default}", keepsRich: true),
            Row(text: "{CHOICE:Pick=A|B}", route: .verbatim, pasted: "{CHOICE:Pick=A|B}", keepsRich: true),
            // Lowercase start but an unknown name: a token, pasted as its own text, no prompt.
            Row(text: "{iNPUT:Name=Default}", route: .expand("{iNPUT:Name=Default}", []), pasted: "{iNPUT:Name=Default}", keepsRich: false),
            Row(text: "{cHOICE:Pick=A|B}", route: .expand("{cHOICE:Pick=A|B}", []), pasted: "{cHOICE:Pick=A|B}", keepsRich: false),
        ]
        for row in rows {
            let clip = rich(row.text)
            XCTAssertEqual(Snippets.pasteRoute(for: clip), row.route, row.text)
            pasted = []
            a.pasteTemplate(clip, named: "T", into: nil)
            XCTAssertEqual(pasted.count, 1, row.text)
            XCTAssertEqual(pasted.first?.plainText, row.pasted, row.text)
            XCTAssertEqual(pasted.first?.formats[ClipItem.Format.rtf] != nil, row.keepsRich, "rich formats: \(row.text)")
            XCTAssertEqual(pasted.first?.formats[ClipItem.Format.html] != nil, row.keepsRich, "rich formats: \(row.text)")
            if case .unescapeOnly = row.route {
                XCTAssertEqual(pasted.first?.contentHash, ClipItem.hash(of: Data(row.pasted.utf8)), "hash follows the new text")
                XCTAssertEqual(pasted.first?.id, clip.id)
            }
        }
    }

    /// PR #30 auditor's P3: a brace followed by a combining mark is one grapheme; compared as a
    /// Character it was not a brace, so `{{`+U+0301 lost its escape and an import that doubled
    /// braces per code point did not round-trip. The lexer walks scalars now.
    func testEscapesBesideCombiningMarks() {
        for mark in ["\u{301}", "\u{332}", "\u{FE0F}", "\u{200D}"] {
            let source = "a{" + mark + "b}" + mark + "{clipboard}"
            let escaped = source.unicodeScalars.map { $0 == "{" ? "{{" : $0 == "}" ? "}}" : String($0) }.joined()
            let route = Snippets.pasteRoute(for: rich(escaped))
            XCTAssertEqual(route, .unescapeOnly(source), "U+\(mark.unicodeScalars.first!.value)")
            if case .unescapeOnly(let text) = route {
                XCTAssertEqual(Array(text.unicodeScalars), Array(source.unicodeScalars))
            }
            // Through `expand` as well: an escaped brace before a mark stays a brace, a token after it is seen.
            let out = Snippets.expand("{{" + mark + "{clipboard}", context: ctxWithClip).text
            XCTAssertEqual(Array(out.unicodeScalars), Array(("{" + mark + "CLIP").unicodeScalars))
        }
    }

    private var ctxWithClip: Snippets.Context {
        var c = Snippets.Context()
        c.clipboard = { _ in "CLIP" }
        return c
    }

    func testNonTextClipsAreVerbatim() {
        let png = ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.png: Data([0x89])], sourceApp: nil, contentHash: "x")
        XCTAssertEqual(Snippets.pasteRoute(for: png), .verbatim)
        let files = ClipItem(id: UUID(), date: Date(), formats: [ClipItem.Format.files: Data("[\"/a/{b}\"]".utf8)], sourceApp: nil, contentHash: "x")
        XCTAssertEqual(Snippets.pasteRoute(for: files), .verbatim)
    }

    // MARK: dates

    private let d = Date(timeIntervalSince1970: 1_700_000_000)
    private var ctx: Snippets.Context {
        var c = Snippets.Context()
        c.now = d
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }
    private func fmt(_ date: Date, _ ds: DateFormatter.Style, _ ts: DateFormatter.Style) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateStyle = ds; f.timeStyle = ts
        return f.string(from: date)
    }

    func testNamedStyles() {
        XCTAssertEqual(Snippets.expand("{date:long}", context: ctx).text, fmt(d, .long, .none))
        XCTAssertEqual(Snippets.expand("{date:MEDIUM}", context: ctx).text, fmt(d, .medium, .none))
        XCTAssertEqual(Snippets.expand("{time:short}", context: ctx).text, fmt(d, .none, .short))
        XCTAssertEqual(Snippets.expand("{time:full}", context: ctx).text, fmt(d, .none, .full))
        XCTAssertEqual(Snippets.expand("{datetime:medium}", context: ctx).text, fmt(d, .medium, .medium))
        XCTAssertEqual(Snippets.expand("{date}", context: ctx).text, fmt(d, .short, .none), "bare {date} stays short")
        XCTAssertEqual(Snippets.expand("{date:yyyy}", context: ctx).text, "2023", "a pattern is still a pattern")
    }

    func testShiftsOnTimeAndDatetime() {
        let cal = Calendar.current
        let plusHour = cal.date(byAdding: .hour, value: 1, to: d)!
        XCTAssertEqual(Snippets.expand("{time+1h:short}", context: ctx).text, fmt(plusHour, .none, .short))
        XCTAssertEqual(Snippets.expand("{time+1h}", context: ctx).text, fmt(plusHour, .none, .short))
        let minusDay = cal.date(byAdding: .day, value: -1, to: d)!
        XCTAssertEqual(Snippets.expand("{datetime-1d:full}", context: ctx).text, fmt(minusDay, .full, .full))
        XCTAssertEqual(Snippets.expand("{datetime-1d:HH}", context: ctx).text, { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH"; return f.string(from: minusDay) }())
        XCTAssertEqual(Snippets.expand("{time+1x}", context: ctx).text, "{time+1x}", "a malformed shift stays as text")
    }

    func testSeveralShiftsInOneToken() {
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: -2, to: cal.date(byAdding: .year, value: 1, to: d)!)!
        XCTAssertEqual(Snippets.shifted(d, by: "+1y-2d", calendar: cal), expected)
        XCTAssertEqual(Snippets.shifted(d, by: "+1y-2d+3h-4w", calendar: cal),
                       cal.date(byAdding: .weekOfYear, value: -4, to: cal.date(byAdding: .hour, value: 3, to: expected)!)!)
        XCTAssertNil(Snippets.shifted(d, by: "+1y-2d+3h-4w+5m", calendar: cal), "five shifts is past the cap")
        XCTAssertNil(Snippets.shifted(d, by: "+1y-", calendar: cal))
        XCTAssertNil(Snippets.shifted(d, by: "+1y2d", calendar: cal), "every shift carries its sign")
        XCTAssertNil(Snippets.shifted(d, by: "+1y-12345d", calendar: cal))
        XCTAssertEqual(Snippets.expand("{date+1y-2d:yyyy-MM-dd}", context: ctx).text,
                       { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: expected) }())
    }
}
