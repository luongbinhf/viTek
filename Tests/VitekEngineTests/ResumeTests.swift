import Testing
@testable import VitekEngine

/// Resumes `word`, types `keys`, and returns what is committed.
private func resumed(_ word: String, _ keys: String, _ options: EngineOptions = EngineOptions()) -> String? {
    var engine = VitekEngine(options: options)
    guard engine.resume(word) else { return nil }
    for key in keys { _ = engine.type(key) }
    return engine.finish()?.text
}

@Suite struct ResumeTests {
    @Test(arguments: [
        ("viêt", "j", "việt"), ("Viêt", "j", "Việt"), ("việt", "s", "viết"), ("tieng", "es", "tiếng"),
        ("duong", "dwf", "đường"), ("hoa", "f", "hoà"), ("hoà", "z", "hoa"), ("viêt", "jj", "viêtj"),
        ("viet", "ej", "việt"),
    ] as [(String, String, String)])
    func editsTheWordBeforeTheCaret(_ word: String, _ keys: String, _ result: String) {
        #expect(resumed(word, keys) == result)
    }

    @Test(arguments: ["test", "hòa", "đc", "abc1", "a-b", "", "ss"])
    func leavesWordsThatDoNotRenderBack(_ word: String) {
        var engine = VitekEngine()
        let resumed = engine.resume(word)
        #expect(!resumed)
        #expect(!engine.isComposing)
    }

    @Test func traditionalStyleResumesItsOwnSpelling() {
        #expect(resumed("hòa", "", traditional) == "hòa")
        #expect(resumed("hòa", "s", traditional) == "hóa")
    }

    @Test func neverResumesOverAWordInProgress() {
        var engine = VitekEngine()
        _ = engine.type("a")
        let resumed = engine.resume("viet")
        #expect(!resumed)
        #expect(engine.composition == "a")
    }

    @Test func markKeysFollowTheInputMethod() {
        #expect(EngineOptions().isMarkKey("j"))
        #expect(!EngineOptions().isMarkKey("t"))
        #expect(vni.isMarkKey("5"))
        #expect(!vni.isMarkKey("j"))
    }
}

@Suite struct SpellingTests {
    @Test(arguments: [("người", "ngu"), ("người", "ngư"), ("người", "ngườ"), ("đường", "d"), ("Việt", "vie"),
                      ("Nguyen", "ngu"), ("test", "TE")] as [(String, String)])
    func continues(_ word: String, _ prefix: String) {
        #expect(Spelling.word(word, continues: prefix))
    }

    @Test(arguments: [("ngủ", "ngư"), ("người", "ngừa"), ("dương", "đ"), ("viết", "việ"), ("ab", "abc")]
          as [(String, String)])
    func doesNotContinue(_ word: String, _ prefix: String) {
        #expect(!Spelling.word(word, continues: prefix))
    }
}
