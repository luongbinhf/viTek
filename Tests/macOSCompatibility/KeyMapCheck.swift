import AppKit
import VitekSession

@main struct KeyMapCheck {
    static func main() {
        let codes: [UInt16] = [0x7A,0x78,0x63,0x76,0x60,0x61,0x62,0x64,0x65,0x6D,
                               0x67,0x6F,0x69,0x6B,0x71,0x6A,0x40,0x4F,0x50,0x5A]
        var failures = 0
        for (index, code) in codes.enumerated() {
            let characters = String(UnicodeScalar(0xF704 + index)!)
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters,
                isARepeat: false, keyCode: code)!
            if case .boundary = KeyMap.hostEvent(for: event) { }
            else { print("FAIL F\(index + 1) must invalidate the document anchor"); failures += 1 }
        }
        let modifiers: [(NSEvent.EventType, UInt16, NSEvent.ModifierFlags, Bool)] = [
            (.flagsChanged, 55, .command, true),
            (.flagsChanged, 54, .command, true),
            (.flagsChanged, 55, [.command, .shift], true),
            (.flagsChanged, 55, [], false),
            (.flagsChanged, 56, .shift, false),
            (.flagsChanged, 58, .option, false),
            (.flagsChanged, 59, .control, false),
            (.flagsChanged, 56, [.command, .shift], false),
            (.keyDown, 3, .command, false),
        ]
        for (type, code, flags, expected) in modifiers {
            let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: code)!
            if KeyMap.endsCompositionBeforeShortcut(for: event, commandIsCurrentlyDown: true) != expected {
                print("FAIL shortcut boundary type=\(type.rawValue) keyCode=\(code) flags=\(flags.rawValue)")
                failures += 1
            }
            if KeyMap.endsCompositionBeforeShortcut(for: event, commandIsCurrentlyDown: false) {
                print("FAIL obsolete modifier notification must not end new composition")
                failures += 1
            }
        }
        guard failures == 0 else { exit(1) }
        print("PASS all 20 function keys are boundaries")
        print("PASS 18 modifier/shortcut boundary cases, including obsolete Command notifications")
    }
}
