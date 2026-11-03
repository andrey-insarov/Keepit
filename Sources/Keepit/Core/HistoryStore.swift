import Foundation

/// Ordered clipboard history, newest first.
final class HistoryStore {
    private(set) var items: [ClipItem] = []
    var settings: Settings
    var onChange: (() -> Void)?

    private lazy var saver = DebouncedSaver(delay: 1.5) { [weak self] background in self?.saveNow(background: background) }
    /// True between `purge()` (lock) and the next `reload()`: memory is empty on purpose and must
    /// never be written over the file on disk — quitting or updating while locked used to do that.
    private(set) var isPurged = false

    init(settings: Settings) {
        self.settings = settings
        reload()
    }

    /// (Re)load from disk — used at start and after unlocking.
    func reload() {
        isPurged = false
        items = []
        if settings.historySave, let loaded = Storage.load([ClipItem].self, from: Storage.historyURL) {
            items = loaded
            trim()
        }
        onChange?()
    }

    /// Drop everything from memory without touching the disk (lock).
    func purge() {
        saver.flush()
        isPurged = true
        items = []
        onChange?()
    }

    func add(_ item: ClipItem) {
        if settings.overlapCheck {
            items.removeAll { $0.contentHash == item.contentHash }
        }
        items.insert(item, at: 0)
        trim()
        changed()
    }

    /// Called when the user pastes an item from the menu.
    func touch(_ item: ClipItem) {
        guard settings.moveToTopOnPaste, let idx = items.firstIndex(where: { $0.id == item.id }), idx != 0 else { return }
        let it = items.remove(at: idx)
        items.insert(it, at: 0)
        changed()
    }

    func item(id: UUID) -> ClipItem? {
        items.first { $0.id == id }
    }

    /// Viewer edit: replace an item (same id) in place.
    func replace(_ item: ClipItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        changed()
    }

    /// Insert without dedupe/trim semantics of `add` (used by Viewer "New Item" / drag into history).
    func insert(_ item: ClipItem, at index: Int) {
        items.insert(item, at: min(max(0, index), items.count))
        trim()
        changed()
    }

    /// Viewer Up/Down.
    func move(id: UUID, by delta: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard j >= 0, j < items.count else { return }
        items.swapAt(i, j)
        changed()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        changed()
    }

    func clear() {
        items.removeAll()
        changed()
    }

    /// Backup import, "Replace": the imported list becomes the history (trimmed to the limits).
    func replaceAll(_ newItems: [ClipItem]) {
        items = newItems
        trim()
        changed()
    }

    /// Backup import, "Merge": append imported items whose content is not already present,
    /// keeping the current items newest. Returns how many were added.
    @discardableResult
    func merge(_ newItems: [ClipItem]) -> Int {
        var seen = Set(items.map(\.contentHash))
        var added = 0
        for it in newItems where !seen.contains(it.contentHash) {
            seen.insert(it.contentHash)
            items.append(it)
            added += 1
        }
        trim()
        changed()
        return added
    }

    func updateSettings(_ s: Settings) {
        settings = s
        trim()
        changed()
    }

    var textItems: [ClipItem] { items.filter { $0.kind != .image } }
    var imageItems: [ClipItem] { items.filter { $0.kind == .image } }

    /// Drop items older than `historyMaxAge` (no-op when 0). Returns how many were removed.
    /// Called from `trim()` on every change and by the app's minute timer, so items also vanish
    /// while nothing is being copied.
    @discardableResult
    func expire(now: Date = Date()) -> Int {
        guard settings.historyMaxAge > 0 else { return 0 }
        let cutoff = now.addingTimeInterval(-settings.historyMaxAge)
        let before = items.count
        items.removeAll { $0.date < cutoff }
        let removed = before - items.count
        if removed > 0 { changed() }
        return removed
    }

    /// Two independent rings: text/file items and image items, each dropping its oldest first.
    private func trim() {
        if settings.historyMaxAge > 0 {
            let cutoff = Date().addingTimeInterval(-settings.historyMaxAge)
            items.removeAll { $0.date < cutoff }
        }
        var textSeen = 0, imageSeen = 0
        items = items.filter { item in
            if item.kind == .image {
                imageSeen += 1
                return imageSeen <= settings.historyImageMax
            } else {
                textSeen += 1
                return textSeen <= settings.historyMax
            }
        }
        var total = items.reduce(0) { $0 + $1.byteSize }
        while total > settings.maxHistoryBytes, items.count > 1 {
            total -= items.removeLast().byteSize
        }
    }

    private func changed() {
        onChange?()
        if settings.historySave { saver.schedule() }
    }

    /// Write the history to disk. `background: true` (debounced saves) queues the encode/encrypt/write
    /// off the main thread; the default waits for it.
    func saveNow(background: Bool = false) {
        if isPurged { return }
        if settings.historySave {
            Storage.save(items, to: Storage.historyURL, background: background)
        } else {
            try? FileManager.default.removeItem(at: Storage.historyURL)
        }
    }

    func flush() {
        if settings.historySave { saver.flush() }
    }
}
