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
