/// Shows the word being composed as ordinary text in the document instead of marked text, for hosts
/// that can replace a range of their client's text. No underline, no highlight: each command becomes
/// "replace what I last put there with this".
///
/// Positions and lengths are in UTF-16 code units, the unit of `NSRange`.
public struct DirectEditor: Sendable, Equatable {
    /// One change to make in the document.
    public struct Edit: Sendable, Equatable {
        /// Where the replaced text starts.
        public var location: Int
        /// How much of it to replace; zero inserts.
        public var length: Int
        public var text: String

        public init(location: Int, length: Int, text: String) {
            self.location = location
            self.length = length
            self.text = text
        }
    }

    /// Where the composition starts in the document, while there is one on screen.
    public private(set) var start: Int?
    /// The composition as it is now in the document.
    public private(set) var shown = ""

    public init() {}

    public var isActive: Bool { start != nil }

    /// Where the caret must be for the document to still hold what the editor put there.
    public var expectedCaret: Int? { start.map { $0 + shown.utf16.count } }

    /// Takes over text that is already in the document (a resumed word) as the composition.
    /// Invalid host offsets drop the previous composition rather than create an unsafe range.
    public mutating func adopt(_ text: String, endingAt caret: Int) {
        let length = text.utf16.count
        guard !text.isEmpty, caret >= length, caret < Int.max else {
            reset()
            return
        }
        start = caret - length
        shown = text
    }

    /// True when the document still holds the composition right before the caret. `before` is the
    /// document text that ends at `caret` and is at least as long as the composition.
    public func isIntact(caret: Int, before: String) -> Bool {
        guard let expectedCaret else { return true }
        return caret == expectedCaret && before.hasSuffix(shown)
    }

    /// Turns a session command into a document edit. `caret` is where the caret is now; it starts a
    /// composition when there is none.
    public mutating func edit(for command: HostCommand, caret: Int) -> Edit? {
        // Int.max is the Foundation NSNotFound sentinel. Keep this platform-independent and
        // reject both invalid host positions and ranges whose end would overflow or hit it.
        let text: String
        switch command {
        case .mark(let value), .insert(let value): text = value
        }
        let location = start ?? caret
        guard caret >= 0, caret < Int.max, location >= 0,
              text.utf16.count < Int.max - location else {
            reset()
            return nil
        }
        switch command {
        case .mark(let text):
            let location = start ?? caret
            let edit = Edit(location: location, length: shown.utf16.count, text: text)
            if text.isEmpty {
                reset()
            } else {
                start = location
                shown = text
            }
            return edit.length == 0 && edit.text.isEmpty ? nil : edit
        case .insert(let text):
            let edit = Edit(location: start ?? caret, length: shown.utf16.count, text: text)
            let unchanged = text == shown && start != nil
            reset()
            return unchanged ? nil : edit
        }
    }

    public mutating func reset() {
        start = nil
        shown = ""
    }
}
