import AppKit
import SwiftUI
import VitekSession

/// Cursor-anchored Liquid Glass Quick Text & AI Action Palette (`⌃⌥A`).
/// Transforms either the currently selected text in the active client (replacing it in-place)
/// or the latest clipboard text using on-device Apple Intelligence (`@Generable`) and instant
/// Vietnamese encoding/case utilities (`TextConverter`).
@MainActor
enum QuickActionPanel {
    fileprivate struct ActionItem: Identifiable {
        enum Execution {
            case deterministic(TextConverter.LegacyEncoding)
            case aiRestoreDiacritics
            case aiProofreadHomophones
            case aiPolishProfessional
        }

        let id: String
        let title: String
        let subtitle: String
        let symbolName: String
        let tint: Color
        let isAI: Bool
        let execution: Execution
    }

    private static var glass: GlassPanel<QuickActionPopupView>?
    private static var actions: [ActionItem] = []
    private static var selectedIndex = 0
    private static var sourceText = ""
    private static var replacesSelection = false
    private static var lastCaret: NSRect = .zero
    private static var onApply: (@MainActor (String) -> Void)?
    private static var runningActionID: String?
    private static var errorMessage: String?
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
        runningActionID = nil
        errorMessage = nil
        self.lastCaret = caret
        self.sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : sourceText
        self.replacesSelection = replacesSelection
        self.onApply = onApply
        self.actions = buildActions()
        self.selectedIndex = 0
        render()
    }

    static func hide() {
        runningTask?.cancel()
        runningTask = nil
        runningActionID = nil
        errorMessage = nil
        isVisible = false
        actions = []
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
                runningActionID = nil
                render()
            } else {
                hide()
            }
            return true
        }

        guard runningActionID == nil else { return true }

        if event.keyCode == 0x7E { // Up
            if !actions.isEmpty {
                selectedIndex = (selectedIndex - 1 + actions.count) % actions.count
                render()
            }
            return true
        }
        if event.keyCode == 0x7D { // Down
            if !actions.isEmpty {
                selectedIndex = (selectedIndex + 1) % actions.count
                render()
            }
            return true
        }

        if event.keyCode == 0x24 || event.keyCode == 0x4C { // Return / Enter
            if actions.indices.contains(selectedIndex) {
                trigger(at: selectedIndex)
            } else {
                hide()
            }
            return true
        }

        let digitCodes: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]
        if (mods.isEmpty || mods == [.command]),
           let digitIdx = digitCodes.firstIndex(of: event.keyCode),
           actions.indices.contains(digitIdx) {
            trigger(at: digitIdx)
            return true
        }

        return false
    }

    private static func buildActions() -> [ActionItem] {
        var list: [ActionItem] = []
        if #available(macOS 26.0, *), WritingSuggestion.readiness().canGenerate {
            list.append(ActionItem(
                id: "ai.restore",
                title: "Khôi phục dấu tiếng Việt",
                subtitle: "Thêm dấu chuẩn ngữ cảnh bằng Apple Intelligence trên thiết bị",
                symbolName: "sparkles",
                tint: .indigo,
                isAI: true,
                execution: .aiRestoreDiacritics
            ))
            list.append(ActionItem(
                id: "ai.proofread",
                title: "Sửa chính tả đồng âm",
                subtitle: "Rà soát lỗi ch/tr, s/x, d/gi/r, hỏi/ngã trên thiết bị",
                symbolName: "doc.text.fill",
                tint: .blue,
                isAI: true,
                execution: .aiProofreadHomophones
            ))
            list.append(ActionItem(
                id: "ai.polish",
                title: "Chuẩn hoá lịch sự công sở",
                subtitle: "Diễn đạt mạch lạc, giữ nguyên số liệu & thuật ngữ",
                symbolName: "envelope.fill",
                tint: .teal,
                isAI: true,
                execution: .aiPolishProfessional
            ))
        }
        list.append(ActionItem(
            id: "conv.unicode",
            title: "Sửa lỗi font cũ → Unicode NFC",
            subtitle: "Tự động chuyển TCVN3, VNI Windows hoặc tổ hợp NFD sang dựng sẵn",
            symbolName: "bolt.horizontal.fill",
            tint: .orange,
            isAI: false,
            execution: .deterministic(.autoToUnicode)
        ))
        list.append(ActionItem(
            id: "conv.strip",
            title: "Bỏ dấu tiếng Việt",
            subtitle: "Chuyển sang chữ Latinh không dấu (đ → d)",
            symbolName: "textformat",
            tint: .mint,
            isAI: false,
            execution: .deterministic(.stripAccents)
        ))
        list.append(ActionItem(
            id: "conv.title",
            title: "Viết Hoa Đầu Từ",
            subtitle: "Chuẩn hoá chữ hoa đầu mỗi từ tiếng Việt",
            symbolName: "text.alignleft",
            tint: .purple,
            isAI: false,
            execution: .deterministic(.titleCase)
        ))
        list.append(ActionItem(
            id: "conv.upper",
            title: "CHỮ HOA TIẾNG VIỆT",
            subtitle: "Chuyển toàn bộ đoạn văn sang chữ in hoa Unicode",
            symbolName: "shift.fill",
            tint: .pink,
            isAI: false,
            execution: .deterministic(.uppercase)
        ))
        return list
    }

    private static func trigger(at index: Int) {
        guard actions.indices.contains(index) else { return }
        guard !sourceText.isEmpty else {
            errorMessage = "Hãy bôi đen văn bản hoặc sao chép nội dung vào Clipboard trước."
            render()
            return
        }
        selectedIndex = index
        let action = actions[index]
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
            runningActionID = action.id
            errorMessage = nil
            render()
            runningTask = Task { @MainActor in
                do {
                    let output = try await WritingSuggestion.runTask(mode: taskMode, input: input)
                    guard !Task.isCancelled, isVisible else { return }
                    hide()
                    apply?(output.text)
                } catch {
                    guard !Task.isCancelled, isVisible else { return }
                    runningActionID = nil
                    runningTask = nil
                    errorMessage = error.localizedDescription
                    render()
                }
            }
        }
    }

    private static func render() {
        let view = QuickActionPopupView(
            sourcePreview: previewText(for: sourceText),
            hasSourceText: !sourceText.isEmpty,
            replacesSelection: replacesSelection,
            actions: actions,
            selectedIndex: selectedIndex,
            runningActionID: runningActionID,
            errorMessage: errorMessage,
            onHoverIndex: { idx in
                guard runningActionID == nil else { return }
                selectedIndex = idx
                render()
            },
            onTriggerIndex: { idx in
                trigger(at: idx)
            },
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

        let glass = glass ?? GlassPanel(view, cornerStyle: .rounded(16), acceptsMouseEvents: true)
        self.glass = glass
        let size = glass.update(view)
        let screen = (lastCaret != .zero
            ? NSScreen.screens.first { $0.frame.contains(lastCaret.origin) }?.visibleFrame
            : nil)
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        var origin: NSPoint
        if lastCaret != .zero {
            origin = NSPoint(x: lastCaret.minX, y: lastCaret.minY - size.height - 10)
            if origin.y < screen.minY + 10 {
                origin.y = min(screen.maxY - size.height - 10, lastCaret.maxY + 10)
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
        guard !collapsed.isEmpty else {
            return "Chưa có văn bản được chọn hoặc trong Bộ nhớ tạm"
        }
        if collapsed.count <= 84 { return collapsed }
        return String(collapsed.prefix(84)) + "…"
    }
}

private struct QuickActionPopupView: View {
    let sourcePreview: String
    let hasSourceText: Bool
    let replacesSelection: Bool
    let actions: [QuickActionPanel.ActionItem]
    let selectedIndex: Int
    let runningActionID: String?
    let errorMessage: String?
    let onHoverIndex: @MainActor (Int) -> Void
    let onTriggerIndex: @MainActor (Int) -> Void
    let onOpenStudio: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Công cụ chữ & AI nhanh")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text(replacesSelection ? "Thay vùng đang chọn" : "Xử lý Clipboard")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(replacesSelection ? Color.accentColor : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .glassFilterChip(isSelected: replacesSelection)
                    }
                    Text(sourcePreview)
                        .font(.system(size: 11.5))
                        .foregroundStyle(hasSourceText ? .secondary : .tertiary)
                        .lineLimit(1)
                        .padding(.vertical, 0.5)
                }

                Spacer(minLength: 6)

                if #available(macOS 26.0, *) {
                    Button {
                        onOpenStudio()
                    } label: {
                        Label("Mở rộng", systemImage: "arrow.up.right.square")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .glassButton()
                    .controlSize(.small)
                }
            }

            VStack(spacing: 3) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { idx, item in
                    let isSelected = idx == selectedIndex
                    let isRunning = runningActionID == item.id
                    Button {
                        onTriggerIndex(idx)
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )

                            Image(systemName: item.symbolName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(item.tint)
                                .frame(width: 24, height: 24)
                                .background(item.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                            VStack(alignment: .leading, spacing: 1.5) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    if item.isAI {
                                        Text("AI trên máy")
                                            .font(.system(size: 9.5, weight: .semibold))
                                            .foregroundStyle(.indigo)
                                            .padding(.horizontal, 5.5)
                                            .padding(.vertical, 1)
                                            .background(Color.indigo.opacity(0.12), in: Capsule())
                                    }
                                }
                                Text(item.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if isRunning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasSourceText || runningActionID != nil)
                    .onHover { inside in
                        if inside { onHoverIndex(idx) }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Text("↑↓ chọn")
                Text("·").foregroundStyle(.quaternary)
                Text("1–\(actions.count) thực thi ngay")
                Text("·").foregroundStyle(.quaternary)
                Text("↵ áp dụng")
                Text("·").foregroundStyle(.quaternary)
                Text("Esc đóng")
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
        }
        .padding(14)
        .frame(width: 468)
        .fixedSize(horizontal: false, vertical: true)
        .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
