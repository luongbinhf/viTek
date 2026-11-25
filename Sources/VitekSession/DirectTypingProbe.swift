/// A read-only capability probe before a host starts replacing ordinary document text.
/// All offsets and lengths use UTF-16, like the macOS text-input protocol.
public struct DirectTypingProbe: Sendable, Equatable {
    public let location: Int
    public let length: Int

    public init?(caret: Int) {
        guard caret >= 0, caret < Int.max else { return nil }
        length = min(caret, 1)
        location = caret - length
    }

    /// The host supplies exactly the requested substring, or nil if unavailable.
    public func accepts(_ text: String?) -> Bool {
        guard let text else { return false }
        return text.utf16.count == length
    }
}
