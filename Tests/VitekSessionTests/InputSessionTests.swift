import Testing
import VitekEngine
import VitekSession

/// Feeds events to a fresh session and returns one output per event.
private func outputs(_ events: [HostEvent], session: InputSession = InputSession()) -> [SessionOutput] {
    var session = session
    return events.map { session.handle($0) }
}

private func keys(_ text: String) -> [HostEvent] {
    text.map { HostEvent.character($0) }
}

private func marked(_ text: String) -> SessionOutput { SessionOutput(commands: [.mark(text)], passThrough: false) }
private func committed(_ text: String) -> SessionOutput { SessionOutput(commands: [.insert(text)], passThrough: true) }
private let passed = SessionOutput(commands: [], passThrough: true)

@Suite struct InputSessionTests {
    @Test func composingMarksTextAndSpaceCommitsIt() {
        #expect(outputs(keys("vieetj  ")) == [
            marked("v"), marked("vi"), marked("vie"), marked("viê"), marked("viêt"), marked("việt"),
            committed("việt"), passed,
        ])
    }

    @Test func boundaryKeysCommitAndPassThrough() {
        #expect(outputs(keys("as") + [.boundary, .boundary]) == [marked("a"), marked("á"), committed("á"), passed])
    }

    @Test func backspaceEditsTheCompositionUntilItIsEmpty() {
        #expect(outputs(keys("as") + [.backspace, .backspace]) == [
            marked("a"), marked("á"), SessionOutput(commands: [.mark("")], passThrough: false), passed,
        ])
    }

    @Test func unchangedCompositionSendsNoCommand() {
        let last = outputs(keys("as") + [.backspace, .character("a"), .character("a")]).suffix(2)
        #expect(Array(last) == [marked("a"), marked("â")])
        // A key consumed without changing what is shown asks the host for nothing.
        var session = InputSession()
        _ = session.handle(.character("a"))
        _ = session.handle(.character("z"))
        let unchanged = session.handle(.character("z"))
        #expect(unchanged.commands == [.mark("azz")])
    }

    @Test func flushCommitsOnFocusLoss() {
        var session = InputSession()
        _ = session.handle(.character("d"))
        _ = session.handle(.character("d"))
        let first = session.flush()
        let second = session.flush()
        #expect(first == [.insert("đ")])
        #expect(second == [])
    }

    @Test func shortcutsExpandWithTheTypedCase() {
        let shortcuts = Shortcuts(["ko": "không", "vn": "Việt Nam", "aa": "anh ấy"])
        let session = InputSession(shortcuts: shortcuts)
        #expect(SimulatedTextField.result(of: "ko bieets", session: session) == "không biết")
        #expect(SimulatedTextField.result(of: "Ko KO vn", session: session) == "Không KHÔNG Việt Nam")
        #expect(SimulatedTextField.result(of: "aa", session: session) == "anh ấy")
        #expect(shortcuts.expansion(of: "kho") == nil)
    }

    @Test func shortcutsSupportDynamicDateTimeMacrosAndEnglishMode() {
        let ts = MacroTimestamp(year: 2026, month: 11, day: 25, hour: 9, minute: 5)
        let shortcuts = Shortcuts(
            ["ngay": "hôm nay {{date}}", "gio": "{{time}}", "ko": "không"],
            timestampProvider: { ts }
        )
        #expect(shortcuts.expansion(of: "ngay") == "hôm nay 25/11/2026")
        #expect(shortcuts.expansion(of: "gio") == "09:05")

        var session = InputSession(shortcuts: shortcuts, shortcutsInEnglishMode: true)
        _ = session.setVietnamese(false)
        #expect(SimulatedTextField.result(of: "ko server keep ngay", session: session) == "không server keep hôm nay 25/11/2026")
    }

    @Test func englishModeCommitsTheWordThenPassesEveryKey() {
        var session = InputSession()
        _ = session.handle(.character("a"))
        _ = session.handle(.character("s"))
        #expect(session.setVietnamese(false) == [.insert("á")])
        #expect(session.setVietnamese(false) == [])
        #expect(outputs(keys("as") + [.backspace, .boundary], session: session) == [passed, passed, passed, passed])
        #expect(session.setVietnamese(true) == [])
        #expect(session.handle(.character("a")) == marked("a"))
    }

    @Test func resumingMarksTheOldWordAndCommitsTheEdit() {
        var session = InputSession()
        let resumed = session.resume("viêt")
        let tone = session.handle(.character("j"))
        let end = session.handle(.boundary)
        #expect(resumed)
        #expect(tone == marked("việt"))
        #expect(end == committed("việt"))
        _ = session.setVietnamese(false)
        let inEnglish = session.resume("viêt")
        #expect(!inEnglish)
    }

    @Test func discardDropsTheWordWithoutCommitting() {
        var session = InputSession()
        _ = session.handle(.character("a"))
        session.discard()
        let flushed = session.flush()
        let next = session.handle(.character("b"))
        #expect(flushed == [])
        #expect(next == marked("b"))
    }

    @Test func shortcutAbbreviationsIgnoreCase() {
        let shortcuts = Shortcuts(["vn": "Việt Nam", "VN": "Việt Nam"])
        #expect(shortcuts.count == 1)
        #expect(Shortcuts().isEmpty)
    }

    @Test func simulatedFieldMatchesWhatAUserSees() {
        #expect(SimulatedTextField.result(of: "Xin chaof, tooi laf viTek.") == "Xin chào, tôi là viTek.")
        #expect(SimulatedTextField.result(of: "abc⌫⌫⌫⌫x") == "x")
        #expect(SimulatedTextField.result(of: "ok ⌫⌫⌫hi") == "hi")
    }
}
