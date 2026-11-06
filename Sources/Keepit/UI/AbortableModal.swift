import AppKit

/// A modal dialog that a lock may close. `lock()` aborts the running modal session only while one
/// of these is on screen; every other `runModal` (the recovery phrase, which must be read before
/// it goes; a password prompt; the restore progress panel with its own completion rules) is left
/// alone. A dialog opened here returns `.abort` when the lock closed it; callers treat that as
/// Cancel — and, where the dialog's result would have acted on data read before it opened, check
/// the lock generation as well (`lockCount`), because a lock followed by an unlock also ends here.
enum AbortableModal {
    private(set) static var depth = 0

    static var isRunning: Bool { depth > 0 }

    @discardableResult
    static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        depth += 1
        defer { depth -= 1 }
        return alert.runModal()
    }

    /// What `lock()` calls: ends the session of an abortable dialog, if one is running.
    static func abortIfRunning() {
        guard isRunning, NSApp.modalWindow != nil else { return }
        NSApp.abortModal()
    }
}
