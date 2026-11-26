import AppKit
import Observation
import SwiftUI
import VitekSession

@MainActor
@Observable
final class ClipboardPanelState {
    var items: [ClipboardItem] = []
    var selectedIndex = 0
    var searchQuery = ""
    var pinnedOnly = false
}

/// Minimal, high-speed Spotlight-style Liquid Glass Quick-Paste Palette (`⌃⌥V`).
/// Uses a single fixed-size card (`396 × 364 pt`) backed by `@Observable` state so
/// arrow navigation (`↑`/`↓`), hover, and live search incur zero panel resizes or view rebuilds.
@MainActor
enum ClipboardPanel {
    private static let panelSize = NSSize(width: 396, height: 364)
    private static let state = ClipboardPanelState()
    private static var glass: GlassPanel<ClipboardPopupView>?
    private static var lastCaret: NSRect = .zero
    private static var activePaste: (@MainActor (String) -> Void)?
    private(set) static var isVisible = false

    static func toggle(caret: NSRect, onPaste: @escaping @MainActor (String) -> Void) {
        if isVisible {
            hide()
            return
        }
        state.searchQuery = ""
        state.pinnedOnly = false
        state.selectedIndex = 0
        show(caret: caret, onPaste: onPaste)
    }

    static func show(caret: NSRect, onPaste: @escaping @MainActor (String) -> Void) {
        ClipboardMonitor.shared.checkPasteboard()
        lastCaret = caret
        activePaste = onPaste
        refreshItems()
        presentAtCaret()
    }

    static func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

        if event.keyCode == 0x35 { // Escape
            if !state.searchQuery.isEmpty {
                state.searchQuery = ""
                state.selectedIndex = 0
                refreshItems()
            } else {
                hide()
            }
            return true
        }

        if event.keyCode == 0x7E { // Up
            if !state.items.isEmpty {
                state.selectedIndex = (state.selectedIndex - 1 + state.items.count) % state.items.count
            }
            return true
        }
        if event.keyCode == 0x7D { // Down
            if !state.items.isEmpty {
                state.selectedIndex = (state.selectedIndex + 1) % state.items.count
            }
            return true
        }

        if event.keyCode == 0x30, mods.isEmpty { // Tab toggles All <-> Pinned
            state.pinnedOnly.toggle()
            state.selectedIndex = 0
            refreshItems()
            return true
        }

        if event.keyCode == 0x24 || event.keyCode == 0x4C { // Return / Enter
            guard state.items.indices.contains(state.selectedIndex), let onPaste = activePaste else {
                hide()
                return true
            }
            let raw = state.items[state.selectedIndex].text
            let output = mods.contains(.shift)
                ? TextConverter.convert(raw, mode: .autoToUnicode)
                : raw
            hide()
            onPaste(output)
            return true
        }

        if mods == [.command], event.keyCode == 0x23 { // ⌘P
            if state.items.indices.contains(state.selectedIndex) {
                SettingsStore.shared.togglePinClipboard(state.items[state.selectedIndex].text)
                refreshItems()
            }
            return true
        }

        let pasteDigits: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]
        if let digitIdx = pasteDigits.firstIndex(of: event.keyCode),
           mods == [.command] || (mods.isEmpty && state.searchQuery.isEmpty) {
            if pasteByNumber(digitIdx + 1) { return true }
        }

        if event.keyCode == 0x33 { // Backspace
            if !state.searchQuery.isEmpty {
                state.searchQuery.removeLast()
                state.selectedIndex = 0
                refreshItems()
            }
            return true
        }

        if mods.intersection([.command, .control, .option]).isEmpty,
           let chars = event.characters, !chars.isEmpty,
           chars.allSatisfy({ !$0.isNewline && $0 != "\t" }) {
            state.searchQuery.append(chars)
            state.selectedIndex = 0
            refreshItems()
            return true
        }

        return false
    }

    static func pasteByNumber(_ number: Int) -> Bool {
        guard isVisible, (1...9).contains(number) else { return false }
        let idx = number - 1
        guard state.items.indices.contains(idx), let onPaste = activePaste else { return false }
        let text = state.items[idx].text
        hide()
        onPaste(text)
        return true
    }

    static func hide() {
        isVisible = false
        state.items = []
        state.searchQuery = ""
        activePaste = nil
        glass?.hide()
    }

    private static func refreshItems() {
        let filter: ClipboardFilter = state.pinnedOnly ? .pinned : .all
        let items = Array(SettingsStore.shared.clipboardHistory.filter(filter, query: state.searchQuery).prefix(9))
        state.items = items
        state.selectedIndex = items.isEmpty ? 0 : min(max(0, state.selectedIndex), items.count - 1)
    }

    private static func presentAtCaret() {
        if glass == nil {
            let view = ClipboardPopupView(
                state: state,
                onPaste: { text in
                    let paste = activePaste
                    hide()
                    paste?(text)
                },
                onTogglePinnedFilter: { pinned in
                    state.pinnedOnly = pinned
                    state.selectedIndex = 0
                    refreshItems()
                },
                onClearSearch: {
                    state.searchQuery = ""
                    state.selectedIndex = 0
                    refreshItems()
                },
                onTogglePinItem: { text in
                    SettingsStore.shared.togglePinClipboard(text)
                    if isVisible { refreshItems() }
                },
                onManage: {
                    hide()
                    SettingsWindow.show(page: .clipboard)
                }
            )
            glass = GlassPanel(view, cornerStyle: .rounded(16), acceptsMouseEvents: true)
        }

        guard let glass else { return }
        let size = panelSize
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
}

struct ClipboardPopupView: View {
    let state: ClipboardPanelState
    let onPaste: @MainActor (String) -> Void
    let onTogglePinnedFilter: @MainActor (Bool) -> Void
    let onClearSearch: @MainActor () -> Void
    let onTogglePinItem: @MainActor (String) -> Void
    let onManage: @MainActor () -> Void
    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Single compact header: live search + 2-way filter toggle
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if state.searchQuery.isEmpty {
                        Text("Tìm clipboard…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(state.searchQuery)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    if !state.searchQuery.isEmpty {
                        Button {
                            onClearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Compact 2-state pill selector — fixed single line, never wraps
                HStack(spacing: 2) {
                    filterSegment(title: "Tất cả", isSelected: !state.pinnedOnly) {
                        onTogglePinnedFilter(false)
                    }
                    filterSegment(title: "Ghim", isSelected: state.pinnedOnly) {
                        onTogglePinnedFilter(true)
                    }
                }
                .padding(2)
                .background(.primary.opacity(0.06), in: Capsule())
                .fixedSize()
            }

            // Fixed-height single-column list (zero resize jitter)
            Group {
                if state.items.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: state.pinnedOnly ? "pin.slash" : "doc.on.clipboard")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                        Text(state.searchQuery.isEmpty
                             ? (state.pinnedOnly ? "Chưa có mục ghim nào" : "Chưa có lịch sử sao chép")
                             : "Không khớp “\(state.searchQuery)”")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 2) {
                        ForEach(Array(state.items.enumerated()), id: \.element.text) { idx, item in
                            rowView(idx: idx, item: item)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(height: 274)

            // Minimal footer: 3 essential hints + Settings icon button
            HStack(spacing: 6) {
                Text("↵ Dán")
                Text("·").foregroundStyle(.quaternary)
                Text("⇧↵ Unicode")
                Text("·").foregroundStyle(.quaternary)
                Text("⌘P Ghim")
                Spacer()
                Button {
                    onManage()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quản lý Clipboard trong Cài đặt")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 396, height: 364)
        .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func filterSegment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    isSelected ? Color.primary.opacity(0.12) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func rowView(idx: Int, item: ClipboardItem) -> some View {
        let isSelected = idx == state.selectedIndex
        let isHovered = hoveredIndex == idx

        return HStack(spacing: 8) {
            Text("\(idx + 1)")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 19, height: 19)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

            Group {
                if !item.alias.isEmpty {
                    HStack(spacing: 5) {
                        Text(item.alias)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(item.preview)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(item.preview)
                        .font(item.kind.usesMonospacedFont
                              ? .system(size: 12, design: .monospaced)
                              : .system(size: 12.5))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .truncationMode(.tail)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isPinned || isHovered {
                Button {
                    onTogglePinItem(item.text)
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10.5))
                        .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
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
        .onTapGesture {
            onPaste(item.text)
        }
        .onHover { inside in
            hoveredIndex = inside ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
            if inside { state.selectedIndex = idx }
        }
    }
}
