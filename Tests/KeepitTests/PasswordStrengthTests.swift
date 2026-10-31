import XCTest
@testable import Keepit

final class PasswordStrengthTests: XCTestCase {
    private func level(_ s: String) -> PasswordStrength.Level? { PasswordStrength.evaluate(.of(s))?.level }

    func testLevels() {
        XCTAssertNil(PasswordStrength.evaluate(.of("")))
        XCTAssertEqual(level("1234"), .weak)
        XCTAssertEqual(level("password"), .weak)
        XCTAssertEqual(level("aaaaaaaaaaaa"), .weak)
        XCTAssertEqual(level("Tr0ub4dor"), .fair)
        XCTAssertEqual(level("Correct-7"), .good)
        XCTAssertEqual(level("Correct-Horse-7"), .excellent)
        XCTAssertEqual(level("correct horse battery staple 2026!"), .excellent)
    }

    func testNonASCIICounted() {
        XCTAssertNotEqual(level("пароль"), nil)
        XCTAssertEqual(level("Очень длинная русская фраза 42"), .excellent)
    }
}
