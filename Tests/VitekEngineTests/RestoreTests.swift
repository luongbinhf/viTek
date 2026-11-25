import Testing
@testable import VitekEngine

/// Words that are not Vietnamese keep the keys the user typed.
@Suite struct RestoreTests {
    @Test(arguments: [
        "server", "express", "class", "user", "data", "banana", "camera", "hello", "look", "free",
        "were", "with", "window", "word", "what", "add", "odd", "sudden", "facebook", "string",
        "lol", "ok", "hihi", "jquery", "dead",
    ])
    func englishWordsComeBack(_ word: String) {
        #expect(typed(word) == word)
    }

    @Test func restoredWordsShowTheirKeysWhileTyping() {
        #expect(composing("se") == "se")
        #expect(composing("ser") == "sẻ")
        #expect(composing("serv") == "serv")
        #expect(composing("serve") == "serve")
    }

    @Test func aWordWithoutItsToneIsNotFinished() {
        #expect(composing("vieet") == "viêt")
        #expect(typed("vieet") == "vieet")
    }

    /// â and ă only exist before a final consonant, so on their own they go back to their keys.
    @Test func lonelyBreveAndCircumflexAreNotWords() {
        #expect(composing("aa") == "â")
        #expect(typed("aa") == "aa")
        #expect(composing("aw") == "ă")
        #expect(typed("aw") == "aw")
    }

    @Test func turningRestoreOffKeepsTheVietnameseReading() {
        let keep = EngineOptions(restoreInvalidWords: false)
        #expect(typed("user", keep) == "ủe")
        #expect(typed("vieet", keep) == "viêt")
    }

    @Test func turningSpellCheckOffMarksWheneverThereIsATarget() {
        let free = EngineOptions(spellCheck: false)
        #expect(typed("cls", free) == "cls")
        #expect(typed("ase", free) == "áe")
        #expect(typed("express", free) != "express")
    }

    /// Telex readings that are real Vietnamese and not in the English word list stay Vietnamese:
    /// a vowel mark typed with the vowel (`seem`, `wow`) is how Vietnamese is typed.
    @Test(arguments: [("seem", "sêm"), ("wow", "uơ"), ("teen", "tên")] as [(String, String)])
    func knownAmbiguities(_ keys: String, _ reading: String) {
        #expect(typed(keys) == reading)
    }
}
