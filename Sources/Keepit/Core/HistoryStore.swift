import Foundation

/// Ordered clipboard history, newest first.
final class HistoryStore {
    private(set) var items: [ClipItem] = []
    var settings: Settings
    var onChange: (() -> Void)?
    /// Bumped on every change to `items` (edits, reload, purge). A plan computed from the store is
    /// valid only while this is what it was when the plan was made.
    private(set) var revision = 0

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
        revision += 1
        items = []
        if settings.historySave, let loaded = Storage.load([ClipItem].self, from: Storage.historyURL) {
            items = Self.validated(loaded)
            trim()
        }
        onChange?()
    }

    /// The file on disk is decoded, not trusted: every item passes the same validator as a backup's
    /// (content, hash, unique id). A rich format that fails is dropped from its item; an item whose
    /// primary content fails, or a second item with an id already seen, is left out — and the file is
    /// copied aside first, so nothing is lost to a rule that turns out to be too strict.
    /// First holder of an id wins.
    static func uniqueIDs(_ items: [ClipItem]) -> [ClipItem] {
        var ids = Set<UUID>()
        return items.filter { ids.insert($0.id).inserted }
    }

    static func validated(_ loaded: [ClipItem]) -> [ClipItem] {
        var ids = Set<UUID>()
        var out: [ClipItem] = []
        var dropped = 0, repaired = 0
        for item in loaded {
            guard let ok = item.validated(), ids.insert(ok.id).inserted else { dropped += 1; continue }
            if ok.formats.count != item.formats.count { repaired += 1 }
            out.append(ok)
        }
        if dropped > 0 || repaired > 0 {
            Log.storage.error("history.json: \(dropped) items dropped, \(repaired) stripped of a rich format — a copy was kept next to it")
            Storage.keepCopy(of: Storage.historyURL)
        }
        return out
    }

    /// Drop everything from memory without touching the disk (lock).
    func purge() {
        saver.flush()
        isPurged = true
        revision += 1
        items = []
        onChange?()
    }

    func add(_ item: ClipItem) {
        guard (try? Backup.validate(item: item)) != nil else { Log.storage.error("history: refused an item that fails validation"); return }
        items.removeAll { $0.id == item.id }                 // one holder per id: the newer takes the place
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

    /// Viewer edit: replace an item (same id) in place. False = the edit fails validation (too large,
    /// not what its format claims) and nothing changed.
    @discardableResult
    func replace(_ item: ClipItem) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return false }
        guard (try? Backup.validate(item: item)) != nil else { return false }
        items[idx] = item
        changed()
        return true
    }

    /// Insert without dedupe/trim semantics of `add` (used by Viewer "New Item" / drag into history).
    /// False = the item fails validation and nothing changed.
    @discardableResult
    func insert(_ item: ClipItem, at index: Int) -> Bool {
        guard (try? Backup.validate(item: item)) != nil, !items.contains(where: { $0.id == item.id }) else { return false }
        items.insert(item, at: min(max(0, index), items.count))
        trim()
        changed()
        return true
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

    /// Restore commit: the items and the settings they are trimmed under, in one step — no observer
    /// is called and no save is scheduled, so nothing can run between the two stores being filled
    /// (a lock there purged one and left the other), and the plan's items are trimmed under the
    /// *restored* limits, not the ones being replaced (auditor's two P2 on PR #28). The caller calls
    /// `notePublished()` once everything is in place.
    func publish(_ newItems: [ClipItem], settings s: Settings) {
        isPurged = false
        settings = s
        items = Self.trimmed(Self.uniqueIDs(newItems.compactMap { $0.validated() }), settings: s)
        revision += 1
    }

    /// After `publish`: observers and the debounced save, as any change would have had.
    func notePublished() { changed() }

    /// Backup import, "Replace": the imported list becomes the history (trimmed to the limits).
    func replaceAll(_ newItems: [ClipItem]) {
        isPurged = false
        items = Self.uniqueIDs(newItems.compactMap { $0.validated() })   // a payload has passed Backup.validate; the store checks on its own account
        trim()
        changed()
    }

    /// Backup import, "Merge": append imported items whose content is not already present,
    /// keeping the current items newest. Returns how many were added.
    @discardableResult
    func merge(_ newItems: [ClipItem]) -> Int {
        var seen = Set(items.map(\.contentHash))
        var ids = Set(items.map(\.id))
        var added = 0
        for it in newItems.compactMap({ $0.validated() }) where !seen.contains(it.contentHash) && !ids.contains(it.id) {
            seen.insert(it.contentHash)
            ids.insert(it.id)
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
        items = Self.trimmed(items, settings: settings)
    }

    /// The ring rules as a pure function: age, the text and image rings, then the byte budget.
    /// Used by `trim()` and by `RestorePlan`, which must know the outcome before anything changes.
    static func trimmed(_ input: [ClipItem], settings: Settings, now: Date = Date()) -> [ClipItem] {
        var items = input
        if settings.historyMaxAge > 0 {
            let cutoff = now.addingTimeInterval(-settings.historyMaxAge)
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
        return items
    }

    private func changed() {
        revision += 1
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
