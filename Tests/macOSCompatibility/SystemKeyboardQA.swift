// Standalone macOS QA driver. Sends physical key codes through the system event stream,
// never Unicode text, paste, or process-targeted events. It does not record user keystrokes.
// Run only with --run and a dedicated VS Code window titled viTek-System-QA.txt.
import AppKit
import ApplicationServices
import Carbon

@main struct SystemKeyboardQA {
    enum Failure: Error { case permission, target, observation, mismatch(String) }
    static let targetID = "com.microsoft.VSCode"
    static let fixtureName = "viTek-System-QA.txt"

    static func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    static func selectedSourceID() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "unknown" }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    @MainActor static func activateFixture(_ app: NSRunningApplication, title: String) throws {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        app.activate(options: [])
        settle(0.5)
        guard let windows = attribute(axApp, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first(where: {
                  (attribute($0, kAXTitleAttribute) as? String)?.contains(title) == true
              }) else {
            let titles = (attribute(axApp, kAXWindowsAttribute) as? [AXUIElement])?.map {
                (attribute($0, kAXTitleAttribute) as? String) ?? "<untitled>"
            }
            print("fixtureWindowUnavailable pid=\(app.processIdentifier) windows=\(titles?.description ?? "AX unavailable")")
            throw Failure.target
        }
        // Activation is asynchronous. Raise only the disposable fixture, then wait
        // for both foreground ownership and the requested window before sending keys.
        if #available(macOS 14.0, *) {
            NSApplication.shared.yieldActivation(to: app)
            _ = app.activate(from: .current, options: [])
        } else {
            app.activate(options: [])
        }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        let deadline = Date().addingTimeInterval(3)
        repeat {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
               let focused = attribute(axApp, kAXFocusedWindowAttribute), CFEqual(focused, window) {
                return
            }
            settle(0.05)
        } while Date() < deadline
        print("fixtureActivationTimedOut foregroundMatches=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier)")
        throw Failure.target
    }

    @MainActor static func main() {
        // Finish the accessory app's launch before handing activation to a fixture.
        // Deferred launch events must not restore the caller midway through typing.
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.finishLaunching()
        settle(0.3)
        do {
            if CommandLine.arguments.contains("--stress") { try StressKeyboardQA.run() }
            else if CommandLine.arguments.contains("--suggestions") { try DelayedSuggestionQA.run() }
            else if CommandLine.arguments.contains("--race") { try FocusRaceQA.run() }
            else { try run() }
        }
        catch { print("QA FAILED: \(error)"); exit(1) }
    }

    @MainActor static func run() throws {
        let trusted = AXIsProcessTrusted(), canPost = CGPreflightPostEventAccess()
        print("accessibility=\(trusted) postEvents=\(canPost)")
        guard CommandLine.arguments.contains("--run") else { return }
        // Never request/grant privileges automatically or type into an unrelated application.
        guard trusted && canPost else { throw Failure.permission }
        let requestedPID = CommandLine.arguments.first(where: { $0.hasPrefix("--pid=") })
            .flatMap { Int32($0.dropFirst(6)) }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: targetID)
            .first(where: { requestedPID == nil || $0.processIdentifier == requestedPID }) else {
            throw Failure.target
        }
        try activateFixture(app, title: fixtureName)
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = attribute(axApp, kAXFocusedWindowAttribute) else { throw Failure.target }
        guard CFGetTypeID(window) == AXUIElementGetTypeID() else { throw Failure.target }
        let axWindow = unsafeDowncast(window, to: AXUIElement.self)
        print("targetPID=\(app.processIdentifier) fixtureWindow=\((attribute(axWindow, kAXTitleAttribute) as? String)?.contains(fixtureName) == true)")
        guard let title = attribute(axWindow, kAXTitleAttribute) as? String,
              title.contains(fixtureName) else { throw Failure.target }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            throw Failure.target
        }
        // Focus the first editor group in this already-verified disposable window.
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 18, keyDown: down)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        settle(0.3)
        for _ in 0..<3 {
            if let f = attribute(axApp, kAXFocusedUIElementAttribute), CFGetTypeID(f) == AXUIElementGetTypeID(),
               (attribute(unsafeDowncast(f, to: AXUIElement.self), kAXDescriptionAttribute) as? String)?.localizedCaseInsensitiveContains("find") == true {
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
                    throw Failure.target
                }
                CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)?.post(tap: .cghidEventTap)
                CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)?.post(tap: .cghidEventTap)
                settle(0.3)
            } else { break }
        }
        if let f = attribute(axApp, kAXFocusedUIElementAttribute), CFGetTypeID(f) == AXUIElementGetTypeID() {
            let e = unsafeDowncast(f, to: AXUIElement.self)
            print("initialFocus=\(attribute(e, kAXDescriptionAttribute) as? String ?? "none")")
            print("focusedRole=\(attribute(e, kAXRoleAttribute) as? String ?? "none") fixtureEditor=\((attribute(e, kAXDescriptionAttribute) as? String)?.contains(fixtureName) == true)")
        }
        guard let focused = attribute(axApp, kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID(),
              let description = attribute(unsafeDowncast(focused, to: AXUIElement.self), kAXDescriptionAttribute) as? String,
              description.contains(fixtureName) else { throw Failure.target }

        // Selection from a background helper is not proof of the target application's source.
        // Preserve the target source; the conversion assertion below is the positive control.
        print("selectedSource=\(selectedSourceID()) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")")

        func key(_ code: CGKeyCode, _ flags: CGEventFlags = [], delay: UInt32 = 5_000) throws {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
                  let currentWindow = attribute(axApp, kAXFocusedWindowAttribute),
                  CFEqual(currentWindow, axWindow) else {
                throw Failure.target
            }
            let source = CGEventSource(stateID: .hidSystemState)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
                throw Failure.target
            }
            down.flags = flags; up.flags = flags
            down.post(tap: .cghidEventTap)
            usleep(1_000)
            up.post(tap: .cghidEventTap)
            usleep(delay)
        }
        let codes: [Character: CGKeyCode] = ["v":9, "i":34, "e":14, "t":17, "j":38,
                                            "n":45, "a":0, "m":46, " ":49, "6":22, "5":23]
        func type(_ text: String, delay: UInt32) throws {
            for char in text {
                guard let code = codes[char] else { throw Failure.target }
                try key(code, delay: delay)
            }
        }
        func expect(_ expected: String, _ label: String) throws {
            // Electron's AXValue can lag the renderer. Wait for the assertion, not just a
            // fixed sleep, while keeping the original window and foreground app guarded.
            let deadline = Date().addingTimeInterval(2)
            var lastValue: String?
            var lastDescription = ""
            repeat {
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
                      let window = attribute(axApp, kAXFocusedWindowAttribute), CFEqual(window, axWindow) else {
                    throw Failure.target
                }
                if let focused = attribute(axApp, kAXFocusedUIElementAttribute),
                   CFGetTypeID(focused) == AXUIElementGetTypeID() {
                    let element = unsafeDowncast(focused, to: AXUIElement.self)
                    lastDescription = attribute(element, kAXDescriptionAttribute) as? String ?? ""
                    lastValue = attribute(element, kAXValueAttribute) as? String
                    if lastValue == expected || lastValue == expected + "\n" {
                        print("PASS \(label)")
                        return
                    }
                }
                settle(0.05)
            } while Date() < deadline
            guard let value = lastValue else { throw Failure.observation }
            print("mismatch expectedLength=\(expected.utf16.count) actualLength=\(value.utf16.count) focus=\(lastDescription)")
            if value.count < 80, value.allSatisfy({ "vietjnams65 êệếềểễâăôơưáàảãạíìỉĩịóòỏõọúùủũụ\n".contains($0) }) {
                print("fixtureResult=\(value.debugDescription)")
            }
            throw Failure.mismatch(label)
        }
        func clear() throws {
            try key(0, .maskCommand)
            settle(0.2)
            try key(51)
            settle(0.3)
            try expect("", "fixture cleared")
        }

        func waitForFocus(_ matches: (String) -> Bool) throws {
            let deadline = Date().addingTimeInterval(3)
            repeat {
                if let focused = attribute(axApp, kAXFocusedUIElementAttribute),
                   CFGetTypeID(focused) == AXUIElementGetTypeID(),
                   let description = attribute(unsafeDowncast(focused, to: AXUIElement.self), kAXDescriptionAttribute) as? String,
                   matches(description) { return }
                settle(0.01)
            } while Date() < deadline
            throw Failure.observation
        }
        try clear()
        settle(0.5)
        try type("vieetj vie65t ", delay: 150_000)
        print("sourceAfterTyping=\(selectedSourceID())")
        try expect("việt việt ", "positive control Telex/VNI")
        for delay: UInt32 in [0, 5_000, 20_000, 0, 5_000, 20_000, 0, 5_000, 20_000] {
            // Wait for the target field, then send its printable keys without a settling delay.
            try key(3, .maskCommand, delay: delay)
            try waitForFocus { $0.localizedCaseInsensitiveContains("find") }
            try key(0, .maskCommand, delay: delay)
            try type("nam", delay: delay)
            try expect("nam", "Find at \(delay)us")
            try key(53)
            settle(0.1)
            try key(53)
            try waitForFocus { $0.contains(fixtureName) }
            try clear()
            settle(0.3)
            try type("vieet", delay: delay)
            try key(123); try key(123); try key(51)
            try expect("vêt", "caret deletion at \(delay)us")
        }
        // Open a disposable editor and type as soon as Accessibility confirms its focus.
        try key(45, .maskCommand, delay: 0)
        try waitForFocus { $0.contains("Untitled") }
        try type("vieetj ", delay: 5_000)
        try expect("việt ", "new editor immediate typing")
        print("SYSTEM KEYBOARD QA PASSED")
    }
}
