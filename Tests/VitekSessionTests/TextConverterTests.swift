import Testing
import VitekSession

@Suite struct TextConverterTests {
    @Test func normalizesDecomposedNFDAndWindows1258ToSingleScalarNFC() {
        // Canonical NFD puts combining dot below (U+0323) before circumflex (U+0302).
        let nfd = "Vie\u{0323}\u{0302}t Nam — o\u{031B}\u{0300} u\u{031B}\u{0301} a\u{0306}\u{0309}"
        let expected = "Việt Nam — ờ ứ ẳ"
        let normalized = TextConverter.normalizeNFC(nfd)
        #expect(normalized == expected)
        #expect(Array(normalized.unicodeScalars) == Array(expected.unicodeScalars))

        // Windows-1258 style: precomposed vowel + combining tone mark.
        let cp1258 = "Ti\u{00EA}\u{0301}ng Vi\u{00EA}\u{0323}t \u{01B0}\u{0303}"
        let expected1258 = "Tiếng Việt ữ"
        let normalized1258 = TextConverter.normalizeNFC(cp1258)
        #expect(Array(normalized1258.unicodeScalars) == Array(expected1258.unicodeScalars))
    }

    @Test func stripsVietnameseAccentsPreservingCaseAndPunctuation() {
        let input = "Độc lập - Tự do - Hạnh phúc! Tiếng Việt 2026 🚀"
        #expect(TextConverter.stripVietnameseAccents(input) == "Doc lap - Tu do - Hanh phuc! Tieng Viet 2026 🚀")

        let decomposed = "Đo\u{0323}\u{0302}ng Nai & ĐA\u{0300} NA\u{0306}\u{0303}NG"
        #expect(TextConverter.stripVietnameseAccents(decomposed) == "Dong Nai & DA NANG")
    }

    @Test func convertsVNIWindowsToUnicodeNFC() {
        let vni = "Coäng hoøa Xaõ hoäi Chuû nghóa Vieät Nam - Ñoäc laäp - Töï do - Haïnh phuùc"
        let expected = "Cộng hòa Xã hội Chủ nghĩa Việt Nam - Độc lập - Tự do - Hạnh phúc"
        let converted = TextConverter.convertVNIWindowsToUnicode(vni)
        #expect(converted == expected)
        #expect(Array(converted.unicodeScalars) == Array(expected.unicodeScalars))

        let upper = "ÑAØ NAÜNG — VIEÄT NAM — ÑOÀNG NAI — ÖÔÙC MÔ"
        #expect(TextConverter.convertVNIWindowsToUnicode(upper) == "ĐÀ NẴNG — VIỆT NAM — ĐỒNG NAI — ƯỚC MƠ")
    }

    @Test func convertsTCVN3ToUnicodeNFC() {
        // "Cộng hoà xã hội chủ nghĩa Việt Nam - Độc lập - Tự do - Hạnh phúc" in TCVN3 (.VnTime)
        let tcvn = "C\u{00E9}ng ho\u{00B5} x\u{00B7} h\u{00E9}i ch\u{00F1} ngh\u{00DC}a Vi\u{00D6}t Nam - \u{00A7}\u{00E9}c l\u{00CB}p - T\u{00F9} do - H\u{00B9}nh ph\u{00F3}c"
        let expected = "Cộng hoà xã hội chủ nghĩa Việt Nam - Độc lập - Tự do - Hạnh phúc"
        let converted = TextConverter.convertTCVN3ToUnicode(tcvn)
        #expect(converted == expected)
        #expect(Array(converted.unicodeScalars) == Array(expected.unicodeScalars))
    }

    @Test func searchesEmojisByVietnameseAndUnaccentedKeywords() {
        #expect(EmojiSuggestions.search("tim").first == "❤️")
        #expect(EmojiSuggestions.search("trà sữa").contains("🧋"))
        #expect(EmojiSuggestions.search("tra sua").contains("🧋"))
        #expect(EmojiSuggestions.search("việt").contains("🇻🇳"))
        #expect(EmojiSuggestions.search("cuoi").contains("😂"))
        #expect(EmojiSuggestions.search("   ").isEmpty)
    }

    @Test func autoDetectsLegacyEncodingsAndConvertsCaseProperly() {
        let vni = "Coäng hoøa Xaõ hoäi Chuû nghóa Vieät Nam - Ñoäc laäp"
        #expect(TextConverter.autoConvertToUnicode(vni) == "Cộng hòa Xã hội Chủ nghĩa Việt Nam - Độc lập")

        let tcvn = "C\u{00E9}ng ho\u{00B5} x\u{00B7} h\u{00E9}i ch\u{00F1} ngh\u{00DC}a Vi\u{00D6}t Nam"
        #expect(TextConverter.autoConvertToUnicode(tcvn) == "Cộng hoà xã hội chủ nghĩa Việt Nam")

        let nfd = "Tiê\u{0301}ng Viê\u{0323}t"
        let autoNFD = TextConverter.autoConvertToUnicode(nfd)
        #expect(Array(autoNFD.unicodeScalars) == Array("Tiếng Việt".unicodeScalars))

        #expect(TextConverter.uppercaseVietnamese("đồng bằng sông cửu long") == "ĐỒNG BẰNG SÔNG CỬU LONG")
        #expect(TextConverter.lowercaseVietnamese("ĐỒNG BẰNG SÔNG CỬU LONG") == "đồng bằng sông cửu long")
        #expect(TextConverter.titleCaseVietnamese("NGUYỄN VĂN ĐỒNG") == "Nguyễn Văn Đồng")
    }
}
