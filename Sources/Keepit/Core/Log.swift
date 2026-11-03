import Foundation
import os

/// Keepit's diagnostics go to the unified system log (Console.app, `log show`, sysdiagnose) under
/// subsystem `com.it.keep`. Rules, so that the log can never become a side channel:
///
/// - Only errors and unexpected states are logged — never a clipboard item, a template, a password,
///   a key, a file's contents, or the fact that a particular copy was or was not recorded.
/// - Static text is public; every interpolated value is `.private` (Logger's default), so Console
///   shows `<private>` unless an administrator turns private data on for the subsystem
///   (`sudo log config --subsystem com.it.keep --mode private_data:on`).
/// - `NSLog` is not used in the app (it marks the whole message public). The self-test harness
///   still uses it, because CI reads its stderr.
///
/// Watching live: `log stream --predicate 'subsystem == "com.it.keep"' --level info`
enum Log {
    static let storage  = Logger(subsystem: "com.it.keep", category: "storage")
    static let vault    = Logger(subsystem: "com.it.keep", category: "vault")
    static let system   = Logger(subsystem: "com.it.keep", category: "system")   // hot keys, login item, Accessibility, updater
}
