import AppKit
import Observation
import SwiftUI
import VitekSession

@MainActor
@Observable
final class QuickActionPanelState {
    var sourcePreview = ""
    var hasSourceText = false
    var replacesSelection = false
    var actions: [QuickActionPanel.ActionItem] = []
    var selectedIndex = 0
    var runningActionID: String?
    var errorMessage: String?
}

/// Minimal, Spotlight-style Liquid Glass Quick Text & AI Action Palette (`⌃⌥A`).
/// Backed by `@Observable` state so arrow navigation (`↑`/`↓`) and hover incur
/// zero panel resizes or view rebuilds.
@MainActor
enum QuickActionPanel {
    struct ActionItem: Identifiable {
        enum Execution {
            case deterministic(TextConverter.LegacyEncoding)
            case aiRestoreDiacritics
            case aiProofreadHomophones
            case aiPolishProfessional
        }

        let id: String
        let title: String
        let isAI: Bool
        let execution: Execution
    }

    private static let state = QuickActionPanelState()
    private static var glass: GlassPanel<QuickActionPopupView>?
    private static var sourceText = ""
    private static var lastCaret: NSRect = .zero
    private static var onApply: (@MainActor (String) -> Void)?
    private static var runningTask: Task<Void, Never>?
    private(set) static var isVisible = false

    static func toggle(
        caret: NSRect,
        sourceText: String,
        replacesSelection: Bool,
        onApply: @escaping @MainActor (String) -> Void
    ) {
        if isVisible {
            hide()
            return
        }
        show(caret: caret, sourceText: sourceText, replacesSelection: replacesSelection, onApply: onApply)
    }

    static func show(
        caret: NSRect,
        sourceText: String,
        replacesSelection: Bool,
        onApply: @escaping @MainActor (String) -> Void
    ) {
        runningTask?.cancel()
        runningTask = nil
        lastCaret = caret
        let clean = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : sourceText
        self.sourceText = clean
        self.onApply = onApply

        state.sourcePreview = previewText(for: clean)
        state.hasSourceText = !clean.isEmpty
        state.replacesSelection = replacesSelection
        state.actions = buildActions()
        state.selectedIndex = 0
        state.runningActionID = nil
        state.errorMessage = nil

        presentAtCaret()
    }

    static func hide() {
        runningTask?.cancel()
        runningTask = nil
        state.runningActionID = nil
        state.errorMessage = nil
        state.actions = []
        isVisible = false
        onApply = nil
        glass?.hide()
    }

    static func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

        if event.keyCode == 0x35 { // Escape
            if runningTask != nil {
                runningTask?.cancel()
                runningTask = nil
                state.runningActionID = nil
            } else {
                hide()
            }
            return true
        }

        guard state.runningActionID == nil else { return true }

        if event.keyCode == 0x7E { // Up
            if !state.actions.isEmpty {
                state.selectedIndex = (state.selectedIndex - 1 + state.actions.count) % state.actions.count
            }
            return true
        }
        if event.keyCode == 0x7D { // Down
            if !state.actions.isEmpty {
                state.selectedIndex = (state.selectedIndex + 1) % state.actions.count
            }
            return true
        }

        if event.keyCode == 0x24 || event.keyCode == 0x4C { // Return / Enter
            if state.actions.indices.contains(state.selectedIndex) {
                trigger(at: state.selectedIndex)
            } else {
                hide()
            }
            return true
        }

        let digitCodes: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]
        if (mods.isEmpty || mods == [.command]),
           let digitIdx = digitCodes.firstIndex(of: event.keyCode),
           state.actions.indices.contains(digitIdx) {
            trigger(at: digitIdx)
            return true
        }

        return false
    }

    private static func buildActions() -> [ActionItem] {
        var list: [ActionItem] = []
        if #available(macOS 26.0, *), WritingSuggestion.readiness().canGenerate {
            list.append(ActionItem(id: "ai.restore", title: "Khôi phục dấu tiếng Việt", isAI: true, execution: .aiRestoreDiacritics))
            list.append(ActionItem(id: "ai.proofread", title: "Sửa chính tả đồng âm", isAI: true, execution: .aiProofreadHomophones))
            list.append(ActionItem(id: "ai.polish", title: "Chuẩn hoá lịch sự công sở", isAI: true, execution: .aiPolishProfessional))
        }
        list.append(ActionItem(id: "conv.unicode", title: "Sửa font cũ → Unicode NFC", isAI: false, execution: .deterministic(.autoToUnicode)))
        list.append(ActionItem(id: "conv.strip", title: "Bỏ dấu tiếng Việt", isAI: false, execution: .deterministic(.stripAccents)))
        list.append(ActionItem(id: "conv.title", title: "Viết Hoa Đầu Từ", isAI: false, execution: .deterministic(.titleCase)))
        list.append(ActionItem(id: "conv.upper", title: "CHỮ HOA TIẾNG VIỆT", isAI: false, execution: .deterministic(.uppercase)))
        return list
    }

    private static func trigger(at index: Int) {
        guard state.actions.indices.contains(index) else { return }
        guard !sourceText.isEmpty else {
            state.errorMessage = "Hãy bôi đen văn bản hoặc sao chép trước."
            return
        }
        state.selectedIndex = index
        let action = state.actions[index]
        let input = sourceText
        let apply = onApply

        switch action.execution {
        case .deterministic(let mode):
            let converted = TextConverter.convert(input, mode: mode)
            hide()
            apply?(converted)

        case .aiRestoreDiacritics, .aiProofreadHomophones, .aiPolishProfessional:
            guard #available(macOS 26.0, *) else { return }
            let taskMode: WritingTaskMode = switch action.execution {
            case .aiRestoreDiacritics: .restoreDiacritics
            case .aiProofreadHomophones: .proofreadHomophones
            case .aiPolishProfessional: .polishProfessional
            case .deterministic: .proofreadHomophones
            }
            state.runningActionID = action.id
            state.errorMessage = nil
            runningTask = Task { @MainActor in
                do {
                    let output = try await WritingSuggestion.runTask(mode: taskMode, input: input)
                    guard !Task.isCancelled, isVisible else { return }
                    hide()
                    apply?(output.text)
                } catch {
                    guard !Task.isCancelled, isVisible else { return }
                    state.runningActionID = nil
                    runningTask = nil
                    state.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private static func presentAtCaret() {
        if glass == nil {
            let view = QuickActionPopupView(
                state: state,
                onTriggerIndex: { idx in trigger(at: idx) },
                onOpenStudio: {
                    let draft = sourceText
                    hide()
                    if #available(macOS 26.0, *) {
                        WritingWindow.show(draft: draft)
                    } else {
                        SettingsWindow.show(page: .clipboard)
                    }
                }
            )
            glass = GlassPanel(view, cornerStyle: .rounded(16), acceptsMouseEvents: true)
        }

        guard let glass else { return }
        let rowHeight: CGFloat = 30
        let panelHeight = CGFloat(state.actions.count) * rowHeight + 88
        let size = NSSize(width: 348, height: panelHeight)
        let screen = (lastCaret != .zero
            ? NSScreen.screens.first { $0.frame.contains(lastCaret.origin) }?.visibleFrame
            : nil)
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        var origin: NSPoint
        if lastCaret != .zero {
            origin = NSPoint(x: lastCaret.minX, y: lastCaret.minY - size.height - 8)
            if origin.y < screen.minY + 10 {
                origin.y = min(screen.maxY - size.height - 10, lastCaret.maxY + 8)
            }
        } else {
            origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, screen.minX + 10), screen.maxX - size.width - 10)
        origin.y = min(max(origin.y, screen.minY + 10), screen.maxY - size.height - 10)

        isVisible = true
        glass.show(at: NSRect(origin: origin, size: size))
    }

    private static func previewText(for raw: String) -> String {
        let collapsed = raw
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return "Chưa có văn bản" }
        return collapsed.count <= 56 ? collapsed : String(collapsed.prefix(56)) + "…"
    }
}

private struct QuickActionPopupView: View {
    let state: QuickActionPanelState
    let onTriggerIndex: @MainActor (Int) -> Void
    let onOpenStudio: @MainActor () -> Void
    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Compact source preview header
            HStack(spacing: 6) {
                Text(state.replacesSelection ? "Đang chọn:" : "Clipboard:")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Text(state.sourcePreview)
                    .font(.system(size: 12))
                    .foregroundStyle(state.hasSourceText ? .primary : .tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if #available(macOS 26.0, *) {
                    Button {
                        onOpenStudio()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Mở khung AI Viết")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Compact single-line action rows
            VStack(spacing: 2) {
                ForEach(Array(state.actions.enumerated()), id: \.element.id) { idx, item in
                    let isSelected = idx == state.selectedIndex
                    let isHovered = hoveredIndex == idx
                    let isRunning = state.runningActionID == item.id

                    HStack(spacing: 8) {
                        Text("\(idx + 1)")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .frame(width: 19, height: 19)
                            .background(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                            )

                        Text(item.title)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.vertical, 1)

                        Spacer(minLength: 4)

                        if isRunning {
                            ProgressView().controlSize(.small)
                        } else if item.isAI {
                            Text("AI")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.indigo)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.indigo.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected
                                  ? Color.accentColor.opacity(0.16)
                                  : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .opacity((!state.hasSourceText || state.runningActionID != nil) ? 0.5 : 1)
                    .onTapGesture {
                        guard state.hasSourceText, state.runningActionID == nil else { return }
                        onTriggerIndex(idx)
                    }
                    .onHover { inside in
                        hoveredIndex = inside ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
                        if inside, state.runningActionID == nil { state.selectedIndex = idx }
                    }
                }
            }

            if let error = state.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }

            // Minimal footer
            HStack(spacing: 6) {
                Text("↵ Áp dụng")
                Text("·").foregroundStyle(.quaternary)
                Text("1–\(state.actions.count) chọn nhanh")
                Text("·").foregroundStyle(.quaternary)
                Text("Esc đóng")
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 348)
        .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
