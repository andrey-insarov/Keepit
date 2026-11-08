import Foundation

/// Hard caps that keep hostile or runaway input from blowing up memory, disk, menus or dialogs.
/// Soft (user-tunable) limits live in Settings; these are the ceilings they are clamped to.
enum Limits {
    static let passwordMaxChars = 256
    static let recoveryInputMaxChars = 2_000
    static let templateNameMaxChars = 200
    static let templateMaxDepth = 16
    static let templateMaxCount = 5_000
    static let templateHotKeysMax = 50
    static let menuMaxItemsCeiling = 200
    static let historyMaxCeiling = 10_000
    // Ceilings of the per-item size settings (Settings.clamp uses them; the backup validator accepts
    // anything up to them, since any installation may have been configured that high).
    static let textBytesCeiling = 50 * 1024 * 1024
    static let imageBytesCeiling = 100 * 1024 * 1024
    static let fileListEntriesCeiling = 10_000
    static let filePathMaxBytes = 4_096              // one entry of a file list (PATH_MAX is 1 024 on macOS)
    static let dataFileMaxBytes = 512 * 1024 * 1024
    /// What a history may occupy *in the file*: the reader's limit minus the GCM seal. The JSON
    /// carries every format as Base64 (4/3 of the bytes) plus the item's fields, so the setting
    /// `maxHistoryBytes` (raw bytes) is capped at `historyBytesCeiling`, and `HistoryStore` trims by
    /// its serialized estimate before a snapshot is taken (3.0.7, the write/read limit mismatch:
    /// 400 MiB of raw bytes made a ≈533 MiB file the reader then refused).
    static var historyFileBudget: Int { dataFileMaxBytes - Vault.sealOverhead - 1024 }
    static var historyBytesCeiling: Int { historyFileBudget * 3 / 4 - 16 * 1024 * 1024 }   // ≈ 368 MiB
    /// Tests only: a smaller file budget so the trim can be exercised with small items.
    static var historyFileBudgetForTesting: Int?
    static var effectiveHistoryFileBudget: Int { historyFileBudgetForTesting ?? historyFileBudget }
    static let imageMaxPixels = 40_000_000           // 40 MP: a 10 MB PNG can still be a 20 000×20 000 bomb
    static let queueMaxItems = 500                    // paste queue entries per session
    static let promptInputMaxChars = 10_000           // one {input:} answer
    static let snippetPromptsMax = 20                 // {input:}/{choice:} questions one template may ask
    static let snippetChoicesMax = 50                 // options in one {choice:}
    static let snippetShiftMaxDigits = 4              // {date+NNNNd}: at most 9 999 of a unit
    static let snippetShiftsMax = 4                   // {date+1y-2d+3h}: shifts in one token
    static let snippetDateFormatMaxChars = 200        // a {date:…} pattern longer than this is kept as text
    static let snippetOutputMaxBytes = textBytesCeiling   // an expansion never grows past one text item
    static let snippetCursorMoveMax = 2_000           // ← key presses after a paste to reach {cursor}
    static let ignoreAppsMaxLines = 500
    static let urlCommandMaxChars = 128 * 1024        // a keepit:// URL longer than this is not a command (text ≤ 64 KiB + overhead)
    static let urlCommandTextMaxBytes = 64 * 1024     // add / add-template text (UTF-8)
    static let urlCommandArgumentMaxChars = 1_024     // the path part: item number or template path
    static let pendingOpenURLsMax = 32                // URLs and files queued before the app is ready
    static let bundleIdMaxChars = 255
    static let unlockBackoffSeconds: [Double] = [1, 2, 4]   // after the 1st, 2nd, 3rd wrong password
    static let unlockLockoutSeconds: Double = 30            // after the 3rd, before the dialog may reappear

    static func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
}
