import AppKit
import SwiftUI

@main
struct InstallerApp: App {
    @NSApplicationDelegateAdaptor(InstallerDelegate.self) private var delegate

    var body: some Scene {
        Window("Cài viTek", id: "install") { InstallerView() }
            .windowResizability(.contentSize)
    }
}

private final class InstallerDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private struct InstallerView: View {
    private enum Stage { case installing, activating, ready, failed(String) }
    @State private var stage = Stage.installing
    @State private var installed: URL?
    @State private var attempt = 0
    @State private var sample = ""
    @FocusState private var typing: Bool

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var currentStep: Int {
        switch stage {
        case .installing: 1
        case .activating: 2
        case .ready: 3
        case .failed: installed == nil ? 1 : 2
        }
    }

    private var typedVietnamese: Bool {
        sample.unicodeScalars.contains { $0.value > 127 && CharacterSet.letters.contains($0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            heroHeader
            stepProgressBar
            stageCard
            footerBar
        }
        .padding(24)
        .frame(width: 504)
        .background(installerBackdrop)
        .task(id: attempt) {
            do {
                if installed == nil {
                    stage = .installing
                    installed = try await Installation.install()
                }
                if let installed {
                    stage = .activating
                    try await Installation.reconnect(at: installed)
                    stage = .ready
                }
            } catch {
                stage = .failed(error.localizedDescription)
            }
        }
    }

    private var installerBackdrop: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.11),
                    Color.cyan.opacity(0.06),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var heroHeader: some View {
        HStack(spacing: 16) {
            BrandMascotView(size: 76)
                .shadow(color: Color.blue.opacity(0.16), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("viTek")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Liquid Glass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                    Text("MIT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                Text("Bộ gõ tiếng Việt 100% Swift 6 Native cho macOS")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !version.isEmpty {
                    Text("Phiên bản \(version) · Không cần quyền Trợ năng để gõ")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var stepProgressBar: some View {
        let row = HStack(spacing: 10) {
            stepPill(index: 1, title: "Cài bộ gõ")
            stepConnector(active: currentStep >= 2)
            stepPill(index: 2, title: "Kích hoạt")
            stepConnector(active: currentStep >= 3)
            stepPill(index: 3, title: "Gõ thử")
        }
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { row }
        } else {
            row
        }
    }

    @ViewBuilder
    private func stepPill(index: Int, title: String) -> some View {
        let isDone = currentStep > index || (index == 3 && typedVietnamese)
        let isCurrent = currentStep == index && !isDone
        let label = HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isCurrent ? Color.accentColor : Color.secondary.opacity(0.22)))
                    .frame(width: 20, height: 20)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(index)")
                        .font(.caption2.bold())
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }
            Text(title)
                .font(.caption.weight(isCurrent || isDone ? .semibold : .medium))
                .foregroundStyle(isCurrent || isDone ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        if #available(macOS 26.0, *) {
            label.glassEffect(
                isCurrent ? .regular.tint(.accentColor) : .regular,
                in: .capsule
            )
        } else {
            label.background(.quaternary.opacity(0.5), in: Capsule())
        }
    }

    private func stepConnector(active: Bool) -> some View {
        Capsule()
            .fill(active ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var stageCard: some View {
        let content = stageBody
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.secondary.opacity(0.18)))
        }
    }

    @ViewBuilder
    private var stageBody: some View {
        switch stage {
        case .installing, .activating:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 3) {
                    Text(installed == nil ? "Đang cài viTek vào ~/Library/Input Methods…" : "Đang kết nối nguồn nhập viTek…")
                        .font(.headline)
                    Text("Quá trình diễn ra nguyên tử ngay trên máy, giữ nguyên cài đặt cá nhân của bạn.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text("Đã cài và kích hoạt viTek sẵn sàng!")
                        .font(.headline)
                }
                Text("Thử gõ **vieetj**, **tuoongw** (Telex) hoặc **vie65t** (VNI) vào ô dưới đây:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("Gõ thử tiếng Việt ở đây…", text: $sample)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .onAppear { typing = true }

                let words = sample.lowercased().split(whereSeparator: \.isWhitespace)
                if typedVietnamese {
                    Label("Tuyệt vời! Bộ gõ viTek đang phản hồi mượt mà.", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                } else if sample.last?.isWhitespace == true, words.contains("vieetj") || words.contains("vie65t") {
                    HStack {
                        Text("Chưa thấy dấu? Hãy chọn viTek qua 🌐 hoặc ⌃ Space.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        reconnectButton
                    }
                } else {
                    HStack(spacing: 8) {
                        shortcutHint("⌥ ⌥", "VI ↔ EN")
                        shortcutHint("⌃ ⌥ V", "Clipboard")
                        shortcutHint("⌃ ⌥ A", "AI & Sửa chữ")
                    }
                }
            }

        case .failed(let reason):
            VStack(alignment: .leading, spacing: 10) {
                Label(installed == nil ? "Chưa cài được viTek" : "Đã cài viTek · Cần bật nguồn nhập",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    if installed != nil {
                        openKeyboardSettingsButton
                    }
                    Spacer()
                    retryButton
                }
            }
        }
    }

    private func shortcutHint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var reconnectButton: some View {
        let btn = Button("Kết nối lại") {
            Task {
                stage = .activating
                do {
                    if let installed { try await Installation.reconnect(at: installed) }
                    sample = ""
                    stage = .ready
                    typing = true
                } catch { stage = .failed(error.localizedDescription) }
            }
        }
        .controlSize(.small)
        if #available(macOS 26.0, *) { btn.buttonStyle(.glass) } else { btn }
    }

    @ViewBuilder
    private var openKeyboardSettingsButton: some View {
        let btn = Button("Mở Cài đặt Bàn phím…") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
        if #available(macOS 26.0, *) { btn.buttonStyle(.glass) } else { btn }
    }

    @ViewBuilder
    private var retryButton: some View {
        let btn = Button("Thử lại") { attempt += 1 }
            .keyboardShortcut(.defaultAction)
        if #available(macOS 26.0, *) { btn.buttonStyle(.glassProminent) } else { btn.buttonStyle(.borderedProminent) }
    }

    private var footerBar: some View {
        HStack {
            if let repoURL = URL(string: "https://github.com/luongbinhf/viTek") {
                Link(destination: repoURL) {
                    Label("github.com/luongbinhf/viTek", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            if case .ready = stage {
                finishButton
            } else {
                closeButton
            }
        }
    }

    @ViewBuilder
    private var finishButton: some View {
        let btn = Button("Hoàn tất") { NSApp.terminate(nil) }
            .keyboardShortcut(.defaultAction)
        if #available(macOS 26.0, *) { btn.buttonStyle(.glassProminent) } else { btn.buttonStyle(.borderedProminent) }
    }

    @ViewBuilder
    private var closeButton: some View {
        let btn = Button("Đóng") { NSApp.terminate(nil) }
        if #available(macOS 26.0, *) { btn.buttonStyle(.glass) } else { btn }
    }
}
