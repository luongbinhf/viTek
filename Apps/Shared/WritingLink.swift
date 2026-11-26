import Foundation

/// Only safe tab navigation crosses the URL boundary; arbitrary query/path payloads are always rejected.
enum WritingLink {
    enum RouteTarget: String, Sendable {
        case keyboard
        case writing
        case clipboard
        case settings
    }

    static let url = URL(string: "vitek://writing")!
    static let clipboardURL = URL(string: "vitek://clipboard")!
    static let keyboardURL = URL(string: "vitek://keyboard")!

    static func resolve(_ url: URL) -> RouteTarget? {
        guard url.scheme == "vitek",
              let host = url.host,
              let target = RouteTarget(rawValue: host),
              (url.path.isEmpty || url.path == "/"),
              url.query == nil,
              url.fragment == nil,
              url.user == nil,
              url.password == nil,
              url.port == nil else {
            return nil
        }
        return target
    }

    static func matches(_ url: URL) -> Bool {
        resolve(url) == .writing
    }
}
