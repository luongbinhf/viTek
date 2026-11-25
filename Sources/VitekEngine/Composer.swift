/// One word being typed: letters with their marks, one tone for the syllable, and the keys that
/// produced them. See docs/ENGINE.md §3.
struct Composer: Sendable {
    enum Mode: Equatable, Sendable {
        /// Letters and tone render as Vietnamese, and modifier keys keep marking them.
        case vietnamese
        /// The user took a mark back, or the word stopped being Vietnamese before viTek changed
        /// anything: the text stays as shown and further keys are typed as they are.
        case literal
        /// viTek changed the word, then it stopped being Vietnamese: the keys show as typed.
        case restored
    }

    var options: EngineOptions
    private(set) var mode: Mode = .vietnamese
    private(set) var letters: [Letter] = []
    private(set) var tone: Tone = .level
    /// The keys that went into this word, verbatim. After a Backspace inside a Vietnamese word they
    /// are replaced by the characters on screen, which is what a restore should then show.
    private(set) var keys: [Character] = []
    /// What `.literal` mode shows.
    private var text: [Character] = []
    /// Index of an ư that Telex `w` typed on its own, so that a second `w` can take it back.
    private var standaloneW: Int?
    /// The ê inserted by iw, so repeating w can remove just that generated letter.
    private var quickWInsertion: Int?
    /// Base ASCII byte (`c`, `g`, `k`, `n`, `p`, `q`, `t`) expanded at syllable start, so a 3rd key undoes it.
    private var quickStartBase: UInt8?

    init(options: EngineOptions) {
        self.options = options
    }

    var isEmpty: Bool {
        switch mode {
        case .vietnamese: letters.isEmpty
        case .literal: text.isEmpty
        case .restored: keys.isEmpty
        }
    }

    var display: String {
        switch mode {
        case .vietnamese: render(letters, tone)
        case .literal: String(text)
        case .restored: String(keys)
        }
    }

    // MARK: Typing

    /// Adds a key to the word. Returns false, leaving the word unchanged, when the key is not part
    /// of a word: space, punctuation, or a digit that marks nothing.
    mutating func type(_ key: Character) -> Bool {
        switch mode {
        case .restored:
            guard Self.isLetter(key) else { return false }
            keys.append(key)
            return true
        case .literal:
            guard Self.isLetter(key) else { return false }
            appendLiteral(key)
            return true
        case .vietnamese:
            return typeVietnamese(key)
        }
    }

    /// An alphanumeric token whose digits could not form a VNI word (for example MA123).
    mutating func keepLiteral(appending key: Character) {
        keys.append(key)
        keepLiteral()
    }

    mutating func keepLiteral() {
        text = keys
        mode = .literal
    }

    private static func isLetter(_ key: Character) -> Bool {
        if let byte = key.asciiValue { return ASCII.isLetter(byte) }
        return Glyphs.parse(key) != nil
    }

    private mutating func typeVietnamese(_ key: Character) -> Bool {
        guard let byte = key.asciiValue else {
            // A keyboard layout that types Vietnamese letters directly (ư, ệ).
            guard let parsed = Glyphs.parse(key) else { return false }
            append(parsed.letter, key: key, tone: parsed.tone)
            return true
        }
        if options.inputMethod == .telex {
            if options.quickStartConsonants, applyQuickStartConsonant(byte: byte, key: key) {
                return true
            }
            if options.quickEndConsonants, applyQuickEndConsonant(byte: byte, key: key) {
                return true
            }
        }
        if let action = options.inputMethod.action(for: byte, options: options), apply(action, key: key) {
            return true
        }
        guard ASCII.isLetter(byte) else { return false }
        append(Letter(form: Form(ASCII.lowercased(byte)), isUppercase: ASCII.isUppercase(byte)), key: key)
        return true
    }

    private mutating func applyQuickStartConsonant(byte: UInt8, key: Character) -> Bool {
        let lower = ASCII.lowercased(byte)
        if let base = quickStartBase, letters.count == 2, tone == .level, lower == base {
            letters.removeLast()
            quickStartBase = nil
            undo(appending: key)
            return true
        }
        guard letters.count == 1, tone == .level, letters[0].form.mark == .none, letters[0].form.base == lower else {
            return false
        }
        let secondBase: UInt8
        switch lower {
        case UInt8(ascii: "c"): secondBase = UInt8(ascii: "h")
        case UInt8(ascii: "g"): secondBase = UInt8(ascii: "i")
        case UInt8(ascii: "k"): secondBase = UInt8(ascii: "h")
        case UInt8(ascii: "n"): secondBase = UInt8(ascii: "g")
        case UInt8(ascii: "p"): secondBase = UInt8(ascii: "h")
        case UInt8(ascii: "q"): secondBase = UInt8(ascii: "u")
        case UInt8(ascii: "t"): secondBase = UInt8(ascii: "h")
        default: return false
        }
        let second = Letter(form: Form(secondBase), isUppercase: ASCII.isUppercase(byte))
        guard accept([letters[0], second], tone, key: key) else { return false }
        quickStartBase = lower
        return true
    }

    private mutating func applyQuickEndConsonant(byte: UInt8, key: Character) -> Bool {
        let run = vowels
        guard !run.isEmpty, run.upperBound == letters.count else { return false }
        let pair: (UInt8, UInt8)
        switch ASCII.lowercased(byte) {
        case UInt8(ascii: "g"): pair = (UInt8(ascii: "n"), UInt8(ascii: "g"))
        case UInt8(ascii: "h"): pair = (UInt8(ascii: "n"), UInt8(ascii: "h"))
        case UInt8(ascii: "k"): pair = (UInt8(ascii: "c"), UInt8(ascii: "h"))
        default: return false
        }
        let upper = ASCII.isUppercase(byte)
        let candidate = letters + [
            Letter(form: Form(pair.0), isUppercase: upper),
            Letter(form: Form(pair.1), isUppercase: upper),
        ]
        guard Orthography.isPlausiblePrefix(candidate.map(\.form), tone: tone) else { return false }
        letters = candidate
        keys.append(key)
        return true
    }

    /// Applies a modifier key. Returns false when it finds nothing to mark; a Telex modifier is then
    /// typed as a letter, a VNI digit ends the word.
    private mutating func apply(_ action: KeyAction, key: Character) -> Bool {
        switch action {
        case .tone(let newTone):
            return applyTone(newTone, key: key)
        case .clearTone:
            guard tone != .level else { return false }
            tone = .level
            keys.append(key)
            return true
        case .circumflex(let vowel):
            return applyCircumflex(on: vowel, key: key)
        case .horn:
            return applyHornOrBreve(horn: true, breve: false, key: key)
        case .breve:
            return applyHornOrBreve(horn: false, breve: true, key: key)
        case .hornOrBreve:
            if options.quickTelexW, applyQuickTelexW(key: key) { return true }
            return applyHornOrBreve(horn: true, breve: true, key: key)
        case .stroke:
            return applyStroke(key: key)
        case .insert(let letter):
            return accept(letters + [letter], tone, key: key)
        }
    }

    private var vowels: Range<Int> {
        Orthography.segments(letters).vowels
    }

    private mutating func applyTone(_ newTone: Tone, key: Character) -> Bool {
        guard !vowels.isEmpty else { return false }
        if tone == newTone {
            tone = .level
            undo(appending: key)
            return true
        }
        return accept(letters, newTone, key: key)
    }

    private mutating func applyCircumflex(on vowel: UInt8?, key: Character) -> Bool {
        let run = vowels
        func targets(_ form: Form) -> Bool {
            form.accepts(.circumflex) && (vowel == nil || form.base == vowel)
        }
        for index in run.reversed() where targets(letters[index].form) && letters[index].form.mark != .circumflex {
            var candidate = letters
            candidate[index].form.mark = .circumflex
            if accept(candidate, tone, key: key) { return true }
        }
        if let index = run.last(where: { targets(letters[$0].form) && letters[$0].form.mark == .circumflex }) {
            letters[index].form.mark = .none
            undo(appending: key)
            return true
        }
        return false
    }

    private mutating func applyQuickTelexW(key: Character) -> Bool {
        let run = vowels
        guard let first = run.first, letters[first].form == Form("i") else { return false }
        if run.count == 1 {
            let index = run.upperBound
            var candidate = letters
            candidate.insert(Letter(form: Form("e", .circumflex), isUppercase: letters[first].isUppercase), at: index)
            guard accept(candidate, tone, key: key) else { return false }
            quickWInsertion = index
            return true
        }
        guard run.count == 2, letters[first + 1].form.base == ASCII.e else { return false }
        let index = first + 1
        if letters[index].form.mark == .circumflex {
            if quickWInsertion == index { letters.remove(at: index) }
            else { letters[index].form.mark = .none }
            undo(appending: key)
            return true
        }
        guard letters[index].form.mark == .none else { return false }
        var candidate = letters
        candidate[index].form.mark = .circumflex
        return accept(candidate, tone, key: key)
    }

    private mutating func applyHornOrBreve(horn: Bool, breve: Bool, key: Character) -> Bool {
        let run = vowels
        var candidates: [[Letter]] = []
        // uo takes both horns at once: ươ.
        if horn, let u = run.dropLast().first(where: { letters[$0].form.base == ASCII.u && letters[$0 + 1].form.base == ASCII.o }) {
            let marks = (letters[u].form.mark, letters[u + 1].form.mark)
            if [Mark.none, .horn].contains(marks.0), [Mark.none, .horn].contains(marks.1), marks != (.horn, .horn) {
                var candidate = letters
                candidate[u].form.mark = .horn
                candidate[u + 1].form.mark = .horn
                candidates.append(candidate)
            }
        }
        for index in run.reversed() {
            let form = letters[index].form
            let mark: Mark
            switch form.base {
            case ASCII.a where breve: mark = .breve
            case ASCII.o where horn, ASCII.u where horn: mark = .horn
            default: continue
            }
            guard form.mark != mark else { continue }
            var candidate = letters
            candidate[index].form.mark = mark
            candidates.append(candidate)
        }
        for candidate in candidates {
            if accept(candidate, tone, key: key) { return true }
        }

        // Nothing left to mark: a repeated key takes its marks back (`aww` → `aw`, `ww` → `w`).
        if let inserted = standaloneW, inserted < letters.count, letters[inserted].form == Form("u", .horn) {
            letters.remove(at: inserted)
            undo(appending: key)
            return true
        }
        func undoable(_ mark: Mark) -> Bool { (horn && mark == .horn) || (breve && mark == .breve) }
        if run.contains(where: { undoable(letters[$0].form.mark) }) {
            for index in run where undoable(letters[index].form.mark) {
                letters[index].form.mark = .none
            }
            undo(appending: key)
            return true
        }
        if horn, breve, options.standaloneW {
            let letter = Letter(form: Form("u", .horn), isUppercase: key.isUppercase)
            if accept(letters + [letter], tone, key: key) {
                standaloneW = letters.count - 1
                return true
            }
        }
        return false
    }

    private mutating func applyStroke(key: Character) -> Bool {
        guard let first = letters.first, first.form.base == ASCII.d else { return false }
        if first.form.mark == .stroke {
            letters[0].form.mark = .none
            undo(appending: key)
            return true
        }
        var candidate = letters
        candidate[0].form.mark = .stroke
        return accept(candidate, tone, key: key)
    }

    /// Takes the candidate spelling when it can still be Vietnamese.
    private mutating func accept(_ candidate: [Letter], _ candidateTone: Tone, key: Character) -> Bool {
        if options.spellCheck, !Orthography.isPlausiblePrefix(candidate.map(\.form), tone: candidateTone) {
            return false
        }
        letters = candidate
        tone = candidateTone
        keys.append(key)
        return true
    }

    /// The modifier was pressed again after its mark was taken back: type the key itself, and leave
    /// the word as shown from here on (`ass` → `as`, `ddd` → `dd`).
    private mutating func undo(appending key: Character) {
        text = Array(render(letters, tone))
        mode = .literal
        standaloneW = nil
        quickWInsertion = nil
        quickStartBase = nil
        appendLiteral(key)
    }

    private mutating func appendLiteral(_ key: Character) {
        keys.append(key)
        text.append(key)
        if text.count < keys.count, options.keepEnglishWords, options.inputMethod == .telex,
           EnglishWords.keepsRepeatedToneKey(in: keys) {
            text = keys
        }
    }

    private mutating func append(_ letter: Letter, key: Character, tone glyphTone: Tone = .level) {
        letters.append(letter)
        if glyphTone != .level, tone == .level { tone = glyphTone }
        keys.append(key)
        guard options.spellCheck, !Orthography.isPlausiblePrefix(letters.map(\.form), tone: tone) else { return }
        let shown = render(letters, tone)
        // A changed word with a vowel goes back to its keys (`sẻv` → `serv`). Consonants alone keep
        // their đ, which chat shorthand uses (`đc`, `đt`).
        if options.restoreInvalidWords, shown != String(keys), letters.contains(where: \.isVowel) {
            mode = .restored
        } else {
            text = Array(shown)
            mode = .literal
        }
        standaloneW = nil
        quickWInsertion = nil
        quickStartBase = nil
    }

    // MARK: Resuming

    /// Loads a word that is already in the document, so the next keys edit it (`viet` + `j` →
    /// việt). Returns false, leaving the composer empty, unless every character is a letter and the
    /// word renders back exactly as given; English words and other tone styles are left alone.
    mutating func resume(_ word: String) -> Bool {
        guard isEmpty, !word.isEmpty else { return false }
        for character in word {
            if let byte = character.asciiValue, ASCII.isLetter(byte) {
                append(Letter(form: Form(ASCII.lowercased(byte)), isUppercase: ASCII.isUppercase(byte)), key: character)
            } else if let parsed = Glyphs.parse(character) {
                append(parsed.letter, key: character, tone: parsed.tone)
            } else {
                self = Composer(options: options)
                return false
            }
        }
        guard mode == .vietnamese, display == word else {
            self = Composer(options: options)
            return false
        }
        return true
    }

    // MARK: Deleting

    /// Deletes the last character on screen. Returns false when the word is already empty.
    mutating func deleteBackward() -> Bool {
        switch mode {
        case .restored:
            // Typing on may have been what broke the word, so replay the keys without the last one:
            // `đườngg` ⌫ gives `đường` back, not `dduowngf`.
            guard !keys.isEmpty else { return false }
            let remaining = keys.dropLast()
            self = Composer(options: options)
            for key in remaining { _ = type(key) }
            return true
        case .literal:
            guard !text.isEmpty else { return false }
            text.removeLast()
            keys = text
            if text.isEmpty { self = Composer(options: options) }
            return true
        case .vietnamese:
            guard !letters.isEmpty else { return false }
            let toneIndex = tone == .level ? nil : Orthography.toneIndex(letters, style: options.toneStyle)
            letters.removeLast()
            // The tone goes with the letter that showed it (việ ⌫ → vi, not vị).
            if toneIndex == letters.count || !letters.contains(where: \.isVowel) { tone = .level }
            if let inserted = standaloneW, inserted >= letters.count { standaloneW = nil }
            if let inserted = quickWInsertion, inserted >= letters.count { quickWInsertion = nil }
            if letters.count < 2 { quickStartBase = nil }
            keys = Array(render(letters, tone))
            if letters.isEmpty { self = Composer(options: options) }
            return true
        }
    }

    // MARK: Finishing

    /// Ends the word and clears the composer. Returns nil when nothing was typed.
    mutating func finish() -> FinishedWord? {
        defer { self = Composer(options: options) }
        switch mode {
        case .restored:
            let typed = String(keys)
            return FinishedWord(text: typed, keys: typed, vietnamese: nil)
        case .literal:
            return FinishedWord(text: String(text), keys: String(keys), vietnamese: nil)
        case .vietnamese:
            guard !letters.isEmpty else { return nil }
            var final = letters
            Self.writeOpenUo(&final)
            let rendered = render(final, tone)
            let typed = String(keys)
            let isWord = Orthography.isComplete(final.map(\.form), tone: tone)
            let keep = isWord || rendered == typed || !final.contains(where: \.isVowel)
            let restore = options.spellCheck && options.restoreInvalidWords && !keep
            return FinishedWord(text: restore ? typed : rendered, keys: typed, vietnamese: isWord ? rendered : nil)
        }
    }

    /// ươ needs a final letter (ương, mươi); without one it is written uơ (thuở, huơ). Telex `uow`
    /// always marks both, so the choice waits until the word ends.
    private static func writeOpenUo(_ letters: inout [Letter]) {
        let parts = Orthography.segments(letters)
        let run = parts.vowels
        guard run.count == 2, parts.vowelEnd == letters.count,
              letters[run.lowerBound].form == Form("u", .horn),
              letters[run.lowerBound + 1].form == Form("o", .horn)
        else { return }
        letters[run.lowerBound].form.mark = .none
    }

    // MARK: Rendering

    private func render(_ letters: [Letter], _ tone: Tone) -> String {
        let toneIndex = tone == .level ? nil : Orthography.toneIndex(letters, style: options.toneStyle)
        var result = ""
        result.reserveCapacity(letters.count * 2)
        for (index, letter) in letters.enumerated() {
            result.append(Glyphs.character(letter, tone: index == toneIndex ? tone : .level))
        }
        return result
    }
}
