import AppKit
import SwiftUI
import VitekSession

/// Floating Liquid Glass Quick-Paste Palette (`⌃⌥V`), supporting live accent-insensitive search,
/// filter chips, full keyboard navigation (`↑↓`, `↵`, `⇧↵`, `⌘P`, `Tab`, `1–9`, `Esc`), and preview pane.
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
        render(reposition: true)
    }

    static func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

        // Escape clears non-empty search first; second Escape hides the palette.
        if event.keyCode == 0x35 {
            if !searchQuery.isEmpty {
                searchQuery = ""
                selectedIndex = 0
                render(reposition: false)
            } else {
                hide()
            }
            return true
        }

        // Up / Down arrows move the highlighted row.
        if event.keyCode == 0x7E { // Up
            if !activeItems.isEmpty {
                selectedIndex = (selectedIndex - 1 + activeItems.count) % activeItems.count
                render(reposition: false)
            }
            return true
        }
        if event.keyCode == 0x7D { // Down
            if !activeItems.isEmpty {
                selectedIndex = (selectedIndex + 1) % activeItems.count
                render(reposition: false)
            }
            return true
        }

        // Tab cycles category filters.
        if event.keyCode == 0x30, mods.isEmpty {
            let cases = ClipboardFilter.allCases
            if let idx = cases.firstIndex(of: filter) {
                filter = cases[(idx + 1) % cases.count]
                selectedIndex = 0
                render(reposition: false)
            }
            return true
        }

        // Return / Numpad Enter: paste selected item (⇧Return auto-fixes legacy font -> Unicode NFC).
        if event.keyCode == 0x24 || event.keyCode == 0x4C {
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

        // ⌘P toggles pin state on the selected item.
        if mods == [.command], event.keyCode == 0x23 {
            if activeItems.indices.contains(selectedIndex) {
                SettingsStore.shared.togglePinClipboard(activeItems[selectedIndex].text)
                render(reposition: false)
            }
            return true
        }

        // 1–9 quick paste: plain digits when search query is empty, or ⌘1–9 anytime.
        let pasteDigits: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19]
        if let digitIdx = pasteDigits.firstIndex(of: event.keyCode),
           mods == [.command] || (mods.isEmpty && searchQuery.isEmpty) {
            if pasteByNumber(digitIdx + 1) { return true }
        }

        // Backspace edits live search query.
        if event.keyCode == 0x33 {
            if !searchQuery.isEmpty {
                searchQuery.removeLast()
                selectedIndex = 0
                render(reposition: false)
            }
            return true
        }

        // Printable characters without Cmd/Ctrl/Option filter live in-place.
        if mods.intersection([.command, .control, .option]).isEmpty,
           let chars = event.characters, !chars.isEmpty,
           chars.allSatisfy({ !$0.isNewline && $0 != "\t" }) {
            searchQuery.append(chars)
            selectedIndex = 0
            render(reposition: false)
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

    private static func render(reposition: Bool) {
        let items = Array(SettingsStore.shared.clipboardHistory.filter(filter, query: searchQuery).prefix(9))
        activeItems = items
        if items.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = min(max(0, selectedIndex), items.count - 1)
        }

        let view = ClipboardPopupView(
            items: items,
            selectedIndex: selectedIndex,
            searchQuery: searchQuery,
            activeFilter: filter,
            onSelectIndex: { idx in
                selectedIndex = idx
                render(reposition: false)
            },
            onPaste: { text in
                let paste = activePaste
                hide()
                paste?(text)
            },
            onSelectFilter: { next in
                filter = next
                selectedIndex = 0
                render(reposition: false)
            },
            onClearSearch: {
                searchQuery = ""
                selectedIndex = 0
                render(reposition: false)
            },
            onTogglePin: { text in
                SettingsStore.shared.togglePinClipboard(text)
                if isVisible { render(reposition: false) }
            },
            onManage: {
                hide()
                SettingsWindow.show(page: .clipboard)
            }
        )

        let glass = glass ?? GlassPanel(view, acceptsMouseEvents: true)
        self.glass = glass
        let size = glass.update(view)
        let screen = (lastCaret != .zero
            ? NSScreen.screens.first { $0.frame.contains(lastCaret.origin) }?.visibleFrame
            : nil)
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        var origin: NSPoint
        if lastCaret != .zero {
            origin = NSPoint(x: lastCaret.minX, y: lastCaret.minY - size.height - 8)
            if origin.y < screen.minY + 8 {
                origin.y = min(screen.maxY - size.height - 8, lastCaret.maxY + 8)
            }
        } else {
            origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
        origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - size.height - 8)

        if reposition || !isVisible {
            isVisible = true
            glass.show(at: NSRect(origin: origin, size: size))
        } else {
            // Keep existing origin vertically anchored when filtering shrinks/grows rows cleanly.
            glass.show(at: NSRect(origin: origin, size: size))
        }
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
        VStack(alignment: .leading, spacing: 8) {
            // Top bar: title + live search indicator + Manage button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.teal.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("Clipboard viTek")
                        .font(.system(size: 13, weight: .semibold))
                }

                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if searchQuery.isEmpty {
                        Text("Gõ trực tiếp để tìm không dấu…")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(searchQuery)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if !searchQuery.isEmpty {
                        Button {
                            onClearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Button {
                    onManage()
                } label: {
                    Label("Quản lý", systemImage: "square.and.pencil")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)
            }

            // Category filter pills
            HStack(spacing: 6) {
                ForEach(ClipboardFilter.allCases, id: \.self) { chip in
                    let isActive = chip == activeFilter
                    Button {
                        onSelectFilter(chip)
                    } label: {
                        Label(chip.title, systemImage: chip.symbolName)
                            .font(.caption2.weight(isActive ? .semibold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                isActive ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05),
                                in: Capsule()
                            )
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Tab lọc")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            if items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty
                         ? "Chưa có mục Clipboard nào phù hợp. Sao chép văn bản hoặc ghim mẫu trong Cài đặt."
                         : "Không tìm thấy mục nào khớp “\(searchQuery)”.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 12)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    // Left column: 1–9 quick list
                    VStack(spacing: 3) {
                        ForEach(Array(items.enumerated()), id: \.element.text) { idx, item in
                            let isSelected = idx == selectedIndex
                            HStack(spacing: 8) {
                                Button {
                                    onPaste(item.text)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                            .frame(width: 18, height: 18)
                                            .background(
                                                isSelected ? Color.accentColor : Color.secondary.opacity(0.16),
                                                in: Circle()
                                            )
                                        ClipboardKindBadge(item: item, size: 24)
                                        VStack(alignment: .leading, spacing: 1) {
                                            if !item.alias.isEmpty {
                                                Text(item.alias)
                                                    .font(.system(size: 11.5, weight: .semibold))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)
                                            }
                                            Text(item.preview)
                                                .font(item.kind.usesMonospacedFont
                                                      ? .system(size: item.alias.isEmpty ? 12 : 11, design: .monospaced)
                                                      : .system(size: item.alias.isEmpty ? 12.5 : 11))
                                                .foregroundStyle(item.alias.isEmpty ? .primary : .secondary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if item.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.18))
                                } else if hoveredIndex == idx {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                }
                            }
                            .onHover { inside in
                                hoveredIndex = inside ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
                                if inside { onSelectIndex(idx) }
                            }
                        }
                    }
                    .frame(width: 304)

                    Divider()

                    // Right column: live detail preview & quick transforms
                    if let current = selectedItem {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                ClipboardKindBadge(item: current, size: 22)
                                Text(current.alias.isEmpty ? current.kind.badgeTitle : current.alias)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    onTogglePin(current.text)
                                } label: {
                                    Image(systemName: current.isPinned ? "pin.slash" : "pin")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help(current.isPinned ? "Bỏ ghim (⌘P)" : "Ghim lên đầu (⌘P)")
                            }

                            ScrollView {
                                Text(current.text)
                                    .font(current.kind.usesMonospacedFont
                                          ? .system(size: 12, design: .monospaced)
                                          : .system(size: 12.5))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 128)
                            .padding(8)
                            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            let rel = current.relativeTimeText(now: now)
                            Text(rel.isEmpty ? current.statsSummary : "\(current.statsSummary) · \(rel)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                Button {
                                    onPaste(current.text)
                                } label: {
                                    Label("Dán", systemImage: "doc.on.clipboard")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button {
                                    onPaste(TextConverter.convert(current.text, mode: .autoToUnicode))
                                } label: {
                                    Label("Sửa font", systemImage: "textformat")
                                        .font(.caption.weight(.medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Sửa lỗi font cũ sang Unicode NFC rồi dán (⇧↵)")
                            }
                        }
                        .frame(width: 228)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text("↑↓ chọn · ↵ dán · ⇧↵ sửa font · ⌘P ghim · 1–9 dán nhanh · Esc đóng")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(10)
        .frame(width: items.isEmpty ? 380 : 566)
        .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fixedSize()
    }
}
