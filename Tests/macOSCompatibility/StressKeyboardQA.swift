import AppKit
import ApplicationServices
import Carbon

/// Repeatable system-input stress in dedicated QA fixtures. No paste or Unicode injection.
@MainActor enum StressKeyboardQA {
    typealias QA = SystemKeyboardQA
    static func run() throws {
        guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { throw QA.Failure.permission }
        guard let pid = FocusRaceQA.arg("--pid").flatMap(Int32.init),
              let app = NSRunningApplication(processIdentifier: pid) else { throw QA.Failure.target }
        let chrome = CommandLine.arguments.contains("--chrome")
        let rounds = max(1, min(100, FocusRaceQA.arg("--rounds").flatMap(Int.init) ?? 10))
        let only = FocusRaceQA.arg("--case")
        guard app.bundleIdentifier == (chrome ? "com.google.Chrome" : QA.targetID) else { throw QA.Failure.target }
        try QA.activateFixture(app, title: chrome ? "viTek-Focus-QA" : QA.fixtureName)
        let abc = CommandLine.arguments.contains("--abc")
        let previousSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        if abc {
            guard only == "burst" || only == "focus", let layout = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
                  TISSelectInputSource(layout) == noErr else { throw QA.Failure.target }
            QA.settle(0.2)
        }
        defer { if abc, let previousSource { TISSelectInputSource(previousSource) } }
        let axApp = AXUIElementCreateApplication(pid)
        guard let window = QA.attribute(axApp, kAXFocusedWindowAttribute),
              CFGetTypeID(window) == AXUIElementGetTypeID(),
              let ime = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.luongbinhf.inputmethod.viTek").first else { throw QA.Failure.target }
        var keys = 0, assertions = 0, cases = 0, accepted = 0, hostCommandRetries = 0
        var modifierEvents = 0
        guard let keyboardSource = CGEventSource(stateID: .privateState) else { throw QA.Failure.target }
        var pause: UInt32 = 0
        let start = ContinuousClock.now
        func output(_ text: String) { FileHandle.standardOutput.write(Data((text + "\n").utf8)) }
        func guardTarget() throws {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  let current = QA.attribute(axApp, kAXFocusedWindowAttribute), CFEqual(window, current) else {
                output("INTERRUPTED foregroundPID=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1) targetPID=\(pid) windowMatches=\(QA.attribute(axApp, kAXFocusedWindowAttribute).map { CFEqual(window, $0) } ?? false)")
                throw QA.Failure.mismatch("QA foreground/window changed; stress interrupted")
            }
        }
        func focused() -> AXUIElement? {
            guard let element = QA.attribute(axApp, kAXFocusedUIElementAttribute),
                  CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
            return unsafeDowncast(element, to: AXUIElement.self)
        }
        func value() -> String? { focused().flatMap { QA.attribute($0, kAXValueAttribute) as? String } }
        func description() -> String { focused().flatMap { QA.attribute($0, kAXDescriptionAttribute) as? String } ?? "" }
        func sided(_ flags: CGEventFlags) -> CGEventFlags {
            var result = flags
            for (flag, bit): (CGEventFlags, UInt64) in [(.maskCommand, CommandLine.arguments.contains("--right-command") ? 0x10 : 0x8), (.maskShift, 0x2), (.maskAlternate, 0x20), (.maskControl, 0x1)] where flags.contains(flag) {
                result.insert(CGEventFlags(rawValue: bit))
            }
            return result
        }
        func key(_ code: CGKeyCode, _ flags: CGEventFlags = [], _ deviceFlags: CGEventFlags = []) throws {
            try guardTarget()
            let physicalModifiers = CommandLine.arguments.contains("--physical-modifiers")
            let modifierKeys: [(CGKeyCode, CGEventFlags)] = [(CommandLine.arguments.contains("--right-command") ? 54 : 55, .maskCommand), (56, .maskShift), (58, .maskAlternate), (59, .maskControl)]
            var held: CGEventFlags = []
            var pressed: [(CGKeyCode, CGEventFlags)] = []
            func modifier(_ code: CGKeyCode, _ flags: CGEventFlags, down: Bool) {
                let event = CGEvent(keyboardEventSource: keyboardSource, virtualKey: code, keyDown: down)
                event?.type = .flagsChanged; event?.flags = sided(flags)
                event?.post(tap: .cghidEventTap)
                modifierEvents += 1
            }
            defer {
                for (code, flag) in pressed.reversed() {
                    held.remove(flag); modifier(code, held, down: false)
                }
            }
            if physicalModifiers {
                for (code, flag) in modifierKeys where flags.contains(flag) {
                    held.insert(flag); pressed.append((code, flag)); modifier(code, held, down: true)
                }
                try guardTarget()
            }
            guard let down = CGEvent(keyboardEventSource: keyboardSource, virtualKey: code, keyDown: true),
                  let up = CGEvent(keyboardEventSource: keyboardSource, virtualKey: code, keyDown: false) else { throw QA.Failure.target }
            let deliveredFlags = physicalModifiers ? sided(flags) : flags.union(deviceFlags)
            down.flags = deliveredFlags; up.flags = deliveredFlags
            down.post(tap: .cghidEventTap); usleep(1_000)
            up.post(tap: .cghidEventTap)
            if pause > 0 { usleep(pause) }
            if !pressed.isEmpty, let hold = FocusRaceQA.arg("--modifier-hold-ms").flatMap(Int.init), hold > 0 {
                QA.settle(Double(min(hold, 1000)) / 1000)
            }
            keys += 1
        }
        func type(_ text: String) throws {
            let codes: [Character:CGKeyCode] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"9":25,"7":26,"8":28,"0":29,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46," ":49,".":47]
            for ch in text {
                guard let lower = ch.lowercased().first, let code = codes[lower] else { throw QA.Failure.target }
                try key(code, ch.isUppercase ? .maskShift : [])
            }
        }
        func findShortcut() throws {
            if CommandLine.arguments.contains("--physical-modifiers") {
                try key(3, .maskCommand)
                return
            }
            guard let modifierDelay = FocusRaceQA.arg("--command-lead-ms").flatMap(Int.init) else {
                try key(3, .maskCommand)
                return
            }
            try guardTarget()
            let source = keyboardSource
            let commandCode: CGKeyCode = CommandLine.arguments.contains("--right-command") ? 54 : 55
            let deviceCommand = CGEventFlags(rawValue: commandCode == 54 ? 0x10 : 0x8)
            let down = CGEvent(keyboardEventSource: source, virtualKey: commandCode, keyDown: true)
            down?.type = .flagsChanged; down?.flags = CGEventFlags.maskCommand.union(deviceCommand)
            down?.post(tap: .cghidEventTap)
            modifierEvents += 1
            defer {
                let up = CGEvent(keyboardEventSource: source, virtualKey: commandCode, keyDown: false)
                up?.type = .flagsChanged; up?.flags = []
                up?.post(tap: .cghidEventTap)
                modifierEvents += 1
            }
            if modifierDelay > 0 { QA.settle(Double(min(modifierDelay, 1000)) / 1000) }
            try key(3, .maskCommand, deviceCommand)
        }
        func expect(_ expected: String, _ label: String) throws {
            let deadline = Date().addingTimeInterval(2)
            repeat {
                try guardTarget()
                let current = value()
                if current == expected || current == expected + "\n" { assertions += 1; return }
                QA.settle(0.01)
            } while Date() < deadline
            output("FAIL \(label) expected=\(expected.debugDescription) actual=\(value()?.debugDescription ?? "nil") focus=\(description())")
            if chrome {
                try key(99); QA.settle(0.2)
                output("FIXTURE TRACE \(value() ?? "unavailable")")
            }
            throw QA.Failure.mismatch(label)
        }
        func editor() throws {
            if chrome { try key(48, .maskShift) }
            else {
                for _ in 0..<3 {
                    try key(53); QA.settle(0.1)
                    if description().contains(QA.fixtureName) { break }
                }
                try key(18, .maskCommand)
            }
            QA.settle(0.12)
        }
        func reset() throws {
            if chrome {
                // A DOM value reset during native composition can be followed by
                // Chromium's pending commit. Finish a real selection deletion first.
                // F4 then only resets the fixture fields and trace between cases.
                try key(0, .maskCommand)
                let selectionDeadline = Date().addingTimeInterval(2)
                var selectedAll = false
                repeat {
                    try guardTarget()
                    if let field = focused(), let value = QA.attribute(field, kAXSelectedTextRangeAttribute),
                       CFGetTypeID(value) == AXValueGetTypeID() {
                        var range = CFRange()
                        if AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cfRange, &range),
                           range.location == 0, range.length == (QA.attribute(field, kAXValueAttribute) as? String)?.utf16.count {
                            selectedAll = true; break
                        }
                    }
                    QA.settle(0.01)
                } while Date() < selectionDeadline
                guard selectedAll else {
                    output("FAIL fixture selection value=\(value()?.debugDescription ?? "nil")")
                    try key(99); QA.settle(0.2)
                    output("FIXTURE TRACE \(value() ?? "unavailable")")
                    throw QA.Failure.mismatch("fixture selection not acknowledged")
                }
                try key(51)
                try expect("", "native selection deletion before fixture reset")
                let before = focused().flatMap { QA.attribute($0, kAXHelpAttribute) as? String }
                try key(118)
                let deadline = Date().addingTimeInterval(2)
                var acknowledged = false
                repeat {
                    try guardTarget()
                    if let field = focused(), let token = QA.attribute(field, kAXHelpAttribute) as? String,
                       token.hasPrefix("QA-reset-"), token != before {
                        acknowledged = true; break
                    }
                    QA.settle(0.01)
                } while Date() < deadline
                guard acknowledged else { throw QA.Failure.mismatch("fixture reset not acknowledged") }
            }
            else {
                try key(53); try key(53); try key(18, .maskCommand)
                let deadline = Date().addingTimeInterval(3)
                while !description().contains(QA.fixtureName), Date() < deadline {
                    try guardTarget(); QA.settle(0.01)
                }
                guard description().contains(QA.fixtureName) else { throw QA.Failure.mismatch("fixture editor is not focused") }
                try key(0, .maskCommand); try key(51)
            }
            try expect("", "fixture reset")
        }
        func panelVisible() -> Bool {
            let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String:Any]] ?? []
            return info.contains { ($0[kCGWindowOwnerPID as String] as? Int32) == ime.processIdentifier &&
                ($0[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.popUpMenuWindow)) }
        }
        func panelOffers(_ candidate: String) -> Bool {
            let application = AXUIElementCreateApplication(ime.processIdentifier)
            guard let windows = QA.attribute(application, kAXWindowsAttribute) as? [AXUIElement] else { return false }
            func contains(_ element: AXUIElement, depth: Int) -> Bool {
                guard depth < 12 else { return false }
                for name in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
                    if (QA.attribute(element, name) as? String) == candidate { return true }
                }
                return (QA.attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [])
                    .contains { contains($0, depth: depth + 1) }
            }
            return windows.contains { contains($0, depth: 0) }
        }
        func accept(_ expected: String, offered: String? = nil) throws {
            let candidate = offered ?? expected.split(separator: " ").last.map(String.init) ?? expected
            let deadline = Date().addingTimeInterval(3)
            repeat {
                try guardTarget()
                if panelVisible(), panelOffers(candidate) { break }
                QA.settle(0.02)
            } while Date() < deadline
            guard panelVisible(), panelOffers(candidate) else {
                throw QA.Failure.mismatch("missing current suggestion candidate for \(expected)")
            }
            try key(18, .maskAlternate)
            try expect(expected, "suggestion acceptance")
            // Window-server visibility can lag orderOut. Observe the old panel's
            // disappearance so the next acceptance cannot mistake it for a new result.
            let hiddenDeadline = Date().addingTimeInterval(1)
            while panelVisible(), Date() < hiddenDeadline { try guardTarget(); QA.settle(0.01) }
            guard !panelVisible() else { throw QA.Failure.observation }
            accepted += 1
        }
        func scenario(_ name: String, round: Int, body: () throws -> Void) throws {
            guard only == nil || only == name else { return }
            output("BEGIN round=\(round) case=\(name) keyPauseUs=\(pause)")
            try body()
            cases += 1
            output("PASS round=\(round) case=\(name)")
        }
        output("STRESS host=\(chrome ? "Chrome" : "VSCode") rounds=\(rounds) source=\(QA.selectedSourceID()) eventTap=HID sourceState=private")
        if CommandLine.arguments.contains("--cycle-source") {
            try guardTarget()
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 59, keyDown: true)
            down?.type = .flagsChanged; down?.flags = .maskControl; down?.post(tap: .cghidEventTap)
            try key(49, .maskControl)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 59, keyDown: false)
            up?.type = .flagsChanged; up?.flags = []; up?.post(tap: .cghidEventTap)
            QA.settle(0.3)
        }
        if chrome, CommandLine.arguments.contains("--reload-fixture") {
            try key(15, .maskCommand); QA.settle(1)
        }
        pause = 150_000
        try reset()
        try type("vieetj vie65t ")
        try expect(abc ? "vieetj vie65t " : "việt việt ", "input-source positive control")
        for round in 1...rounds {
            pause = FocusRaceQA.arg("--key-pause-us").flatMap(Int.init)
                .map { UInt32(max(0, min($0, 50_000))) } ?? [0, 1_000, 5_000][(round - 1) % 3]
            try scenario("burst", round: round) {
                try reset()
                try type(String(repeating: "vieetj vie65t ", count: 5))
                try expect(String(repeating: abc ? "vieetj vie65t " : "việt việt ", count: 5), "ten consecutive fast words")
            }
            try scenario("quick", round: round) {
                try reset(); try type("viw")
                try expect("viê", "quick Telex live expansion")
                try type("tj viwts VIWTJ ")
                try expect("việt viết VIỆT ", "quick Telex j, s and uppercase")
                try reset(); try type("viww ")
                try expect("viw ", "repeated quick modifier stays literal")
            }
            try scenario("english", round: round) {
                for word in ["view", "views", "viewer", "viewing", "VIEW", "Views", "swiss", "switch", "news", "password", "assess"] {
                    try reset(); try type(word)
                    try expect(word, "English live \(word)")
                    try type(" ")
                    try expect(word + " ", "English commit \(word)")
                }
                for (script, expected) in [("view⌫", "vie"), ("views⌫", "view"), ("view⌫w", "view"), ("views⌫s", "views"), ("viewss", "viewss"), ("vieww", "view"), ("viws⌫wtj", "việt"), ("viwtj⌫c", "việc"), ("viwtss", "viêts"), ("viwww", "viww")] {
                    try reset()
                    for character in script {
                        if character == "⌫" { try key(51) }
                        else { try type(String(character)) }
                    }
                    try expect(expected, "live edit \(script)")
                }
            }
            try scenario("selection", round: round) {
                try reset(); try type("vieetj nam ")
                try expect("việt nam ", "selection setup")
                try key(123, .maskCommand); try key(124)
                try key(124, .maskShift); try key(124, .maskShift)
                try type("a")
                try expect("vat nam ", "replace iệ with a")
                try key(51)
                try expect("vt nam ", "delete replacement preserving neighbours")
            }
            try scenario("focus", round: round) {
                try reset(); try type("vieet")
                try expect(abc ? "vieet" : "viêt", "uncommitted old field")
                if chrome { try key(48) } else { try findShortcut() }
                if !chrome, !CommandLine.arguments.contains("--raw-focus-race") {
                    var deadline = Date().addingTimeInterval(0.3)
                    while !description().localizedCaseInsensitiveContains("find"), Date() < deadline {
                        try guardTarget(); QA.settle(0.01)
                    }
                    if !description().localizedCaseInsensitiveContains("find"), !CommandLine.arguments.contains("--wait-focus") {
                        // VS Code can treat the first shortcut as part of composition.
                        // Count that host limitation and never send new text to the old field.
                        try expect(abc ? "vieet" : "viêt", "old field before host command retry")
                        output("HOST command retry after composition round=\(round)")
                        hostCommandRetries += 1
                        try key(3, .maskCommand)
                        deadline = Date().addingTimeInterval(2)
                        while !description().localizedCaseInsensitiveContains("find"), Date() < deadline {
                            try guardTarget(); QA.settle(0.01)
                        }
                    }
                    guard description().localizedCaseInsensitiveContains("find") else {
                        output("HOST Find did not open; focus=\(description()) value=\(value()?.debugDescription ?? "nil")")
                        throw QA.Failure.mismatch("Find did not receive focus before new input")
                    }
                }
                if !chrome { try key(0, .maskCommand) }
                try type("vieetj ")
                try expect(abc ? "vieetj " : "việt ", "immediate new field conversion")
                if !chrome, !description().localizedCaseInsensitiveContains("find") {
                    throw QA.Failure.mismatch("Find focus not confirmed after immediate input")
                }
                try editor()
                try expect(abc ? "vieet" : "viêt", "old field retained once")
            }
            if only == "shortcut" {
                try scenario("shortcut", round: round) {
                    try key(53)
                    try reset(); try type("vieet")
                    try expect("viêt", "shortcut composition setup")
                    guard let previousField = focused() else { throw QA.Failure.observation }
                    try findShortcut()
                    let deadline = Date().addingTimeInterval(2)
                    while Date() < deadline {
                        try guardTarget()
                        if let current = focused(), !CFEqual(current, previousField),
                           description().localizedCaseInsensitiveContains("find") { break }
                        QA.settle(0.01)
                    }
                    guard let current = focused(), !CFEqual(current, previousField),
                          description().localizedCaseInsensitiveContains("find") else {
                        output("FAIL first shortcut focus=\(description()) value=\(value()?.debugDescription ?? "nil")")
                        throw QA.Failure.mismatch("first Cmd+F must focus Find")
                    }
                    assertions += 1
                    try key(0, .maskCommand); try key(51)
                    try expect("", "Find cleared before new input")
                    try type("vieetj ")
                    try expect("việt ", "fast typing after Cmd+F and Cmd+A")
                    try key(53)
                    if chrome {
                        let closedDeadline = Date().addingTimeInterval(2)
                        while description().localizedCaseInsensitiveContains("find"), Date() < closedDeadline {
                            try guardTarget(); QA.settle(0.01)
                        }
                        guard !description().localizedCaseInsensitiveContains("find") else { throw QA.Failure.observation }
                        // Chrome can return focus to the page, not the original input.
                        // Observe that exact input, then explicitly restore it for caret QA.
                        let deadline = Date().addingTimeInterval(2)
                        while (QA.attribute(previousField, kAXValueAttribute) as? String) != "viêt", Date() < deadline {
                            try guardTarget(); QA.settle(0.01)
                        }
                        guard (QA.attribute(previousField, kAXValueAttribute) as? String) == "viêt" else {
                            throw QA.Failure.mismatch("original Chrome field changed after Find")
                        }
                        assertions += 1
                        guard AXUIElementSetAttributeValue(previousField, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else {
                            throw QA.Failure.observation
                        }
                    } else { try key(18, .maskCommand) }
                    try expect("viêt", "shortcut preserves original composition once")
                    try key(123); try key(123); try key(51)
                    try expect("vêt", "caret edit after closing Find")
                }
            }
            try scenario("chain", round: round) {
                try reset(); try type("cow ")
                try expect("cơ ", "prediction chain setup")
                try accept("cơ sở "); try accept("cơ sở dữ "); try accept("cơ sở dữ liệu ")
                try key(53)
            }
            try scenario("uppercase", round: round) {
                try reset(); try type("AP")
                try expect("AP", "uppercase prefix")
                try accept("API ")
                try key(53)
            }
            if only == "rewrite" {
                try scenario("rewrite", round: round) {
                    try reset(); try type("vieetj")
                    try expect("việt", "composed first word")
                    for _ in 0..<4 { try key(51) }
                    try type("Gawpj")
                    try expect("Gặp", "first word after erasing all of the composition")
                    try key(51); try type("p")
                    try expect("Gặp", "partial erase and retype")
                    try type(" "); try expect("Gặp ", "committed word before select all")
                    try key(0, .maskCommand)
                    let deadline = Date().addingTimeInterval(2)
                    var selected = false
                    repeat {
                        try guardTarget()
                        selected = focused().flatMap { QA.attribute($0, kAXSelectedTextAttribute) as? String } == "Gặp "
                        if !selected { QA.settle(0.01) }
                    } while !selected && Date() < deadline
                    guard selected else { throw QA.Failure.mismatch("selection not acknowledged") }
                    try key(51); try type("vieetj")
                    try expect("việt", "immediate rewrite after deleting selection")
                }
            }
            if let only, only == "appearance" || only == "appearance-sentence" {
                try scenario(only, round: round) {
                    try reset()
                    let lead = only == "appearance-sentence" ? "nam " : ""
                    if !lead.isEmpty { try type(lead); try expect(lead, "confirmed preceding word"); QA.settle(0.25) }
                    try type("Gawpj")
                    try expect(lead + "Gặp", "appearance sample before commit")
                    output("CAPTURE composing")
                    QA.settle(2)
                    try key(124)
                    try expect(lead + "Gặp", "same letters after right arrow")
                    output("CAPTURE committed")
                    QA.settle(2)
                }
            }
            if only == "prediction" {
                try scenario("prediction", round: round) {
                    try reset(); try type("nguw")
                    try expect("ngư", "local Vietnamese completion prefix")
                    try accept("người ")
                    try reset(); try type("baor veej mooi ")
                    try expect("bảo vệ môi ", "science phrase prefix")
                    try accept("bảo vệ môi trường ")
                    try reset(); try type("howpj ddoongf lao ")
                    try expect("hợp đồng lao ", "business phrase prefix")
                    try accept("hợp đồng lao động ")
                    try reset(); try type("JSON.pa")
                    try expect("JSON.pa", "code member prefix")
                    try accept("JSON.parse", offered: "parse")
                    try key(51); try expect("JSON.pars", "code completion has no trailing space")
                    try key(53)
                }
            }
            if only == "relevance" {
                try scenario("relevance", round: round) {
                    for (keys, written, unexpected) in [
                        ("Con ddang hocj ", "Con đang học ", "máy"),
                        ("Tooi vuwaf mua bao ", "Tôi vừa mua bao ", "mật"),
                    ] {
                        try reset(); try type(keys); try expect(written, "sentence before prediction")
                        let deadline = Date().addingTimeInterval(1)
                        repeat {
                            try guardTarget()
                            if panelVisible(), panelOffers(unexpected) {
                                throw QA.Failure.mismatch("irrelevant suggestion for " + written)
                            }
                            QA.settle(0.03)
                        } while Date() < deadline
                    }
                    try reset(); try type("cow sowr duwx li")
                    try expect("cơ sở dữ li", "phrase before completion")
                    try accept("cơ sở dữ liệu ")
                }
            }
            if only == "phrase-burst" {
                try scenario("phrase-burst", round: round) {
                    try reset(); try type("howpj ddoongf lao ")
                    try expect("hợp đồng lao ", "fast phrase before prediction")
                }
            }
            if only == "prediction-pause" {
                try scenario("prediction-pause", round: round) {
                    try reset(); try type("howpj ddo")
                    try expect("hợp đo", "same-length modifier before pause")
                    QA.settle(0.7)
                    try type("ongf lao ")
                    try expect("hợp đồng lao ", "composition survives typing pause")
                    try accept("hợp đồng lao động ")
                    try key(53)
                }
            }
            try scenario("caret", round: round) {
                try reset(); try type("vieet")
                try key(123); try key(123); try key(51)
                try expect("vêt", "native caret deletion")
            }
        }
        try key(53)
        output("STRESS QA PASSED cases=\(cases) assertions=\(assertions) accepted=\(accepted) physicalKeys=\(keys) hostCommandRetries=\(hostCommandRetries) modifierEvents=\(modifierEvents) elapsed=\(start.duration(to: .now))")
    }
}
