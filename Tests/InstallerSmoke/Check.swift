import Foundation

/// Run against the built installer. Keep the user's real input sources and preferences untouched.
@main struct InstallerSmoke {
    @MainActor static func main() async throws {
        if CommandLine.arguments.dropFirst().first == "--connection-responder" {
            serveConnection()
            return
        }
        let files = FileManager.default
        let installer = URL(fileURLWithPath: CommandLine.arguments[1])
        let payload = installer.appendingPathComponent("Contents/Helpers/viTek.app")
        for url in [installer, payload] {
            let bundle = Bundle(url: url)
            let icon = bundle?.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
            precondition(icon == "AppIcon" || icon == "AppIcon.icns")
            precondition(bundle?.url(forResource: "AppIcon", withExtension: "icns") != nil)
        }

        let temp = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: temp) }
        let target = temp.appendingPathComponent("Input Methods/viTek.app")
        try await Installation.update(from: payload, to: target)
        precondition(files.contentsEqual(atPath: payload.path, andPath: target.path))

        let obsolete = target.appendingPathComponent("obsolete")
        try Data().write(to: obsolete)
        do {
            try await Installation.update(from: temp.appendingPathComponent("missing.app"), to: target)
            fatalError("Accepted a missing installer payload")
        } catch {
            precondition(files.fileExists(atPath: obsolete.path))
        }
        try await Installation.update(from: payload, to: target)
        precondition(files.contentsEqual(atPath: payload.path, andPath: target.path))

        // Exercise the real distributed-notification transport from an async CLI, including
        // its run-loop delivery. No source is registered/enabled/selected by this check.
        // Give each run a unique bundle identity: an orphan from a failed test must never
        // answer for a later test and make the delayed-start check pass spuriously.
        let responderBundle = temp.appendingPathComponent("ConnectionResponder.app")
        let executable = responderBundle.appendingPathComponent("Contents/MacOS/ConnectionResponder")
        try files.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[0]), to: executable)
        let version = UUID().uuidString
        let plist = ["CFBundleExecutable": "ConnectionResponder", "CFBundleIdentifier": "io.github.luongbinhf.viTek.qa.responder",
                     "CFBundleVersion": version, "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: responderBundle.appendingPathComponent("Contents/Info.plist"))
        let responder = Process()
        responder.executableURL = executable
        responder.arguments = ["--connection-responder", "--delayed"]
        try responder.run()
        defer { responder.terminate(); responder.waitUntilExit() }
        let path = responderBundle
        let connectionStart = ContinuousClock.now
        let early = try await InputMethodConnection.check(version: version, bundleURL: path, timeout: .milliseconds(300))
        guard !early, connectionStart.duration(to: .now) >= .milliseconds(300) else {
            throw Installation.Failure(message: "Cold responder must time out before it starts")
        }
        let connected = try await InputMethodConnection.check(version: version, bundleURL: path)
        guard connected, connectionStart.duration(to: .now) >= .seconds(4) else {
            throw Installation.Failure(message: "Delayed responder failed: connected=\(connected)")
        }
        let clock = ContinuousClock(), start = ContinuousClock().now
        let wrongVersion = try await InputMethodConnection.check(version: version + "-wrong", bundleURL: path, timeout: .milliseconds(400))
        guard start.duration(to: clock.now) >= .milliseconds(400) else {
            throw Installation.Failure(message: "Handshake timed out before its deadline")
        }
        let wrongPath = try await InputMethodConnection.check(version: version, bundleURL: path.appendingPathComponent("wrong"), timeout: .milliseconds(400))
        let cancelled = Task { try await InputMethodConnection.check(version: version, bundleURL: path) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            throw Installation.Failure(message: "Cancelled handshake did not throw")
        } catch is CancellationError { }
        // Cancellation must win even when the deadline has already elapsed.
        let cancelledExpired = Task {
            try await InputMethodConnection.check(version: version, bundleURL: path, timeout: .zero)
        }
        cancelledExpired.cancel()
        do {
            _ = try await cancelledExpired.value
            throw Installation.Failure(message: "Cancelled expired handshake returned instead of throwing")
        } catch is CancellationError { }
        async let concurrentFirst = InputMethodConnection.check(version: version, bundleURL: path)
        async let concurrentSecond = InputMethodConnection.check(version: version, bundleURL: path)
        let concurrent = try await (concurrentFirst, concurrentSecond)
        guard concurrent.0 && concurrent.1 else {
            throw Installation.Failure(message: "Concurrent nonce handshakes interfered")
        }
        print("timeout then reconnect: passed; cancelled expired deadline: passed; concurrent nonces: passed")
        print("delayed responder: \(connected), wrong version: \(wrongVersion), wrong path: \(wrongPath)")
        guard !wrongVersion && !wrongPath else {
            throw Installation.Failure(message: "Accepted a mismatched responder")
        }
        print("Installer copy/update and connection handshake passed")
    }

    @MainActor private static func serveConnection() {
        if CommandLine.arguments.contains("--delayed") { Thread.sleep(forTimeInterval: 4) }
        let connection = InputMethodConnection.responder()
        withExtendedLifetime(connection) { RunLoop.main.run() }
    }
}
