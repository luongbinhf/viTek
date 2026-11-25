import AppKit
import SwiftUI

@available(macOS 26, *)
@MainActor enum WritingWindow {
    private static var window: NSWindow?

    static func show(draft: String) {
        let window = self.window ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 380),
                                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Gợi ý viết · viTek"
        window.isReleasedWhenClosed = false
        if self.window == nil { window.center() }
        if !window.isVisible || !draft.isEmpty {
            window.contentView = NSHostingView(rootView: WritingView(draft: draft))
        }
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
