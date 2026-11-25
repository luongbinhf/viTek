import Foundation
import Testing

/// The version scheme of docs/ARCHITECTURE.md §8: one `VERSION` file (`YYYYMMDD.X.YYY`), read by every build.
@Suite struct VersionTests {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private var version: String {
        get throws { try read("VERSION").trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    @Test func versionIsDateReleaseBuild() throws {
        let version = try version
        #expect(version.wholeMatch(of: /(20\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\.(\d+)\.(\d{3})/) != nil,
                "VERSION is \(version)")
        #expect(!version.hasSuffix(".000"), "build numbers start at 001")
    }

    @Test func macOSBuildSettingsMatchVersion() throws {
        let config = try read("Apps/macOS/Config/Version.xcconfig")
        let version = try version
        #expect(config.contains("MARKETING_VERSION = \(version)\n"))
        #expect(config.contains("CURRENT_PROJECT_VERSION = \(version)\n"))
    }

    @Test func iOSBuildSettingsUseUnpaddedAppStoreVersion() throws {
        let config = try read("Apps/iOS/Config/Version.xcconfig")
        let parts = try version.split(separator: ".").compactMap { Int($0) }
        #expect(parts.count == 3)
        let unpadded = "\(parts[0]).\(parts[1]).\(parts[2])"
        #expect(config.contains("MARKETING_VERSION = \(unpadded)\n"))
        #expect(config.contains("CURRENT_PROJECT_VERSION = \(unpadded)\n"))
    }
}
