import AppKit
import Observation
import SwiftUI

/// The settings window, opened from the input menu. The input method has no Dock icon, so the
/// window activates the app itself to take keyboard focus.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(page: SettingsPage? = nil) {
        if let page { SettingsNavigation.shared.page = page }
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Cài đặt viTek"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            if LiquidGlass.isAvailable {
                // A unified toolbar lets the split view float its sidebar as a Liquid Glass pane.
                window.toolbar = NSToolbar()
                window.toolbarStyle = .unified
            }
            window.setContentSize(NSSize(width: 780, height: 560))
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// The pages of the settings window, in sidebar order.
enum SettingsPage: String, CaseIterable, Identifiable {
    case typing, shortcuts, clipboard, dictionary, about

    var id: Self { self }

    var title: String {
        switch self {
        case .typing: "Bộ gõ"
        case .shortcuts: "Gõ tắt"
        case .clipboard: "Clipboard"
        case .dictionary: "Từ điển"
        case .about: "Giới thiệu"
        }
    }

    var symbol: String {
        switch self {
        case .typing: "keyboard"
        case .shortcuts: "text.badge.plus"
        case .clipboard: "doc.on.clipboard"
        case .dictionary: "character.book.closed"
        case .about: "info"
        }
    }

    var tint: Color {
        switch self {
        case .typing: .blue
        case .shortcuts: .orange
        case .clipboard: .teal
        case .dictionary: .indigo
        case .about: .gray
        }
    }
}

/// Which page the window shows; the input menu can open it at a given page.
@MainActor @Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var page: SettingsPage = .typing
}

struct SettingsView: View {
    @Bindable private var navigation = SettingsNavigation.shared

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding($navigation.page)) { page in
                Label {
                    Text(page.title)
                } icon: {
                    PageIcon(page: page, size: 20)
                }
                .padding(.vertical, 2)
            }
            .sidebarSurface()
            .navigationSplitViewColumnWidth(185)
        } detail: {
            page(navigation.page)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(navigation.page.title)
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 460, idealHeight: 540)
    }

    @ViewBuilder
    private func page(_ page: SettingsPage) -> some View {
        switch page {
        case .typing: TypingPage()
        case .shortcuts: ShortcutsPage()
        case .clipboard: ClipboardPage()
        case .dictionary: DictionaryPage()
        case .about: AboutPage()
        }
    }
}

/// An SF Symbol in a tinted rounded square, the way System Settings marks its panes.
struct PageIcon: View {
    let page: SettingsPage
    var size: CGFloat

    var body: some View {
        Image(systemName: page.symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(page.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

extension View {
    /// On macOS 26 and later, the sidebar floats as an inset Liquid Glass pane, the way the system's
    /// own settings windows draw it.
    @ViewBuilder
    func sidebarSurface() -> some View {
        if #available(macOS 26.0, *) {
            scrollContentBackground(.hidden)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(8)
        } else {
            self
        }
    }

    /// The grouped form every settings page uses, on the window's own background so the page header
    /// and the form read as one surface.
    func settingsForm() -> some View {
        formStyle(.grouped).scrollContentBackground(.hidden)
    }
}

/// Explanatory text under a settings group.
struct Footnote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A key, drawn like a keycap.
struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.secondary.opacity(0.35)))
    }
}
