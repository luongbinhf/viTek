import Testing
import Foundation
import VitekSession

@Suite struct DirectEditorTests {
    @Test func composingReplacesWhatItLastPutThere() {
        var editor = DirectEditor()
        let first = editor.edit(for: .mark("v"), caret: 10)
        let second = editor.edit(for: .mark("vi"), caret: 11)
        let third = editor.edit(for: .mark("việt"), caret: 12)
        #expect(first == DirectEditor.Edit(location: 10, length: 0, text: "v"))
        #expect(second == DirectEditor.Edit(location: 10, length: 1, text: "vi"))
        #expect(third == DirectEditor.Edit(location: 10, length: 2, text: "việt"))
        #expect(editor.expectedCaret == 14)
    }

    @Test func committingTheShownTextChangesNothing() {
        var editor = DirectEditor()
        _ = editor.edit(for: .mark("việt"), caret: 0)
        let commit = editor.edit(for: .insert("việt"), caret: 4)
        #expect(commit == nil)
        #expect(!editor.isActive)
    }

    @Test func committingOtherTextReplacesTheComposition() {
        var editor = DirectEditor()
        _ = editor.edit(for: .mark("sẻv"), caret: 3)
        let restore = editor.edit(for: .insert("serv"), caret: 6)
        #expect(restore == DirectEditor.Edit(location: 3, length: 3, text: "serv"))
        let plain = editor.edit(for: .insert("không"), caret: 9)
        #expect(plain == DirectEditor.Edit(location: 9, length: 0, text: "không"))
    }

    @Test func deletingTheLastLetterEndsTheComposition() {
        var editor = DirectEditor()
        _ = editor.edit(for: .mark("á"), caret: 5)
        let cleared = editor.edit(for: .mark(""), caret: 6)
        #expect(cleared == DirectEditor.Edit(location: 5, length: 1, text: ""))
        #expect(!editor.isActive)
        let nothing = editor.edit(for: .mark(""), caret: 5)
        #expect(nothing == nil)
    }

    @Test func utf16LengthsCountComposedCharactersOnce() {
        var editor = DirectEditor()
        _ = editor.edit(for: .mark("người"), caret: 0)
        #expect(editor.expectedCaret == 5)
    }

    @Test func intactOnlyWhileTheCaretAndTextAreWhereTheyWereLeft() {
        var editor = DirectEditor()
        _ = editor.edit(for: .mark("việt"), caret: 4)
        #expect(editor.isIntact(caret: 8, before: "tôi việt"))
        #expect(!editor.isIntact(caret: 3, before: "tôi"))
        #expect(!editor.isIntact(caret: 8, before: "tôi Việt"))
        #expect(DirectEditor().isIntact(caret: 0, before: ""))
    }

    @Test func adoptedWordsAreReplacedInPlace() {
        var editor = DirectEditor()
        editor.adopt("viêt", endingAt: 12)
        let edit = editor.edit(for: .mark("việt"), caret: 12)
        #expect(edit == DirectEditor.Edit(location: 8, length: 4, text: "việt"))
    }

    @Test(arguments: [-1, 0, 3, Int.max])
    func invalidAdoptionDropsAnyPreviousRange(caret: Int) {
        var editor = DirectEditor()
        editor.adopt("cũ", endingAt: 2)
        editor.adopt("việt", endingAt: caret)
        #expect(!editor.isActive)
        #expect(editor.shown.isEmpty)
    }

    @Test(arguments: [-1, Int.max, Int.max - 1])
    func invalidInsertionRangeProducesNoEdit(caret: Int) {
        var editor = DirectEditor()
        #expect(editor.edit(for: .mark("việt"), caret: caret) == nil)
        #expect(!editor.isActive)
        #expect(editor.edit(for: .insert("việt"), caret: caret) == nil)
    }

    @Test func expansionCannotOverflowAnAdoptedRange() {
        var editor = DirectEditor()
        editor.adopt("a", endingAt: Int.max - 1)
        #expect(editor.isActive)
        #expect(editor.edit(for: .mark("abc"), caret: Int.max - 1) == nil)
        #expect(!editor.isActive)
    }

    @Test func emptyAdoptionDoesNotStartAComposition() {
        var editor = DirectEditor()
        editor.adopt("", endingAt: 0)
        #expect(!editor.isActive)
    }

    @Test func composingAndDeletingAfterEmojiKeepsTheSurroundingDocument() throws {
        let prefix = "👩🏽‍💻 Xin "
        let suffix = " — cuối"
        var document = prefix + suffix
        var caret = prefix.utf16.count
        var session = InputSession()
        var editor = DirectEditor()
        let events = "vieetj".map(HostEvent.character) + [.backspace, .character("t"), .boundary]
        for event in events {
            #expect(editor.isIntact(caret: caret, before: String(decoding: document.utf16.prefix(caret), as: UTF16.self)))
            for command in session.handle(event).commands {
                guard let edit = editor.edit(for: command, caret: caret) else { continue }
                let range = try #require(Range(NSRange(location: edit.location, length: edit.length), in: document))
                document.replaceSubrange(range, with: edit.text)
                caret = edit.location + edit.text.utf16.count
            }
        }
        #expect(document == prefix + "việt" + suffix)
        #expect(!editor.isActive)
        #expect(session.flush().isEmpty)
    }

    @Test func discardingAfterCaretMovementCannotCommitIntoTheNewField() {
        var session = InputSession()
        var editor = DirectEditor()
        let prefix = "🙂 "
        var caret = prefix.utf16.count
        for key in "vieetj" {
            for command in session.handle(.character(key)).commands {
                if let edit = editor.edit(for: command, caret: caret) {
                    caret = edit.location + edit.text.utf16.count
                }
            }
        }
        #expect(!editor.isIntact(caret: 0, before: ""))
        session.discard()
        editor.reset()
        #expect(session.flush().isEmpty)
        #expect(editor.edit(for: session.handle(.character("x")).commands[0], caret: 0)
                == DirectEditor.Edit(location: 0, length: 0, text: "x"))
    }
}

@Suite struct SuggestionsTests {
    @Test func keepsWordsThatContinueThePrefix() {
        #expect(Suggestions.prepare(["Ngư ", "Người ", "ngủ", "Nguyen", "ngư"], prefix: "ngư") == ["Người"])
        #expect(Suggestions.prepare(["người", "ngủ", "Nguyen", "nhà"], prefix: "ngu") == ["người", "ngủ", "Nguyen"])
        #expect(Suggestions.prepare(["đường", "dương"], prefix: "đ") == ["đường"])
    }

    @Test func nextWordsKeepTheirSpellingAndDropRepeats() {
        #expect(Suggestions.prepare(["tìm ", "học", "Học", "two words", ""], prefix: "") == ["tìm", "học"])
    }

    @Test func suggestionsNeverInsertAnEmbeddedLineBreakOrTab() {
        let candidates = [" hai\ntừ ", "hai\ttừ", "hai\u{00a0}từ", "\nngười\t"]
        #expect(Suggestions.prepare(candidates, prefix: "") == ["người"])
    }

    @Test func nonPositiveLimitReturnsNoSuggestions() {
        #expect(Suggestions.prepare(["người"], prefix: "ng", limit: 0).isEmpty)
        #expect(Suggestions.prepare(["người"], prefix: "ng", limit: -1).isEmpty)
    }

    @Test func aCapitalisedPrefixCapitalisesAndTheLimitHolds() {
        #expect(Suggestions.prepare(["người", "ngủ", "ngưng"], prefix: "Ng", limit: 2) == ["Người", "Ngủ"])
    }
}
