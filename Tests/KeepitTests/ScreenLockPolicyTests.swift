import XCTest
@testable import Keepit

/// Settings → Security → "Lock when the Mac is locked or asleep": never (default), at once, or after
/// the Mac has stayed away for a delay. The clock decides, not a timer.
final class ScreenLockPolicyTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    func testNeverNeverLocks() {
        var p = ScreenLockPolicy(delay: nil)
        XCTAssertFalse(p.wentAway(at: t0))
        XCTAssertNil(p.deadline)
        XCTAssertFalse(p.timerFired(at: at(99_999)))
        XCTAssertFalse(p.cameBack(at: at(99_999)))
    }

    func testImmediatelyLocksOnTheWayOut() {
        var p = ScreenLockPolicy(delay: 0)
        XCTAssertTrue(p.wentAway(at: t0))
        XCTAssertNil(p.deadline, "nothing to wait for")
    }

    func testShortAbsenceChangesNothing() {
        var p = ScreenLockPolicy(delay: 15 * 60)
        XCTAssertFalse(p.wentAway(at: t0))
        XCTAssertEqual(p.deadline, at(15 * 60))
        XCTAssertFalse(p.timerFired(at: at(14 * 60)))
        XCTAssertFalse(p.cameBack(at: at(14 * 60)))
        XCTAssertNil(p.deadline, "the absence is over")
        XCTAssertFalse(p.cameBack(at: at(60 * 60)), "a second 'back' without a new 'away' is not an absence")
    }

    func testLongAbsenceLocksWhenTheTimerFiresOrWhenTheMacComesBack() {
        var p = ScreenLockPolicy(delay: 15 * 60)
        _ = p.wentAway(at: t0)
        XCTAssertTrue(p.timerFired(at: at(15 * 60)))
        // The Mac slept through the deadline: the timer never fired, the wake-up check must catch it.
        var q = ScreenLockPolicy(delay: 15 * 60)
        _ = q.wentAway(at: t0)
        XCTAssertTrue(q.cameBack(at: at(3 * 3600)))
    }

    func testRepeatedAwayNotificationsKeepTheFirstMoment() {
        var p = ScreenLockPolicy(delay: 10 * 60)
        _ = p.wentAway(at: t0)                       // screen locked
        _ = p.wentAway(at: at(5 * 60))               // then the Mac slept
        XCTAssertEqual(p.deadline, at(10 * 60))
        XCTAssertTrue(p.cameBack(at: at(10 * 60)))
    }
}
