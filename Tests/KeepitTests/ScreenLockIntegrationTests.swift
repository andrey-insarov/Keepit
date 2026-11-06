import AppKit
import XCTest
@testable import Keepit

/// The lock-after-delay lifecycle on a real AppDelegate with a temporary vault: the handlers macOS's
/// notifications call, the deadline across sleep, and the one automatic Touch ID prompt. Seeded from
/// the auditor's integration tests of 6 Nov 2026 (didWake used to clear the absence; a queued prompt
/// outlived a new lock, a second "back", a settings change). The modal unlock is replaced by a counter.
final class ScreenLockIntegrationTests: XCTestCase {
    private var storage: TempStorage!

    override func setUpWithError() throws {
        _ = NSApplication.shared
        storage = TempStorage()
        try FileManager.default.createDirectory(at: storage.dir, withIntermediateDirectories: true)
    }
    override func tearDown() { storage.restore() }

    private func app(delay: TimeInterval?, biometric: Bool = false) throws -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        var s = a.settings
        s.lockAfterScreenLock = delay
        s.biometricUnlock = biometric
        a.apply(settings: s)
        Storage.key = try Vault.enable(password: .of("test-only"), rounds: 1000)
        return a
    }

    private func letJobsRun() {
        let e = expectation(description: "0.8 s auto-unlock jobs")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { e.fulfill() }
        wait(for: [e], timeout: 3)
    }

    // MARK: away / back / wake

    func testImmediatelyWipesOnAway() throws {
        let a = try app(delay: 0)
        a.macWentAway()
        XCTAssertTrue(a.isLocked)
        XCTAssertNil(Storage.key)
        XCTAssertTrue(a.history.isPurged)
        XCTAssertTrue(a.templates.isPurged)
    }

    func testNeverLeavesEverythingLoaded() throws {
        let a = try app(delay: nil)
        a.macWentAway()
        XCTAssertFalse(a.isLocked)
        XCTAssertNotNil(Storage.key)
        XCTAssertNil(a.screenLockTimer)
    }

    func testWakeAtTheLoginWindowKeepsTheAbsenceAndTheTimer() throws {
        let a = try app(delay: 300)
        a.macWentAway()
        let since = try XCTUnwrap(a.screenLockPolicy.awaySince)
        XCTAssertNotNil(a.screenLockTimer)
        a.macWoke()                                       // 1 s later, still at the login window
        XCTAssertEqual(a.screenLockPolicy.awaySince, since)
        XCTAssertEqual(a.screenLockPolicy.deadline, since.addingTimeInterval(300))
        XCTAssertTrue(a.screenLockTimer?.isValid == true)
        XCTAssertFalse(a.isLocked)
        a.screenLocked(false)                             // the real return
        XCTAssertNil(a.screenLockPolicy.awaySince)
        XCTAssertNil(a.screenLockTimer)
    }

    func testSessionActiveWithTheScreenStillLockedIsNotBack() throws {
        let a = try app(delay: 300)
        a.screenLocked(true)
        let since = a.screenLockPolicy.awaySince
        // sessionDidBecomeActive is routed through the observer only when the screen is unlocked;
        // the handler the observer would skip is macCameBack — model the observer's guard here.
        if !a.screenIsLocked { a.macCameBack() }
        XCTAssertEqual(a.screenLockPolicy.awaySince, since)
    }

    func testSleepWithoutAScreenLockEndsOnWake() throws {
        let a = try app(delay: 300)
        a.screenLockedProbe = { false }                  // no password after sleep: wake = desktop
        a.macWentAway()                                  // willSleep
        XCTAssertNotNil(a.screenLockPolicy.awaySince)
        a.macWoke()                                      // didWake, no screenIsUnlocked will follow
        XCTAssertNil(a.screenLockPolicy.awaySince)
        XCTAssertNil(a.screenLockTimer)
        XCTAssertFalse(a.isLocked)
    }

    func testAProbeThatNeverSaysUnlockedDoesNotEndTheAbsence() throws {
        let a = try app(delay: 300)
        a.macWentAway()
        let since = a.screenLockPolicy.awaySince
        var calls = 0
        a.screenLockedProbe = { calls += 1; return calls == 1 ? nil : true }   // unknown, then locked — never false
        a.macWoke()
        XCTAssertEqual(a.screenLockPolicy.awaySince, since)
        XCTAssertTrue(a.screenLockTimer?.isValid == true)
        XCTAssertEqual(calls, 1, "one reading per wake")
    }

    func testSleepBehindALockedScreenKeepsWaitingOnWake() throws {
        for probe in [{ true }, { nil }] as [() -> Bool?] {
            let a = try app(delay: 300)
            a.screenLockedProbe = probe
            a.macWentAway()
            let since = a.screenLockPolicy.awaySince
            a.macWoke()
            XCTAssertEqual(a.screenLockPolicy.awaySince, since)
            XCTAssertTrue(a.screenLockTimer?.isValid == true)
        }
    }

    func testAnOpenDuringTheUnlockPromptWaitsInTheQueue() throws {
        let a = try app(delay: 0)
        a.setReadyForOpensForTesting(true)
        a.macWentAway()                                  // locked
        a.setUnlockInProgressForTesting(true)            // the password prompt is up
        let url = URL(string: "keepit://viewer")!      // URL commands are off: handling it is a beep, no dialog
        a.application(NSApp, open: [url])
        XCTAssertEqual(a.pendingOpenURLs, [url], "not dequeued while a prompt is on screen")
        a.setUnlockInProgressForTesting(false)
        a.setLockedForTesting(false)
        a.openPendingURLs()                              // what unlock() does when the prompt is gone
        XCTAssertTrue(a.pendingOpenURLs.isEmpty)
    }

    // MARK: the automatic prompt

    func testOnePromptAfterComingBackWhenLockedWithTouchID() throws {
        let a = try app(delay: 0, biometric: true)
        a.macWentAway()
        var attempts = 0
        a.autoUnlockForTesting = { attempts += 1 }
        a.screenLocked(false)
        XCTAssertNotNil(a.autoUnlockJob)
        letJobsRun()
        XCTAssertEqual(attempts, 1)
        XCTAssertNil(a.autoUnlockJob)
    }

    func testNoPromptWithoutTouchIDOrWhenUnlocked() throws {
        let a = try app(delay: 0, biometric: false)
        a.macWentAway()
        var attempts = 0
        a.autoUnlockForTesting = { attempts += 1 }
        a.screenLocked(false)
        XCTAssertNil(a.autoUnlockJob)
        let b = try app(delay: nil, biometric: true)
        b.autoUnlockForTesting = { attempts += 1 }
        b.screenLocked(false)
        XCTAssertNil(b.autoUnlockJob, "unlocked: nothing to prompt for")
        letJobsRun()
        XCTAssertEqual(attempts, 0)
    }

    func testANewAwayCancelsTheQueuedPrompt() throws {
        let a = try app(delay: 0, biometric: true)
        a.macWentAway()
        var attempts = 0
        a.autoUnlockForTesting = { attempts += 1 }
        a.screenLocked(false)
        a.screenLocked(true)                              // locked again within 0.8 s
        XCTAssertNil(a.autoUnlockJob)
        letJobsRun()
        XCTAssertEqual(attempts, 0)
    }

    func testAManualUnlockThenALockCancelsTheOldPrompt() throws {
        let a = try app(delay: 0, biometric: true)
        a.macWentAway()
        var attempts = 0
        a.autoUnlockForTesting = { attempts += 1 }
        a.screenLocked(false)
        a.setLockedForTesting(false)                      // the user unlocked by hand
        a.lock()                                          // and locked again — a new generation
        letJobsRun()
        XCTAssertEqual(attempts, 0)
    }

    func testTwoBackEventsMakeOnePrompt() throws {
        let a = try app(delay: 0, biometric: true)
        a.macWentAway()
        var attempts = 0
        a.autoUnlockForTesting = { attempts += 1 }
        a.screenLocked(false)
        a.macCameBack()                                   // sessionDidBecomeActive right after
        letJobsRun()
        XCTAssertEqual(attempts, 1)
    }

    func testTurningTouchIDOffCancelsTheQueuedPrompt() throws {
        let a = try app(delay: 0, biometric: true)
        a.macWentAway()
        var attempts = 0
        a.autoUnlockForTesting = { attempts += 1 }
        a.screenLocked(false)
        var s = a.settings; s.biometricUnlock = false; a.apply(settings: s)
        XCTAssertNil(a.autoUnlockJob)
        letJobsRun()
        XCTAssertEqual(attempts, 0)
    }

    func testOpenOrRestoreInProgressSkipsThePrompt() throws {
        for restore in [false, true] {
            let a = try app(delay: 0, biometric: true)
            a.macWentAway()
            var attempts = 0
            a.autoUnlockForTesting = { attempts += 1 }
            a.screenLocked(false)
            if restore { a.restoreInProgress = true } else { a.openInProgress = true }
            letJobsRun()
            XCTAssertEqual(attempts, 0)
        }
    }
}
