import Foundation

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

    func stop() {
        guard isActive else { return }
        isActive = false
        timer?.invalidate(); timer = nil
        items = []; next = 0
        onChange?()
    }

    func toggle() { isActive ? stop() : start() }

    /// A new clipboard capture while the queue is on.
    func record(_ item: ClipItem) {
        guard isActive else { return }
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
            isActive = false
            timer?.invalidate(); timer = nil
            onChange?()
            onAutoStop?()
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
        next = items.count
        isActive = false
        timer?.invalidate(); timer = nil
        onChange?()
        onAutoStop?()
        return texts.joined(separator: separator)
    }

    private func armTimer() {
        timer?.invalidate()
        guard timeout > 0 else { timer = nil; return }
        let t = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.isActive = false
            self.timer = nil
            self.items = []; self.next = 0
            self.onChange?()
            self.onAutoStop?()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
