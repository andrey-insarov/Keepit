import Foundation

/// Ordered clipboard history, newest first.
final class HistoryStore {
    private(set) var items: [ClipItem] = []
    var settings: Settings
    var onChange: (() -> Void)?

    private lazy var saver = DebouncedSaver(delay: 1.5) { [weak self] in self?.saveNow() }

    init(settings: Settings) {
        self.settings = settings
        reload()
    }

    /// (Re)load from disk — used at start and after unlocking.
    func reload() {
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

    func updateSettings(_ s: Settings) {
        settings = s
        trim()
        changed()
    }

    private func trim() {
        if items.count > settings.historyMax {
            items.removeLast(items.count - settings.historyMax)
        }
    }

    private func changed() {
        onChange?()
        if settings.historySave { saver.schedule() }
    }

    func saveNow() {
        if settings.historySave {
            Storage.save(items, to: Storage.historyURL)
        } else {
            try? FileManager.default.removeItem(at: Storage.historyURL)
        }
    }

    func flush() {
        if settings.historySave { saver.flush() }
    }
}
