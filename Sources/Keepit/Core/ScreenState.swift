import CoreGraphics
import Foundation

/// Whether the login/lock screen is up right now, from the window server's session dictionary.
/// `CGSessionCopyCurrentDictionary` is public; the `CGSSessionScreenIsLocked` key is not documented,
/// so an absent key means "unknown", never "unlocked" — callers fall back to the notifications.
enum ScreenState {
    static func isLocked() -> Bool? {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
        guard let v = dict["CGSSessionScreenIsLocked"] else { return nil }
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        return nil
    }
}
