import AppKit
import InputMethodKit
import VitekSession

// The input method is a background app that serves one IMKServer. macOS creates a
// VitekInputController (named in Info.plist) for every text field that uses viTek.

guard let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
      let server = IMKServer(name: connection, bundleIdentifier: Bundle.main.bundleIdentifier)
else {
    fatalError("viTek: Info.plist has no InputMethodConnectionName")
}
// The engine builds its spelling tables on first use (up to ~0.5 ms); do that now rather than on
// the user's first key. `swift run -c release vitek-bench` measures the steady state.
var warmUp = InputSession()
for key in "Tieengs Vieetj test " { _ = warmUp.handle(key == " " ? .boundary : .character(key)) }

CommandModifierMonitor.shared.start()

let writingDelegate = MainActor.assumeIsolated { WritingAppDelegate() }
NSApplication.shared.delegate = writingDelegate

let healthConnection = MainActor.assumeIsolated { InputMethodConnection.responder() }
MainActor.assumeIsolated {
    CloudSettingsSync.shared.start()
    ClipboardMonitor.shared.start()
    Task { @MainActor in await VitekFocusFilter.refreshCurrent() }
}
withExtendedLifetime((server, healthConnection, writingDelegate)) {
    NSApplication.shared.run()
}
