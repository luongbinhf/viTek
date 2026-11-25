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
}
