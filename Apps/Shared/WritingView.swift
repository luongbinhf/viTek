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
    @State private var draft: String
    @State private var suggestion = ""
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
                HStack {
                    #if os(macOS)
                    MacAppIcon(size: 36)
                    #endif
                    Text("Gợi ý viết").font(.title.bold())
                }
                Text("Nhập đoạn đang viết để Apple Intelligence gợi ý câu tiếp theo trên thiết bị.")
                    .foregroundStyle(.secondary)
                Text(readiness.message)
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("writing.readiness")
                if !readiness.canGenerate {
                    Button("Kiểm tra lại Apple Intelligence") { readiness = WritingSuggestion.readiness() }
                }
                TextEditor(text: $draft)
                    .writingToolsBehavior(.complete)
                    .font(.body)
                    .frame(minHeight: 100)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))
                    .accessibilityLabel("Đoạn đang viết")
                    .accessibilityIdentifier("writing.draft")
                    .onChange(of: draft) { reset(); prepare() }
                HStack {
                    Button("Gợi ý câu tiếp theo") { generate() }
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
                    Text(suggestion.isEmpty ? "Đang chuẩn bị gợi ý…" : "Đang viết tiếp · \(suggestion.count) ký tự")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("writing.progress")
                }
                if let error { Text(error).foregroundStyle(.secondary) }
                if !suggestion.isEmpty {
                    Text(suggestion).textSelection(.enabled).accessibilityIdentifier("writing.result")
                    if work == nil {
                        Button("Sao chép gợi ý") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(suggestion, forType: .string)
                            #else
                            UIPasteboard.general.string = suggestion
                            #endif
                        }
                        .buttonStyle(.glass)
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
        if isVisible, readiness.canGenerate { generator.prepare() }
    }

    private func reset() {
        work?.cancel()
        work = nil
        suggestion = ""
        error = nil
    }

    private func generate() {
        reset()
        let input = draft
        work = Task { @MainActor in
            defer { if !Task.isCancelled { work = nil } }
            do {
                let result = try await generator.generate(from: input) { suggestion = $0 }
                if !Task.isCancelled { suggestion = result }
            } catch {
                guard !Task.isCancelled else { return }
                suggestion = ""
                self.error = error.localizedDescription
            }
        }
    }
}
