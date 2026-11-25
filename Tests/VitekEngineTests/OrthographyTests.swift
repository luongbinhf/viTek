import Testing
@testable import VitekEngine

@Suite struct OrthographyTests {
    private func complete(_ word: String, _ tone: Tone = .level) -> Bool {
        Orthography.isComplete(Orthography.forms(word), tone: tone)
    }

    private func plausible(_ word: String, _ tone: Tone = .level) -> Bool {
        Orthography.isPlausiblePrefix(Orthography.forms(word), tone: tone)
    }

    private func toneLetter(_ word: String, _ style: ToneStyle = .modern) -> Character? {
        let forms = Orthography.forms(word)
        return Orthography.toneIndex(forms, style: style).map { Array(word)[$0] }
    }

    @Test(arguments: [
        "a", "ba", "nghiêng", "người", "khuyên", "quôn", "quy", "qua", "gì", "gia", "giữa", "giêng",
        "yêu", "uyên", "khuya", "khuyu", "thuơ", "đường", "oai", "xoong", "kê", "ghi", "nghe", "ca",
    ])
    func completeSyllables(_ word: String) {
        #expect(complete(word))
    }

    @Test(arguments: ["ci", "ce", "ka", "ge", "gha", "nge", "ngi", "nghu", "tyên", "iêu", "ă", "â", "iaê"])
    func spellingRules(_ word: String) {
        #expect(!complete(word))
    }

    @Test(arguments: ["ke", "ky", "ga", "ghe", "nghi", "ăn", "ia", "iu"])
    func spellingAllowed(_ word: String) {
        #expect(complete(word))
    }

    @Test(arguments: ["serv", "cl", "str", "ea", "aơ", "quu", "tanta", "wh", "jo", "ff"])
    func notPrefixes(_ word: String) {
        #expect(!plausible(word))
    }

    @Test(arguments: ["ngh", "q", "qu", "duong", "uo", "nguo", "tieng", "gi", "đ", "kh", "tr"])
    func prefixes(_ word: String) {
        #expect(plausible(word))
    }

    @Test func stopFinalsTakeOnlyRisingOrHeavyTone() {
        #expect(complete("quôc", .acute))
        #expect(!complete("quôc", .level))
        #expect(complete("viêt", .dot))
        #expect(complete("viêt", .acute))
        #expect(!complete("viêt", .grave))
        #expect(!complete("viêt", .level))
        #expect(!plausible("ep", .tilde))
        #expect(plausible("ep", .level))
    }

    @Test(arguments: [
        ("hoa", "a"), ("thuy", "y"), ("khoe", "e"), ("hoan", "a"), ("huynh", "y"), ("mua", "u"),
        ("mai", "a"), ("hoai", "a"), ("khuyu", "y"), ("ngươi", "ơ"), ("tiêng", "ê"), ("quy", "y"),
        ("qua", "a"), ("giưa", "ư"), ("gi", "i"), ("yêu", "ê"), ("thuơ", "ơ"),
    ] as [(String, Character)])
    func modernTonePlacement(_ word: String, _ letter: Character) {
        #expect(toneLetter(word) == letter)
    }

    @Test(arguments: [("hoa", "o"), ("thuy", "u"), ("khoe", "o"), ("hoan", "a"), ("hoai", "a")] as [(String, Character)])
    func traditionalTonePlacement(_ word: String, _ letter: Character) {
        #expect(toneLetter(word, .traditional) == letter)
    }
}
