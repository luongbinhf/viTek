/// A text field that follows `HostCommand`s the way a real host would. Used by tests and the
/// `vitek` command-line tool, and the reference for what a host has to do.
public struct SimulatedTextField: Sendable {
    /// The Backspace key in `type(_:)` scripts.
    public static let backspace: Character = "⌫"

    public var session: InputSession
    public private(set) var committed = ""
    public private(set) var marked = ""

    public init(session: InputSession = InputSession()) {
        self.session = session
    }

    /// What the field shows: committed text followed by the marked text.
    public var text: String { committed + marked }

    /// Types a script of keys. `⌫` is Backspace; every other character is typed as is, and keys
    /// the session lets through land in the field the way the app would insert them.
    public mutating func type(_ script: String) {
        for key in script {
            if key == Self.backspace {
                let output = session.handle(.backspace)
                apply(output.commands)
                if output.passThrough, !committed.isEmpty { committed.removeLast() }
            } else {
                let output = session.handle(.character(key))
                apply(output.commands)
                if output.passThrough { committed.append(key) }
            }
        }
    }

    /// Commits the word in progress, as when the field loses focus.
    public mutating func flush() {
        apply(session.flush())
    }

    private mutating func apply(_ commands: [HostCommand]) {
        for command in commands {
            switch command {
            case .insert(let text):
                marked = ""
                committed += text
            case .mark(let text):
                marked = text
            }
        }
    }

    /// The text a script produces once the last word is committed.
    public static func result(of script: String, session: InputSession = InputSession()) -> String {
        var field = SimulatedTextField(session: session)
        field.type(script)
        field.flush()
        return field.text
    }
}
