import Observation
import SwiftUI

@available(macOS 26, iOS 26, *)
@MainActor @Observable final class WritingRoute {
    static let shared = WritingRoute()
    enum Destination: Hashable { case keyboard, writing, clipboard, settings }
    var destination: Destination = .keyboard

    func open() {
        #if os(macOS)
        WritingWindow.show(draft: "")
        #else
        destination = .writing
        #endif
    }

    @discardableResult func handle(_ url: URL) -> Bool {
        guard WritingLink.matches(url) else { return false }
        open()
        return true
    }
}
