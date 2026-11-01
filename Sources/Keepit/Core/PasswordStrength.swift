import AppKit

/// Rough password strength, computed directly on the locked bytes (no String is ever built).
enum PasswordStrength {
    enum Level: Int { case weak, fair, good, excellent

        var title: String {
            switch self {
            case .weak: return L("Weak")
            case .fair: return L("Fair")
            case .good: return L("Good")
            case .excellent: return L("Excellent")
            }
        }
        var color: NSColor {
            switch self {
            case .weak: return .systemRed
            case .fair: return .systemOrange
            case .good: return .systemYellow
            case .excellent: return .systemGreen
            }
        }
    }

    struct Result {
        let level: Level
        let bits: Double
        let hint: String
    }

    static func evaluate(_ buffer: SecureBuffer) -> Result? {
        buffer.withBytes { raw -> Result? in
            let bytes = Array(raw)
            guard !bytes.isEmpty else { return nil }
            var lower = false, upper = false, digit = false, symbol = false, nonASCII = false
            var length = 0            // characters, counting a UTF-8 sequence once
            var repeats = 0, runs = 0
            var prev: UInt8 = 0, prevPrev: UInt8 = 0
            for (i, b) in bytes.enumerated() {
                if b & 0xC0 == 0x80 { continue }           // UTF-8 continuation byte
                length += 1
                switch b {
                case 0x61...0x7A: lower = true
                case 0x41...0x5A: upper = true
                case 0x30...0x39: digit = true
                case 0x20...0x7E: symbol = true
                default: nonASCII = true
                }
                if i > 0 && b == prev { repeats += 1 }
                if i > 1 && (Int(b) - Int(prev) == 1 && Int(prev) - Int(prevPrev) == 1) { runs += 1 }   // abc / 123
                prevPrev = prev; prev = b
            }
            var pool = 0
            if lower { pool += 26 }
            if upper { pool += 26 }
            if digit { pool += 10 }
            if symbol { pool += 33 }
            if nonASCII { pool += 100 }
            let effective = max(1, length - repeats - runs)
            let bits = Double(effective) * log2(Double(max(pool, 2)))

            let level: Level
            switch bits {
            case ..<36: level = .weak
            case ..<56: level = .fair
            case ..<80: level = .good
            default: level = .excellent
            }
            var hint: String
            switch level {
            case .weak: hint = length < 8 ? L("Use at least 8 characters") : L("Mix letters, digits and symbols")
            case .fair: hint = L("Longer is better — try a phrase of several words")
            case .good: hint = L("Solid. A few more characters make it excellent")
            case .excellent: hint = LF("~%d bits — brute force is impractical", Int(bits))
            }
            if repeats + runs > length / 3 { hint = L("Repeated or sequential characters weaken it") }
            return Result(level: level, bits: bits, hint: hint)
        }
    }
}

/// Small bar + label that reflects `PasswordStrength` for a SecurePasswordField.
final class PasswordStrengthView: NSView {
    private let bar = NSView()
    private let fill = NSView()
    private let label = NSTextField(labelWithString: "")
    private var fillWidth: NSLayoutConstraint!

    override init(frame: NSRect) {
        super.init(frame: frame)
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        bar.layer?.cornerRadius = 2
        fill.wantsLayer = true
        fill.layer?.cornerRadius = 2
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = 300
        for v in [bar, fill, label] { v.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(bar); bar.addSubview(fill); addSubview(label)
        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 4),
            fill.topAnchor.constraint(equalTo: bar.topAnchor),
            fill.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            fillWidth,
            label.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 3),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        update(nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(_ r: PasswordStrength.Result?) {
        guard let r = r else {
            fillWidth.constant = 0
            label.stringValue = L("Strength: —")
            return
        }
        let fraction = CGFloat(r.level.rawValue + 1) / 4
        fillWidth.constant = bounds.width * fraction
        fill.layer?.backgroundColor = r.level.color.cgColor
        label.stringValue = LF("Strength: %@ — %@", r.level.title, r.hint)
    }

    override func layout() {
        super.layout()
        if fillWidth.constant > 0 { fillWidth.constant = min(fillWidth.constant, bounds.width) }
    }
}
