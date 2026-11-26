/// How keystrokes become diacritics.
public enum InputMethod: String, Sendable, CaseIterable {
    /// Letters as modifiers: s f r x j tones, z clears, aa ee oo circumflex, w horn/breve, dd stroke.
    case telex
    /// Digits as modifiers: 1–5 tones, 0 clears, 6 circumflex, 7 horn, 8 breve, 9 stroke.
    case vni
}

/// Where the tone goes in the open syllables oa, oe and uy.
public enum ToneStyle: String, Sendable, CaseIterable {
    /// hoà, khoẻ, thuý
    case modern
    /// hòa, khỏe, thúy
    case traditional
}

public struct EngineOptions: Sendable, Equatable {
    public var automaticallyDetectsMethod: Bool
    public var inputMethod: InputMethod
    public var toneStyle: ToneStyle
    /// Only add a mark when the result can still be a Vietnamese syllable. When off, every
    /// modifier key applies wherever it finds a target letter.
    public var spellCheck: Bool
    /// Show the keys as typed when a word that viTek changed turns out not to be Vietnamese
    /// (`server`, `express`). Requires `spellCheck`.
    public var restoreInvalidWords: Bool
    /// Telex: `w` with no vowel to mark types ư (`tw` → tư).
    public var standaloneW: Bool
    /// viTek Telex shortcut: iw → iê and iew → iê; repeated w restores the literal key.
    public var quickTelexW: Bool
    /// Telex: `[` and `]` type ơ and ư.
    public var bracketVowels: Bool
    /// Telex: `cc`→`ch`, `gg`→`gi`, `kk`→`kh`, `nn`→`ng`, `pp`→`ph`, `qq`→`qu`, `tt`→`th` at syllable start.
    public var quickStartConsonants: Bool
    /// Telex: `g`→`ng`, `h`→`nh`, `k`→`ch` right after vowels when valid in Vietnamese orthography.
    public var quickEndConsonants: Bool
    /// Telex: keep an English word as typed when its keys also read as Vietnamese (`test`, not
    /// `tét`). Applies only when the last key is a plain letter, so `tets` still gives tét.
    public var keepEnglishWords: Bool
    /// Recovers adjacent high-speed key transpositions (`gn`→`ng`, `hn`→`nh`, `hc`→`ch`, `uio`/`uwio`→`ươi`)
    /// when an explicit Vietnamese mark or tone produces a complete syllable (`tieegns` → `tiếng`, `mihnf` → `mình`).
    public var smartTypoRecovery: Bool
    /// User-defined words (lowercased) that viTek always keeps literal without Vietnamese marks.
    public var customEnglishWords: Set<String>

    public init(
        inputMethod: InputMethod = .telex,
        automaticallyDetectsMethod: Bool = false,
        toneStyle: ToneStyle = .modern,
        spellCheck: Bool = true,
        restoreInvalidWords: Bool = true,
        standaloneW: Bool = true,
        bracketVowels: Bool = false,
        quickStartConsonants: Bool = false,
        quickEndConsonants: Bool = false,
        keepEnglishWords: Bool = true,
        quickTelexW: Bool = true,
        smartTypoRecovery: Bool = true,
        customEnglishWords: Set<String> = []
    ) {
        self.automaticallyDetectsMethod = automaticallyDetectsMethod
        self.inputMethod = inputMethod
        self.toneStyle = toneStyle
        self.spellCheck = spellCheck
        self.restoreInvalidWords = restoreInvalidWords
        self.standaloneW = standaloneW
        self.quickTelexW = quickTelexW
        self.bracketVowels = bracketVowels
        self.quickStartConsonants = quickStartConsonants
        self.quickEndConsonants = quickEndConsonants
        self.keepEnglishWords = keepEnglishWords
        self.smartTypoRecovery = smartTypoRecovery
        self.customEnglishWords = customEnglishWords
    }
}

extension EngineOptions {
    /// True for a key that marks a letter rather than spelling one: Telex s f r x j z a e o w d,
    /// VNI digits. Typed right after a word, such a key may edit that word.
    public func isMarkKey(_ key: Character) -> Bool {
        guard let byte = key.asciiValue else { return false }
        return inputMethod.action(for: byte, options: self) != nil
            || (automaticallyDetectsMethod && InputMethod.vni.action(for: byte, options: self) != nil)
    }
}

/// What a modifier key asks for, independent of the input method that produced it.
enum KeyAction: Equatable {
    case tone(Tone)
    case clearTone
    /// Circumflex on the given vowel (Telex `aa`), or on any of a, e, o (VNI `6`) when `nil`.
    case circumflex(UInt8?)
    case horn
    case breve
    /// Telex `w`: breve on a, horn on o and u, both horns on uo, or a new ư.
    case hornOrBreve
    case stroke
    /// A whole letter typed by one key (Telex `[` → ơ).
    case insert(Letter)
}

extension InputMethod {
    func action(for byte: UInt8, options: EngineOptions) -> KeyAction? {
        switch self {
        case .telex:
            switch ASCII.lowercased(byte) {
            case UInt8(ascii: "s"): return .tone(.acute)
            case UInt8(ascii: "f"): return .tone(.grave)
            case UInt8(ascii: "r"): return .tone(.hook)
            case UInt8(ascii: "x"): return .tone(.tilde)
            case UInt8(ascii: "j"): return .tone(.dot)
            case UInt8(ascii: "z"): return .clearTone
            case ASCII.a, ASCII.e, ASCII.o: return .circumflex(ASCII.lowercased(byte))
            case UInt8(ascii: "w"): return .hornOrBreve
            case ASCII.d: return .stroke
            default: break
            }
            guard options.bracketVowels else { return nil }
            switch byte {
            case UInt8(ascii: "["): return .insert(Letter(form: Form("o", .horn), isUppercase: false))
            case UInt8(ascii: "]"): return .insert(Letter(form: Form("u", .horn), isUppercase: false))
            case UInt8(ascii: "{"): return .insert(Letter(form: Form("o", .horn), isUppercase: true))
            case UInt8(ascii: "}"): return .insert(Letter(form: Form("u", .horn), isUppercase: true))
            default: return nil
            }
        case .vni:
            switch byte {
            case UInt8(ascii: "1"): return .tone(.acute)
            case UInt8(ascii: "2"): return .tone(.grave)
            case UInt8(ascii: "3"): return .tone(.hook)
            case UInt8(ascii: "4"): return .tone(.tilde)
            case UInt8(ascii: "5"): return .tone(.dot)
            case UInt8(ascii: "6"): return .circumflex(nil)
            case UInt8(ascii: "7"): return .horn
            case UInt8(ascii: "8"): return .breve
            case UInt8(ascii: "9"): return .stroke
            case UInt8(ascii: "0"): return .clearTone
            default: return nil
            }
        }
    }
}
