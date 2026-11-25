import Testing
@testable import VitekEngine

@Suite struct QuickTelexConflictTests {
    @Test(arguments: [false, true])
    func englishWAndSRemainEditable(_ automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic)
        for word in ["view", "views", "viewer", "viewing", "viewmodel", "VIEW", "Views", "review", "reviews", "preview", "interview", "swift", "switch", "swiss", "news", "windows", "password", "assess", "class", "business"] {
            #expect(composing(word, options) == word, "live \(word)")
            #expect(typed(word, options) == word, "commit \(word)")
        }
        for (script, expected) in [("view⌫", "vie"), ("views⌫", "view"), ("view⌫w", "view"), ("views⌫s", "views"), ("viewss", "viewss"), ("vieww", "view")] {
            #expect(composing(script, options) == expected, "\(script)")
        }
    }

    @Test func englishProtectionCanBeDisabled() {
        let options = EngineOptions(keepEnglishWords: false)
        #expect(composing("view", options) == "viê")
        #expect(composing("viewtj", options) == "việt")
        #expect(composing("view⌫⌫wtj") == "việt")
        #expect(composing("vieww") == "view")
    }

    @Test(arguments: [false, true])
    func editsAndRepeatedModifiers(_ automatic: Bool) {
        let options = EngineOptions(automaticallyDetectsMethod: automatic)
        for (script, expected) in [("viws⌫", "vi"), ("viws⌫wtj", "việt"), ("viwtj⌫c", "việc"), ("viwtj⌫⌫wtj", "việt"), ("viwtss", "viêts"), ("viwww", "viww"), ("viww⌫⌫⌫viwtj", "việt")] {
            #expect(composing(script, options) == expected, "\(script)")
        }
    }
}
