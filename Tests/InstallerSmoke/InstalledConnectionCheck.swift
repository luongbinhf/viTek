import AppKit
import Carbon

/// Explicit integration test of the installed bundle; DEBUG mode adds reversible fault injection.
/// Unlike Check.swift, this intentionally restarts the user's installed viTek process.
@main struct InstalledConnectionCheck {
    @MainActor static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("INSTALLED CONNECTION QA FAILED: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    @MainActor static func run() async throws {
        guard CommandLine.arguments.count == 3,
              ["--debug-installed", "--release-installed"].contains(CommandLine.arguments[1]) else {
            throw Installation.Failure(message: "Expected --debug-installed or --release-installed and exact installed viTek.app path")
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
        guard let bundle = Bundle(url: url), bundle.bundleIdentifier == Installation.bundleID,
              let executable = bundle.executableURL else {
            throw Installation.Failure(message: "Not an installed viTek bundle")
        }
        let before = try Data(contentsOf: executable)
        guard let defaults = UserDefaults(suiteName: Installation.bundleID) else {
            throw Installation.Failure(message: "Missing viTek defaults suite")
        }
        let previous = defaults.object(forKey: "qaConnectionDropReplies")
        defer {
            if let previous { defaults.set(previous, forKey: "qaConnectionDropReplies") }
            else { defaults.removeObject(forKey: "qaConnectionDropReplies") }
            defaults.synchronize()
        }
        defaults.set(false, forKey: "qaConnectionDropReplies")
        defaults.synchronize()
        // Leave the IME before terminating its exact installed process.
        guard let fallback = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              TISSelectInputSource(fallback) == noErr else {
            throw Installation.Failure(message: "Could not leave viTek for cold restart")
        }
        try await Task.sleep(for: .milliseconds(200))
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Installation.bundleID)
            .filter { $0.bundleURL?.standardizedFileURL == url }
        for process in running where !process.isTerminated {
            guard process.terminate() else { throw Installation.Failure(message: "Could not terminate installed viTek") }
        }
        for _ in 0..<40 {
            if running.allSatisfy(\.isTerminated) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard running.allSatisfy(\.isTerminated) else { throw Installation.Failure(message: "Old viTek process still running") }
        try await Installation.reconnect(at: url)
        print("PASS cold installed IME restart and handshake")
        if CommandLine.arguments[1] == "--release-installed" { return }

        defaults.set(true, forKey: "qaConnectionDropReplies")
        defaults.synchronize()
        try await Task.sleep(for: .milliseconds(300))
        let start = ContinuousClock.now
        do {
            try await Installation.reconnect(at: url)
            throw Installation.Failure(message: "Fault injection inactive: reconnect unexpectedly succeeded")
        } catch let failure as Installation.Failure {
            guard failure.message.contains("viTek chưa trả lời") else { throw failure }
        }
        let elapsed = start.duration(to: .now)
        guard elapsed >= .seconds(8), elapsed < .seconds(12) else {
            throw Installation.Failure(message: "Unexpected installed timeout duration: \(elapsed)")
        }
        guard try Data(contentsOf: executable) == before else {
            throw Installation.Failure(message: "Timeout changed the installed executable")
        }
        print("PASS forced installed timeout after \(elapsed); bundle preserved")
        defaults.set(false, forKey: "qaConnectionDropReplies")
        defaults.synchronize()
        try await Task.sleep(for: .milliseconds(300))
        try await Installation.reconnect(at: url)
        print("PASS installed reconnect after timeout")
    }
}
