import AppKit
import SwiftUI
import VitekSession

/// Floating Liquid Glass Quick-Paste Palette (`⌃⌥V`), using continuous 16pt card geometry (`GlassCornerStyle.rounded(16)`),
/// `GlassEffectContainer` filter chips, full Vietnamese line-height spacing, live accent-insensitive search,
/// and keyboard navigation (`↑↓`, `↵`, `⇧↵`, `⌘P`, `Tab`, `1–9`, `Esc`).
@MainActor
enum ClipboardPanel {
    private static var glass: GlassPanel<ClipboardPopupView>?
    private static var activeItems: [ClipboardItem] = []
    private static var selectedIndex = 0
    private static var searchQuery = ""
    private static var filter: ClipboardFilter = .all
    private static var lastCaret: NSRect = .zero
    private static var activePaste: (@MainActor (String) -> Void)?
    private(set) static var isVisible = false

    static func toggle(caret: NSRect, onPaste: @escaping @MainActor (String) -> Void) {
        if isVisible {
            hide()
            return
        }
        searchQuery = ""
        filter = .all
        selectedIndex = 0
        show(caret: caret, onPaste: onPaste)
    }

    static func show(caret: NSRect, onPaste: @escaping @MainActor (String) -> Void) {
        ClipboardMonitor.shared.checkPasteboard()
        lastCaret = caret
        activePaste = onPaste
        render()
    }

    static func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

        if event.keyCode == 0x35 { // Escape
            if !searchQuery.isEmpty {
                searchQuery = ""
                selectedIndex = 0
                render()
            } else {
                hide()
            }
            return true
        }

        if event.keyCode == 0x7E { // Up
            if !activeItems.isEmpty {
                selectedIndex = (selectedIndex - 1 + activeItems.count) % activeItems.count
                render()
            }
            return true
        }
        if event.keyCode == 0x7D { // Down
            if !activeItems.isEmpty {
                selectedIndex = (selectedIndex + 1) % activeItems.count
                render()
            }
            return true
        }

        if event.keyCode == 0x30, mods.isEmpty { // Tab
            let cases = ClipboardFilter.allCases
            if let idx = cases.firstIndex(of: filter) {
                filter = cases[(idx + 1) % cases.count]
                selectedIndex = 0
                render()
            }
            return true
        }

        if event.keyCode == 0x24 || event.keyCode == 0x4C { // Return / Enter
            guard activeItems.indices.contains(selectedIndex), let onPaste = activePaste else {
                hide()
                return true
            }
            let raw = activeItems[selectedIndex].text
            let output = mods.contains(.shift)
                ? TextConverter.convert(raw, mode: .autoToUnicode)
                : raw
            hide()
            onPaste(output)
            return true
        }

        if mods == [.command], event.keyCode == 0x23 { // ⌘P
            if activeItems.indices.contains(selectedIndex) {
                SettingsStore.shared.togglePinClipboard(activeItems[selectedIndex].text)
                render()
            }
            return true
        }

        let pasteDigits: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]
        if let digitIdx = pasteDigits.firstIndex(of: event.keyCode),
           mods == [.command] || (mods.isEmpty && searchQuery.isEmpty) {
            if pasteByNumber(digitIdx + 1) { return true }
        }

        if event.keyCode == 0x33 { // Backspace
            if !searchQuery.isEmpty {
                searchQuery.removeLast()
                selectedIndex = 0
                render()
            }
            return true
        }

        if mods.intersection([.command, .control, .option]).isEmpty,
           let chars = event.characters, !chars.isEmpty,
           chars.allSatisfy({ !$0.isNewline && $0 != "\t" }) {
            searchQuery.append(chars)
            selectedIndex = 0
            render()
            return true
        }

        return false
    }

    static func pasteByNumber(_ number: Int) -> Bool {
        guard isVisible, (1...9).contains(number) else { return false }
        let idx = number - 1
        guard activeItems.indices.contains(idx), let onPaste = activePaste else { return false }
        let text = activeItems[idx].text
        hide()
        onPaste(text)
        return true
    }

    static func hide() {
        isVisible = false
        activeItems = []
        activePaste = nil
        searchQuery = ""
        glass?.hide()
    }

    private static func render() {
        let items = Array(SettingsStore.shared.clipboardHistory.filter(filter, query: searchQuery).prefix(9))
        activeItems = items
        selectedIndex = items.isEmpty ? 0 : min(max(0, selectedIndex), items.count - 1)

        let view = ClipboardPopupView(
            items: items,
            selectedIndex: selectedIndex,
            searchQuery: searchQuery,
            activeFilter: filter,
            onSelectIndex: { idx in
                selectedIndex = idx
                render()
            },
            onPaste: { text in
                let paste = activePaste
                hide()
                paste?(text)
            },
            onSelectFilter: { next in
                filter = next
                selectedIndex = 0
                render()
            },
            onClearSearch: {
                searchQuery = ""
                selectedIndex = 0
                render()
            },
            onTogglePin: { text in
                SettingsStore.shared.togglePinClipboard(text)
                if isVisible { render() }
            },
            onManage: {
                hide()
                SettingsWindow.show(page: .clipboard)
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
}

struct ClipboardPopupView: View {
    let items: [ClipboardItem]
    let selectedIndex: Int
    let searchQuery: String
    let activeFilter: ClipboardFilter
    let onSelectIndex: @MainActor (Int) -> Void
    let onPaste: @MainActor (String) -> Void
    let onSelectFilter: @MainActor (ClipboardFilter) -> Void
    let onClearSearch: @MainActor () -> Void
    let onTogglePin: @MainActor (String) -> Void
    let onManage: @MainActor () -> Void
    @State private var hoveredIndex: Int?

    private var selectedItem: ClipboardItem? {
        items.indices.contains(selectedIndex) ? items[selectedIndex] : items.first
    }

    var body: some View {
        let now = Int(Date().timeIntervalSince1970)
        VStack(alignment: .leading, spacing: 10) {
            // Header row: icon + live search bar + Manage button
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.teal.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text("Clipboard")
                        .font(.system(size: 13.5, weight: .semibold))
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if searchQuery.isEmpty {
                        Text("Gõ trực tiếp để tìm (hỗ trợ không dấu & ngữ nghĩa)…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(searchQuery)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if !searchQuery.isEmpty {
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    onManage()
                } label: {
                    Label("Quản lý", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                }
                .glassButton()
                .controlSize(.small)
            }

            // Native macOS 26/27 GlassEffectContainer filter chips
            filterStrip

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 26))
                        .foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty
                         ? "Chưa có mục Clipboard nào trong nhóm này.\nSao chép văn bản hoặc ghim mẫu cố định trong Cài đặt."
                         : "Không tìm thấy mục nào khớp “\(searchQuery)”.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .padding(.horizontal, 16)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(alignment: .top, spacing: 10) {
                    // Left column: spacious 1–9 rows with full Vietnamese diacritic clearance
                    VStack(spacing: 3) {
                        ForEach(Array(items.enumerated()), id: \.element.text) { idx, item in
                            let isSelected = idx == selectedIndex
                            Button {
                                onPaste(item.text)
                            } label: {
                                HStack(spacing: 9) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? .white : .secondary)
                                        .frame(width: 20, height: 20)
                                        .background(
                                            isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        )

                                    ClipboardKindBadge(item: item, size: 26)

                                    VStack(alignment: .leading, spacing: 2) {
                                        if !item.alias.isEmpty {
                                            Text(item.alias)
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                                .padding(.vertical, 0.5)
                                        }
                                        Text(item.preview)
                                            .font(item.kind.usesMonospacedFont
                                                  ? .system(size: item.alias.isEmpty ? 12 : 11, design: .monospaced)
                                                  : .system(size: item.alias.isEmpty ? 12.5 : 11.5))
                                            .foregroundStyle(item.alias.isEmpty ? .primary : .secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .padding(.vertical, 1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    if item.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(isSelected
                                              ? Color.accentColor.opacity(0.18)
                                              : (hoveredIndex == idx ? Color.primary.opacity(0.06) : Color.clear))
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .onHover { inside in
                                hoveredIndex = inside ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
                                if inside { onSelectIndex(idx) }
                            }
                        }
                    }
                    .frame(width: 320)

                    // Right column: seamless detail card
                    if let current = selectedItem {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                ClipboardKindBadge(item: current, size: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(current.alias.isEmpty ? current.kind.badgeTitle : current.alias)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .lineLimit(1)
                                    let rel = current.relativeTimeText(now: now)
                                    Text(rel.isEmpty ? current.statsSummary : "\(current.statsSummary) · \(rel)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Button {
                                    onTogglePin(current.text)
                                } label: {
                                    Image(systemName: current.isPinned ? "pin.fill" : "pin")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(current.isPinned ? Color.accentColor : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help(current.isPinned ? "Bỏ ghim (⌘P)" : "Ghim lên đầu (⌘P)")
                            }

                            ScrollView {
                                Text(current.text)
                                    .font(current.kind.usesMonospacedFont
                                          ? .system(size: 12, design: .monospaced)
                                          : .system(size: 12.5))
                                    .lineSpacing(3)
                                    .padding(.vertical, 2)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: 136, maxHeight: 196)

                            HStack(spacing: 8) {
                                Button {
                                    onPaste(current.text)
                                } label: {
                                    Label("Dán ngay", systemImage: "doc.on.clipboard")
                                        .font(.system(size: 12, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                }
                                .glassProminentButton()
                                .controlSize(.small)

                                Button {
                                    onPaste(TextConverter.convert(current.text, mode: .autoToUnicode))
                                } label: {
                                    Label("Sửa font", systemImage: "textformat")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .glassButton()
                                .controlSize(.small)
                                .help("Sửa lỗi font cũ sang Unicode NFC rồi dán (⇧↵)")
                            }
                        }
                        .padding(11)
                        .frame(width: 248)
                        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            // Footer shortcut legend with generous horizontal margin
            HStack(spacing: 6) {
                Text("↑↓ chọn")
                Text("·").foregroundStyle(.quaternary)
                Text("↵ dán")
                Text("·").foregroundStyle(.quaternary)
                Text("⇧↵ sửa font")
                Text("·").foregroundStyle(.quaternary)
                Text("⌘P ghim")
                Text("·").foregroundStyle(.quaternary)
                Text("1–9 dán số")
                Text("·").foregroundStyle(.quaternary)
                Text("Esc đóng")
                Spacer()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
        }
        .padding(14)
        .frame(width: items.isEmpty ? 430 : 606)
        .fixedSize(horizontal: false, vertical: true)
        .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var filterStrip: some View {
        let row = HStack(spacing: 6) {
            ForEach(ClipboardFilter.allCases, id: \.self) { chip in
                let isActive = chip == activeFilter
                Button {
                    onSelectFilter(chip)
                } label: {
                    Label(chip.title, systemImage: chip.symbolName)
                        .font(.system(size: 11.5, weight: isActive ? .semibold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(isActive ? Color.accentColor : .primary)
                        .glassFilterChip(isSelected: isActive)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("Tab chuyển nhóm")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 6) { row }
        } else {
            row
        }
    }
}
