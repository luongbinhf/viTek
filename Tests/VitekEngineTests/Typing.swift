@testable import VitekEngine

/// Types a word through the engine the way a host would, and returns what gets committed.
/// `⌫` is Backspace. Keys the engine refuses end the word and are appended as typed.
func typed(_ script: String, _ options: EngineOptions = EngineOptions()) -> String {
    var engine = VitekEngine(options: options)
    var output = ""
    for key in script {
        if key == "⌫" {
            if !engine.deleteBackward(), !output.isEmpty { output.removeLast() }
        } else if !engine.type(key) {
            output += engine.finish()?.text ?? ""
            output.append(key)
        }
    }
    output += engine.finish()?.text ?? ""
    return output
}

/// What the text field shows while the keys are still being composed.
func composing(_ script: String, _ options: EngineOptions = EngineOptions()) -> String {
    var engine = VitekEngine(options: options)
    for key in script {
        if key == "⌫" { _ = engine.deleteBackward() } else { _ = engine.type(key) }
    }
    return engine.composition
}

let vni = EngineOptions(inputMethod: .vni)
let traditional = EngineOptions(toneStyle: .traditional)
