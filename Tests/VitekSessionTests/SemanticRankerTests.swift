import Testing
import VitekSession

@Suite struct SemanticRankerTests {
    @Test func longRangeSentenceContextReranksAmbiguousContinuations() {
        // Without contract context, "điều " may rank other continuations; with contract cues earlier in the
        // sentence, "khoản" should rise to the top of verified candidates without inventing words.
        let contractSentence = "Hợp đồng thuê mặt bằng pháp lý này cần rà soát lại điều "
        let contractRanked = WordPrediction.words(context: contractSentence, prefix: "", limit: 5)
        #expect(contractRanked.first == "khoản")

        // With medical/hospital cues earlier in the sentence, "điều " should prioritize "trị".
        let medicalSentence = "Bác sĩ tại bệnh viện đang khám triệu chứng và hướng dẫn điều "
        let medicalRanked = WordPrediction.words(context: medicalSentence, prefix: "", limit: 5)
        #expect(medicalRanked.first == "trị")
    }

    @Test func semanticClipboardSearchMatchesConceptsWithoutLiteralOverlap() {
        var history = ClipboardHistory()
        let p1 = history.addPinned("VCB 0071001234567 NGUYEN VAN A", timestamp: 10)
        let p2 = history.addPinned("Tầng 12, Toà nhà Bitexco, Quận 1, TP.HCM", timestamp: 20)
        let r1 = history.record("482910", timestamp: 30)
        let r2 = history.record("#0B66E4", timestamp: 40)
        #expect(p1 && p2 && r1 && r2)

        // Concept search: "chuyển khoản" finds VCB account even though neither word appears literally!
        #expect(history.search("chuyển khoản").map(\.text).contains("VCB 0071001234567 NGUYEN VAN A"))
        // Concept search: "địa chỉ giao hàng" finds the office address!
        #expect(history.search("địa chỉ giao hàng").map(\.text).contains("Tầng 12, Toà nhà Bitexco, Quận 1, TP.HCM"))
        // Concept search: "mã xác nhận" finds the 6-digit OTP!
        #expect(history.search("mã xác nhận").map(\.text).contains("482910"))
        // Concept search: "mã màu" finds the hex swatch!
        #expect(history.search("mã màu").map(\.text).contains("#0B66E4"))
    }
}
