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
        #if os(iOS)
        NavigationStack {
            studioBody
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("Gợi ý viết AI")
                .navigationBarTitleDisplayMode(.large)
        }
        #else
        studioBody
        #endif
    }

    private var studioBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerBanner
                modeStrip
                editorCard
                actionToolbar

                if draft.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count > WritingSuggestion.byteLimit {
                    Text("Đoạn nháp quá dài. Hãy chọn một đoạn ngắn hơn.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if work != nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(suggestion.isEmpty ? "Đang xử lý cục bộ trên thiết bị…" : "Đang sinh văn bản · \(suggestion.count) ký tự")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("writing.progress")
                    }
                }

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !suggestion.isEmpty {
                    resultCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
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

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            #if os(macOS)
            HStack(spacing: 10) {
                MacAppIcon(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trợ lý viết tiếng Việt").font(.title2.bold())
                    Text("Chạy 100% cục bộ bằng Apple Intelligence (FoundationModels + @Generable).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            #endif

            HStack(spacing: 8) {
                Image(systemName: readiness.canGenerate ? "sparkles" : "info.circle")
                    .foregroundStyle(readiness.canGenerate ? Color.accentColor : .secondary)
                Text(readiness.message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("writing.readiness")
                Spacer()
                if !readiness.canGenerate {
                    Button("Kiểm tra lại") {
                        readiness = WritingSuggestion.readiness()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }

    private var modeStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(WritingTaskMode.allCases, id: \.self) { item in
                        let isSelected = item == mode
                        Button {
                            mode = item
                            reset()
                        } label: {
                            Label(item.title, systemImage: item.symbolName)
                                .font(.caption.weight(isSelected ? .semibold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                                .glassEffect(
                                    isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Đoạn văn đầu vào")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                #if os(iOS)
                Button {
                    if let clip = UIPasteboard.general.string, !clip.isEmpty {
                        draft = clip
                    }
                } label: {
                    Label("Dán", systemImage: "doc.on.clipboard")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                #endif
                if !draft.isEmpty {
                    Button {
                        draft = ""
                        reset()
                    } label: {
                        Label("Xoá", systemImage: "xmark.circle")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }

            TextEditor(text: $draft)
                .writingToolsBehavior(.complete)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 124)
                .padding(10)
                .background(
                    Color.primary.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .accessibilityLabel("Đoạn đang viết")
                .accessibilityIdentifier("writing.draft")
                .onChange(of: draft) { reset(); prepare() }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var actionToolbar: some View {
        HStack(spacing: 10) {
            Button {
                generate()
            } label: {
                Label(mode.actionTitle, systemImage: mode.symbolName)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("writing.generate")
            .disabled(work != nil || !readiness.canGenerate || (try? WritingSuggestion.validatedDraft(draft)) == nil)

            if work != nil {
                Button("Huỷ") { reset() }
                    .buttonStyle(.glass)
            }
            Spacer()
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !changeNote.isEmpty {
                Label(changeNote, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(suggestion)
                .textSelection(.enabled)
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .accessibilityIdentifier("writing.result")

            if work == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(suggestion, forType: .string)
                                #else
                                UIPasteboard.general.string = suggestion
                                #endif
                            } label: {
                                Label("Sao chép", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)

                            Button {
                                if mode == .continueWriting {
                                    let sep = draft.hasSuffix(" ") || draft.isEmpty ? "" : " "
                                    draft = draft + sep + suggestion
                                } else {
                                    draft = suggestion
                                }
                                reset()
                            } label: {
                                Label(mode == .continueWriting ? "Nối vào nháp" : "Thay vào nháp", systemImage: "square.and.pencil")
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)

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
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
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
