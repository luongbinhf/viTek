#if canImport(AppKit)
import AppKit
import VitekSession
import VitekEngine

/// Drives the shipping DocumentSession in native compatibility mode with real NSTextView storage.
@MainActor final class NativeHostHarness {
    let client = NativeTextClient()
    var document = DocumentSession(session: InputSession(engine: VitekEngine(options: EngineOptions(automaticallyDetectsMethod: true))))

    func type(_ keys: String) {
        for key in keys {
            let output = document.handle(key == "⌫" ? .backspace : .character(key), client: client, prefersMarkedText: true)
            if output.passThrough {
                if key == "⌫" { client.view.deleteBackward(nil) }
                else { client.view.insertText(String(key), replacementRange: NSRange(location: NSNotFound, length: 0)) }
            }
        }
    }

    func flush() { document.interrupt(client: client) }
}
#endif
