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
        guard let target = WritingLink.resolve(url) else { return false }
        #if os(macOS)
        switch target {
        case .writing: WritingWindow.show(draft: "")
        case .clipboard: SettingsWindow.show(page: .clipboard)
        case .keyboard: SettingsWindow.show(page: .welcome)
        case .settings: SettingsWindow.show()
        }
        #else
        switch target {
        case .keyboard: destination = .keyboard
        case .writing: destination = .writing
        case .clipboard: destination = .clipboard
        case .settings: destination = .settings
        }
        #endif
        return true
    }
}
