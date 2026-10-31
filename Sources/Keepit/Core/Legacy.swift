import Foundation

/// Identifiers written by releases before 2.1 (when the project had its previous name).
/// They exist only so that data files created back then still load; nothing new is written with them.
enum Legacy {
    static let dataFolderName = "CLCL"
    static let fileMagic = Data("CLCLENC1".utf8)
    static let vaultOkToken = Data("CLCL-OK".utf8)
    static let filesFormat = "net.nakka.clcl.file-list"
}
