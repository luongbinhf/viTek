import Foundation

/// On-demand GitHub Releases checker triggered only when the user clicks "Kiểm tra bản cập nhật…".
enum UpdateChecker {
    enum Status: Equatable, Sendable {
        case upToDate(version: String)
        case updateAvailable(version: String, url: URL)
        case failed(String)
    }

    private struct ReleaseResponse: Decodable, Sendable {
        let tag_name: String
        let html_url: String
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/luongbinhf/viTek/releases/latest")!

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
            if isNewer(latest, than: current), let url = URL(string: release.html_url) {
                return .updateAvailable(version: latest, url: url)
            }
            return .upToDate(version: current)
        } catch {
            return .failed("Không kiểm tra được bản cập nhật.")
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
