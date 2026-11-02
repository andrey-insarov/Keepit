import AppKit

/// Floating preview beside the history menu: full image or the first ~40 lines of text for the
/// highlighted item, with source app and date underneath. Non-activating, ignores the mouse.
final class PreviewPanel {
    static let shared = PreviewPanel()

    private let panel: NSPanel
    private let imageView = NSImageView()
    private let textView = NSTextView()
    private let textScroll = NSScrollView()
    private let footer = NSTextField(labelWithString: "")
    private var showTimer: Timer?
    private let maxSize = NSSize(width: 440, height: 380)
    private static let cornerRadius: CGFloat = 10
    private static let gap: CGFloat = 8

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    /// The frame of the menu window actually on screen (the estimate from the pop-up point is off
    /// when macOS moves the menu to keep it on screen, or when it was opened from the status item).
    /// Picks the on-screen menu-level window of this process that overlaps the estimate the most.
    private static func onScreenMenuFrame(near estimate: NSRect, excluding exclude: Int) -> NSRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first else { return nil }
        let pid = Int(ProcessInfo.processInfo.processIdentifier)
        var best: (NSRect, CGFloat)?
        for w in list {
            guard (w[kCGWindowOwnerPID as String] as? Int) == pid, (w[kCGWindowNumber as String] as? Int) != exclude,
                  (w[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow)),
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let wd = b["Width"], let ht = b["Height"], wd > 60, ht > 60 else { continue }
            let frame = NSRect(x: x, y: primary.frame.maxY - y - ht, width: wd, height: ht)   // CG (top-left) → AppKit
            let overlap = frame.intersection(estimate)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > 0, best == nil || area > best!.1 { best = (frame, area) }
        }
        return best?.0
    }

    private init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: maxSize.width, height: maxSize.height),
                        styleMask: [.nonactivatingPanel, .borderless],
                        backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        // Rounded like the menu it sits next to; the mask image also shapes the window shadow.
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        panel.contentView = effect

        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        // A hidden view still takes part in Auto Layout: without this a large image's intrinsic size
        // would keep the panel huge for every item shown afterwards.
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textScroll.documentView = textView
        textScroll.drawsBackground = false
        textScroll.hasVerticalScroller = false
        textScroll.borderType = .noBorder

        footer.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        footer.textColor = .secondaryLabelColor
        footer.lineBreakMode = .byTruncatingMiddle

        for v in [imageView, textScroll, footer] {
            v.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(v)
        }
        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            footer.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            footer.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -8),
            imageView.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -6),
            textScroll.topAnchor.constraint(equalTo: effect.topAnchor, constant: 8),
            textScroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 8),
            textScroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -8),
            textScroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -6),
        ])
    }

    /// Show `item` next to `menuFrame` (screen coordinates) after a short delay; cancels any pending show.
    func schedule(_ item: ClipItem, besides menuFrame: NSRect, delay: TimeInterval = 0.35) {
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.show(item, besides: menuFrame)
        }
        RunLoop.main.add(showTimer!, forMode: .eventTracking)   // menus run the event-tracking mode
    }

    func hide() {
        showTimer?.invalidate()
        showTimer = nil
        if panel.isVisible { panel.orderOut(nil) }
    }

    private func show(_ item: ClipItem, besides menuFrame: NSRect) {
        var size = maxSize
        switch item.kind {
        case .image:
            guard let img = item.image else { hide(); return }
            let s = img.size
            let scale = min(1, (maxSize.width - 20) / max(s.width, 1), (maxSize.height - 50) / max(s.height, 1))
            img.size = NSSize(width: s.width * scale, height: s.height * scale)   // a fresh NSImage per call; the data is untouched
            imageView.image = img
            imageView.isHidden = false
            textScroll.isHidden = true
            size = NSSize(width: max(220, img.size.width + 20), height: max(120, img.size.height + 50))
        case .text, .files:
            imageView.image = nil
            let text: String
            if item.kind == .files { text = item.filePaths.joined(separator: "\n") }
            else { text = item.plainText ?? "" }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let shown = lines.prefix(40).joined(separator: "\n") + (lines.count > 40 ? "\n…" : "")
            textView.string = shown
            textView.font = item.kind == .files ? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) : NSFont.systemFont(ofSize: 12)
            imageView.isHidden = true
            textScroll.isHidden = false
            // Size to the text, within limits.
            textView.frame.size.width = maxSize.width - 24
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let used = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
            let w = min(maxSize.width, max(260, used.width + 40))
            let h = min(maxSize.height, max(80, used.height + 52))
            size = NSSize(width: w, height: h)
        }

        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        var parts = [df.string(from: item.date)]
        if let app = item.sourceApp, let name = Self.appName(for: app) { parts.insert(name, at: 0) }
        parts.append(ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))
        footer.stringValue = parts.joined(separator: " · ")

        // Right of the menu, top-aligned; flip to the left edge when it would leave the screen.
        let menuFrame = Self.onScreenMenuFrame(near: menuFrame, excluding: panel.windowNumber) ?? menuFrame
        let screen = NSScreen.screens.first { $0.frame.intersects(menuFrame) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin = NSPoint(x: menuFrame.maxX + Self.gap, y: menuFrame.maxY - size.height)
        if origin.x + size.width > visible.maxX { origin.x = menuFrame.minX - size.width - Self.gap }
        if origin.x < visible.minX { origin.x = visible.minX }
        origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    private static var nameCache: [String: String] = [:]
    static func appName(for bundleID: String) -> String? {
        if let n = nameCache[bundleID] { return n }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        nameCache[bundleID] = name
        return name
    }
}
