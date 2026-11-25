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
    case welcome, typing, habits, shortcuts, dictionary, about

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "Bắt đầu"
        case .typing: "Kiểu gõ"
        case .habits: "Thói quen gõ"
        case .shortcuts: "Gõ tắt"
        case .dictionary: "Từ điển"
        case .about: "Giới thiệu"
        }
    }

    var summary: String {
        switch self {
        case .welcome: "Ba bước làm quen và trạng thái nhanh của viTek."
        case .typing: "Telex hoặc VNI, cách đặt dấu và kiểm tra chính tả."
        case .habits: "Học cách gõ riêng trong mỗi ứng dụng."
        case .shortcuts: "Gõ chữ tắt, viTek thay bằng cụm đầy đủ."
        case .dictionary: "Giữ nguyên các từ tiếng Anh thông dụng khi gõ Telex."
        case .about: "Phiên bản, mã nguồn mở MIT và chẩn đoán."
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "sparkles"
        case .typing: "keyboard"
        case .habits: "globe"
        case .shortcuts: "text.badge.plus"
        case .dictionary: "character.book.closed"
        case .about: "info"
        }
    }

    var tint: Color {
        switch self {
        case .welcome: .cyan
        case .typing: .blue
        case .habits: .green
        case .shortcuts: .orange
        case .dictionary: .indigo
        case .about: .gray
        }
    }
}

/// Which page the window shows; the input menu can open it at a given page.
@MainActor @Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var page: SettingsPage = .welcome
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
            .navigationSplitViewColumnWidth(200)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(page: navigation.page)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                page(navigation.page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 740, idealWidth: 780, minHeight: 480, idealHeight: 560)
    }

    @ViewBuilder
    private func page(_ page: SettingsPage) -> some View {
        switch page {
        case .welcome: WelcomePage()
        case .typing: TypingPage()
        case .habits: TypingHabitsPage()
        case .shortcuts: ShortcutsPage()
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

struct PageHeader: View {
    let page: SettingsPage

    var body: some View {
        HStack(spacing: 14) {
            if page == .welcome || page == .about {
                MacAppIcon(size: 46)
            } else {
                PageIcon(page: page, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title).font(.title2.weight(.semibold))
                Text(page.summary).foregroundStyle(.secondary)
            }
        }
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
