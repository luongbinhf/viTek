/// A mark that changes which letter a base letter is, as opposed to a tone:
/// â ê ô (circumflex), ă (breve), ơ ư (horn) and đ (stroke).
public enum Mark: UInt8, Sendable {
    case none, circumflex, breve, horn, stroke
}

/// The six tones of a Vietnamese syllable, named after the diacritic that writes them.
public enum Tone: UInt8, Sendable, CaseIterable {
    /// ngang: no mark
    case level
    /// huyền: à
    case grave
    /// sắc: á
    case acute
    /// hỏi: ả
    case hook
    /// ngã: ã
    case tilde
    /// nặng: ạ
    case dot
}

/// ASCII codes the orthography refers to by name.
enum ASCII {
    static let a = UInt8(ascii: "a"), c = UInt8(ascii: "c"), d = UInt8(ascii: "d"), e = UInt8(ascii: "e")
    static let g = UInt8(ascii: "g"), i = UInt8(ascii: "i"), o = UInt8(ascii: "o"), p = UInt8(ascii: "p")
    static let q = UInt8(ascii: "q"), t = UInt8(ascii: "t"), u = UInt8(ascii: "u"), y = UInt8(ascii: "y")

    static func isLetter(_ byte: UInt8) -> Bool {
        (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
    }

    static func isUppercase(_ byte: UInt8) -> Bool { (0x41...0x5A).contains(byte) }

    static func lowercased(_ byte: UInt8) -> UInt8 { isUppercase(byte) ? byte | 0x20 : byte }

    static func uppercased(_ byte: UInt8) -> UInt8 { (0x61...0x7A).contains(byte) ? byte & ~0x20 : byte }

    /// Converts an ASCII character buffer to a lowercased `String` in one pass (inline SSO for <= 15 bytes),
    /// returning `nil` if any character is non-ASCII or length exceeds `maxLength`.
    static func lowercasedString(_ chars: [Character], maxLength: Int = 32) -> String? {
        let count = chars.count
        guard count <= maxLength else { return nil }
        if count == 0 { return "" }
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: count) { buffer in
            for i in 0..<count {
                guard let byte = chars[i].asciiValue else { return nil }
                buffer[i] = lowercased(byte)
            }
            return String(decoding: UnsafeBufferPointer(start: buffer.baseAddress, count: count), as: UTF8.self)
        }
    }
}

/// A letter without case or tone: a lowercase ASCII base plus the mark that makes it a Vietnamese letter.
struct Form: Hashable, Sendable {
    var base: UInt8
    var mark: Mark

    init(_ base: UInt8, _ mark: Mark = .none) {
        self.base = base
        self.mark = mark
    }

    init(_ scalar: Unicode.Scalar, _ mark: Mark = .none) {
        self.init(UInt8(scalar.value), mark)
    }

    var isVowel: Bool {
        switch base {
        case ASCII.a, ASCII.e, ASCII.i, ASCII.o, ASCII.u, ASCII.y: true
        default: false
        }
    }

    /// Whether the letter carries one of the vowel marks (â ă ê ô ơ ư), which attract the tone.
    var hasVowelMark: Bool { isVowel && mark != .none }

    /// Whether `mark` can sit on this base letter at all (ă but not ĕ, ơ but not ĩ).
    func accepts(_ mark: Mark) -> Bool {
        switch (base, mark) {
        case (_, .none): true
        case (ASCII.a, .circumflex), (ASCII.a, .breve): true
        case (ASCII.e, .circumflex): true
        case (ASCII.o, .circumflex), (ASCII.o, .horn): true
        case (ASCII.u, .horn): true
        case (ASCII.d, .stroke): true
        default: false
        }
    }
}

/// One letter of the word being composed. The tone belongs to the syllable, not to a letter.
struct Letter: Equatable, Sendable {
    var form: Form
    var isUppercase: Bool

    var isVowel: Bool { form.isVowel }
}
