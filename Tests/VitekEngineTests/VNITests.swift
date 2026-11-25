import Testing
@testable import VitekEngine

@Suite struct VNITests {
    @Test(arguments: [
        ("a1", "á"), ("a2", "à"), ("a3", "ả"), ("a4", "ã"), ("a5", "ạ"), ("a6n", "ân"), ("a8n", "ăn"),
        ("o7", "ơ"), ("u7", "ư"), ("d9", "đ"), ("vie65t", "việt"), ("Vie65t", "Việt"),
        ("d9uo7ng2", "đường"), ("nguo7i2", "người"), ("tie6ng1", "tiếng"), ("quy1", "quý"),
        ("hoa2", "hoà"), ("khuyu3", "khuỷu"), ("giu7a4", "giữa"), ("mu7a", "mưa"),
        ("quau5", "quạu"),
    ] as [(String, String)])
    func words(_ keys: String, _ expected: String) {
        #expect(typed(keys, vni) == expected)
    }

    @Test(arguments: [("a6", "â"), ("a8", "ă"), ("o6", "ô"), ("e6", "ê")] as [(String, String)])
    func vowelMarks(_ keys: String, _ expected: String) {
        #expect(composing(keys, vni) == expected)
    }

    @Test(arguments: [("a11", "a1"), ("a66", "a6"), ("d99", "d9"), ("o77", "o7")] as [(String, String)])
    func repeatingADigitTakesItBack(_ keys: String, _ expected: String) {
        #expect(typed(keys, vni) == expected)
    }

    @Test(arguments: ["var1", "win10", "utf8", "abc9", "x2", "2024", "h264"])
    func digitsThatMarkNothingStayDigits(_ keys: String) {
        #expect(typed(keys, vni) == keys)
    }

    @Test func lettersAreNotModifiersInVNI() {
        #expect(typed("as", vni) == "as")
        #expect(typed("dd", vni) == "dd")
    }
}
