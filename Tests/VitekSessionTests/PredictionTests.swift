import Testing
import VitekSession

@Suite struct PredictionTests {
    @Test func rejectsNonWordsAndInvisibleCharacters() {
        #expect(Suggestions.prepare(["...", "🙂", "123", "người!", "ng\u{200B}ười", "ng\u{0000}ười", "người"], prefix: "") == ["người"])
    }

    @Test func preservesUppercaseTyping() {
        #expect(Suggestions.prepare(["người", "ngủ"], prefix: "NG") == ["NGƯỜI", "NGỦ"])
    }

    @Test func keepsTechnicalTokens() {
        #expect(Suggestions.prepare(["API", "OAuth2", "UTF-8", "CI/CD", "C++", "C#", "HTTP/2"], prefix: "") == ["API", "OAuth2", "UTF-8", "CI/CD", "C++"])
    }

    @Test func phraseContinuationsRespectContextAndAccents() {
        #expect(Terminology.candidates(context: "cơ sở d", prefix: "d") == ["dữ"])
        #expect(Terminology.candidates(context: "cơ sở dữ ", prefix: "") == ["liệu"])
        #expect(Terminology.candidates(context: "kiểm thử ", prefix: "") == ["hồi", "tích", "đơn"])
        #expect(Terminology.candidates(context: "cơ sở dá", prefix: "dá").isEmpty)
        #expect(Terminology.candidates(context: "xin chào ", prefix: "").isEmpty)
    }

    @Test func doesNotCrossParagraphsOrPartialWords() {
        for context in ["cơ sở\n", "cơ sở\r\n", "cơ sở. ", "xcơ sở "] {
            #expect(Terminology.candidates(context: context, prefix: "").isEmpty)
        }
        #expect(Terminology.candidates(context: "xAP", prefix: "AP").isEmpty)
    }

    @Test func acronymCompletionAndModelResultsMergeWithoutDuplicates() {
        let local = Terminology.candidates(context: "AP", prefix: "AP")
        #expect(Suggestions.prepare(local + ["api", "application"], prefix: "AP") == ["API", "APPKIT", "APPLICATION"])
        #expect(Terminology.candidates(context: "A", prefix: "A").isEmpty)
    }

    @Test func completionRangesUseExactUTF16Suffix() {
        #expect(Terminology.prefixLength(context: "🙂 ngư", prefix: "ngư") == 3)
        #expect(Terminology.prefixLength(context: "a", prefix: "abcd") == nil)
        #expect(Terminology.prefixLength(context: "abc", prefix: "xy") == nil)
        #expect(Terminology.prefixLength(context: "e\u{301}", prefix: "é") == nil)
        #expect(Terminology.prefixLength(context: "", prefix: "") == 0)
    }

    @Test func canonicallyEquivalentWordsDeduplicate() {
        #expect(Suggestions.prepare(["người", "ngu\u{31B}o\u{31B}\u{300}i"], prefix: "ngu") == ["người"])
    }
}
