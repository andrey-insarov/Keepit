import Foundation

/// UI strings. Keys are the English text; translations live in Resources/<lang>.lproj/Localizable.strings.
/// Missing translations fall back to the key, so the app always has English.
@inline(__always)
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

/// Formatted variant: `LF("%d item(s)", n)`.
func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: args)
}

/// Same lookup, but in the *system* language rather than the app's. For text that macOS embeds
/// in its own dialogs (the Touch ID sheet), which are drawn in the system language even when
/// the app has a per-app language override — otherwise the sheet comes out half-and-half.
func LSys(_ key: String) -> String {
    let global = CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication,
                                        kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
    let lang = Bundle.preferredLocalizations(from: Bundle.module.localizations, forPreferences: global).first ?? "en"
    guard let path = Bundle.module.path(forResource: lang, ofType: "lproj"), let b = Bundle(path: path) else { return key }
    return b.localizedString(forKey: key, value: key, table: nil)
}
