import Testing
import VitekSession

@Suite struct GlideDecoderTests {
    @Test func decodesContinuousVietnameseSwipePathsWithNoiseKeys() {
        // Swiping v -> u -> i -> e -> r -> t on QWERTY should rank "việt" / "viết"
        let viet = GlideDecoder.decode(sampledKeys: Array("vuiert"))
        #expect(!viet.isEmpty)
        #expect(viet.contains { $0.text == "việt" || $0.text == "viết" })

        // Swiping k -> h -> j -> o -> b -> n -> g should decode "không"
        let khong = GlideDecoder.decode(sampledKeys: Array("khjobng"))
        #expect(khong.first?.text == "không")

        // Swiping n -> g -> u -> o -> i should decode "người"
        let nguoi = GlideDecoder.decode(sampledKeys: Array("nguoi"))
        #expect(nguoi.first?.text == "người")
    }

    @Test func usesPreviousWordContextAndCapitalization() {
        // After "cảm", swiping o -> n strongly prefers "ơn"
        let on = GlideDecoder.decode(sampledKeys: Array("on"), previousWords: ["cảm"])
        #expect(on.contains { $0.text == "ơn" })

        let cap = GlideDecoder.decode(sampledKeys: Array("xcvbin"), capitalizeFirst: true)
        #expect(cap.first?.text.first?.isUppercase == true)
    }
}
