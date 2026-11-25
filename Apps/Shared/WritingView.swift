import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@available(macOS 26, iOS 26, *)
struct WritingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var readiness = WritingSuggestion.readiness()
    @State private var mode: WritingTaskMode = .continueWriting
    @State private var draft: String
    @State private var suggestion = ""
    @State private var changeNote = ""
    @State private var error: String?
    @State private var work: Task<Void, Never>?
    @State private var generator = WritingSuggestion.Generator()
    @State private var isVisible = false

    init(draft: String = "") {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    #if os(macOS)
                    MacAppIcon(size: 36)
                    #endif
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trợ lý viết tiếng Việt").font(.title2.bold())
                        Text("Chạy 100% cục bộ bằng Apple Intelligence (`FoundationModels` + `@Generable`).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(readiness.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("writing.readiness")

                if !readiness.canGenerate {
                    Button("Kiểm tra lại Apple Intelligence") { readiness = WritingSuggestion.readiness() }
                }

                // Task mode pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(WritingTaskMode.allCases, id: \.self) { item in
                            let isSelected = item == mode
                            Button {
                                mode = item
                                reset()
                            } label: {
                                Label(item.title, systemImage: item.symbolName)
                                    .font(.caption.weight(isSelected ? .semibold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                TextEditor(text: $draft)
                    .writingToolsBehavior(.complete)
                    .font(.body)
                    .frame(minHeight: 110)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)))
                    .accessibilityLabel("Đoạn đang viết")
                    .accessibilityIdentifier("writing.draft")
                    .onChange(of: draft) { reset(); prepare() }

                HStack(spacing: 10) {
                    Button {
                        generate()
                    } label: {
                        Label(mode.actionTitle, systemImage: mode.symbolName)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("writing.generate")
                    .disabled(work != nil || !readiness.canGenerate || (try? WritingSuggestion.validatedDraft(draft)) == nil)

                    if work != nil {
                        ProgressView().controlSize(.small)
                        Button("Huỷ") { reset() }
                    }
                }

                if draft.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count > WritingSuggestion.byteLimit {
                    Text("Đoạn nháp quá dài. Hãy chọn một đoạn ngắn hơn.").foregroundStyle(.secondary)
                }

                if work != nil {
                    Text(suggestion.isEmpty ? "Đang xử lý trên thiết bị…" : "Đang sinh văn bản · \(suggestion.count) ký tự")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("writing.progress")
                }

                if let error {
                    Text(error).foregroundStyle(.secondary)
                }

                if !suggestion.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !changeNote.isEmpty {
                            Label(changeNote, systemImage: "sparkles")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(suggestion)
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityIdentifier("writing.result")

                        if work == nil {
                            HStack(spacing: 8) {
                                Button {
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(suggestion, forType: .string)
                                    #else
                                    UIPasteboard.general.string = suggestion
                                    #endif
                                } label: {
                                    Label("Sao chép kết quả", systemImage: "doc.on.clipboard")
                                }
                                .buttonStyle(.glass)

                                Button {
                                    if mode == .continueWriting {
                                        let sep = draft.hasSuffix(" ") || draft.isEmpty ? "" : " "
                                        draft = draft + sep + suggestion
                                    } else {
                                        draft = suggestion
                                    }
                                    reset()
                                } label: {
                                    Label(mode == .continueWriting ? "Nối vào ô nháp" : "Thay vào ô nháp", systemImage: "square.and.pencil")
                                }
                                .buttonStyle(.glass)

                                Button {
                                    #if os(macOS)
                                    SettingsStore.shared.addPinnedClipboard(suggestion, alias: mode.title)
                                    #else
                                    IOSKeyboardSettings.shared.addPinnedClipboard(suggestion, alias: mode.title)
                                    #endif
                                } label: {
                                    Label("Ghim Clipboard", systemImage: "pin.fill")
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .onAppear { isVisible = true; prepare() }
        .onDisappear { isVisible = false; reset(); generator.discardPreparation() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { readiness = WritingSuggestion.readiness(); prepare() }
            else if phase == .background { reset(); generator.discardPreparation() }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            generator.discardPreparation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            generator.discardPreparation()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            generator.discardPreparation()
        }
        #else
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            generator.discardPreparation()
        }
        #endif
    }

    private func prepare() {
        #if os(macOS)
        guard NSApp.isActive else { return }
        #else
        guard scenePhase == .active else { return }
        #endif
        if isVisible, readiness.canGenerate, mode == .continueWriting { generator.prepare() }
    }

    private func reset() {
        work?.cancel()
        work = nil
        suggestion = ""
        changeNote = ""
        error = nil
    }

    private func generate() {
        reset()
        let input = draft
        let activeMode = mode
        work = Task { @MainActor in
            defer { if !Task.isCancelled { work = nil } }
            do {
                let output = try await generator.runTask(mode: activeMode, input: input) { suggestion = $0 }
                if !Task.isCancelled {
                    suggestion = output.text
                    changeNote = output.note
                }
            } catch {
                guard !Task.isCancelled else { return }
                suggestion = ""
                changeNote = ""
                self.error = error.localizedDescription
            }
        }
    }
}
