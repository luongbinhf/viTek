import Testing
import VitekSession

@Suite struct WordPredictionTests {
    @Test func avoidsUnanchoredSpecialistPredictionsInRunningProse() {
        #expect(!WordPrediction.words(context: "Con đang học ", prefix: "").contains("máy"))
        #expect(!WordPrediction.words(context: "Tôi vừa mua bao ", prefix: "").contains("mật"))
        #expect(WordPrediction.words(context: "Tôi đang học m", prefix: "m").contains("máy"))
        #expect(WordPrediction.words(context: "Tôi đang học máy bằng cơ sở dữ ", prefix: "").first == "liệu")
        let strongest = WordPrediction.suggest(context: "cơ sở dữ li", prefix: "li", systemCandidates: ["limit"])
        #expect(strongest.map(\.text) == ["liệu"])
    }

    @Test func completesVietnameseWithoutSystemSpellchecker() {
        #expect(WordPrediction.words(context: "ngư", prefix: "ngư").contains("người"))
        #expect(WordPrediction.words(context: "ngư", prefix: "ngư").first == "người")
        #expect(WordPrediction.words(context: "chuy", prefix: "chuy").contains("chuyển"))
    }

    @Test func ranksContextBeforeGenericVocabulary() {
        #expect(WordPrediction.words(context: "bảo vệ môi ", prefix: "").first == "trường")
        #expect(WordPrediction.words(context: "hợp đồng lao ", prefix: "").first == "động")
        #expect(WordPrediction.words(context: "co so du ", prefix: "").first == "liệu")
    }

    @Test func supportsTechnicalVocabulary() {
        #expect(WordPrediction.words(context: "WebS", prefix: "WebS").contains("WebSocket"))
        #expect(WordPrediction.words(context: "TypeS", prefix: "TypeS").contains("TypeScript"))
    }

    @Test func completesCodeWithoutVietnameseCaseConversion() {
        #expect(WordPrediction.words(context: "let result = JSON.par", prefix: "par").first == "parse")
        #expect(WordPrediction.words(context: "const userName = value; const result = us", prefix: "us").first == "userName")
    }
}

@Suite struct PredictionQualityTests {
    @Test func followsExplicitAccentsAndCase() {
        let cases = [("NGƯ", "NGƯỜI"), ("Ngư", "Người"), ("nguoi", "người"),
                     ("ngu\u{31B}", "người")]
        for (prefix, expected) in cases {
            #expect(WordPrediction.words(context: prefix, prefix: prefix).contains(expected))
        }
        #expect(!WordPrediction.words(context: "ngủ", prefix: "ngủ").contains("người"))
        #expect(!WordPrediction.words(context: "cơ sở dá", prefix: "dá").contains("dữ"))
        #expect(WordPrediction.words(context: "CƠ SỞ DỮ ", prefix: "").first == "liệu")
        #expect(WordPrediction.words(context: "cơ sở dữ L", prefix: "L").first == "Liệu")
    }

    @Test func phraseBoundariesAndEmptyInput() {
        for context in ["", " ", "\n", "cơ sở dữ\n", "cơ sở dữ. ", "cơ sở dữ! ", "xcơ sở "] {
            #expect(WordPrediction.words(context: context, prefix: "").isEmpty, "context: \(context.debugDescription)")
        }
        #expect(WordPrediction.words(context: "n", prefix: "n").isEmpty)
        #expect(WordPrediction.words(context: "xngư", prefix: "ngư").isEmpty)
        #expect(WordPrediction.words(context: "cơ sở d", prefix: "d").first == "dữ")
        #expect(WordPrediction.words(context: "ngư", prefix: "ngư", limit: 0).isEmpty)
        #expect(WordPrediction.words(context: "ngư", prefix: "ngư", limit: -1).isEmpty)
        #expect(WordPrediction.words(context: "abc", prefix: "bcdef").isEmpty)
        #expect(WordPrediction.words(context: "e\u{301}", prefix: "é").isEmpty)
    }

    @Test func longestContextWinsRegardlessOfEntryOrder() {
        let entries = [VocabularyEntry("dữ án", priority: 1_000), VocabularyEntry("cơ sở dữ liệu", priority: 1)]
        for data in [entries, entries.reversed()] {
            let lexicon = PredictionLexicon(entries: Array(data))
            let result = WordPrediction.suggest(context: "cơ sở dữ ", prefix: "", lexicon: lexicon)
            #expect(result.map(\.text) == ["liệu"])
            #expect(result.first?.source == .phrase)
        }
    }

    @Test func domainBiasIsExplicitAndDoesNotErasePhraseEvidence() {
        let lexicon = PredictionLexicon(entries: [
            .init("sinh", domain: .education, priority: 100),
            .init("sinh học", domain: .science, priority: 200),
            .init("sinh hoạt", domain: .general, priority: 300),
        ])
        let result = WordPrediction.suggest(context: "ho", prefix: "ho", domain: .science, lexicon: lexicon)
        #expect(result.first?.text == "học")
        #expect(WordPrediction.suggest(context: "sinh h", prefix: "h", domain: .science,
                                       lexicon: lexicon).allSatisfy { $0.source == .phrase })
    }

    @Test func rejectsInvalidVocabularyAndDeduplicatesCanonicalWords() {
        let lexicon = PredictionLexicon(entries: [
            .init("người", priority: 100), .init("ngu\u{31B}o\u{31B}\u{300}i", priority: 200),
            .init("ng\u{200B}ười"), .init("người\nkhác"), .init(" ngữ"), .init("two  spaces"),
            .init("a b c d e f g h i"), .init("🙂"), .init("user_name"),
        ])
        #expect(lexicon.entryCount == 2)
        #expect(lexicon.rejectedEntryCount == 7)
        #expect(lexicon.wordCount == 1)
        let result = WordPrediction.suggest(context: "ngu", prefix: "ngu", lexicon: lexicon,
                                            systemCandidates: ["Người", "ng\u{200B}ữ", "nguồn"])
        #expect(result.count == 2)
        #expect(result.first?.source == .dictionary)
        #expect(result.last?.source == .system)
    }

    @Test func technicalAndGeneralCoverage() {
        let cases = [("trí tuệ nhân ", "tạo"), ("hệ điều ", "hành"), ("bộ nhớ ", "đệm"),
                     ("ngôn ngữ lập ", "trình"), ("báo cáo tài ", "chính"), ("doanh thu ", "thuần"),
                     ("chăm sóc sức ", "khỏe"), ("phương pháp nghiên ", "cứu"),
                     ("năng lượng tái ", "tạo"), ("thời gian phản ", "hồi"),
                     ("xử lý ngôn ngữ tự ", "nhiên"), ("tính toàn vẹn dữ ", "liệu"),
                     ("rất cảm ", "ơn"), ("hẹn gặp ", "lại")]
        for (context, expected) in cases {
            #expect(WordPrediction.words(context: context, prefix: "").first == expected)
        }
        #expect(PredictionLexicon.standard.rejectedEntryCount == 0)
        #expect(PredictionLexicon.standard.wordCount > 400)
    }

    @Test func codeKeepsSpellingAndNeverAddsSpace() {
        let candidates = WordPrediction.suggest(context: "const user_name = 1; const userName = 2; return us", prefix: "us")
        #expect(candidates.prefix(2).map(\.text) == ["userName", "user_name"])
        #expect(candidates.allSatisfy { !$0.appendsSpace && $0.insertion == $0.text })
        #expect(WordPrediction.words(context: "const Foo = 1; const foo = 2; return F", prefix: "F").isEmpty)
        #expect(WordPrediction.words(context: "JSON.PA", prefix: "PA").isEmpty)
        #expect(WordPrediction.words(context: "console.lo", prefix: "lo").first == "log")
        #expect(WordPrediction.words(context: "unknown.par", prefix: "par").isEmpty)
        #expect(WordPrediction.words(context: "const x = ", prefix: "").isEmpty)
        #expect(WordPrediction.suggest(context: "ret", prefix: "ret", mode: .code).first?.text == "return")
    }

    @Test func doesNotLearnIdentifiersFromCommentsOrStringsOrPreviousRequests() {
        let context = "const value = \"userSecret\"; /* userComment */ const userName = 1; return us"
        #expect(WordPrediction.words(context: context, prefix: "us") == ["userName"])
        #expect(WordPrediction.words(context: "return us", prefix: "us").isEmpty)
        #expect(WordPrediction.words(context: "// cơ sở dữ ", prefix: "").first == "liệu")
        #expect(WordPrediction.words(context: "const note = \"cơ sở dữ ", prefix: "").first == "liệu")
        #expect(WordPrediction.suggest(context: "// ngư", prefix: "ngư", mode: .code).isEmpty)
        #expect(WordPrediction.words(context: "const userOld = 1;\n" + String(repeating: " ", count: 600) + "return us", prefix: "us").isEmpty)
    }

    @Test func suppressesUnsafeReplacementBoundaries() {
        let cases = [("https://example.com/ng", "ng"), ("me@ng", "ng"), ("/tmp/ng", "ng"),
                     ("./ng", "ng"), ("../ng", "ng"), ("~/ng", "ng"), ("user_ng", "ng"),
                     ("const user1ng", "ng"), ("$ng", "ng"), ("some.ng", "ng")]
        for (context, prefix) in cases {
            #expect(WordPrediction.words(context: context, prefix: prefix).isEmpty)
        }
    }

    @Test func stableBoundedResultsThroughTypingAndBackspace() {
        let prefix = "người"
        let expected = WordPrediction.words(context: "ngư", prefix: "ngư")
        for _ in 0..<50 {
            for count in 0...prefix.count {
                let typed = String(prefix.prefix(count))
                let result = WordPrediction.words(context: typed, prefix: typed)
                #expect(result.count <= 5)
                #expect(Set(result).count == result.count)
            }
            #expect(WordPrediction.words(context: "ngư", prefix: "ngư") == expected)
        }
    }
}
