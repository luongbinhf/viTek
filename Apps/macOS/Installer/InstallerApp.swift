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
        sample.lowercased().split(whereSeparator: \.isWhitespace).contains("việt")
    }

    var body: some View {
        VStack(spacing: 0) {
            heroHeader
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                stepProgressBar
                stageContent
            }
            .padding(24)
            Divider()
            footerBar
        }
        .frame(width: 484)
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

    private var heroHeader: some View {
        HStack(spacing: 16) {
            BrandMascotView(size: 76)
                .shadow(color: Color.blue.opacity(0.14), radius: 8, y: 3)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("viTek")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("MIT Open Source")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                Text("Bộ gõ tiếng Việt 100% Swift Native cho macOS")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !version.isEmpty {
                    Text("Phiên bản \(version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var stepProgressBar: some View {
        HStack(spacing: 10) {
            stepPill(index: 1, title: "Cài đặt")
            stepConnector(active: currentStep >= 2)
            stepPill(index: 2, title: "Kích hoạt")
            stepConnector(active: currentStep >= 3)
            stepPill(index: 3, title: "Gõ thử")
        }
    }

    private func stepPill(index: Int, title: String) -> some View {
        let isDone = currentStep > index || (index == 3 && typedVietnamese)
        let isCurrent = currentStep == index && !isDone
        return HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isCurrent ? Color.accentColor : Color.secondary.opacity(0.2)))
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
                .font(.caption.weight(isCurrent || isDone ? .semibold : .regular))
                .foregroundStyle(isCurrent || isDone ? .primary : .secondary)
        }
    }

    private func stepConnector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2))
            .frame(height: 1.5)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .installing, .activating:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(installed == nil ? "Đang cài viTek vào Input Methods…" : "Đang bật nguồn nhập viTek…")
                        .font(.headline)
                    Text("Hoàn toàn trên máy, không cần quyền Trợ năng để gõ.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.secondary.opacity(0.18)))

        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text("Đã cài và bật viTek thành công!")
                        .font(.headline)
                }
                Text("Gõ thử **vieetj** (Telex) hoặc **vie65t** (VNI) rồi nhấn dấu cách để ra “việt”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("Gõ thử ở đây…", text: $sample)
                    .textFieldStyle(.roundedBorder)
                    .focused($typing)
                    .onAppear { typing = true }
                let words = sample.lowercased().split(whereSeparator: \.isWhitespace)
                if typedVietnamese {
                    Label("Tuyệt vời! Bạn đã gõ được tiếng Việt với viTek.", systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                } else if sample.last?.isWhitespace == true, words.contains("vieetj") || words.contains("vie65t") {
                    HStack {
                        Text("Chưa thấy dấu? Hãy chọn viTek qua 🌐 hoặc ⌃ Space.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Kết nối lại") {
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
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.secondary.opacity(0.18)))

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
                        Button("Mở cài đặt Bàn phím…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    Spacer()
                    Button("Thử lại") { attempt += 1 }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.orange.opacity(0.35)))
        }
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
                Button("Hoàn tất") { NSApp.terminate(nil) }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Đóng") { NSApp.terminate(nil) }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}
