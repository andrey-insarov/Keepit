import AppKit

/// Fixed-capacity byte buffer that is page-locked and wiped on `zero()` / deinit.
/// Used for passwords so that no `String` copy of the secret is ever created.
final class SecureBuffer {
    private let ptr: UnsafeMutablePointer<UInt8>
    let capacity: Int
    private(set) var count = 0
    private(set) var isZeroed = false

    init(capacity: Int = 1024) {
        self.capacity = capacity
        ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        ptr.initialize(repeating: 0, count: capacity)
        _ = mlock(ptr, capacity)
    }

    var isEmpty: Bool { count == 0 }

    /// Append raw bytes; silently ignores input beyond capacity.
    @discardableResult
    func append(_ bytes: UnsafeRawBufferPointer) -> Int {
        let n = min(bytes.count, capacity - count)
        guard n > 0 else { return 0 }
        (ptr + count).update(from: bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), count: n)
        count += n
        return n
    }

    /// Remove and wipe the last `n` bytes.
    func removeLast(_ n: Int) {
        let k = min(n, count)
        guard k > 0 else { return }
        _ = memset_s(ptr + (count - k), k, 0, k)
        count -= k
    }

    func withBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try body(UnsafeRawBufferPointer(start: ptr, count: count))
    }

    /// Constant-time comparison of contents.
    static func equal(_ a: SecureBuffer, _ b: SecureBuffer) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a.ptr[i] ^ b.ptr[i] }
        return diff == 0
    }

    func zero() {
        guard !isZeroed else { return }
        _ = memset_s(ptr, capacity, 0, capacity)
        count = 0
        isZeroed = true
    }

    deinit {
        zero()
        _ = munlock(ptr, capacity)
        ptr.deinitialize(count: capacity)
        ptr.deallocate()
    }
}

/// A password field that never builds a String of the secret: each key press is converted to UTF-8
/// and appended to a `SecureBuffer`; the view only draws bullets. Backspace wipes the last character.
/// Paste, copy, drag and input methods are deliberately unsupported.
final class SecurePasswordField: NSView {
    let buffer: SecureBuffer
    /// Byte length of each entered character (for backspace over multi-byte UTF-8).
    private var charLengths: [Int] = []
    var placeholder = L("Password")
    var onTab: (() -> Void)?
    /// Called after every edit (for a strength meter); receives the live buffer, must not copy it into a String.
    var onChange: ((SecureBuffer) -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType { get { .exterior } set {} }

    init(frame: NSRect, buffer: SecureBuffer = SecureBuffer()) {
        self.buffer = buffer
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    var characterCount: Int { charLengths.count }

    func clear() {
        buffer.removeLast(buffer.count)
        charLengths.removeAll()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return true }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) {
            NSSound.beep()          // no paste / shortcuts into the secret
            return
        }
        switch event.keyCode {
        case 51, 117:               // ⌫ / ⌦ — wipe last character
            if let n = charLengths.popLast() { buffer.removeLast(n) }
            needsDisplay = true
            onChange?(buffer)
            return
        case 48:                    // ⇥ — move to the next field
            if let t = onTab { t() } else { window?.selectNextKeyView(nil) }
            return
        case 36, 76, 53:            // ↩ / enter / ⎋ — let the window's default/cancel buttons handle them
            super.keyDown(with: event)
            return
        default:
            break
        }
        // event.characters is a transient system String of (usually) one character; we copy its UTF-8
        // bytes into the locked buffer and never concatenate characters anywhere else.
        guard let chars = event.characters, !chars.isEmpty else { return }
        if charLengths.count >= Limits.passwordMaxChars { NSSound.beep(); return }
        for scalar in chars.unicodeScalars {
            guard scalar.value >= 0x20, scalar.value != 0x7F else { continue }   // skip control chars
            var utf8 = Array(String(scalar).utf8)
            let added = utf8.withUnsafeBytes { buffer.append($0) }
            utf8.withUnsafeMutableBytes { _ = memset_s($0.baseAddress, $0.count, 0, $0.count) }
            if added > 0 { charLengths.append(added) }
        }
        needsDisplay = true
        onChange?(buffer)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (window?.firstResponder === self ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()

        let text: String
        let color: NSColor
        if charLengths.isEmpty {
            text = placeholder
            color = .placeholderTextColor
        } else {
            text = String(repeating: "•", count: min(charLengths.count, 64))
            color = .labelColor
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: color,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: 8, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }
}
