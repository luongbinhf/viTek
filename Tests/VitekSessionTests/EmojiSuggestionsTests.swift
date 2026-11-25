import Testing
import VitekSession

@Suite struct EmojiSuggestionsTests {
    @Test func suggestsEmojiForCompleteVietnameseAndEnglishPrefix() {
        let cafe = WordPrediction.suggest(context: "cafe", prefix: "cafe")
        #expect(cafe.contains { $0.text == "☕️" && $0.source == .emoji })

        let tim = WordPrediction.suggest(context: "tim", prefix: "tim")
        #expect(tim.contains { $0.text == "❤️" && $0.source == .emoji })

        let fire = WordPrediction.suggest(context: "fire", prefix: "fire")
        #expect(fire.contains { $0.text == "🔥" && $0.source == .emoji })
    }

    @Test func suggestsEmojiAfterCompleteTwoWordPhrase() {
        let thanks = WordPrediction.suggest(context: "cảm ơn ", prefix: "")
        #expect(thanks.contains { $0.text == "🙏" && $0.source == .emoji })

        let vn = WordPrediction.suggest(context: "Việt Nam ", prefix: "")
        #expect(vn.contains { $0.text == "🇻🇳" && $0.source == .emoji })

        let congrats = WordPrediction.suggest(context: "chuc mung ", prefix: "")
        #expect(congrats.contains { $0.text == "🎉" && $0.source == .emoji })
    }

    @Test func neverSuggestsEmojiInCodeContextOrPartialUnmatchedPrefix() {
        let code = WordPrediction.suggest(context: "let ok = ", prefix: "")
        #expect(!code.contains { $0.source == .emoji })

        let partial = WordPrediction.suggest(context: "c", prefix: "c")
        #expect(!partial.contains { $0.source == .emoji })
    }
}
