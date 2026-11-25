import Foundation
import os

/// An opt-in log for diagnosing how an app talks to viTek. It records event kinds, lengths and the
/// path taken, never the characters typed. Off unless turned on:
///
///     defaults write io.github.luongbinhf.inputmethod.viTek diagnostics -bool YES
///
/// Streams to Apple Unified Logging (`os.Logger`) and appends to `~/Library/Logs/viTek/diagnostics.log`
/// via a dedicated Swift actor.
enum Diagnostics {
    #if DEBUG
    /// QA only: deliver even after cancellation, like a non-cooperative completion service.
    /// Bounded and excluded from Release. No text is recorded.
    static func delaySuggestionDelivery() async {
        let milliseconds = min(5000, max(0, UserDefaults.standard.integer(forKey: "qaSuggestionDelayMilliseconds")))
        guard milliseconds > 0 else { return }
        log("QA suggestion delay begin ms=\(milliseconds)")
        await Task.detached {
            try? await Task.sleep(for: .milliseconds(milliseconds))
        }.value
        log("QA suggestion delay end cancelled=\(Task.isCancelled)")
    }
    #endif

    private static let logger = Logger(subsystem: "io.github.luongbinhf.inputmethod.viTek", category: "diagnostics")
    private static let sink = FileSink()
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "diagnostics") }

    static func log(_ message: @autoclosure () -> String) {
        guard isOn else { return }
        let time = Date(), text = message()
        logger.debug("\(text, privacy: .public)")
        Task(priority: .utility) { await sink.write(text, at: time) }
    }

    private actor FileSink {
        private let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/viTek/diagnostics.log")

        func write(_ text: String, at time: Date) {
            let line = Data("\(time.formatted(.iso8601.time(includingFractionalSeconds: true))) \(text)\n".utf8)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(line)
                try? handle.close()
            } else {
                try? line.write(to: url)
            }
        }
    }
}
