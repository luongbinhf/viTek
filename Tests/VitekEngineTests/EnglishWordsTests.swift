import Testing
@testable import VitekEngine

@Suite struct EnglishWordsTests {
    @Test(arguments: ["test", "best", "last", "list", "reset", "taxi", "Test", "TEST"])
    func everydayEnglishStaysAsTyped(_ keys: String) {
        #expect(typed(keys) == keys)
    }

    @Test(arguments: [false, true])
    func repeatedToneKeysInEnglish(automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic)
        for word in ["boss", "Offer", "AFFECT", "bosses", "offering", "affected"] {
            #expect(composing(word, options) == word)
            #expect(typed(word, options) == word)
        }
        let sentence = "My boss sent the offer. It can affect me."
        #expect(typed(sentence, options) == sentence)
        #expect(typed("ass tesst", options) == "as test")
        #expect(composing("boss⌫", options) == "bos")
        #expect(typed("offer⌫r", options) == "offer")
        let disabled = EngineOptions(automaticallyDetectsMethod: automatic, keepEnglishWords: false)
        #expect(typed("boss offer affect ass", disabled) == "bos ofer afect as")
    }

    @Test(arguments: [false, true])
    func repeatedToneKeysWithAnEnglishEnding(automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic)
        for word in ["Office", "password", "CURRENT", "differently", "assessments", "correction"] {
            #expect(composing(word, options) == word)
            #expect(typed(word, options) == word)
        }
        // Each shorter sequence is still a deliberate undo, even at the start of a listed word.
        #expect(typed("off ass curr tesst", options) == "of as cur test")
        #expect(typed("office⌫⌫⌫", options) == "off")
        let disabled = EngineOptions(automaticallyDetectsMethod: automatic, keepEnglishWords: false)
        #expect(typed("office current password", disabled) == "ofice curent pasword")
    }

    /// Ending on the tone key is the unambiguous way to type the Vietnamese reading.
    @Test(arguments: [("tets", "tét"), ("bets", "bét"), ("lits", "lít"), ("as", "á"), ("too", "tô")]
          as [(String, String)])
    func endingOnAMarkKeyMeansVietnamese(_ keys: String, _ reading: String) {
        #expect(typed(keys) == reading)
    }

    @Test func wordsOnlyMarkedWithTheVowelAreNotListed() {
        for keys in ["teen", "been", "moon", "own", "awn", "seem"] {
            #expect(!EnglishWords.words.contains(keys), "\\(keys)")
        }
    }

    @Test func theOptionAndVNITurnItOff() {
        #expect(typed("test", EngineOptions(keepEnglishWords: false)) == "tét")
        #expect(typed("test", vni) == "test")
        #expect(typed("te1t", vni) == "tét")
    }

    @Test func everyListedWordReallyConflicts() {
        let plain = EngineOptions(keepEnglishWords: false)
        for word in EnglishWords.words {
            #expect(typed(word, plain) != word, "\\(word)")
            #expect(typed(word) == word, "\\(word)")
        }
        #expect(EnglishWords.words.count == 306)
    }

    @Test func automaticEnglishCuesStayLiteral() {
        let auto = EngineOptions(automaticallyDetectsMethod: true)
        for word in ["core", "sore", "rose", "nose", "door", "poor", "loser", "virus", "versus",
                     "worry", "suffer", "arrest", "barn", "borrow", "horrible", "terrible"] {
            #expect(typed(word, auto) == word, "\\(word)")
        }
    }

    @Test func midWordShortcutsStillComposeTheWord() {
        // The rule looks at the whole word when it ends, never at a prefix.
        #expect(composing("test") == "tét")
        #expect(typed("testing") == "testing")
    }
}
