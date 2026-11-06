import Foundation

/// When Keepit locks itself after the Mac was locked or went to sleep: at once, after a delay the
/// Mac has to stay away for, or never. Pure, so the timing can be tested without AppKit; the app
/// feeds it the screen/sleep/session notifications and a clock.
///
/// A delay means a short absence changes nothing — the key stays in memory and the clipboard keeps
/// being recorded; only when the Mac has been away for the whole delay does Keepit lock. The clock,
/// not a timer, decides: a timer does not run while the Mac sleeps, so the deadline is checked again
/// when the Mac comes back.
struct ScreenLockPolicy: Equatable {
    /// Seconds the Mac must stay away; 0 = lock at once; nil = never.
    var delay: TimeInterval?
    /// When the current absence began; nil while the Mac is in use.
    private(set) var awaySince: Date?

    init(delay: TimeInterval?) { self.delay = delay }

    /// The Mac was locked, went to sleep or the session resigned. Returns true when Keepit must lock now.
    mutating func wentAway(at now: Date) -> Bool {
        guard let delay else { return false }
        if awaySince == nil { awaySince = now }
        return delay <= 0
    }

    /// The screen was unlocked, the Mac woke or the session became active again.
    /// Returns true when the absence lasted at least the delay — Keepit must lock now (it may already have).
    mutating func cameBack(at now: Date) -> Bool {
        defer { awaySince = nil }
        guard let delay, let since = awaySince else { return false }
        return now.timeIntervalSince(since) >= delay
    }

    /// The moment a timer may fire while the Mac is away, if it runs at all; nil when nothing is pending.
    var deadline: Date? {
        guard let delay, delay > 0, let since = awaySince else { return nil }
        return since.addingTimeInterval(delay)
    }

    /// A timer fired at `now` while the Mac is still away. True when Keepit must lock now.
    func timerFired(at now: Date) -> Bool {
        guard let d = deadline else { return false }
        return now >= d
    }
}
