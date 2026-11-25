/// The written shape of a Vietnamese syllable: which letter sequences are syllables, which could
/// still become one, and where the tone mark goes. See docs/ENGINE.md §2.
///
/// A syllable is written onset + rhyme. The rhyme is the vowel run (nucleus, with any glide or
/// semivowel) followed by an optional final consonant. Instead of encoding phonology rule by
/// rule, the engine checks rhymes against the closed list below: it is short, readable and easy to
/// audit against a dictionary.
enum Orthography {
    // MARK: Inventory

    static let onsets: Set<[Form]> = Set([
        "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh",
        "nh", "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ].map(forms))

    /// Every rhyme in modern Vietnamese spelling, without tone. Loanword rhymes (oong, ooc) and
    /// dialect rhymes (ưm, ưn) are included because people type them.
    static let rhymes: [[Form]] = [
        // open, or closed by a semivowel
        "a", "ai", "ao", "au", "ay", "âu", "ây", "e", "eo", "ê", "êu", "i", "ia", "iu", "iêu", "yêu",
        "o", "oi", "ô", "ôi", "ơ", "ơi", "u", "ua", "ui", "uôi", "ư", "ưa", "ưi", "ưu", "ươi", "ươu",
        "y", "oa", "oai", "oao", "oay", "oe", "oeo", "uê", "uy", "uya", "uyu", "uơ", "uây",
        // closed by a consonant
        "ac", "ach", "am", "an", "ang", "anh", "ap", "at",
        "ăc", "ăm", "ăn", "ăng", "ăp", "ăt",
        "âc", "âm", "ân", "âng", "âp", "ât",
        "ec", "em", "en", "eng", "ep", "et",
        "êch", "êm", "ên", "ênh", "êp", "êt",
        "ich", "im", "in", "inh", "ip", "it",
        "iêc", "iêm", "iên", "iêng", "iêp", "iêt",
        "yêm", "yên", "yêt",
        "oc", "om", "on", "ong", "op", "ot", "ooc", "oong",
        "ôc", "ôm", "ôn", "ông", "ôp", "ôt",
        "ơm", "ơn", "ơp", "ơt",
        "uc", "um", "un", "ung", "up", "ut",
        "uôc", "uôm", "uôn", "uông", "uôt",
        "ưc", "ưm", "ưn", "ưng", "ưt",
        "ươc", "ươm", "ươn", "ương", "ươp", "ươt",
        "oac", "oach", "oam", "oan", "oang", "oanh", "oap", "oat",
        "oăc", "oăm", "oăn", "oăng", "oăp", "oăt",
        "oen", "oet",
        "uân", "uâng", "uât",
        "uêch", "uênh",
        "uych", "uyn", "uynh", "uyp", "uyt",
        "uyên", "uyêt",
    ].map(forms)

    /// Rhymes after an empty onset: `iê` is then written `yê` (yêu, yên).
    private static let rhymesAfterNothing = rhymes.filter { !$0.starts(with: forms("iê")) }

    /// Rhymes after an ordinary consonant: `yê` is then written `iê` (tiên, biết).
    private static let rhymesAfterConsonant = rhymes.filter { !$0.starts(with: forms("yê")) }

    /// After `qu` the `u` is the glide, so the rest is a glided rhyme minus its glide letter:
    /// qua (oa), quê (uê), quốc (uôc), quyên (uyên), and the older `i` spelling (quít for quýt).
    private static let rhymesAfterQu: [[Form]] = {
        let o = Form("o"), u = Form("u"), y = Form("y")
        // quạu has the rhyme au after qu, with no corresponding oau in the general inventory.
        var result: Set<[Form]> = [forms("au")]
        for rhyme in rhymes where rhyme.count >= 2 {
            let rest = Array(rhyme.dropFirst())
            if rhyme[0] == o, [Form("a"), Form("a", .breve), Form("e")].contains(rhyme[1]) {
                result.insert(rest)
            }
            if rhyme[0] == u, rhyme[1].isVowel {
                result.insert(rest)
            }
            if rhyme[0] == u, rhyme[1] == y, !rhyme.contains(where: { $0.base == ASCII.e || $0.base == ASCII.a }) {
                result.insert([Form("i")] + rhyme.dropFirst(2))
            }
        }
        return Array(result)
    }()

    /// After `gi` the `i` belongs to the onset; an `iê` rhyme loses its `i` (giêng, giết).
    private static let rhymesAfterGi: [[Form]] = {
        var result: Set<[Form]> = []
        for rhyme in rhymes {
            if rhyme.starts(with: forms("iê")) {
                result.insert(Array(rhyme.dropFirst()))
            } else if rhyme[0].base != ASCII.i, rhyme[0].base != ASCII.y {
                result.insert(rhyme)
            }
        }
        return Array(result)
    }()

    private static let onsetPrefixes: Set<[Form]> = {
        var result: Set<[Form]> = [[]]
        for onset in onsets {
            for length in 1...onset.count { result.insert(Array(onset.prefix(length))) }
        }
        return result
    }()

    private struct RhymeIndex: Sendable {
        let complete: Set<[Form]>
        let byFirstBase: [UInt8: [[Form]]]

        init(_ list: [[Form]]) {
            complete = Set(list)
            var buckets: [UInt8: [[Form]]] = [:]
            for rhyme in list where !rhyme.isEmpty {
                buckets[rhyme[0].base, default: []].append(rhyme)
            }
            byFirstBase = buckets
        }
    }

    private static let indexAfterNothing = RhymeIndex(rhymesAfterNothing)
    private static let indexAfterConsonant = RhymeIndex(rhymesAfterConsonant)
    private static let indexAfterQu = RhymeIndex(rhymesAfterQu)
    private static let indexAfterGi = RhymeIndex(rhymesAfterGi)

    private static func rhymeIndex(after onset: ArraySlice<Form>) -> RhymeIndex {
        switch onset.count {
        case 0:
            return indexAfterNothing
        case 2:
            let first = onset[onset.startIndex]
            let second = onset[onset.index(after: onset.startIndex)]
            if first == Form("q") && second == Form("u") { return indexAfterQu }
            if first == Form("g") && second == Form("i") { return indexAfterGi }
            return indexAfterConsonant
        default:
            return indexAfterConsonant
        }
    }

    // MARK: Segmentation

    /// Where the onset and the vowel run end. Letters after the vowel run are the final consonant.
    struct Segments: Equatable {
        var onsetEnd: Int
        var vowelEnd: Int
        /// False when a vowel follows the final consonant: two syllables, or not Vietnamese.
        var isSingleSyllable: Bool

        var vowels: Range<Int> { onsetEnd..<vowelEnd }
        var hasVowel: Bool { vowelEnd > onsetEnd }
    }

    static func segments(_ forms: [Form]) -> Segments {
        var index = 0
        while index < forms.count, !forms[index].isVowel { index += 1 }
        var onsetEnd = index
        if index == 1, forms.count >= 2, forms[0] == Form("q"), forms[1] == Form("u") {
            onsetEnd = 2   // qu: the u is a glide written with the onset
        } else if index == 1, forms.count >= 3, forms[0] == Form("g"), forms[1] == Form("i"), forms[2].isVowel {
            onsetEnd = 2   // gi before a vowel is the onset (gia, giữa); alone it is g + i (gì, gìn)
        }
        var vowelEnd = onsetEnd
        while vowelEnd < forms.count, forms[vowelEnd].isVowel { vowelEnd += 1 }
        var end = vowelEnd
        while end < forms.count, !forms[end].isVowel { end += 1 }
        return Segments(onsetEnd: onsetEnd, vowelEnd: vowelEnd, isSingleSyllable: end == forms.count)
    }

    static func segments(_ letters: [Letter]) -> Segments {
        var index = 0
        while index < letters.count, !letters[index].form.isVowel { index += 1 }
        var onsetEnd = index
        if index == 1, letters.count >= 2, letters[0].form == Form("q"), letters[1].form == Form("u") {
            onsetEnd = 2
        } else if index == 1, letters.count >= 3, letters[0].form == Form("g"), letters[1].form == Form("i"), letters[2].form.isVowel {
            onsetEnd = 2
        }
        var vowelEnd = onsetEnd
        while vowelEnd < letters.count, letters[vowelEnd].form.isVowel { vowelEnd += 1 }
        var end = vowelEnd
        while end < letters.count, !letters[end].form.isVowel { end += 1 }
        return Segments(onsetEnd: onsetEnd, vowelEnd: vowelEnd, isSingleSyllable: end == letters.count)
    }

    // MARK: Validity

    /// Whether more letters or marks could still turn this into a syllable. Typed letters without a
    /// mark may later receive one (`duong` can become `đương`), so they match marked rhyme letters.
    static func isPlausiblePrefix(_ forms: [Form], tone: Tone) -> Bool {
        let parts = segments(forms)
        guard parts.isSingleSyllable else { return false }
        guard parts.hasVowel else { return tone == .level && onsetPrefixes.contains(forms) }
        let onsetSlice = forms[..<parts.onsetEnd]
        if !onsetSlice.isEmpty, !onsets.contains(Array(onsetSlice)) { return false }
        let rhyme = forms[parts.onsetEnd...]
        let firstForm = rhyme[rhyme.startIndex]
        guard spellingAllows(onset: onsetSlice, rhymeStart: firstForm) else { return false }
        if parts.vowelEnd < forms.count, isStop(forms[parts.vowelEnd]), ![.level, .acute, .dot].contains(tone) {
            return false
        }
        guard let bucket = rhymeIndex(after: onsetSlice).byFirstBase[firstForm.base] else { return false }
        return bucket.contains { candidate in
            guard candidate.count >= rhyme.count else { return false }
            var rIdx = rhyme.startIndex
            var cIdx = 0
            while rIdx < rhyme.endIndex {
                let typed = rhyme[rIdx]
                let target = candidate[cIdx]
                if typed != target && !(typed.mark == .none && typed.base == target.base) {
                    return false
                }
                rIdx = rhyme.index(after: rIdx)
                cIdx += 1
            }
            return true
        }
    }

    /// Whether the letters and tone spell a complete Vietnamese syllable.
    static func isComplete(_ forms: [Form], tone: Tone) -> Bool {
        let parts = segments(forms)
        guard parts.isSingleSyllable, parts.hasVowel else { return false }
        let onsetSlice = forms[..<parts.onsetEnd]
        if !onsetSlice.isEmpty, !onsets.contains(Array(onsetSlice)) { return false }
        let rhyme = Array(forms[parts.onsetEnd...])
        guard spellingAllows(onset: onsetSlice, rhymeStart: rhyme[0]) else { return false }
        // A syllable closed by c, ch, p or t only takes the rising or the heavy tone.
        if parts.vowelEnd < forms.count, isStop(forms[parts.vowelEnd]), ![.acute, .dot].contains(tone) {
            return false
        }
        return rhymeIndex(after: onsetSlice).complete.contains(rhyme)
    }

    /// c/k, g/gh and ng/ngh are one sound each, spelled by the vowel that follows:
    /// k, gh, ngh before e ê i y; c, g, ng elsewhere. `gì` is g + i written once.
    private static func spellingAllows(onset: ArraySlice<Form>, rhymeStart: Form) -> Bool {
        let front = rhymeStart.base == ASCII.e || rhymeStart.base == ASCII.i || rhymeStart.base == ASCII.y
        switch onset.count {
        case 1:
            switch onset[onset.startIndex] {
            case Form("k"): return front
            case Form("c"): return !front
            case Form("g"): return !front || rhymeStart == Form("i")
            default: return true
            }
        case 2:
            let a = onset[onset.startIndex]
            let b = onset[onset.index(after: onset.startIndex)]
            if a == Form("g") && b == Form("h") { return front }
            if a == Form("n") && b == Form("g") { return !front }
            return true
        case 3:
            let i0 = onset.startIndex
            let i1 = onset.index(after: i0)
            let i2 = onset.index(after: i1)
            if onset[i0] == Form("n") && onset[i1] == Form("g") && onset[i2] == Form("h") { return front }
            return true
        default:
            return true
        }
    }

    private static func isStop(_ form: Form) -> Bool {
        form == Form("c") || form == Form("p") || form == Form("t")
    }

    // MARK: Tone placement

    /// Which letter carries the tone mark. `nil` when there is no vowel to carry it.
    ///
    /// 1. A single vowel takes it.
    /// 2. Otherwise a vowel with a mark (â ă ê ô ơ ư) takes it; in ươ the ơ.
    /// 3. Otherwise in a closed syllable the last vowel (hoàn, huỳnh).
    /// 4. Otherwise three vowels put it in the middle (hoài, khuỷu).
    /// 5. Otherwise oa, oe, uy follow the style (hoà/hòa); other pairs take the first (mái, múa).
    static func toneIndex(_ forms: [Form], style: ToneStyle) -> Int? {
        let parts = segments(forms)
        guard parts.hasVowel else { return forms.lastIndex(where: \.isVowel) }
        let vowels = parts.vowels
        if vowels.count == 1 { return vowels.lowerBound }
        if let marked = vowels.last(where: { forms[$0].hasVowelMark }) { return marked }
        if parts.vowelEnd < forms.count { return vowels.upperBound - 1 }
        if vowels.count >= 3 { return vowels.lowerBound + 1 }
        let pair = (forms[vowels.lowerBound].base, forms[vowels.lowerBound + 1].base)
        switch pair {
        case (ASCII.o, ASCII.a), (ASCII.o, ASCII.e), (ASCII.u, ASCII.y):
            return style == .modern ? vowels.lowerBound + 1 : vowels.lowerBound
        default:
            return vowels.lowerBound
        }
    }

    static func toneIndex(_ letters: [Letter], style: ToneStyle) -> Int? {
        let parts = segments(letters)
        guard parts.hasVowel else { return letters.lastIndex(where: \.isVowel) }
        let vowels = parts.vowels
        if vowels.count == 1 { return vowels.lowerBound }
        if let marked = vowels.last(where: { letters[$0].form.hasVowelMark }) { return marked }
        if parts.vowelEnd < letters.count { return vowels.upperBound - 1 }
        if vowels.count >= 3 { return vowels.lowerBound + 1 }
        let pair = (letters[vowels.lowerBound].form.base, letters[vowels.lowerBound + 1].form.base)
        switch pair {
        case (ASCII.o, ASCII.a), (ASCII.o, ASCII.e), (ASCII.u, ASCII.y):
            return style == .modern ? vowels.lowerBound + 1 : vowels.lowerBound
        default:
            return vowels.lowerBound
        }
    }

    // MARK: Helpers

    /// Parses a lowercase Vietnamese spelling without tones (`"ương"`) into forms.
    static func forms(_ spelling: String) -> [Form] {
        spelling.map { character in
            if let byte = character.asciiValue { return Form(byte) }
            guard let parsed = Glyphs.parse(character) else {
                preconditionFailure("not a Vietnamese letter: \(character)")
            }
            return parsed.letter.form
        }
    }
}
