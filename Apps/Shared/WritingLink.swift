import Foundation

/// Only navigation crosses the URL boundary; drafts never travel in widget/deep-link URLs.
enum WritingLink {
    static let url = URL(string: "vitek://writing")!

    static func matches(_ url: URL) -> Bool {
        url.scheme == "vitek" && url.host == "writing" && (url.path.isEmpty || url.path == "/")
            && url.query == nil && url.fragment == nil && url.user == nil && url.password == nil && url.port == nil
    }
}
