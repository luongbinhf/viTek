#if canImport(AppKit)
import AppKit
import Testing
import VitekSession

/// Uses the real Cocoa text system for marked selection/replacement. Only document read access
/// is varied; this is not an end-to-end test of IMK delivery from another process.
@MainActor final class NativeTextClient {
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
    var readable = true
    var explicitReplacements = 0
    var commits = 0

    func selectedRange() -> NSRange { view.selectedRange() }
    func attributedSubstring(from range: NSRange) -> NSAttributedString? {
        guard readable else { return nil }
        let text = view.string as NSString
        guard range.location >= 0, range.location <= text.length,
              range.length <= text.length - range.location else { return nil }
        return NSAttributedString(string: text.substring(with: range))
    }
    func insertText(_ text: String, replacementRange: NSRange) {
        if replacementRange.location != NSNotFound { explicitReplacements += 1 }
        commits += 1
        view.insertText(text, replacementRange: replacementRange)
    }
    func setMarkedText(_ text: NSAttributedString, selectionRange: NSRange, replacementRange: NSRange) {
        if replacementRange.location != NSNotFound { explicitReplacements += 1 }
        view.setMarkedText(text, selectedRange: selectionRange, replacementRange: replacementRange)
    }
}

extension NativeTextClient: DocumentClient {
    var documentID: ObjectIdentifier { ObjectIdentifier(self) }
    var selection: DocumentRange? {
        let range = view.selectedRange()
        return DocumentRange(range.location, range.length)
    }
    var markedRange: DocumentRange? {
        let range = view.markedRange()
        return range.length > 0 ? DocumentRange(range.location, range.length) : nil
    }
    func text(in range: DocumentRange) -> String? {
        attributedSubstring(from: NSRange(location: range.location, length: range.length))?.string
    }
    func insert(_ text: String, replacing range: DocumentRange?) {
        insertText(text, replacementRange: range.map { NSRange(location: $0.location, length: $0.length) }
                   ?? NSRange(location: NSNotFound, length: NSNotFound))
    }
    func mark(_ text: String, replacing range: DocumentRange?) {
        setMarkedText(NSAttributedString(string: text), selectionRange: NSRange(location: text.utf16.count, length: 0),
                      replacementRange: range.map { NSRange(location: $0.location, length: $0.length) }
                      ?? NSRange(location: NSNotFound, length: NSNotFound))
    }
}

@Suite @MainActor struct NativeCompositionWriterTests {
    @Test(arguments: [("vie", "etj "), ("vie", "65t ")])
    func losingReadbackMidWordPreservesWholeComposition(prefix: String, suffix: String) {
        let host = NativeHostHarness()
        host.type(prefix)
        host.client.readable = false
        host.type(suffix)
        #expect(host.client.view.string == "việt ")
        #expect(!host.client.view.hasMarkedText())
        #expect(host.client.explicitReplacements == 0)
    }

    @Test func sameLengthToneUpdateAndBackspaceRemainInOwnedComposition() {
        let host = NativeHostHarness()
        host.type("vieet")
        host.client.readable = false
        host.type("j")
        #expect(host.client.view.string == "việt")
        #expect(host.client.view.hasMarkedText())
        host.type("⌫")
        #expect(host.client.view.string == "việ")
        host.type("t ")
        #expect(host.client.view.string == "việt ")
    }

    @Test func selectedTextIsReplacedOnceAndFlushIsIdempotent() {
        let host = NativeHostHarness()
        host.client.view.string = "Trước OLD sau"
        host.client.view.setSelectedRange(NSRange(location: 6, length: 3))
        host.type("vie")
        host.client.readable = false
        host.type("etj")
        host.flush()
        let commits = host.client.commits
        host.flush()
        #expect(host.client.view.string == "Trước việt sau")
        #expect(!host.client.view.hasMarkedText())
        #expect(host.client.commits == commits)
        #expect(host.client.explicitReplacements == 0)
    }
}
#endif
