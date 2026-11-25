import AppKit

@MainActor final class WritingAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard #available(macOS 26, *) else { return }
        for url in urls where WritingLink.matches(url) { WritingRoute.shared.handle(url) }
    }
}
