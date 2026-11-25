import AppKit

/// Platform hints for positioning suggestions. Typing uses native composition in every app.
@MainActor
enum AppCompatibility {
    private static var chromium: [String: Bool] = [:]

    /// True when `bundleID` is built on Chromium (Chrome, Edge, Electron apps such as Claude, Slack,
    /// VS Code). Such apps tell an input method where the caret is only while there is marked text
    /// (see `AccessibilityCaret`). Every Chromium build ships `chrome_crashpad_handler` in its
    /// framework, which is how they are recognised.
    static func isChromium(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        if let known = chromium[bundleID] { return known }
        var found = false
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let frameworks = app.appendingPathComponent("Contents/Frameworks")
            let names = (try? FileManager.default.contentsOfDirectory(atPath: frameworks.path)) ?? []
            found = names.contains { name in
                name.hasSuffix(".framework") && FileManager.default.fileExists(
                    atPath: frameworks.appendingPathComponent(name).appendingPathComponent("Helpers/chrome_crashpad_handler").path)
            }
        }
        chromium[bundleID] = found
        return found
    }
}
