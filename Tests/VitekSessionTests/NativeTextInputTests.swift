#if canImport(AppKit)
import AppKit
import Testing
import VitekEngine
import VitekSession

/// Exercises Cocoa's real replacement and marked-text semantics. This is an adapter integration
/// test, not an IMK controller, keyboard-event, or third-party application end-to-end test.
@Suite @MainActor struct NativeTextInputTests {
    enum Mode: CaseIterable, Sendable { case direct, marked }

    @Test(arguments: Mode.allCases)
    func automaticTypingCommitsBothMethodsAndEnglish(mode: Mode) {
        let field = NativeField(mode: mode)
        field.type("vieetj vie65t reset server ")
        field.flush()
        #expect(field.view.string == "việt việt reset server ")
        #expect(field.view.selectedRange() == NSRange(location: 23, length: 0))
        #expect(!field.view.hasMarkedText())
    }

    @Test(arguments: Mode.allCases)
    func selectionIsReplacedWithoutDeletingItsNeighbours(mode: Mode) {
        let field = NativeField(mode: mode, text: "trước OLD sau")
        field.view.setSelectedRange(NSRange(location: 6, length: 3))
        field.type("vieetj")
        #expect(field.view.string == "trước việt sau")
        #expect(field.view.hasMarkedText())
        field.flush()
        #expect(field.view.string == "trước việt sau")
        #expect(field.view.selectedRange() == NSRange(location: 10, length: 0))
        #expect(!field.view.hasMarkedText())
    }

    @Test(arguments: Mode.allCases)
    func emojiPrefixUsesUTF16OffsetsAndPreservesTheSuffix(mode: Mode) {
        let prefix = "👩🏽‍💻 Xin "
        let suffix = " — cuối"
        let field = NativeField(mode: mode, text: prefix + suffix)
        field.view.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))
        field.type("vieetj")
        field.flush()
        #expect(field.view.string == prefix + "việt" + suffix)
        #expect(field.view.selectedRange() == NSRange(location: prefix.utf16.count + 4, length: 0))
        #expect(!field.view.hasMarkedText())
    }

    @Test(arguments: Mode.allCases)
    func backspaceDeletesVisibleLettersAndCanRestart(mode: Mode) {
        let field = NativeField(mode: mode, text: "🙂 ")
        field.type("vieetj⌫")
        #expect(field.view.string == "🙂 việ")
        field.type("⌫")
        #expect(field.view.string == "🙂 vi")
        field.type("⌫⌫")
        #expect(field.view.string == "🙂 ")
        #expect(!field.view.hasMarkedText())
        field.type("vie65t ")
        field.flush()
        #expect(field.view.string == "🙂 việt ")
        #expect(!field.view.hasMarkedText())
    }

    @Test(arguments: Mode.allCases)
    func sameLengthToneChangesReachTheTextStorageImmediately(mode: Mode) {
        let field = NativeField(mode: mode)
        field.type("vieet")
        #expect(field.view.string == "viêt")
        field.type("j")
        #expect(field.view.string == "việt")
        #expect(field.view.selectedRange() == NSRange(location: 4, length: 0))
        field.type("s")
        #expect(field.view.string == "viết")
        field.flush()
        #expect(field.view.string == "viết")
        #expect(!field.view.hasMarkedText())
    }

    @Test func capabilityProbeReadsNativeTextWithoutEditingIt() throws {
        let field = NativeField(mode: .direct, text: "🙂 Việt")
        let caret = field.view.selectedRange()
        let probe = try #require(DirectTypingProbe(caret: caret.location))
        var actual = NSRange(location: NSNotFound, length: 0)
        let sample = field.view.attributedSubstring(
            forProposedRange: NSRange(location: probe.location, length: probe.length), actualRange: &actual)
        #expect(sample?.string == "t")
        #expect(actual == NSRange(location: caret.location - 1, length: 1))
        #expect(probe.accepts(sample?.string))
        #expect(field.view.string == "🙂 Việt")
        #expect(field.view.selectedRange() == caret)
    }

    /// Deliberately small host adapter: DirectEditor produces explicit replacement ranges;
    /// marked text uses Cocoa's current selection/composition. A nonempty selection starts a
    /// marked composition even in direct mode, matching the controller's selection fallback.
    @MainActor private final class NativeField {
        let view: NSTextView
        let mode: Mode
        var session = InputSession(engine: VitekEngine(options: .init(automaticallyDetectsMethod: true)))
        var editor = DirectEditor()

        init(mode: Mode, text: String = "") {
            _ = NSApplication.shared
            self.mode = mode
            view = NSTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 240))
            view.isAutomaticSpellingCorrectionEnabled = false
            view.isAutomaticTextReplacementEnabled = false
            view.isAutomaticQuoteSubstitutionEnabled = false
            view.isAutomaticDashSubstitutionEnabled = false
            view.string = text
            view.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
        }

        func type(_ script: String) {
            for key in script {
                let output = session.handle(key == "⌫" ? .backspace : .character(key))
                apply(output.commands)
                if output.passThrough {
                    if key == "⌫" {
                        view.deleteBackward(nil)
                    } else {
                        view.insertText(String(key), replacementRange: NSRange(location: NSNotFound, length: 0))
                    }
                }
            }
        }

        func flush() { apply(session.flush()) }

        private func apply(_ commands: [HostCommand]) {
            for command in commands {
                let selection = view.selectedRange()
                if mode == .direct, selection.length == 0, !view.hasMarkedText() {
                    if let edit = editor.edit(for: command, caret: selection.location) {
                        view.insertText(edit.text, replacementRange: NSRange(location: edit.location, length: edit.length))
                    }
                } else {
                    let current = NSRange(location: NSNotFound, length: 0)
                    switch command {
                    case .insert(let text):
                        view.insertText(text, replacementRange: current)
                    case .mark(let text):
                        view.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0),
                                           replacementRange: current)
                    }
                }
            }
        }
    }
}
#endif
