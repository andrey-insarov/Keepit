import AppKit
import UniformTypeIdentifiers

/// Viewer → *Create a template item from a file*: what a chosen file becomes, decided without ever
/// reading more than the limits allow and without decoding an image whose header already says it is
/// too big. Pure: the Viewer calls it off the main thread and inserts the result.
///
/// - an image file within `Limits.imageBytesCeiling` and `Limits.imageMaxPixels` → a PNG item;
/// - a UTF-8 text file within `Limits.textBytesCeiling` → a text item;
/// - anything else — larger, not text, not a decodable image, not a regular file — → a **file
///   reference** item: the path only, nothing of the content is read into the template.
///
/// Every result passes the same validator a backup payload does before it may enter the tree.
enum FileImport {
    enum Outcome: Equatable {
        case image, text, reference
    }

    static func clip(from url: URL) -> (ClipItem, Outcome) {
        let type = UTType(filenameExtension: url.pathExtension)
        if let type, type.conforms(to: .image) {
            if let png = imagePNG(url) {
                var clip = ClipItem.text("")
                clip.setData(png, for: ClipItem.Format.png)
                clip.removeFormat(ClipItem.Format.text)
                if validated(clip) { return (clip, .image) }
            }
            return (reference(url), .reference)
        }
        if let data = try? BoundedFileReader.read(url, max: Limits.textBytesCeiling),
           let s = String(data: data, encoding: .utf8) {
            let clip = ClipItem.text(s)
            if validated(clip) { return (clip, .text) }
        }
        return (reference(url), .reference)
    }

    /// Size cap, then the pixel count from the header, then — and only then — the decode to PNG.
    private static func imagePNG(_ url: URL) -> Data? {
        guard let data = try? BoundedFileReader.read(url, max: Limits.imageBytesCeiling),
              ClipItem.pixelCountOK(data) else { return nil }
        if ClipItem.isPNG(data) { return data }
        guard let rep = NSBitmapImageRep(data: data),
              let png = rep.representation(using: .png, properties: [:]),
              png.count <= Limits.imageBytesCeiling else { return nil }
        return png
    }

    private static func reference(_ url: URL) -> ClipItem {
        var clip = ClipItem.text("")
        clip.setFilePaths([url.path])
        clip.removeFormat(ClipItem.Format.text)
        return clip
    }

    private static func validated(_ clip: ClipItem) -> Bool {
        (try? Backup.validate(item: clip)) != nil
    }
}
