import AppKit
import ApplicationServices
import Carbon

/// Differential tests in disposable windows only; all typed input is physical key codes.
@MainActor enum FocusRaceQA {
    typealias QA = SystemKeyboardQA
    static func arg(_ name: String) -> String? {
        CommandLine.arguments.first { $0.hasPrefix(name + "=") }.map { String($0.dropFirst(name.count + 1)) }
    }
    static func run() throws {
        if let id = arg("--select-source") {
            let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
            guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
                  let source = sources.first, TISSelectInputSource(source) == noErr else { throw QA.Failure.target }
            QA.settle(0.3)
            print("selectedSource=\(QA.selectedSourceID())")
            return
        }
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { throw QA.Failure.permission }
        guard let pid = arg("--pid").flatMap(Int32.init), let app = NSRunningApplication(processIdentifier: pid) else {
            throw QA.Failure.target
        }
        let chrome = CommandLine.arguments.contains("--chrome")
        guard app.bundleIdentifier == (chrome ? "com.google.Chrome" : QA.targetID) else { throw QA.Failure.target }
        try QA.activateFixture(app, title: chrome ? "viTek-Focus-QA" : QA.fixtureName)
        print("targetForeground=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == pid)")
        let axApp = AXUIElementCreateApplication(pid)
        guard let window = QA.attribute(axApp, kAXFocusedWindowAttribute), CFGetTypeID(window) == AXUIElementGetTypeID() else { throw QA.Failure.mismatch("missing focused window") }
        var axWindow = unsafeDowncast(window, to: AXUIElement.self)
        guard let title = QA.attribute(axWindow, kAXTitleAttribute) as? String,
              title.contains(chrome ? "viTek-Focus-QA" : QA.fixtureName) else { throw QA.Failure.mismatch("fixture window not selected") }
        func field(_ title: String, in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
            guard depth < 20 else { return nil }
            if QA.attribute(element, kAXTitleAttribute) as? String == title { return element }
            for child in QA.attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                if let result = field(title, in: child, depth: depth + 1) { return result }
            }
            return nil
        }
        if CommandLine.arguments.contains("--inspect") {
            func walk(_ e: AXUIElement, _ depth: Int) {
                guard depth < 20 else { return }
                let role = QA.attribute(e, kAXRoleAttribute) as? String ?? "?"
                let description = QA.attribute(e, kAXDescriptionAttribute) as? String ?? ""
                let title = QA.attribute(e, kAXTitleAttribute) as? String ?? ""
                print(String(repeating: " ", count: depth) + role + " " + description + " " + title)
                for child in QA.attribute(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] { walk(child, depth + 1) }
            }
            walk(axWindow, 0)
            return
        }
        func guardTarget() throws {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  let current = QA.attribute(axApp, kAXFocusedWindowAttribute),
                  CFGetTypeID(current) == AXUIElementGetTypeID() else {
                throw QA.Failure.mismatch("lost QA target: foreground=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == pid), windowAvailable=\(QA.attribute(axApp, kAXFocusedWindowAttribute) != nil)")
            }
            let currentWindow = unsafeDowncast(current, to: AXUIElement.self)
            guard QA.attribute(currentWindow, kAXTitleAttribute) as? String == title else {
                throw QA.Failure.mismatch("focused window title changed")
            }
            // Refresh observations only while the foreground app and exact QA title match.
            axWindow = currentWindow
        }
        func key(_ code: CGKeyCode, _ flags: CGEventFlags = [], pause: Double = 0) throws {
            try guardTarget()
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: code, keyDown: down) else { throw QA.Failure.target }
                event.flags = flags
                event.post(tap: .cghidEventTap)
                usleep(1_000)
            }
            if pause > 0 { QA.settle(pause) }
        }
        func type(_ value: String) throws {
            let codes: [Character: CGKeyCode] = ["v":9,"i":34,"e":14,"t":17,"j":38,"n":45,"a":0,"m":46," ":49]
            for char in value { guard let code = codes[char] else { throw QA.Failure.target }; try key(code) }
        }
        func focused() -> AXUIElement? {
            guard let v = QA.attribute(axApp, kAXFocusedUIElementAttribute), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
            return unsafeDowncast(v, to: AXUIElement.self)
        }
        func value() -> String? {
            let target = chrome ? field("QA old", in: axWindow) : focused()
            return target.flatMap { QA.attribute($0, kAXValueAttribute) as? String }
        }
        func description() -> String { focused().flatMap { QA.attribute($0, kAXDescriptionAttribute) as? String } ?? "" }
        func expect(_ expected: String) throws {
            let until = Date().addingTimeInterval(2)
            repeat {
                try guardTarget()
                if value() == expected || value() == expected + "\n" { return }
                QA.settle(0.05)
            } while Date() < until
            print("controlValue=\(value()?.debugDescription ?? "nil")")
            throw QA.Failure.mismatch("control expected length \(expected.count), actual \(value()?.count ?? -1)")
        }
        func clear() throws {
            try key(0, .maskCommand, pause: 0.15)
            try key(51, pause: 0.3)
            try expect("")
        }
        func editor() throws {
            for _ in 0..<3 {
                try key(53, pause: 0.15)
                if description().contains(QA.fixtureName) { return }
            }
            try key(18, .maskCommand, pause: 0.3)
            guard description().contains(QA.fixtureName) else { throw QA.Failure.target }
        }
        print("host=\(chrome ? "Chrome" : "VSCode") source=\(QA.selectedSourceID())")
        if chrome {
            QA.settle(0.3)
            if CommandLine.arguments.contains("--cycle-source") {
                let controlDown = CGEvent(keyboardEventSource: nil, virtualKey: 59, keyDown: true)
                controlDown?.type = .flagsChanged
                controlDown?.flags = .maskControl
                controlDown?.post(tap: .cghidEventTap)
                try key(49, .maskControl)
                let controlUp = CGEvent(keyboardEventSource: nil, virtualKey: 59, keyDown: false)
                controlUp?.type = .flagsChanged
                controlUp?.flags = []
                controlUp?.post(tap: .cghidEventTap)
                QA.settle(0.5)
                print("afterCycle=\(QA.selectedSourceID())")
            }
            // F4 resets/focuses only our local fixture; F2 schedules focus 150ms later.
            let sample = arg("--sample") ?? "nam"
            let expectedSample = sample == "vieetj " && !CommandLine.arguments.contains("--abc") ? "việt " : sample
            let modes = CommandLine.arguments.contains("--single") ? [CommandLine.arguments.contains("--delayed")] : [false, true, false, true, false, true]
            for delayed in modes {
                try key(118, pause: 0.3)
                for code: CGKeyCode in [9,34,14,14,17,38,49] { try key(code, pause: 0.02) }
                try expect(CommandLine.arguments.contains("--abc") ? "vieetj " : "việt ")
                print("PASS conversion control")
                try key(118, pause: 0.3)
                try key(delayed ? 120 : 48)
                try type(sample)
                QA.settle(0.25)
                // The fixture exports a trace into its read-only field when F3 is pressed.
                try key(99, pause: 0.3)
                guard let traceField = field("QA trace", in: axWindow),
                      let trace = QA.attribute(traceField, kAXValueAttribute) as? String, trace.hasPrefix("QA:") else { throw QA.Failure.observation }
                print(trace)
                let data = Data(trace.dropFirst(3).utf8)
                guard let report = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      report["old"] as? String == (delayed ? expectedSample : ""),
                      report["next"] as? String == (delayed ? "" : expectedSample) else {
                    throw QA.Failure.mismatch("Chrome focus routing or character preservation")
                }
                print("PASS Chrome \(delayed ? "delayed focus keeps early keys in old field" : "Tab routes keys to new field")")
            }
            return
        }
        try editor()
        try clear()
        // Slow control isolates conversion from focus transition races.
        for code: CGKeyCode in [9,34,14,14,17,38,49] { try key(code, pause: 0.15) }
        try expect(CommandLine.arguments.contains("--abc") ? "vieetj " : "việt ")
        print("PASS conversion control")
        for gap in [0.0, 0.02, 0.1, 0.3] {
            for iteration in 1...3 {
                try editor()
                try key(3, .maskCommand, pause: 0.4)
                let focusDeadline = Date().addingTimeInterval(2)
                while !description().localizedCaseInsensitiveContains("find"), Date() < focusDeadline { QA.settle(0.05) }
                guard description().localizedCaseInsensitiveContains("find") else { throw QA.Failure.mismatch("setup Find focus") }
                try clear()
                try editor()
                try clear()
                let start = ContinuousClock.now
                try key(3, .maskCommand, pause: gap)
                let before = description().localizedCaseInsensitiveContains("find")
                if CommandLine.arguments.contains("--with-select-all") { try key(0, .maskCommand) }
                try type("nam")
                let duration = start.duration(to: .now)
                QA.settle(0.8)
                let find = value() ?? "<unavailable>"
                let findFocused = description().localizedCaseInsensitiveContains("find")
                try editor()
                QA.settle(0.3)
                let document = value() ?? "<unavailable>"
                // Values belong only to this disposable fixture, never arbitrary user documents.
                print("race gap=\(gap) iteration=\(iteration) focusBefore=\(before) findFocused=\(findFocused) duration=\(duration) find=\(find.debugDescription) editor=\(document.debugDescription)")
                guard findFocused, find == "nam", document.trimmingCharacters(in: .newlines).isEmpty else {
                    throw QA.Failure.mismatch("VS Code focus routing or character preservation")
                }
            }
        }
    }
}
