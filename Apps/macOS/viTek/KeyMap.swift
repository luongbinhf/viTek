import AppKit
import VitekSession

/// Turns an NSEvent into the session's vocabulary. The layout has already produced the
/// characters; only keys that edit or move need their key codes.
enum KeyMap {
    /// Modifier-down is a separate event, before the host classifies a shortcut key.
    /// Shift and Option must leave composition intact (uppercase and suggestion keys).
    static func endsCompositionBeforeShortcut(for event: NSEvent, commandIsCurrentlyDown: Bool) -> Bool {
        commandIsCurrentlyDown && event.type == .flagsChanged && event.modifierFlags.contains(.command)
            && (event.keyCode == 54 || event.keyCode == 55)
    }

    /// Carbon virtual key codes (kVK_*) of the keys that never become text.
    private static let backspace: UInt16 = 0x33
    private static let boundaries: Set<UInt16> = [
        0x24, 0x4C,             // Return, keypad Enter
        0x30, 0x35,             // Tab, Escape
        0x75,                   // Forward Delete
        0x73, 0x77, 0x74, 0x79, // Home, End, Page Up, Page Down
        0x7B, 0x7C, 0x7D, 0x7E, // arrows
        // Function keys can reset/focus fields. Their private-use NSEvent characters
        // are not text and must invalidate cached anchors just like other shortcuts.
        0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D, // F1–F10
        0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A, // F11–F20
    ]

    static func hostEvent(for event: NSEvent) -> HostEvent {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !modifiers.isDisjoint(with: [.command, .control, .option]) { return .boundary }
        if event.keyCode == backspace { return .backspace }
        if boundaries.contains(event.keyCode) { return .boundary }
        guard let characters = event.characters, characters.count == 1, let key = characters.first else {
            return .boundary
        }
        return .character(key)
    }
}
