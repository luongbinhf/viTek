public enum ContextLanguageHint: Sendable, Equatable {
    case automatic
    case vietnamese
    case english
}

/// The Vietnamese input engine for one text field. Feed it keys, show `composition` as the word in
/// progress, and commit what `finish()` returns when the word ends.
///
/// A value type with no global state: one engine per text field, used from one thread.
public struct VitekEngine: Sendable {
    public var options: EngineOptions {
        didSet { composer.options = options }
    }

    public var habits = TypingHabits()
    /// Asynchronous sentence-level hint supplied off the keystroke hot path (e.g. ANE Core ML classifier).
    public var contextHint: ContextLanguageHint = .automatic
    private var evidence: TypingHabits.Evidence?
    private enum Language { case english, vietnamese }
    private var previousLanguage: Language?
    private var composer: Composer

    public mutating func takeTypingEvidence() -> TypingHabits.Evidence? {
        defer { evidence = nil }
        return evidence
    }

    public init(options: EngineOptions = EngineOptions()) {
        self.options = options
        composer = Composer(options: options)
    }

    /// The word being typed, as it should appear in the text field.
    public var composition: String {
        prefersLiteralReading ? String(composer.keys) : composer.display
    }

    /// The raw keys typed for the current word, before any Vietnamese marks were applied.
    public var rawKeys: String {
        String(composer.keys)
    }

    /// Restores the current composition to its raw typed keys and finishes the word.
    /// Returns nil when nothing is being composed.
    public mutating func restoreRawKeys() -> String? {
        guard !composer.isEmpty else { return nil }
        let raw = String(composer.keys)
        reset()
        return raw
    }

    /// The new iew shortcut collides with the complete English word "view".
    /// Keep the composer underneath so a second w can still undo its mark.
    private var prefersQuickEnglishReading: Bool {
        options.quickTelexW && options.keepEnglishWords && composer.options.inputMethod == .telex
            && composer.mode == .vietnamese && composer.keys.count == 4
            && ASCII.lowercasedString(composer.keys, maxLength: 4) == "view"
    }

    private var prefersLiteralReading: Bool {
        if prefersQuickEnglishReading { return true }
        if options.keepEnglishWords, !options.customEnglishWords.isEmpty {
            let lower = ASCII.lowercasedString(composer.keys) ?? String(composer.keys).lowercased()
            if options.customEnglishWords.contains(lower) { return true }
        }
        let automatic = options.automaticallyDetectsMethod
        guard (automatic || previousLanguage == .english || contextHint == .english), composer.keys.count <= 7 else { return false }
        if automatic, TypingHabits.resemblesCellReference(composer.keys) { return habits.vniScore <= 0 }
        guard options.keepEnglishWords, composer.options.inputMethod == .telex else { return false }
        guard let keys = ASCII.lowercasedString(composer.keys, maxLength: 7) else { return false }
        if automatic, TypingHabits.englishCues.contains(keys) { return true }
        if TypingHabits.codeSwitchAmbiguous.contains(keys) {
            if let previousLanguage { return previousLanguage == .english }
            return contextHint == .english
        }
        guard TypingHabits.ambiguous.contains(keys) else { return false }
        if let previousLanguage { return previousLanguage == .english }
        if contextHint == .english { return true }
        if contextHint == .vietnamese { return false }
        return habits.telexScore <= 0 && !TypingHabits.needsEnglishContext.contains(keys)
    }

    /// The session passes the committed text so a shortcut cannot teach the language of its keys.
    package mutating func followSpace(after text: String, source: FinishedWord) {
        guard options.keepEnglishWords else { return }
        if !text.utf8.allSatisfy(ASCII.isLetter) {
            if text.allSatisfy(\.isLetter), text.contains(where: { !$0.isASCII && Glyphs.parse($0) != nil }) {
                previousLanguage = .vietnamese
            }
            return
        }

        let lower = text.lowercased()
        if TypingHabits.vietnameseCues.contains(lower) {
            previousLanguage = .vietnamese
        } else if text == "I" || TypingHabits.englishCues.contains(lower)
                    || TypingHabits.ambiguous.contains(lower) || EnglishWords.words.contains(lower) {
            previousLanguage = .english
        } else if text == source.keys, text.utf8.count > 1, source.vietnamese == nil {
            // E.g. "read", "need", "over": literal letters with no complete Vietnamese reading.
            previousLanguage = .english
        }
    }

    public var isComposing: Bool { !composer.isEmpty }

    /// Feeds one key. Returns false when the key is not part of a word (space, punctuation, a digit
    /// that marks nothing); the caller then ends the word with `finish()` and lets the key through.
    public mutating func type(_ key: Character) -> Bool {
        // Once the English word continues, retain the visible prefix for viewer,
        // views, viewing, etc. Repeated w remains the explicit Telex undo.
        if prefersQuickEnglishReading, key.isLetter, key.lowercased() != "w" {
            composer.keepLiteral()
        }
        guard options.automaticallyDetectsMethod, let byte = key.asciiValue, (48...57).contains(byte),
              !composer.isEmpty else { return composer.type(key) }
        if composer.options.inputMethod == .telex, composer.mode == .vietnamese || composer.mode == .literal,
           composer.keys.count <= 32, composer.keys.allSatisfy({ $0.isLetter }) {
            // Reinterpret letters literally before the first VNI mark, including double vowels.
            var vni = options
            vni.inputMethod = .vni
            var candidate = Composer(options: vni)
            for letter in composer.keys { _ = candidate.type(letter) }
            if candidate.type(key) {
                composer = candidate
                return true
            }
        } else if composer.options.inputMethod == .vni {
            // Two adjacent tone digits are much more likely to be an identifier (A12).
            let consecutiveTones = composer.keys.last.map { "12345".contains($0) } == true
                && "12345".contains(key)
            if !consecutiveTones, composer.type(key) { return true }
        }
        composer.keepLiteral(appending: key)
        return true
    }

    /// Deletes the last character of the composition. Returns false when nothing is being composed,
    /// so the deletion belongs to the document.
    public mutating func deleteBackward() -> Bool {
        if !isComposing { previousLanguage = nil }
        if prefersLiteralReading {
            let remaining = Array(composer.keys.dropLast())
            composer = Composer(options: options)
            for key in remaining { _ = composer.type(key) }
            // Removing e from English "more" leaves visible "mor", even though replay reads mỏ.
            if composition != String(remaining) { composer.keepLiteral() }
            return true
        }
        let deleted = composer.deleteBackward()
        if composer.isEmpty { composer.options = options }
        return deleted
    }

    /// Ends the word. Returns nil when nothing was being typed.
    public mutating func finish() -> FinishedWord? {
        let method = composer.options.inputMethod
        let keepLiteral = prefersLiteralReading
        previousLanguage = nil
        let cellReference = options.automaticallyDetectsMethod && TypingHabits.resemblesCellReference(composer.keys)
        guard var word = composer.finish() else { return nil }
        composer.options = options
        if keepLiteral { word.text = word.keys }
        if options.automaticallyDetectsMethod {
            let keys = word.keys.lowercased()
            evidence = nil
            if !cellReference && !TypingHabits.ambiguous.contains(keys) && !TypingHabits.codeSwitchAmbiguous.contains(keys) {
                if EnglishWords.words.contains(keys) || TypingHabits.englishCues.contains(keys) {
                    evidence = .english
                } else if word.text == word.vietnamese, word.text != word.keys, word.keys.allSatisfy(\.isASCII) {
                    evidence = method == .telex ? .telex : .vni
                }
            }
            if let evidence { habits.observe(evidence) }
        }
        if word.text != word.keys {
            if EnglishWords.keepsKeys(word.keys, options: options)
                || (options.keepEnglishWords && (options.customEnglishWords.contains(word.keys.lowercased())
                                                 || Self.resemblesCamelCase(word.keys))) {
                word.text = word.keys
            }
        }
        return word
    }

    /// True for camelCase / PascalCase identifiers (`userName`, `useState`, `iPhone`, `SwiftUI`)
    /// while never matching accidental Shift on a doubled Telex vowel or trailing tone key (`vieEtJ`).
    /// Scans `keys.utf8` directly with zero heap allocations.
    private static func resemblesCamelCase(_ keys: String) -> Bool {
        let utf8 = keys.utf8
        guard utf8.count >= 3 else { return false }
        var index = utf8.index(after: utf8.startIndex)
        var prev = utf8[utf8.startIndex]
        while index < utf8.endIndex {
            let curr = utf8[index]
            let next = utf8.index(after: index)
            if (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(prev),
               (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(curr) {
                let currLower = curr &+ 32
                if prev != currLower {
                    let isTelexModifier = currLower == UInt8(ascii: "s") || currLower == UInt8(ascii: "f")
                        || currLower == UInt8(ascii: "r") || currLower == UInt8(ascii: "x")
                        || currLower == UInt8(ascii: "j") || currLower == UInt8(ascii: "z")
                        || currLower == UInt8(ascii: "w") || currLower == UInt8(ascii: "a")
                        || currLower == UInt8(ascii: "e") || currLower == UInt8(ascii: "o")
                        || currLower == UInt8(ascii: "d")
                    if !isTelexModifier || next < utf8.endIndex {
                        return true
                    }
                }
            }
            prev = curr
            index = next
        }
        return false
    }

    /// Takes a word that is already in the text field back into the composition, so the next keys
    /// edit it: `viet` then `j` gives việt. Returns false, changing nothing, while a word is being
    /// composed or when the word does not render back exactly as given (`test`, `hòa` in the modern
    /// tone style).
    public mutating func resume(_ word: String) -> Bool {
        guard composer.resume(word) else { return false }
        previousLanguage = nil
        return true
    }

    /// Drops the word in progress without committing it.
    public mutating func reset() {
        previousLanguage = nil
        composer = Composer(options: options)
    }
}

/// A word the engine has finished composing.
public struct FinishedWord: Equatable, Sendable {
    /// What to commit: the Vietnamese spelling, or the keys as typed when viTek changed the word and
    /// it did not turn out to be Vietnamese, or it is an English word (`EngineOptions.keepEnglishWords`).
    public var text: String
    /// The keys as typed.
    public var keys: String
    /// The Vietnamese spelling when the word is a complete syllable, otherwise nil.
    public var vietnamese: String?

    public init(text: String, keys: String, vietnamese: String?) {
        self.text = text
        self.keys = keys
        self.vietnamese = vietnamese
    }
}
