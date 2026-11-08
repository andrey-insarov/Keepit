import AppKit

/// Serial copy-and-paste ("paste queue").
///
/// Turn it on, copy several things in a row, then paste them back one by one in the same order with
/// a single key. The queue holds copies of the items (not history indexes), so deduplication or
/// "move to top on paste" in the history cannot shuffle it. It ends by itself when the last item has
/// been pasted or when nothing happens for `timeout` seconds.
final class PasteQueue {
    private(set) var items: [ClipItem] = []     // in copy order
    private(set) var next = 0                   // index of the item the next paste takes
    private(set) var isActive = false
    var timeout: TimeInterval = 120
    /// Called on every change (start, stop, copy, paste) — the UI reads `isActive` / `remaining`.
    var onChange: (() -> Void)?
    /// Called when the queue ends by itself (exhausted or timed out), after `onChange`.
    var onAutoStop: (() -> Void)?

    private var timer: Timer?

    var remaining: Int { items.count - next }
    var pending: ArraySlice<ClipItem> { items[next...] }
    var nextItem: ClipItem? { next < items.count ? items[next] : nil }
    func wasPasted(_ id: UUID) -> Bool { items[..<next].contains { $0.id == id } }
    func isNext(_ id: UUID) -> Bool { nextItem?.id == id }
    func isQueued(_ id: UUID) -> Bool { pending.contains { $0.id == id } }

    func start() {
        items = []; next = 0; isActive = true
        armTimer()
        onChange?()
    }

    /// Ends the queue and drops its copies. Also on a queue that already ended by itself: nothing
    /// may stay behind (3.0.5 security review, SEC05 — `stop()` returned early then, and the copies
    /// taken under the queue outlived it; a lock calls this). Announces a change only if it was on.
    func stop() {
        let wasActive = isActive
        isActive = false
        timer?.invalidate(); timer = nil
        items = []; next = 0
        if wasActive { onChange?() }
    }

    /// The queue ended by itself (last item taken, or the timeout): nothing of what it held stays.
    private func exhausted() {
        isActive = false
        timer?.invalidate(); timer = nil
        items = []; next = 0
        onChange?()
        onAutoStop?()
    }

    func toggle() { isActive ? stop() : start() }

    /// A new clipboard capture while the queue is on.
    func record(_ item: ClipItem) {
        guard isActive else { return }
        guard items.count < Limits.queueMaxItems else { NSSound.beep(); return }   // a runaway copier cannot grow it forever
        items.append(item)
        armTimer()
        onChange?()
    }

    /// The item to paste now, or nil when the queue is empty. Advances the queue; when the last item
    /// has been taken the queue stops itself.
    func take() -> ClipItem? {
        guard isActive, let item = nextItem else { return nil }
        next += 1
        if next >= items.count {
            exhausted()                               // the copies go with it (SEC05)
        } else {
            armTimer()
            onChange?()
        }
        return item
    }

    /// Everything not yet pasted, as one text (text items only), then the queue stops.
    func takeAll(separator: String) -> String? {
        guard isActive else { return nil }
        let texts = pending.compactMap { $0.plainText }
        guard !texts.isEmpty else { return nil }
        exhausted()
        return texts.joined(separator: separator)
    }

    private func armTimer() {
        timer?.invalidate()
        guard timeout > 0 else { timer = nil; return }
        let t = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.exhausted()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
