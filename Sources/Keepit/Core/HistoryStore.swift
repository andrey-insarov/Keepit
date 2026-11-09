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
    /// Set when history.json exists but could not be read (no key, another key, damaged, not the
    /// expected JSON, too large, I/O error). The file is then left exactly as it is: nothing is
    /// saved over it, and nothing deletes it, until a restore replaces it or the user starts fresh.
    /// Before 3.0.6 every one of those looked like "no history" and the empty list was written back.
    private(set) var loadFailure: Storage.LoadFailure?

    init(settings: Settings) {
        self.settings = settings
        reload()
    }

    /// (Re)load from disk — used at start and after unlocking.
    func reload() {
        isPurged = false
        revision += 1
        items = []
        loadFailure = nil
        // Read even when "save history" is off: with it off, the next save deletes the file, and a
        // file that cannot be read must be known about first (3.0.6 audit: turning the setting off
        // after a failure, then lock / unlock / lock, used to skip the read and delete the original).
        switch Storage.read([ClipItem].self, from: Storage.historyURL) {
        case .loaded(let loaded):
            if settings.historySave {
                items = Self.validated(loaded)
                trim()
            }
        case .missing:
            break
        case .failed(let f):
            loadFailure = f
        }
        onChange?()
    }

    /// The user's answer to `loadFailure`: the unreadable file is renamed `.corrupt-<time>` next
    /// to the new one, and the store starts empty. Throws (and changes nothing) if the rename fails.
    func startFresh() throws {
        guard loadFailure != nil, !isPurged else { return }     // never while locked: the store is purged then
        try Storage.setAside([Storage.historyURL])
        reload()
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

    /// Drop everything from memory (lock). A pending save lands first; with history-save off, the
    /// file on disk is removed instead (SEC11) — the setting means "no history on disk".
    func purge() {
        if settings.historySave { saver.flush() } else { report(removeSavedFile(), .lock) }
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
        // An edit can grow the history past the byte limits (PR #48 round 1: the file budget was
        // not applied here, the save was refused, and the edit vanished at the next reload). Trim
        // as every other change does — and refuse the edit if the edited item itself would not fit,
        // rather than accept it and drop it.
        var next = items
        next[idx] = item
        next = Self.trimmed(next, settings: settings)
        guard next.contains(where: { $0.id == item.id }) else { return false }
        items = next
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
        loadFailure = nil                      // the restore commit has written a readable file
        settings = s
        items = Self.trimmed(Self.uniqueIDs(newItems.compactMap { $0.validated() }), settings: s)
        revision += 1
    }

    /// After `publish`: observers and the debounced save, as any change would have had.
    func notePublished() { changed() }

    /// Backup import, "Replace": the imported list becomes the history (trimmed to the limits).
    func replaceAll(_ newItems: [ClipItem]) {
        isPurged = false
        loadFailure = nil                      // the user chose to replace what is on disk
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

    /// Settings changed. Turning *Save history* off removes the saved file at once (SEC11): until
    /// 3.0.7 it stayed on disk until the next lock or quit, and the setting said nothing about it.
    /// The removal is reported through `onSavedFileRemovalFailed` with `.settingChanged`.
    func updateSettings(_ s: Settings) {
        let wasSaving = settings.historySave
        settings = s
        trim()
        changed()
        if wasSaving, !s.historySave { report(removeSavedFile(), .settingChanged) }
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
        // The file, not the raw bytes: what the reader will accept (Limits.historyFileBudget). The
        // estimate is computed here, in the store's own context on the main thread, before any
        // snapshot is encoded — so memory and disk agree, and no store mutation happens off-thread.
        var estimate = items.reduce(0) { $0 + $1.serializedEstimate }
        let budget = Limits.effectiveHistoryFileBudget
        if estimate > budget {
            let before = items.count
            while estimate > budget, items.count > 1 { estimate -= items.removeLast().serializedEstimate }
            Log.storage.error("history trimmed to fit the data-file limit: \(before - items.count) oldest item(s) dropped")
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
        if !settings.historySave {             // even while purged: this removes, it writes nothing
            report(removeSavedFile(), .save)
            return
        }
        if isPurged { return }
        if loadFailure != nil {                // neither written over nor deleted: see loadFailure
            Log.storage.notice("not saving history.json: the file on disk could not be read and is being kept as it is")
            return
        }
        Storage.save(items, to: Storage.historyURL, background: background)
    }

    /// A pending save lands now (quit, a protection commit, a backup). With history-save off this
    /// removes the saved file instead, so a removal that failed earlier is retried at quit (SEC11).
    func flush() {
        if settings.historySave { saver.flush() } else { report(removeSavedFile(), .flush) }
    }

    // MARK: History-save off (SEC11)

    /// Where a removal of the saved file was asked for; the app decides how a failure is told.
    enum RemovalOccasion { case settingChanged, lock, flush, save }

    /// Called on the caller's thread when `removeSavedFile()` failed. Unset → logged only. A held
    /// file (SEC10) counts as a failure too: it is not ours to delete, and the SEC10 report says why.
    var onSavedFileRemovalFailed: ((Error, RemovalOccasion) -> Void)?

    /// Removes history.json through `ioQueue`, in order after any queued write. A missing file is
    /// success; a held file is refused (`Storage.Failure.held`). Saves nothing, so it may run while
    /// purged. The result is returned, not discarded: the setting promises the file is gone.
    func removeSavedFile() -> Result<Void, Error> {
        Result { try Storage.removeNow(Storage.historyURL) }
    }

    private func report(_ r: Result<Void, Error>, _ occasion: RemovalOccasion) {
        guard case .failure(let e) = r else { return }
        Log.storage.error("history.json could not be removed (\(String(describing: occasion))): \(String(describing: e))")
        onSavedFileRemovalFailed?(e, occasion)
    }
}
