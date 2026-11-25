/// Sends a session's commands through a host's native marked-text protocol. The host owns the
/// active composition, so updating it never requires reading the document or guessing a range.
/// Kept for clients that need only the raw protocol; the macOS host uses DocumentSession to own
/// document ranges, lifecycle and committed edits. Underline styling belongs to `mark`.
public enum NativeCompositionWriter {
    public static func apply(
        _ commands: [HostCommand],
        mark: (_ text: String, _ selectionUTF16: Int) -> Void,
        insert: (_ text: String) -> Void
    ) {
        for command in commands {
            switch command {
            case .mark(let text): mark(text, text.utf16.count)
            case .insert(let text): insert(text)
            }
        }
    }
}
