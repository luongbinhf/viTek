import AppKit
import ApplicationServices

/// Real HID input and on-screen panel observation in disposable fixture windows only.
@MainActor enum DelayedSuggestionQA {
    typealias QA = SystemKeyboardQA
    static func run() throws {
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess(),
              let pid = FocusRaceQA.arg("--pid").flatMap(Int32.init),
              let app = NSRunningApplication(processIdentifier: pid) else { throw QA.Failure.permission }
        let chrome = CommandLine.arguments.contains("--chrome")
        let release = CommandLine.arguments.contains("--release-positive")
        guard app.bundleIdentifier == (chrome ? "com.google.Chrome" : QA.targetID) else { throw QA.Failure.target }
        guard let defaults = UserDefaults(suiteName: "io.github.luongbinhf.inputmethod.viTek") else { throw QA.Failure.target }
        let previousDelay = defaults.object(forKey: "qaSuggestionDelayMilliseconds")
        defer {
            if let previousDelay { defaults.set(previousDelay, forKey: "qaSuggestionDelayMilliseconds") }
            else { defaults.removeObject(forKey: "qaSuggestionDelayMilliseconds") }
            defaults.synchronize()
        }
        if !release {
            defaults.set(2000, forKey: "qaSuggestionDelayMilliseconds")
            defaults.synchronize()
        }
        try QA.activateFixture(app, title: chrome ? "viTek-Focus-QA" : QA.fixtureName)
        let axApp = AXUIElementCreateApplication(pid)
        guard let window = QA.attribute(axApp, kAXFocusedWindowAttribute),
              CFGetTypeID(window) == AXUIElementGetTypeID(),
              let ime = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.luongbinhf.inputmethod.viTek").first else { throw QA.Failure.target }
        let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/viTek/diagnostics.log")
        func logSize() -> Int { (try? Data(contentsOf: logURL).count) ?? 0 }
        func logSince(_ offset: Int) -> String {
            let data = (try? Data(contentsOf: logURL)) ?? Data()
            return String(decoding: data.dropFirst(min(offset, data.count)), as: UTF8.self)
        }
        func guardTarget() throws {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  let current = QA.attribute(axApp, kAXFocusedWindowAttribute), CFEqual(window, current) else {
                throw QA.Failure.mismatch("QA target lost; no more keys sent")
            }
        }
        func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) throws {
            try guardTarget()
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: code, keyDown: down)
                event?.flags = flags
                event?.post(tap: .cghidEventTap)
                usleep(1_000)
            }
            QA.settle(0.02)
        }
        func type(_ text: String) throws {
            let codes: [Character:CGKeyCode] = ["c":8,"o":31,"w":13,"s":1,"r":15,"d":2,"u":32,"x":7," ":49,"l":37,"i":34,"e":14,"j":38,"n":45,"a":0,"m":46]
            for ch in text { guard let code = codes[ch] else { throw QA.Failure.target }; try key(code) }
        }
        func focusedValue() -> String? {
            guard let focused = QA.attribute(axApp, kAXFocusedUIElementAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
            return QA.attribute(unsafeDowncast(focused, to: AXUIElement.self), kAXValueAttribute) as? String
        }
        func expect(_ expected: String) throws {
            try guardTarget()
            let value = focusedValue()
            guard value == expected || value == expected + "\n" else {
                print("fixture expected=\(expected.debugDescription) actual=\(value?.debugDescription ?? "nil")")
                throw QA.Failure.mismatch("fixture text")
            }
        }
        func panelVisible() -> Bool {
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []
            return windows.contains {
                ($0[kCGWindowOwnerPID as String] as? Int32) == ime.processIdentifier &&
                ($0[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow))
            }
        }
        func waitPanel(_ visible: Bool, seconds: Double = 3) throws {
            let end = Date().addingTimeInterval(seconds)
            repeat {
                try guardTarget()
                if panelVisible() == visible { return }
                QA.settle(0.05)
            } while Date() < end
            throw QA.Failure.mismatch("suggestion panel visible expected \(visible)")
        }
        func reset() throws {
            if chrome { try key(118) }
            else {
                try key(53); try key(53); try key(18, .maskCommand)
                QA.settle(0.15)
                try key(0, .maskCommand); QA.settle(0.1); try key(51)
            }
            QA.settle(0.2)
            try expect("")
        }
        func arm() throws -> Int {
            try reset()
            let offset = logSize()
            try type("cow sowr duwx ")
            QA.settle(0.4)
            try expect("cơ sở dữ ")
            if release { return offset }
            let log = logSince(offset)
            guard log.contains("context=9 endsWithSpace=true"), log.contains("QA suggestion delay begin ms=2000") else {
                throw QA.Failure.mismatch("forced delay did not start for fixture context")
            }
            guard !panelVisible() else { throw QA.Failure.mismatch("panel appeared before forced delay") }
            return offset
        }
        func expectCancelled(_ offset: Int, label: String, text: String) throws {
            // Observe throughout the delivery interval, not only after a possibly transient bar.
            let end = Date().addingTimeInterval(2.5)
            repeat {
                try guardTarget()
                guard !panelVisible() else { throw QA.Failure.mismatch("late panel reappeared: \(label)") }
                QA.settle(0.025)
            } while Date() < end
            try expect(text)
            guard logSince(offset).contains("QA suggestion delay end cancelled=true") else {
                throw QA.Failure.mismatch("non-cooperative cancelled delivery not observed")
            }
            print("PASS \(label): delayed completion arrived cancelled; panel stayed hidden; text preserved")
        }
        print("host=\(chrome ? "Chrome" : "VSCode") forcedDelayMs=\(release ? 0 : 2000) physicalHID=true")
        _ = try arm()
        try waitPanel(true)
        try key(18, .maskAlternate)
        QA.settle(0.25)
        try expect("cơ sở dữ liệu ")
        print("PASS positive control: visible panel and Option+1 accepted liệu")
        if release {
            try key(53)
            print("RELEASE SUGGESTION UI QA PASSED")
            return
        }

        var offset = try arm()
        try key(chrome ? 48 : 3, chrome ? [] : .maskCommand)
        QA.settle(0.2)
        if !chrome { try key(0, .maskCommand); try key(51) }
        try expectCancelled(offset, label: "field switch", text: "")

        offset = try arm()
        try key(123)
        try expectCancelled(offset, label: "caret moved", text: "cơ sở dữ ")

        offset = try arm()
        try key(123); try key(124)
        try expectCancelled(offset, label: "caret returned to same position", text: "cơ sở dữ ")

        offset = try arm()
        // Reverse response order: the old task captured 2000 ms, the new one gets 300 ms.
        defaults.set(300, forKey: "qaSuggestionDelayMilliseconds")
        defaults.synchronize()
        QA.settle(0.1)
        try type("li")
        try waitPanel(true, seconds: 1)
        guard logSince(offset).contains("QA suggestion delay begin ms=300") else {
            throw QA.Failure.mismatch("out-of-order delay override not applied")
        }
        let untilOldArrives = Date().addingTimeInterval(2.1)
        repeat {
            try guardTarget()
            guard panelVisible() else { throw QA.Failure.mismatch("old result hid the newer panel") }
            QA.settle(0.025)
        } while Date() < untilOldArrives
        try key(18, .maskAlternate)
        QA.settle(0.25)
        try expect("cơ sở dữ liệu ")
        guard logSince(offset).contains("QA suggestion delay end cancelled=true") else { throw QA.Failure.observation }
        print("PASS out-of-order response: 300ms result stayed visible after cancelled 2000ms result; accepted once")
        try key(53)
        print("DELAYED SUGGESTION UI QA PASSED")
    }
}
