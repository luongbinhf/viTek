#if os(macOS)
import AppKit

/// A nonce/version handshake verifies that selection reached a live input-method process.
/// No typed text, application context, or preferences are sent through distributed notifications.
@MainActor final class InputMethodConnection: NSObject {
    private static let ping = Notification.Name("io.github.luongbinhf.viTek.connection.ping")
    private static let pong = Notification.Name("io.github.luongbinhf.viTek.connection.pong")
    private let center = DistributedNotificationCenter.default()
    private var expectedNonce: String?
    private var expectedVersion: String?
    private var expectedPath: String?
    private var answered = false

    static func responder() -> InputMethodConnection {
        let connection = InputMethodConnection()
        connection.center.addObserver(connection, selector: #selector(reply(_:)), name: ping, object: nil)
        return connection
    }

    static func check(version: String, bundleURL: URL, timeout: Duration = .seconds(8)) async throws -> Bool {
        try Task.checkCancellation()
        let connection = InputMethodConnection()
        let nonce = UUID().uuidString
        connection.expectedNonce = nonce
        connection.expectedVersion = version
        connection.expectedPath = bundleURL.standardizedFileURL.path
        connection.center.addObserver(connection, selector: #selector(receive(_:)), name: pong, object: nonce)
        defer { connection.center.removeObserver(connection) }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try Task.checkCancellation()
            connection.center.postNotificationName(ping, object: nonce, userInfo: nil, deliverImmediately: true)
            // The dev installer is an async CLI, not an NSApplication. Distributed notifications
            // use the CF run loop; awaiting Task.sleep alone does not service that delivery path.
            connection.receiveReplies()
            try Task.checkCancellation()
            if connection.answered { return true }
            // An empty run loop can return immediately. Count elapsed time, not iterations;
            // also yield real time for a cold IMK server to launch and register its responder.
            try await Task.sleep(for: min(.milliseconds(100), clock.now.duration(to: deadline)))
        }
        try Task.checkCancellation()
        return false
    }

    private func receiveReplies() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.025))
    }

    @objc private func reply(_ notification: Notification) {
        guard let nonce = notification.object as? String else { return }
        #if DEBUG
        // Local installer QA only. Release cannot suppress connection replies via defaults.
        if UserDefaults.standard.bool(forKey: "qaConnectionDropReplies") { return }
        #endif
        center.postNotificationName(Self.pong, object: nonce,
                                    userInfo: ["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                                               "path": Bundle.main.bundleURL.standardizedFileURL.path],
                                    deliverImmediately: true)
    }

    @objc private func receive(_ notification: Notification) {
        if notification.object as? String == expectedNonce,
           notification.userInfo?["version"] as? String == expectedVersion,
           notification.userInfo?["path"] as? String == expectedPath { answered = true }
    }
}
#endif
