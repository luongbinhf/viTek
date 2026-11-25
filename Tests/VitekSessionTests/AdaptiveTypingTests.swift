import Testing
import VitekEngine
import VitekSession

@Suite struct AdaptiveTypingTests {
    private func field() -> SimulatedTextField {
        SimulatedTextField(session: InputSession(engine: VitekEngine(options: .init(automaticallyDetectsMethod: true))))
    }

    @Test func switchesWithinOneSentence() {
        var field = field()
        field.type("vieetj vie65t server reset MA123 A11 123 ")
        #expect(field.text == "việt việt server reset MA123 A11 123 ")
    }

    @Test func preservesEnglishAndCellReferences() {
        var field = field()
        field.type("The new row has issues at www.example.com A11 A1 ")
        #expect(field.text == "The new row has issues at www.example.com A11 A1 ")
    }

    @Test(arguments: [false, true])
    func ambiguousVowelsFollowEnglishContext(automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic)
        var field = SimulatedTextField(session: InputSession(engine: VitekEngine(options: options)))
        field.session.engine.habits = TypingHabits(telexScore: 3)
        field.type("I see the moon")
        #expect(field.text == "I see the moon")
        field.type(" quauj moon ")
        #expect(field.committed == "I see the moon quạu môn ")
    }

    @Test func englishContextEndsOnFocusLoss() {
        var field = field()
        field.session.engine.habits = TypingHabits(telexScore: 3)
        field.type("the ")
        field.flush()
        field.type("moon ")
        #expect(field.committed == "the môn ")
    }

    @Test(arguments: [false, true])
    func englishContextRespectsKeepEnglishWords(automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic, keepEnglishWords: false)
        let session = InputSession(engine: VitekEngine(options: options))
        #expect(SimulatedTextField.result(of: "I see the moon", session: session) == "I sê the môn")
    }

    @Test(arguments: [false, true])
    func nearbyWordsSelectTheReading(automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic)
        var field = SimulatedTextField(session: InputSession(engine: VitekEngine(options: options)))
        field.session.engine.habits = TypingHabits(telexScore: 3)
        field.type("Read THIS. Need more. Over there. With this more ")
        #expect(field.committed == "Read THIS. Need more. Over there. With this more ")
        field.session.engine.habits = TypingHabits(telexScore: -3)
        field.type("cos there sinh this ")
        #expect(field.committed.hasSuffix("có thể sinh thí "))
    }

    @Test func ambiguousReadingsWithoutAnAdjacentCue() {
        let keys = ["this", "more", "there"]
        let vietnamese = ["thí", "moẻ", "thể"]
        for (raw, marked) in zip(keys, vietnamese) {
            #expect(SimulatedTextField.result(of: raw, session: field().session) == raw)
            #expect(SimulatedTextField.result(of: raw) == marked)
            var learned = field()
            learned.session.engine.habits = TypingHabits(telexScore: 3)
            learned.type(raw + " ")
            #expect(learned.committed == marked + " ")
            #expect(learned.session.engine.habits == TypingHabits(telexScore: 3))
        }
    }

    @Test func shortToneCollisionsNeedAnEnglishCue() {
        var field = field()
        field.type("car. need her car. cos car ")
        #expect(field.committed == "cả. need her car. có cả ")
    }

    @Test func deletingInAnEnglishReadingKeepsTheVisiblePrefix() {
        var field = field()
        field.type("need more⌫")
        #expect(field.text == "need mor")
        field.type("e over there⌫ ")
        #expect(field.committed == "need more over ther ")
    }

    @Test func onlyUnambiguousWordsTeach() {
        var field = field()
        field.type("as A1 as ")
        #expect(field.text == "as A1 as ")
        #expect(field.session.engine.habits == TypingHabits())
        field.type("vieetj as vie65t vie65t A1 ")
        #expect(field.text.hasSuffix("việt á việt việt Á "))
        field.type("server reset as A1 ")
        #expect(field.text.hasSuffix("server reset as A1 "))
    }

    @Test func deletesVisibleCharactersAndRestartsDetection() {
        var field = field()
        field.type("as⌫ A1⌫ vie65t⌫⌫⌫⌫vieetj ")
        #expect(field.text == "a A việt ")
    }

    @Test func discardedWordDoesNotTeach() {
        var field = field()
        field.type("vieetj")
        field.session.discard()
        #expect(field.session.engine.habits == TypingHabits())
    }
}
