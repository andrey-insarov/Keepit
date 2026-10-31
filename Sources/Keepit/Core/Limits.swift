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
    static let dataFileMaxBytes = 512 * 1024 * 1024
    static let ignoreAppsMaxLines = 500
    static let bundleIdMaxChars = 255
    static let unlockBackoffSeconds: [Double] = [1, 2, 4]   // after the 1st, 2nd, 3rd wrong password
    static let unlockLockoutSeconds: Double = 30            // after the 3rd, before the dialog may reappear

    static func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }
}
