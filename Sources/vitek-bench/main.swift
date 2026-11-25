import Foundation
import VitekEngine
import VitekSession

// Measures how long one key takes through InputSession, the path every host uses.
// Run in release: `swift run -c release vitek-bench`. The budget is 50 µs per key at p99.

let telex = """
    Tooi yeeu tieengs Vieetj Nam. Hoom nay trowif ddepj quas, chungs tooi ddi dao quanh Hoof Guowm \
    vaf uoongs caf phee suwax ddas. Nguwowif Vieetj Nam raast hieeus khachs vaf thaan thieenj. \
    Ddaay laf mootj ddoanj vawn banr ddeer ddo toocs ddooj cuar booj gox: tieengs, nguwowif, khuyeenr, \
    nghieeng, quyeetj, giuwax, chuyeenj, thuowr, khoarng, ddwowcj. server express github test reset \
    vieetjj aaa ddd wwow tieengss Truwowngf Ddaij hocj Baachs khoa Haf Nooij.
    """
let vni = "Tie6ng1 Vie65t ra6t1 hay. Truo7ng72 dda5i ho5c, nguo7i72 Vie65t Nam, khuye6n3 khi1ch1."

var keys: [(Character, EngineOptions)] = []
for _ in 0..<60 { for key in telex { keys.append((key, EngineOptions())) } }
for _ in 0..<60 { for key in vni { keys.append((key, EngineOptions(inputMethod: .vni))) } }
var seed: UInt64 = 0x5EED
let alphabet = Array("abcdefghijklmnopqrstuvwxyz      .,sfrxjwaeod")
for _ in 0..<20_000 {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    keys.append((alphabet[Int(seed >> 33) % alphabet.count], EngineOptions()))
}

let clock = ContinuousClock()
var sessions: [InputMethod: InputSession] = [
    .telex: InputSession(engine: VitekEngine(options: EngineOptions())),
    .vni: InputSession(engine: VitekEngine(options: EngineOptions(inputMethod: .vni))),
]
var samples: [Duration] = []
samples.reserveCapacity(keys.count)
var sink = 0
for (key, options) in keys {
    let event: HostEvent = key == " " || key == "." || key == "," ? .boundary : .character(key)
    let start = clock.now
    let output = sessions[options.inputMethod]!.handle(event)
    samples.append(clock.now - start)
    sink &+= output.commands.count
}
if case .character = HostEvent.boundary { print(sink) }

func microseconds(_ d: Duration) -> Double {
    Double(d.components.seconds) * 1e6 + Double(d.components.attoseconds) / 1e12
}
let sorted = samples.map(microseconds).sorted()
func percentile(_ p: Double) -> Double { sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))] }
let mean = sorted.reduce(0, +) / Double(sorted.count)
print("keys: \(sorted.count)  first five: " + samples.prefix(5).map { String(format: "%.1f", microseconds($0)) }.joined(separator: " ") + " µs")
print("slowest after the first word: " + String(format: "%.2f", samples.dropFirst(8).map(microseconds).max()!) + " µs")
print("mean: \(String(format: "%.2f", mean)) µs  p50: \(String(format: "%.2f", percentile(0.5))) µs  "
      + "p99: \(String(format: "%.2f", percentile(0.99))) µs  max: \(String(format: "%.2f", sorted.last!)) µs")
print(percentile(0.99) < 50 ? "within the 50 µs p99 budget" : "OVER the 50 µs p99 budget")
