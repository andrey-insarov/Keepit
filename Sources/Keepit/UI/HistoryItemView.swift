import AppKit

/// Custom view for a history entry in the popup menu. AppKit draws nothing for an item with a view, so this
/// reproduces the native look (highlight, icon, accelerator column) and, in return, owns the mouse:
/// a click pastes; with ⇧ held the app delegate attaches the action submenu (ExtendedMenuWatch).
final class HistoryItemView: NSView {
    static let rowHeight: CGFloat = 22
    static let font = NSFont.menuFont(ofSize: 0)
    static let keyFont = NSFont.menuFont(ofSize: 0)

    var prefix: String = ""            // "1", "A" — accelerator shown before the title
    var title: String = ""
    var keyLabel: String = ""          // right column, e.g. "⇧⌘1"
    var image: NSImage?
    var imageSize = NSSize(width: 16, height: 16)
    var isDimmed = false               // disabled look ("… N more in the Viewer")
    var accessibilityHint: String?

    // Layout
    private let hPad: CGFloat = 14     // native menu text inset
    private let highlightInset: CGFloat = 5
    private let gap: CGFloat = 6
    private let prefixWidth: CGFloat = 16

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    /// Width the row needs for its content (the menu takes the widest).
    func preferredWidth() -> CGFloat {
        let t = (title as NSString).size(withAttributes: [.font: Self.font]).width
        let k = (keyLabel as NSString).size(withAttributes: [.font: Self.keyFont]).width
        var w = hPad + (prefix.isEmpty ? 0 : prefixWidth + gap) + (image == nil ? 0 : imageSize.width + gap) + ceil(t)
        w += keyLabel.isEmpty ? 0 : 24 + ceil(k)
        return w + hPad
    }

    func sizeToFit(width: CGFloat) {
        let h = max(Self.rowHeight, (image == nil ? 0 : imageSize.height + 6))
        frame = NSRect(x: 0, y: 0, width: width, height: h)
    }

    private var highlighted: Bool {
        guard let mi = enclosingMenuItem else { return false }
        return mi.isHighlighted && mi.isEnabled
    }

    override func draw(_ dirtyRect: NSRect) {
        let hl = highlighted
        if hl {
            let r = bounds.insetBy(dx: highlightInset, dy: 0)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: r, xRadius: 5, yRadius: 5).fill()
        }
        let textColor: NSColor = hl ? .selectedMenuItemTextColor : (isDimmed ? .disabledControlTextColor : .labelColor)
        let dimColor: NSColor = hl ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.75) : .tertiaryLabelColor

        var x = hPad
        let midY = bounds.midY
        if !prefix.isEmpty {
            let a: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: textColor]
            let s = (prefix as NSString)
            let sz = s.size(withAttributes: a)
            s.draw(at: NSPoint(x: x, y: midY - sz.height / 2), withAttributes: a)
            x += prefixWidth + gap
        }
        if let img = image {
            let r = NSRect(x: x, y: midY - imageSize.height / 2, width: imageSize.width, height: imageSize.height)
            img.draw(in: r, from: .zero, operation: .sourceOver, fraction: isDimmed ? 0.5 : 1, respectFlipped: true, hints: nil)
            x += imageSize.width + gap
        }
        var keyW: CGFloat = 0
        let hasSubmenu = enclosingMenuItem?.submenu != nil
        if hasSubmenu {
            // Submenu chevron at the right edge, like AppKit draws for native items.
            let cfg = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            if let chev = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
                let tinted = chev.copy() as! NSImage
                tinted.isTemplate = true
                let sz = tinted.size
                let r = NSRect(x: bounds.maxX - hPad + 2 - sz.width, y: midY - sz.height / 2, width: sz.width, height: sz.height)
                NSGraphicsContext.saveGraphicsState()
                textColor.set()
                let tintedImage = NSImage(size: sz, flipped: false) { rect in
                    tinted.draw(in: rect); rect.fill(using: .sourceAtop); return true
                }
                tintedImage.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                NSGraphicsContext.restoreGraphicsState()
                keyW = sz.width
            }
        }
        let keyLabel = hasSubmenu ? "" : self.keyLabel
        if !keyLabel.isEmpty {
            let a: [NSAttributedString.Key: Any] = [.font: Self.keyFont, .foregroundColor: dimColor]
            let sz = (keyLabel as NSString).size(withAttributes: a)
            keyW = ceil(sz.width)
            (keyLabel as NSString).draw(at: NSPoint(x: bounds.maxX - hPad - keyW, y: midY - sz.height / 2), withAttributes: a)
        }
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingTail
        let a: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: textColor, .paragraphStyle: para]
        let avail = bounds.maxX - hPad - (keyW > 0 ? keyW + 24 : 0) - x
        let sz = (title as NSString).size(withAttributes: a)
        (title as NSString).draw(in: NSRect(x: x, y: midY - sz.height / 2, width: max(0, avail), height: sz.height + 2), withAttributes: a)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        guard let mi = enclosingMenuItem, mi.isEnabled, let menu = mi.menu else { return }
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        let idx = menu.index(of: mi)
        guard idx >= 0 else { return }
        menu.cancelTracking()
        DispatchQueue.main.async { menu.performActionForItem(at: idx) }
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .menuItem }
    override func accessibilityLabel() -> String? { (prefix.isEmpty ? "" : prefix + " ") + title }
}
