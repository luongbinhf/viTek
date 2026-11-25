import Testing
import VitekEngine
import VitekSession

@Suite struct SmartBypassTests {
    @Test func preservesCamelCaseAndPascalCaseIdentifiers() {
        let session = InputSession()
        #expect(SimulatedTextField.result(of: "userName useState SwiftUI iPhone macOS onClick ", session: session)
                == "userName useState SwiftUI iPhone macOS onClick ")
    }

    @Test func preservesTechnicalTokensURLsEmailsAndSnakeCase() {
        let session = InputSession()
        #expect(SimulatedTextField.result(of: "user_id self.view github.com a@b.com /Users/test ", session: session)
                == "user_id self.view github.com a@b.com /Users/test ")
        // Normal Vietnamese resumes immediately after whitespace.
        #expect(SimulatedTextField.result(of: "github.com vieetj nam ", session: session)
                == "github.com việt nam ")
    }

    @Test func preservesCustomPersonalExceptionWords() {
        let options = EngineOptions(customEnglishWords: ["vitek", "nextjs"])
        let session = InputSession(engine: VitekEngine(options: options))
        #expect(SimulatedTextField.result(of: "vitek nextjs vieetj ", session: session)
                == "vitek nextjs việt ")
    }

    @Test func restoreRawKeysRevertsVietnameseMarksImmediately() {
        var session = InputSession()
        for ch in "vieetj" { _ = session.handle(.character(ch)) }
        #expect(session.engine.composition == "việt")
        #expect(session.engine.rawKeys == "vieetj")
        let commands = session.restoreRawKeys()
        #expect(commands == [.insert("vieetj")])
        #expect(!session.engine.isComposing)
    }
}
