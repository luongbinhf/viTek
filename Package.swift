// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "viTek",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "VitekEngine", targets: ["VitekEngine"]),
        .library(name: "VitekSession", targets: ["VitekSession"]),
        .executable(name: "vitek", targets: ["vitek-cli"]),
    ],
    targets: [
        // Vietnamese orthography and keystroke composition. Pure Swift standard library: no Foundation
        // overhead, so the same code runs fast in the macOS input method and memory-constrained iOS
        // keyboard extension.
        .target(name: "VitekEngine"),
        // The editing protocol between the engine and any host: key events in, insert/mark commands out.
        .target(name: "VitekSession", dependencies: ["VitekEngine"]),
        .executableTarget(name: "vitek-cli", dependencies: ["VitekSession"]),
        /// Regenerates Sources/VitekEngine/EnglishWordList.swift; a development tool, not a product.
        .executableTarget(name: "vitek-wordlist", dependencies: ["VitekEngine"]),
        /// Per-key latency through InputSession; `swift run -c release vitek-bench`.
        .executableTarget(name: "vitek-bench", dependencies: ["VitekSession"]),
        /// Local dictionary latency and reproducible prediction examples, independent of macOS spellcheck.
        .executableTarget(name: "vitek-prediction-bench", dependencies: ["VitekSession"]),
        /// Reproducible accuracy benchmark for Vietnamese orthography, bilingual code-switching, and semantic ranking.
        .executableTarget(name: "vitek-eval", dependencies: ["VitekEngine", "VitekSession"]),
        .testTarget(name: "VitekEngineTests", dependencies: ["VitekEngine"]),
        .testTarget(name: "VitekSessionTests", dependencies: ["VitekSession"]),
        .testTarget(name: "RepositoryTests"),
    ],
    swiftLanguageModes: [.v6]
)
