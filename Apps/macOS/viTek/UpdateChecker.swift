import AppKit
import CryptoKit
import Foundation

/// On-demand GitHub Releases checker & SHA-256 verified DMG updater triggered from Settings → About.
enum UpdateChecker {
    enum Status: Equatable, Sendable {
        case upToDate(version: String)
        case updateAvailable(version: String, pageURL: URL, dmgURL: URL?, sha256URL: URL?)
        case failed(String)
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Asset: Decodable, Sendable {
        let name: String
        let browser_download_url: String
    }

    private struct ReleaseResponse: Decodable, Sendable {
        let tag_name: String
        let html_url: String
        let assets: [Asset]
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/luongbinhf/viTek/releases/latest")!
    private static let installerBundleID = "io.github.luongbinhf.viTek.installer"

    static func check(currentVersion: String) async -> Status {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("viTek/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failed("Không thể kết nối GitHub Releases.")
            }
            let release = try JSONDecoder().decode(ReleaseResponse.self, from: data)
            let latest = normalizeVersion(release.tag_name)
            let current = normalizeVersion(currentVersion)
            if isNewer(latest, than: current), let pageURL = URL(string: release.html_url) {
                let dmgURL = release.assets
                    .first { $0.name.hasSuffix(".dmg") }
                    .flatMap { URL(string: $0.browser_download_url) }
                let sha256URL = release.assets
                    .first { $0.name.hasSuffix(".dmg.sha256") }
                    .flatMap { URL(string: $0.browser_download_url) }
                return .updateAvailable(version: latest, pageURL: pageURL, dmgURL: dmgURL, sha256URL: sha256URL)
            }
            return .upToDate(version: current)
        } catch {
            return .failed("Không kiểm tra được bản cập nhật.")
        }
    }

    static func parseExpectedSHA256(_ text: String) -> String? {
        for token in text.split(whereSeparator: { $0.isWhitespace }) {
            let trimmed = String(token).lowercased()
            if trimmed.count == 64, trimmed.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) {
                return trimmed
            }
        }
        return nil
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Downloads the release DMG, verifies its SHA-256 digest when provided, validates the bundled
    /// installer's identity, stages `Cài viTek.app`, and opens it cleanly.
    static func downloadAndLaunchInstaller(
        dmgURL: URL,
        sha256URL: URL?,
        onProgress: @MainActor @Sendable (String) -> Void
    ) async throws {
        await onProgress("Đang tải bản cập nhật…")
        let (dmgData, dmgResp) = try await URLSession.shared.data(from: dmgURL)
        guard let http = dmgResp as? HTTPURLResponse, (200..<300).contains(http.statusCode), !dmgData.isEmpty else {
            throw Failure(message: "Không tải được tệp cài đặt DMG.")
        }

        if let sha256URL {
            await onProgress("Đang xác minh chữ ký SHA-256…")
            let (shaData, shaResp) = try await URLSession.shared.data(from: sha256URL)
            guard let shaHTTP = shaResp as? HTTPURLResponse, (200..<300).contains(shaHTTP.statusCode),
                  let shaText = String(data: shaData, encoding: .utf8),
                  let expected = parseExpectedSHA256(shaText) else {
                throw Failure(message: "Không đọc được mã kiểm tra SHA-256 từ bản phát hành.")
            }
            let actual = sha256Hex(of: dmgData)
            guard actual == expected else {
                throw Failure(message: "Mã SHA-256 không khớp — đã huỷ cập nhật để đảm bảo an toàn.")
            }
        }

        await onProgress("Đang chuẩn bị bộ cài viTek…")
        let files = FileManager.default
        let workDir = files.temporaryDirectory.appendingPathComponent("viTek-Download-\(UUID().uuidString)")
        let mountDir = workDir.appendingPathComponent("mount")
        let dmgFile = workDir.appendingPathComponent("viTek.dmg")
        try files.createDirectory(at: mountDir, withIntermediateDirectories: true)

        var mounted = false
        defer {
            if mounted { _ = try? runHDIUtil(["detach", mountDir.path, "-quiet"]) }
            try? files.removeItem(at: workDir)
        }

        try dmgData.write(to: dmgFile, options: .atomic)
        try runHDIUtil(["attach", "-nobrowse", "-readonly", "-mountpoint", mountDir.path, dmgFile.path])
        mounted = true

        let mountedInstaller = mountDir.appendingPathComponent("Cài viTek.app")
        let payload = mountedInstaller.appendingPathComponent("Contents/Helpers/viTek.app")
        guard let bundle = Bundle(url: mountedInstaller),
              bundle.bundleIdentifier == installerBundleID,
              files.fileExists(atPath: payload.path) else {
            throw Failure(message: "Ảnh đĩa DMG không chứa bộ cài viTek hợp lệ.")
        }

        let stagingRoot = files.temporaryDirectory.appendingPathComponent("viTek-Update-\(UUID().uuidString)")
        try files.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        let stagedInstaller = stagingRoot.appendingPathComponent("Cài viTek.app")
        try files.copyItem(at: mountedInstaller, to: stagedInstaller)

        try? runHDIUtil(["detach", mountDir.path, "-quiet"])
        mounted = false

        await onProgress("Đang mở Cài viTek…")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: stagedInstaller, configuration: config)
    }

    private static func runHDIUtil(_ arguments: [String]) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = arguments
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw Failure(message: "Không gắn được ảnh đĩa cài đặt (\(proc.terminationStatus)).")
        }
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = parseComponents(candidate)
        let rhs = parseComponents(current)
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let l = index < lhs.count ? lhs[index] : 0
            let r = index < rhs.count ? rhs[index] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func normalizeVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    private static func parseComponents(_ version: String) -> [Int] {
        normalizeVersion(version).split(separator: ".").map { Int($0) ?? 0 }
    }
}
