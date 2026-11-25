import Foundation
import VitekSession

let queries = [
    ("ngư", "ngư"), ("chuy", "chuy"), ("cơ sở d", "d"), ("co so du ", ""),
    ("bảo vệ môi ", ""), ("hợp đồng lao ", ""), ("chăm sóc sức ", ""),
    ("cảm ơn ", ""), ("chúc mừng ", ""), ("cafe", "cafe"), ("fire", "fire"),
    ("TypeS", "TypeS"), ("WebS", "WebS"), ("JSON.par", "par"),
    ("const userName = value; const result = us", "us"), ("https://example.com/ng", "ng"),
]
func microseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1e6 + Double(duration.components.attoseconds) / 1e12
}
// Read one context per line for paired out-of-sample next-token evaluation.
if CommandLine.arguments.contains("--contexts") {
    let lexicon = PredictionLexicon.standard
    while let context = readLine() {
        let start = ContinuousClock.now
        let words = WordPrediction.suggest(context: context, prefix: "", lexicon: lexicon).map(\.text)
        let elapsed = microseconds(ContinuousClock.now - start)
        let row = try JSONSerialization.data(withJSONObject: ["words": words, "us": elapsed])
        print(String(decoding: row, as: UTF8.self))
    }
    exit(0)
}
let start = ContinuousClock.now
let lexicon = PredictionLexicon.standard
let initialization = microseconds(ContinuousClock.now - start)
var examples: [[String: Any]] = []
for (context, prefix) in queries {
    examples.append(["context": context, "prefix": prefix,
                     "words": WordPrediction.suggest(context: context, prefix: prefix, lexicon: lexicon).map(\.text)])
}
var samples: [Double] = []
var sink = 0
for _ in 0..<1_000 {
    for (context, prefix) in queries {
        let began = ContinuousClock.now
        let results = WordPrediction.suggest(context: context, prefix: prefix, lexicon: lexicon)
        samples.append(microseconds(ContinuousClock.now - began))
        sink += results.count
    }
}
samples.sort()
let report: [String: Any] = [
    "entries": lexicon.entryCount, "words": lexicon.wordCount, "rejected": lexicon.rejectedEntryCount,
    "initialization_us": initialization, "queries": samples.count,
    "p50_us": samples[samples.count / 2], "p99_us": samples[samples.count * 99 / 100],
    "max_us": samples.last ?? 0, "checksum": sink, "examples": examples,
    "scope": "Local lookup, synthetic cases, warm process; excludes host, drawing and NSSpellChecker",
]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
