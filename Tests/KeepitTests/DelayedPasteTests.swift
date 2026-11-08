import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Keepit

/// SEC08 — a paste is a ticket checked immediately before every key event (`DESIGN-3.0.7.md`,
/// SEC08). The whole timeline runs here against a fake clock, a fake scheduler, a fake front app
/// and a fake pasteboard: nothing touches the real pasteboard, the keyboard or another process.
final class DelayedPasteTests: XCTestCase {
    final class FakeTarget: PasteTarget {
        let processIdentifier: pid_t
        var isTerminated = false
        var bundleIdentifier: String? = "com.example.editor"
        var activations = 0
        init(pid: pid_t) { processIdentifier = pid }
        func bringToFront() { activations += 1 }
    }

    var tmp: TempStorage!
    var monitor: ClipboardMonitor!
    var settings = Settings()
    var target: FakeTarget!
    var frontPID: pid_t? = 1              // something else is in front until a test says otherwise
    var changeCount = 10
    var modifiersHeld = false
    var locked = false
    var generation = 0
    var clock = Date(timeIntervalSince1970: 1_800_000_000)
    var queue: [(delay: TimeInterval, body: () -> Void)] = []
    var delays: [TimeInterval] = []
    var events: [(key: PasteKey, pid: pid_t)] = []
    var written: [String] = []

    override func setUp() {
        tmp = TempStorage()
        settings = Settings()
        settings.pasteAfterSelect = true
        settings.pasteDelay = 0
        monitor = ClipboardMonitor(settings: settings)
        target = FakeTarget(pid: 4242)
        frontPID = 1; changeCount = 10; modifiersHeld = false; locked = false; generation = 0
        queue = []; delays = []; events = []; written = []
        Paster.cancelPending()
        Paster.trustedForTesting = true
        Paster.pasteboardWriteForTesting = { [unowned self] in self.written.append($0.plainText ?? ""); self.changeCount += 1 }
        Paster.eventSinkForTesting = { [unowned self] k, pid in self.events.append((k, pid)) }
        Paster.frontmostPIDForTesting = { [unowned self] in self.frontPID }
        Paster.changeCountForTesting = { [unowned self] in self.changeCount }
        Paster.modifiersHeldForTesting = { [unowned self] in self.modifiersHeld }
        Paster.nowForTesting = { [unowned self] in self.clock }
        Paster.scheduleForTesting = { [unowned self] delay, body in self.queue.append((delay, body)) }
        Paster.gate = { [unowned self] g in !self.locked && g == self.generation }
        Paster.currentGeneration = { [unowned self] in self.generation }
    }

    override func tearDown() {
        Paster.cancelPending()
        Paster.trustedForTesting = nil
        Paster.pasteboardWriteForTesting = nil
        Paster.eventSinkForTesting = nil
        Paster.frontmostPIDForTesting = nil
        Paster.changeCountForTesting = nil
        Paster.modifiersHeldForTesting = nil
        Paster.nowForTesting = nil
        Paster.scheduleForTesting = nil
        Paster.gate = nil
        Paster.currentGeneration = nil
        tmp.restore()
    }

    // MARK: driving the fake scheduler

    /// Runs the next scheduled step: the fake clock advances by its delay first.
    @discardableResult
    private func step() -> Bool {
        guard !queue.isEmpty else { return false }
        let next = queue.removeFirst()
        delays.append(next.delay)
        clock.addTimeInterval(next.delay)
        next.body()
        return true
    }
    private func runToEnd(limit: Int = 500) {
        var n = 0
        while step() { n += 1; if n > limit { return XCTFail("the timeline did not end") } }
    }
    private func paste(_ text: String = "hello", sendKey: Bool = true, extraDelay: TimeInterval = 0, cursorBack: Int = 0) {
        Paster.paste(.text(text), into: target, monitor: monitor, settings: settings, sendKey: sendKey, extraDelay: extraDelay, cursorBack: cursorBack)
    }
    private var commandV: PasteKey { PasteKey.commandV }
    private var left: PasteKey { PasteKey(keyCode: UInt16(kVK_LeftArrow), command: false) }

    // MARK: the ordinary paths

    func testOrdinaryPastePostsOnePairToTheTargetsPid() {
        frontPID = target.processIdentifier
        paste()
        XCTAssertEqual(written, ["hello"])
        XCTAssertEqual(target.activations, 1)
        XCTAssertNotNil(Paster.pending)
        runToEnd()
        XCTAssertEqual(events.map { $0.pid }, [target.processIdentifier])
        XCTAssertEqual(events.map { $0.key }, [commandV])
        XCTAssertNil(Paster.pending, "done")
    }

    func testCursorMovesFollowThePasteKeyAsPartOfTheSameTicket() {
        frontPID = target.processIdentifier
        paste(cursorBack: 3)
        runToEnd()
        XCTAssertEqual(events.map { $0.key }, [commandV, left, left, left])
        XCTAssertEqual(delays.filter { $0 == Paster.cursorMoveDelay }.count, 1, "the first move 0.25 s after ⌘V, the rest at once")
        XCTAssertTrue(events.allSatisfy { $0.pid == target.processIdentifier })
    }

    func testTheUsersDelayIsAMinimumEvenWhenTheTargetIsAlreadyInFront() {
        settings.pasteDelay = 3
        frontPID = target.processIdentifier
        paste(extraDelay: 0.35)
        XCTAssertEqual(queue.first?.delay ?? 0, 3.35, accuracy: 0.001, "nothing happens before the delay")
        runToEnd()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(delays.first ?? 0, 3.35, accuracy: 0.001)
    }

    func testWithZeroDelayThePasteWaitsForTheTargetToComeToTheFront() {
        paste()
        step()                                    // the minimum delay (0) has passed; the target is not in front
        XCTAssertEqual(events.count, 0)
        step(); step()                            // two polls
        XCTAssertEqual(events.count, 0)
        frontPID = target.processIdentifier       // activation took
        runToEnd()
        XCTAssertEqual(events.count, 1)
        XCTAssertLessThanOrEqual(clock.timeIntervalSince(Date(timeIntervalSince1970: 1_800_000_000)), Paster.readinessWindow + 0.05)
    }

    func testATargetThatNeverComesToTheFrontIsCancelledAtTheCeilingAndTheItemStaysOnThePasteboard() {
        paste()
        let ticket = Paster.pending
        runToEnd()
        XCTAssertEqual(events.count, 0)
        XCTAssertEqual(ticket?.cancelled, true)
        XCTAssertNil(Paster.pending)
        XCTAssertEqual(written, ["hello"], "the data is there for a manual ⌘V")
        XCTAssertGreaterThanOrEqual(clock.timeIntervalSince(Date(timeIntervalSince1970: 1_800_000_000)), Paster.readinessWindow)
    }

    // MARK: everything that cancels

    func testALockCancelsThePendingPaste() {
        frontPID = target.processIdentifier
        paste()
        Paster.cancelPending("Keepit locked")       // what lock() calls
        runToEnd()
        XCTAssertEqual(events.count, 0)
        XCTAssertNil(Paster.pending)
    }

    func testTheGateRefusesALockedAppAndAMovedGeneration() {
        frontPID = target.processIdentifier
        paste()
        locked = true
        runToEnd()
        XCTAssertEqual(events.count, 0, "locked")

        locked = false
        paste()
        generation += 1                             // lock, unlock
        runToEnd()
        XCTAssertEqual(events.count, 0, "another lock generation")
    }

    func testTheUserSwitchingAppsCancels() {
        frontPID = target.processIdentifier
        paste()
        frontPID = 7                                // another app came to the front after activation
        runToEnd()
        XCTAssertEqual(events.count, 0)
        XCTAssertEqual(written, ["hello"])
    }

    func testTheTargetQuittingCancels() {
        frontPID = target.processIdentifier
        paste()
        target.isTerminated = true
        runToEnd()
        XCTAssertEqual(events.count, 0)
    }

    func testAnotherAppWritingThePasteboardCancels() {
        frontPID = target.processIdentifier
        paste()
        changeCount += 1                            // someone else wrote since our write
        runToEnd()
        XCTAssertEqual(events.count, 0)
    }

    func testModifiersHeldPastTheAttemptsCancelInsteadOfSending() {
        frontPID = target.processIdentifier
        modifiersHeld = true
        paste()
        runToEnd()
        XCTAssertEqual(events.count, 0, "⌘V with a held ⌥ is a different command: not sent")
        XCTAssertEqual(delays.filter { $0 == Paster.modifierPoll }.count, Paster.modifierAttempts)
    }

    func testModifiersReleasedInTimeLetThePasteThrough() {
        frontPID = target.processIdentifier
        modifiersHeld = true
        paste()
        step()                                      // delay
        step(); step()                              // two modifier polls
        modifiersHeld = false
        runToEnd()
        XCTAssertEqual(events.map { $0.key }, [commandV])
    }

    func testModifiersPressedBeforeACursorMoveCancelTheRemainingMoves() {
        frontPID = target.processIdentifier
        paste(cursorBack: 2)
        step()                                      // delay → readiness → modifiers → ⌘V posted
        XCTAssertEqual(events.map { $0.key }, [commandV])
        modifiersHeld = true
        runToEnd()
        XCTAssertEqual(events.map { $0.key }, [commandV], "no arrow with a modifier")
        XCTAssertNil(Paster.pending)
    }

    func testANewPasteCancelsTheOldTicketsRemainingArrows() {
        frontPID = target.processIdentifier
        paste("first", cursorBack: 2)
        step()                                      // ⌘V of the first
        XCTAssertEqual(events.map { $0.key }, [commandV])
        paste("second")                             // before the first's arrows
        runToEnd()
        XCTAssertEqual(events.map { $0.key }, [commandV, commandV], "the first's arrows never fire")
        XCTAssertEqual(written, ["first", "second"])
    }

    func testACancelledTicketLeavesNoHalfPair() {
        // A pair is one call to the sink; cancellation can only happen between calls.
        frontPID = target.processIdentifier
        paste(cursorBack: 1)
        runToEnd()
        XCTAssertEqual(events.count, 2)
    }

    // MARK: no target, no keys

    func testNoTargetMeansPasteboardOnly() {
        Paster.paste(.text("x"), into: nil, monitor: monitor, settings: settings, sendKey: true)
        XCTAssertEqual(written, ["x"])
        XCTAssertNil(Paster.pending)
        XCTAssertTrue(queue.isEmpty, "nothing scheduled")
        runToEnd()
        XCTAssertEqual(events.count, 0)
    }

    func testKeepitItselfOrATerminatedAppIsNoTarget() {
        let me = FakeTarget(pid: ProcessInfo.processInfo.processIdentifier)
        Paster.paste(.text("x"), into: me, monitor: monitor, settings: settings, sendKey: true)
        XCTAssertNil(Paster.pending)
        target.isTerminated = true
        paste()
        XCTAssertNil(Paster.pending)
        XCTAssertTrue(queue.isEmpty)
    }

    func testSendKeyFalseLeavesNothingPending() {
        frontPID = target.processIdentifier
        paste(sendKey: false)
        XCTAssertEqual(written, ["hello"])
        XCTAssertNil(Paster.pending)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(target.activations, 0)
    }

    func testWithoutAccessibilityTheItemIsOnThePasteboardAndNothingIsPending() {
        Paster.trustedForTesting = false
        frontPID = target.processIdentifier
        paste()
        XCTAssertEqual(written, ["hello"])
        XCTAssertNil(Paster.pending)
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: the app's side

    func testLockCancelsThePendingPasteAndTheGateFollowsTheLockCount() throws {
        Storage.key = try Vault.enable(password: .of("pw"), rounds: 1000)
        let app = AppDelegate()                     // sets Paster.gate / currentGeneration
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        Vault.errorSinkForTesting = { _ in }
        defer { Vault.errorSinkForTesting = nil; Storage.clearKey() }
        frontPID = target.processIdentifier
        paste()
        let ticket = try XCTUnwrap(Paster.pending)
        XCTAssertEqual(ticket.generation, app.lockCount)
        app.lock()
        XCTAssertNil(Paster.pending)
        XCTAssertTrue(ticket.cancelled)
        XCTAssertEqual(Paster.gate?(ticket.generation), false, "locked")
        runToEnd()
        XCTAssertEqual(events.count, 0)
    }
}
