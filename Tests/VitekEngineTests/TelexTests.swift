import Testing
@testable import VitekEngine

/// Telex cases written for viTek from the rules in docs/ENGINE.md, one behaviour per group.
@Suite struct TelexTests {
    @Test(arguments: [
        ("as", "á"), ("af", "à"), ("ar", "ả"), ("ax", "ã"), ("aj", "ạ"),
        ("aan", "ân"), ("awn", "ăn"), ("ee", "ê"), ("oo", "ô"), ("ow", "ơ"), ("uw", "ư"), ("dd", "đ"),
        ("vieetj", "việt"), ("nam", "nam"), ("tieengs", "tiếng"), ("nguowif", "người"),
        ("dduowngf", "đường"), ("dduwowngf", "đường"), ("dduowcj", "được"), ("tuooir", "tuổi"),
        ("khuyur", "khuỷu"), ("quys", "quý"), ("quaf", "quà"), ("quoocs", "quốc"), ("quyeets", "quyết"),
        ("quauj", "quạu"), ("quaju", "quạu"),
        ("gif", "gì"), ("giaf", "già"), ("giuwax", "giữa"), ("gieets", "giết"), ("nghieengx", "nghiễng"),
        ("yeeu", "yêu"), ("yeeus", "yếu"), ("khuyeen", "khuyên"), ("uyeen", "uyên"), ("hoaif", "hoài"),
        ("muwaf", "mừa"), ("muwa", "mưa"), ("cuwus", "cứu"), ("ruwowuj", "rượu"), ("muowif", "mười"),
        ("hoawcj", "hoặc"), ("khuaast", "khuất"), ("thuowr", "thuở"), ("huow", "huơ"),
        ("xoong", "xông"), ("xooong", "xoong"), ("nhuwngx", "những"), ("ddi", "đi"), ("ddc", "đc"),
    ] as [(String, String)])
    func words(_ keys: String, _ expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test(arguments: [
        ("việt", ["vieetj", "vietje", "viejet", "vieejt"]),
        ("tiếng", ["tieengs", "tiengse", "tiesneg"]),
        ("đường", ["dduowngf", "duowngfd", "dduowfng"]),
    ] as [(String, [String])])
    func marksInAnyOrder(_ word: String, _ spellings: [String]) {
        for keys in spellings {
            #expect(typed(keys) == word, "\(keys)")
        }
    }

    @Test(arguments: [
        ("hoaf", "hoà", "hòa"), ("khoer", "khoẻ", "khỏe"), ("thuys", "thuý", "thúy"),
        ("hoanf", "hoàn", "hoàn"), ("quys", "quý", "quý"),
    ] as [(String, String, String)])
    func toneStyle(_ keys: String, _ modern: String, _ old: String) {
        #expect(typed(keys) == modern)
        #expect(typed(keys, traditional) == old)
    }

    @Test(arguments: [
        ("ass", "as"), ("aaa", "aa"), ("aww", "aw"), ("oww", "ow"), ("ddd", "dd"), ("ww", "w"),
        ("tww", "tw"), ("tesst", "test"), ("uoww", "uow"), ("ddass", "đas"),
    ] as [(String, String)])
    func repeatingAModifierTakesItBack(_ keys: String, _ expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test(arguments: [
        ("asf", "à"), ("asz", "a"), ("vieetjz", "viêt"), ("z", "z"), ("az", "az"),
    ] as [(String, String)])
    func changingAndClearingTones(_ keys: String, _ expected: String) {
        #expect(composing(keys) == expected)
    }

    @Test(arguments: [
        ("w", "ư"), ("tw", "tư"), ("nhw", "như"), ("nhwngx", "những"), ("Tw", "Tư"), ("TW", "TƯ"),
    ] as [(String, String)])
    func standaloneW(_ keys: String, _ expected: String) {
        #expect(typed(keys) == expected)
        #expect(typed(keys, EngineOptions(standaloneW: false)) == keys)
    }

    @Test(arguments: [
        ("VIEETJ", "VIỆT"), ("Vieetj", "Việt"), ("DDUOWNGF", "ĐƯỜNG"), ("Ddi", "Đi"), ("NGUOWIF", "NGƯỜI"),
        ("QUOOCS", "QUỐC"), ("vieEtJ", "việt"),
    ] as [(String, String)])
    func letterCaseFollowsTheLetterKeys(_ keys: String, _ expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test(arguments: [("[", "ơ"), ("]", "ư"), ("t]", "tư"), ("m[i", "mơi"), ("{", "Ơ")] as [(String, String)])
    func bracketVowels(_ keys: String, _ expected: String) {
        #expect(typed(keys, EngineOptions(bracketVowels: true)) == expected)
        #expect(typed(keys) == keys)
    }

    @Test(arguments: [
        ("tuoongw", "tương"), ("buoonfw", "bườn"), ("muooiwf", "mười"),
        ("tuowngo", "tuông"), ("muowifo", "muồi"), ("duowcjo", "duộc"),
        ("taanw", "tăn"), ("tawna", "tân"),
    ] as [(String, String)])
    func switchesSmoothlyBetweenCompoundVowelMarks(_ keys: String, _ expected: String) {
        #expect(typed(keys) == expected, "\(keys)")
    }
}
