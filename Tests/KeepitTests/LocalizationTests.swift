import XCTest
@testable import Keepit

final class LocalizationTests: XCTestCase {
    static let languages = ["en", "ru", "de", "fr", "es", "ja", "zh-Hans", "uk", "ar", "it"]

    private func table(_ lang: String) throws -> [String: String] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: lang),
                                "missing \(lang).lproj/Localizable.strings")
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "\(lang) does not parse")
        return dict
    }

    func testEveryLanguageHasTheSameKeys() throws {
        let en = try table("en")
        XCTAssertGreaterThan(en.count, 150)
        for lang in Self.languages.dropFirst() {
            let t = try table(lang)
            XCTAssertEqual(Set(t.keys), Set(en.keys), "\(lang) key set differs from en")
        }
    }

    func testPlaceholdersSurviveTranslation() throws {
        let re = try NSRegularExpression(pattern: "%[@d]")
        func ph(_ s: String) -> [String] {
            re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }
        }
        for lang in Self.languages {
            for (k, v) in try table(lang) {
                XCTAssertEqual(ph(k), ph(v), "[\(lang)] placeholders differ for \(k)")
                XCTAssertFalse(v.isEmpty, "[\(lang)] empty translation for \(k)")
            }
        }
    }

    func testLookupFallsBackToKey() {
        XCTAssertFalse(L("Cancel").isEmpty)            // whatever the machine's language is
        XCTAssertEqual(L("no such key 123"), "no such key 123")
        XCTAssertTrue(LF("%d item(s)", 3).contains("3"))
    }

    func testRussianTableIsUsed() throws {
        let ru = try table("ru")
        XCTAssertEqual(ru["Cancel"], "Отмена")
        XCTAssertEqual(ru["Quit Keepit"], "Завершить Keepit")
    }
}
