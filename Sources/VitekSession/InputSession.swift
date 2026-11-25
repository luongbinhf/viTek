import VitekEngine

/// A key event as a host sees it, after the host has resolved the keyboard layout.
public enum HostEvent: Equatable, Sendable {
    /// Text the active layout produced, with no Command or Control held.
    case character(Character)
    /// Delete one character backwards.
    case backspace
    /// A key that ends the word and must still reach the app: Return, Tab, Escape, arrows,
    /// Command and Control shortcuts, Option characters.
    case boundary
}

/// What the host must do to the text field.
public enum HostCommand: Equatable, Sendable {
    /// Insert text at the caret, replacing the marked text if any.
    case insert(String)
    /// Show this as the marked (in-progress) text. An empty string removes the marked text.
    case mark(String)
}

public struct SessionOutput: Equatable, Sendable {
    /// To apply in order before deciding about the event.
    public var commands: [HostCommand]
    /// True when the host must let the original event through to the app after `commands`.
    public var passThrough: Bool

    public init(commands: [HostCommand], passThrough: Bool) {
        self.commands = commands
        self.passThrough = passThrough
    }
}

/// The editing protocol between the engine and a host. A host maps its native key events to
/// `HostEvent`, calls `handle`, and applies the commands; all decisions about words live here and
/// in the engine, so every host behaves the same and the behaviour is testable without one.
public struct InputSession: Sendable {
    public var engine: VitekEngine
    public var shortcuts: Shortcuts
    /// When true, shortcuts continue to expand even while `isVietnamese` is false.
    public var shortcutsInEnglishMode: Bool
    /// When false the session is an English keyboard: every key reaches the app untouched
    /// (except prefix-matched shortcuts when `shortcutsInEnglishMode` is enabled).
    public private(set) var isVietnamese = true
    private var marked = ""
    /// True after a technical separator (`_`, `/`, `\`, `@`, `$`, `#`, `:`, or `.` right after a word)
    /// until whitespace or a closing boundary resets it. Keeps `snake_case`, URLs, emails, and
    /// member access (`self.view`, `github.com`) completely untouched by Vietnamese marks.
    private var inTechnicalToken = false
    private var englishShortcutBuffer = ""
    private var atEnglishWordStart = true

    public init(
        engine: VitekEngine = VitekEngine(),
        shortcuts: Shortcuts = Shortcuts(),
        shortcutsInEnglishMode: Bool = false
    ) {
        self.engine = engine
        self.shortcuts = shortcuts
        self.shortcutsInEnglishMode = shortcutsInEnglishMode
    }

    public mutating func handle(_ event: HostEvent) -> SessionOutput {
        guard isVietnamese else { return handleEnglishMode(event) }
        switch event {
        case .character(let key):
            if key.isWhitespace || key.isNewline {
                inTechnicalToken = false
            } else if inTechnicalToken {
                if key.isLetter || key.isNumber || Self.technicalConnectors.contains(key) || key == "." || key == "-" {
                    return SessionOutput(commands: [], passThrough: true)
                }
                inTechnicalToken = false
            }
            if engine.type(key) {
                return SessionOutput(commands: markCommands(), passThrough: false)
            }
            let hadWord = engine.isComposing
            let commands = finishCommands(followedBySpace: key == " ")
            if Self.technicalConnectors.contains(key) || (key == "." && hadWord) {
                inTechnicalToken = true
            }
            return SessionOutput(commands: commands, passThrough: true)
        case .backspace:
            if inTechnicalToken {
                inTechnicalToken = false
                return SessionOutput(commands: [], passThrough: true)
            }
            if engine.deleteBackward() {
                return SessionOutput(commands: markCommands(), passThrough: false)
            }
            return SessionOutput(commands: [], passThrough: true)
        case .boundary:
            inTechnicalToken = false
            return SessionOutput(commands: finishCommands(), passThrough: true)
        }
    }

    private static let technicalConnectors: Set<Character> = ["_", "/", "\\", "@", "$", "#", ":"]

    /// Restores the word in progress to its raw keys (for instant Escape undo).
    public mutating func restoreRawKeys() -> [HostCommand] {
        inTechnicalToken = false
        defer { marked = "" }
        guard let raw = engine.restoreRawKeys() else { return [] }
        return [.insert(raw)]
    }

    /// Commits the word in progress, for when the host loses focus, the user clicks elsewhere or
    /// the input source changes.
    public mutating func flush() -> [HostCommand] {
        if !isVietnamese {
            return flushEnglishShortcut(expand: true)
        }
        return finishCommands()
    }

    /// Takes the word just before the caret back into the composition (see `VitekEngine.resume`).
    /// The host has already turned that word into marked text; the next event edits it.
    public mutating func resume(_ word: String) -> Bool {
        guard isVietnamese, engine.resume(word) else { return false }
        marked = word
        return true
    }

    /// Drops the word in progress without committing anything: the host found that the text it
    /// put on screen is no longer there (the user clicked elsewhere, the app corrected it).
    public mutating func discard() {
        engine.reset()
        marked = ""
        inTechnicalToken = false
        englishShortcutBuffer = ""
        atEnglishWordStart = true
    }

    /// Switches between Vietnamese and English typing. Returns the commands that commit the word in
    /// progress; the host applies them before the next key.
    public mutating func setVietnamese(_ on: Bool) -> [HostCommand] {
        guard on != isVietnamese else { return [] }
        let commands = isVietnamese ? finishCommands() : flushEnglishShortcut(expand: false)
        isVietnamese = on
        atEnglishWordStart = true
        return commands
    }

    private mutating func handleEnglishMode(_ event: HostEvent) -> SessionOutput {
        guard shortcutsInEnglishMode, !shortcuts.isEmpty else {
            return SessionOutput(commands: [], passThrough: true)
        }
        switch event {
        case .character(let key):
            if !englishShortcutBuffer.isEmpty || atEnglishWordStart {
                let candidate = englishShortcutBuffer + String(key)
                if !key.isWhitespace, !key.isNewline, shortcuts.hasPrefix(candidate) {
                    englishShortcutBuffer = candidate
                    marked = candidate
                    atEnglishWordStart = false
                    return SessionOutput(commands: [.mark(candidate)], passThrough: false)
                }
            }
            let isBreak = !key.isLetter && !key.isNumber && !Self.technicalConnectors.contains(key)
            let commands = flushEnglishShortcut(expand: isBreak)
            atEnglishWordStart = key.isWhitespace || key.isNewline
            return SessionOutput(commands: commands, passThrough: true)
        case .backspace:
            if !englishShortcutBuffer.isEmpty {
                englishShortcutBuffer.removeLast()
                marked = englishShortcutBuffer
                atEnglishWordStart = englishShortcutBuffer.isEmpty
                return SessionOutput(commands: [.mark(englishShortcutBuffer)], passThrough: false)
            }
            atEnglishWordStart = true
            return SessionOutput(commands: [], passThrough: true)
        case .boundary:
            let commands = flushEnglishShortcut(expand: true)
            atEnglishWordStart = true
            return SessionOutput(commands: commands, passThrough: true)
        }
    }

    private mutating func flushEnglishShortcut(expand: Bool) -> [HostCommand] {
        guard !englishShortcutBuffer.isEmpty else { return [] }
        let word = englishShortcutBuffer
        englishShortcutBuffer = ""
        marked = ""
        let text = expand ? (shortcuts.expansion(of: word) ?? word) : word
        return [.insert(text)]
    }

    private mutating func markCommands() -> [HostCommand] {
        let composition = engine.composition
        guard composition != marked else { return [] }
        marked = composition
        return [.mark(composition)]
    }

    private mutating func finishCommands(followedBySpace: Bool = false) -> [HostCommand] {
        defer { marked = "" }
        guard let word = engine.finish() else {
            return marked.isEmpty ? [] : [.mark("")]
        }
        let text = shortcuts.expansion(of: word.text) ?? shortcuts.expansion(of: word.keys) ?? word.text
        if followedBySpace { engine.followSpace(after: text, source: word) }
        return [.insert(text)]
    }
}
