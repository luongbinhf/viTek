import Testing
import VitekSession

@Suite struct DirectTypingProbeTests {
    @Test func unreadableEmptyFieldMustUseMarkedTextFromFirstLetter() throws {
        let probe = try #require(DirectTypingProbe(caret: 0))
        #expect(probe.location == 0)
        #expect(probe.length == 0)
        // Without this rejection the first letter is inserted directly, then stranded when
        // the next key cannot read it back and has to start a fresh marked composition.
        #expect(!probe.accepts(nil))
        #expect(probe.accepts(""))
        #expect(!probe.accepts("unexpected"))
    }

    @Test func truncatedOrExpandedReadbackCannotAuthorizeReplacement() throws {
        let probe = try #require(DirectTypingProbe(caret: 8))
        #expect(probe.location == 7)
        #expect(probe.length == 1)
        #expect(!probe.accepts(nil))
        #expect(!probe.accepts(""))
        #expect(!probe.accepts("ab"))
        #expect(!probe.accepts("😀"))
        #expect(!probe.accepts("a\u{0301}"))
        #expect(probe.accepts("ệ"))
    }

    @Test func invalidOrUnknownCaretCannotAuthorizeReplacement() {
        #expect(DirectTypingProbe(caret: -1) == nil)
        #expect(DirectTypingProbe(caret: Int.max) == nil)
    }
}
