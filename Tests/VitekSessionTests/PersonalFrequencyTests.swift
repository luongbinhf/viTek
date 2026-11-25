import Testing
import VitekSession

@Suite struct PersonalFrequencyTests {
    @Test func learnsPersonalUnigramsAndBigrams() {
        var memory = PersonalFrequency()
        memory.record(word: "viTek", after: "dùng")
        memory.record(word: "viTek", after: "dùng")
        memory.record(word: "nhanh", after: "gõ")

        let afterDung = WordPrediction.suggest(context: "Tôi đang dùng ", prefix: "", personal: memory)
        #expect(afterDung.first?.text == "vitek")

        let prefixMatch = WordPrediction.suggest(context: "vit", prefix: "vit", personal: memory)
        #expect(prefixMatch.contains { $0.text == "vitek" })
    }

    @Test func prunesToMaxCapacityAndIgnoresNonWords() {
        var memory = PersonalFrequency()
        memory.record(word: "12345")
        memory.record(word: "a")
        #expect(memory.isEmpty)

        for i in 0..<(PersonalFrequency.maxEntries + 50) {
            let word = "tu" + String(repeating: "a", count: (i % 10) + 1) + String(UnicodeScalar(97 + (i % 26))!) + String(UnicodeScalar(97 + ((i / 26) % 26))!)
            memory.record(word: word)
        }
        #expect(memory.unigrams.count <= PersonalFrequency.maxEntries)
    }

    @Test func trigramBeatsConflictingBigramAndMergesFromCloud() {
        var memory = PersonalFrequency()
        memory.record(word: "liệu", after: "dữ", beforeThat: "sở")
        memory.record(word: "bảng", after: "dữ", beforeThat: "khác")
        memory.record(word: "bảng", after: "dữ", beforeThat: "khác")

        let afterSoDu = WordPrediction.suggest(context: "cơ sở dữ ", prefix: "", personal: memory)
        #expect(afterSoDu.first?.text == "liệu")

        var remote = PersonalFrequency()
        remote.record(word: "sữa", after: "phê", beforeThat: "cà")
        remote.record(word: "sữa", after: "phê", beforeThat: "cà")
        memory.merge(remote)
        let afterCaPhe = WordPrediction.suggest(context: "đang uống cà phê ", prefix: "", personal: memory)
        #expect(afterCaPhe.first?.text == "sữa")
    }

    @Test func suggestsShortcutExpansionsLive() {
        let shortcuts = Shortcuts(["ko": "không", "vn": "Việt Nam"])
        let ko = WordPrediction.suggest(context: "Tôi ko", prefix: "ko", shortcuts: shortcuts)
        #expect(ko.first?.text == "không")
        let vn = WordPrediction.suggest(context: "người Vn", prefix: "Vn", shortcuts: shortcuts)
        #expect(vn.first?.text == "Việt nam" || vn.first?.text == "Việt Nam")
    }

    @Test func minesCollisionFreeShortcutSuggestionsFromRepeatedPhrases() {
        var memory = PersonalFrequency()
        for _ in 0..<5 {
            memory.record(word: "ơn", after: "cảm")
            memory.record(word: "bạn", after: "ơn", beforeThat: "cảm")
            memory.record(word: "khoản", after: "tài")
        }
        let suggestions = memory.suggestedShortcuts(excluding: ["existing"], minCount: 4, limit: 5)
        #expect(suggestions.contains { $0.abbreviation == "cob" && $0.phrase == "cảm ơn bạn" && $0.count == 5 })
        #expect(suggestions.contains { $0.abbreviation == "tk" && $0.phrase == "tài khoản" && $0.count == 5 })
        // "cảm ơn" -> "co" is a valid Vietnamese syllable, so it must NEVER be suggested as a collision-prone shortcut.
        #expect(!suggestions.contains { $0.abbreviation == "co" })

        let filtered = memory.suggestedShortcuts(excluding: ["cob"], existingExpansions: ["tài khoản"], minCount: 4)
        #expect(!filtered.contains { $0.abbreviation == "cob" })
        #expect(!filtered.contains { $0.abbreviation == "tk" })
    }
}
