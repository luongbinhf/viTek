import Foundation
import VitekEngine
import VitekSession

// vitek — type key scripts through the engine and print the text they produce.
//
//   vitek "vieetj nam"                 → việt nam
//   vitek --vni "Vie65t Nam"           → Việt Nam
//   echo "hoaf binhf" | vitek --traditional
//
// `⌫` in a script is Backspace. With no script arguments, each line of standard input is a script.

let usage = """
    usage: vitek [--vni] [--traditional] [--no-spell-check] [--keep-invalid] [--brackets] [--no-english] [script ...]
    """

var options = EngineOptions(automaticallyDetectsMethod: true)
var scripts: [String] = []
for argument in CommandLine.arguments.dropFirst() {
    switch argument {
    case "--vni":
        options.automaticallyDetectsMethod = false
        options.inputMethod = .vni
    case "--telex":
        options.automaticallyDetectsMethod = false
        options.inputMethod = .telex
    case "--traditional": options.toneStyle = .traditional
    case "--no-spell-check": options.spellCheck = false
    case "--keep-invalid": options.restoreInvalidWords = false
    case "--brackets": options.bracketVowels = true
    case "--no-english": options.keepEnglishWords = false
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        if argument.hasPrefix("--") {
            print(usage)
            exit(64)
        }
        scripts.append(argument)
    }
}

@MainActor func run(_ script: String) -> String {
    SimulatedTextField.result(of: script, session: InputSession(engine: VitekEngine(options: options)))
}

if scripts.isEmpty {
    while let line = readLine() { print(run(line)) }
} else {
    print(run(scripts.joined(separator: " ")))
}
