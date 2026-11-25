import Testing
@testable import VitekEngine

@Suite struct QuickTelexTests {
    @Test(arguments: [
        ("viw", "viê"), ("viwtj", "việt"), ("viwts", "viết"),
        ("viwst", "viết"), ("viswt", "viết"), ("vietwj", "việt"),
        ("VIWTJ", "VIỆT"), ("Viwts", "Viết"), ("viWts", "viết"),
        ("biwn", "biên"), ("tiwngs", "tiếng"),
        ("yw", "yê"), ("ywu", "yêu"), ("ywus", "yếu"), ("ywn", "yên"),
        ("quywts", "quyết"), ("chuywnj", "chuyện"), ("nguywnx", "nguyễn"), ("tuywts", "tuyết"),
        ("yww", "yw"), ("chuyww", "chuyw"),
        ("viww", "viw"), ("vieww", "view"), ("viwtss", "viêts"),
    ] as [(String, String)])
    func composingQuickW(_ keys: String, _ expected: String) {
        #expect(composing(keys) == expected, "\(keys)")
    }

    @Test(arguments: [
        ("viwtj", "việt"), ("viwts", "viết"), ("vietwj", "việt"),
        ("tiwngs", "tiếng"), ("view", "view"), ("swift", "swift"),
        ("switch", "switch"), ("window", "window"), ("news", "news"),
        ("awn", "ăn"), ("ow", "ơ"), ("uw", "ư"), ("uowng", "ương"),
    ] as [(String, String)])
    func commitAndExistingRules(_ keys: String, _ expected: String) {
        #expect(typed(keys) == expected, "\(keys)")
    }

    @Test func canDisableShortcut() {
        #expect(composing("viw", EngineOptions(quickTelexW: false)) == "viw")
        #expect(typed("vieetj", EngineOptions(quickTelexW: false)) == "việt")
        #expect(typed("vie65t", EngineOptions(inputMethod: .vni)) == "việt")
    }

    @Test func backspaceRemovesDisplayedLetter() {
        var composer = Composer(options: .init())
        for key in "viw" { _ = composer.type(key) }
        #expect(composer.display == "viê")
        let deleted = composer.deleteBackward()
        #expect(deleted)
        #expect(composer.display == "vi")
        for key in "wtj" { _ = composer.type(key) }
        #expect(composer.display == "việt")
    }

    @Test(arguments: [
        ("cca", "cha"), ("gga", "gia"), ("ggf", "gì"), ("kka", "kha"),
        ("nna", "nga"), ("nnhe", "nghe"), ("ppa", "pha"), ("qqa", "qua"),
        ("qqas", "quá"), ("tta", "tha"), ("ttuwowngf", "thường"),
        ("Cca", "Cha"), ("CCA", "CHA"),
        ("ccc", "cc"), ("ggg", "gg"), ("ttt", "tt"),
    ] as [(String, String)])
    func quickStartConsonants(_ keys: String, _ expected: String) {
        let options = EngineOptions(quickStartConsonants: true)
        #expect(typed(keys, options) == expected, "\(keys)")
    }

    @Test(arguments: [
        ("ag", "ang"), ("ah", "anh"), ("aks", "ách"), ("akj", "ạch"),
        ("tog", "tong"), ("togo", "tông"), ("dduogwf", "đường"),
        ("tiwgs", "tiếng"), ("ih", "inh"), ("ikj", "ịch"),
        ("ehe", "ênh"), ("ekes", "ếch"), ("ak", "ak"),
        ("oh", "oh"), ("book", "book"), ("big", "big"), ("egg", "egg"),
    ] as [(String, String)])
    func quickEndConsonants(_ keys: String, _ expected: String) {
        let options = EngineOptions(quickEndConsonants: true)
        #expect(typed(keys, options) == expected, "\(keys)")
    }

    @Test func combinedQuickConsonants() {
        let options = EngineOptions(quickStartConsonants: true, quickEndConsonants: true)
        #expect(typed("ttuowgf", options) == "thường")
        #expect(typed("ttuwowgf", options) == "thường")
        #expect(typed("ccugs", options) == "chúng")
        #expect(typed("kkoog", options) == "không")
        #expect(typed("nnhihs", options) == "nghính")
    }
}
