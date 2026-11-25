import Testing
@testable import VitekEngine

@Suite struct EditingTests {
    @Test(arguments: [
        ("vieetj⌫", "việ"), ("vieetj⌫⌫", "vi"), ("vieetj⌫c", "việc"), ("ddi⌫⌫", ""),
        ("nguowif⌫", "ngườ"), ("as⌫", ""), ("ass⌫", "a"), ("serv⌫", "sẻ"),
        ("dduowngfg⌫", "đường"), ("cl⌫", "c"),
    ] as [(String, String)])
    func backspaceDeletesWhatIsOnScreen(_ keys: String, _ expected: String) {
        #expect(composing(keys) == expected)
    }

    @Test func backspaceOnAnEmptyWordBelongsToTheDocument() {
        var engine = VitekEngine()
        let fromEmpty = engine.deleteBackward()
        _ = engine.type("a")
        let fromWord = engine.deleteBackward()
        let fromEmptyAgain = engine.deleteBackward()
        #expect(!fromEmpty)
        #expect(fromWord)
        #expect(!fromEmptyAgain)
        #expect(!engine.isComposing)
    }

    @Test func nonWordKeysLeaveTheWordAlone() {
        var engine = VitekEngine()
        for key in "vieetj" { _ = engine.type(key) }
        let refused = [engine.type(" "), engine.type("."), engine.type("1")]
        #expect(refused == [false, false, false])
        #expect(engine.composition == "việt")
        let word = engine.finish()
        let nothing = engine.finish()
        #expect(word == FinishedWord(text: "việt", keys: "vieetj", vietnamese: "việt"))
        #expect(nothing == nil)
    }

    @Test func sentences() {
        #expect(typed("Tooi yeeu tieengs Vieetj.") == "Tôi yêu tiếng Việt.")
        #expect(typed("Hoom nay, server bij lawngj!") == "Hôm nay, server bị lặng!")
    }

    @Test func precomposedLettersFromTheLayoutJoinTheWord() {
        #expect(typed("tiếng") == "tiếng")
        #expect(typed("trương") == "trương")
        #expect(typed("trươngf") == "trường")
    }

    @Test func randomKeysNeverBreakTheEngine() {
        var generator = SplitMix64(seed: 2026)
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzADEOUW0123456789[] .,⌫")
        for options in [EngineOptions(), vni, EngineOptions(spellCheck: false), EngineOptions(bracketVowels: true)] {
            for _ in 0..<2_000 {
                let length = Int(generator.next() % 14) + 1
                let script = String((0..<length).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] })
                var engine = VitekEngine(options: options)
                for key in script {
                    if key == "⌫" { _ = engine.deleteBackward() } else { _ = engine.type(key) }
                    #expect(engine.isComposing || engine.composition.isEmpty)
                    #expect(engine.composition.unicodeScalars.count == engine.composition.count, "\(script)")
                }
                while engine.deleteBackward() {}
                #expect(!engine.isComposing, "\(script)")
            }
        }
    }
}

/// A small seeded generator so the random test is the same on every run.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
