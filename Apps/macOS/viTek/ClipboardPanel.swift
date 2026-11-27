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
    var islandStyle: ScreenCutoutGeometry.Style?
    var topCutoutHeight: CGFloat = 0
}

/// Minimal, high-speed Spotlight-style Quick-Paste Palette (`⌃⌥V`).
/// - In `.notchIsland` mode: drops smoothly out of the physical Notch / OLED Dynamic Island (or top-center
///   floating pill on external displays) with pure-black `#000000` OLED surface.
/// - In `.caret` mode: floats as a Liquid Glass card beside the active text caret.
/// Uses fixed dimensions + `@Observable` state so `↑`/`↓`, hover, and live search incur zero panel resizes.
@MainActor
enum ClipboardPanel {
    private static let caretSize = NSSize(width: 396, height: 364)
    private static let islandBaseSize = NSSize(width: 416, height: 364)
    private static let state = ClipboardPanelState()
    private static var glass: GlassPanel<ClipboardPopupView>?
    private static var islandDrawerPanel: NSPanel?
    private static var outsideClickMonitor: Any?
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
        present()
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
            searchQueryAppend(chars)
            return true
        }

        return false
    }

    private static func searchQueryAppend(_ chars: String) {
        state.searchQuery.append(chars)
        state.selectedIndex = 0
        refreshItems()
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
        removeOutsideClickMonitor()
        glass?.hide()
        islandDrawerPanel?.orderOut(nil)
    }

    private static func refreshItems() {
        let filter: ClipboardFilter = state.pinnedOnly ? .pinned : .all
        let items = Array(SettingsStore.shared.clipboardHistory.filter(filter, query: state.searchQuery).prefix(9))
        state.items = items
        state.selectedIndex = items.isEmpty ? 0 : min(max(0, state.selectedIndex), items.count - 1)
    }

    private static func makePopupView() -> ClipboardPopupView {
        ClipboardPopupView(
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
    }

    private static func ensureIslandDrawerPanel() -> NSPanel {
        if let islandDrawerPanel { return islandDrawerPanel }
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: makePopupView())
        islandDrawerPanel = panel
        return panel
    }

    private static func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated {
                guard isVisible else { return }
                let mouse = NSEvent.mouseLocation
                let activeFrame = (SettingsStore.shared.overlayPlacement == .notchIsland)
                    ? islandDrawerPanel?.frame
                    : glass?.panel.frame
                if let activeFrame, !activeFrame.contains(mouse) {
                    hide()
                }
            }
        }
    }

    private static func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    private static func present() {
        if SettingsStore.shared.overlayPlacement == .notchIsland {
            DynamicIslandPanel.hideCompact()
            glass?.hide()

            let geo = ScreenCutoutGeometry.resolve(for: lastCaret)
            let topPad: CGFloat = (geo.style == .floatingPill) ? 0 : geo.cutoutRect.height + 6
            state.islandStyle = geo.style
            state.topCutoutHeight = topPad

            let size = NSSize(width: islandBaseSize.width, height: islandBaseSize.height + topPad)
            let origin: NSPoint
            switch geo.style {
            case .notch:
                origin = NSPoint(
                    x: geo.cutoutRect.midX - size.width / 2,
                    y: geo.screenFrame.maxY - size.height
                )
            case .dynamicIsland:
                origin = NSPoint(
                    x: geo.cutoutRect.midX - size.width / 2,
                    y: geo.cutoutRect.maxY - size.height + 2
                )
            case .floatingPill:
                origin = NSPoint(
                    x: geo.screenFrame.midX - size.width / 2,
                    y: geo.visibleFrame.maxY - size.height - 6
                )
            }

            let panel = ensureIslandDrawerPanel()
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
            isVisible = true
            installOutsideClickMonitor()
            panel.orderFrontRegardless()
            return
        }

        // Caret-anchored Liquid Glass placement
        islandDrawerPanel?.orderOut(nil)
        state.islandStyle = nil
        state.topCutoutHeight = 0

        if glass == nil {
            glass = GlassPanel(makePopupView(), cornerStyle: .rounded(16), acceptsMouseEvents: true)
        }
        guard let glass else { return }
        let size = caretSize
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
        installOutsideClickMonitor()
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
        let isIsland = state.islandStyle != nil
        let horizontalPad: CGFloat = state.islandStyle == .notch ? 20 : 12

        Group {
            if let style = state.islandStyle {
                contentBody
                    .padding(.top, state.topCutoutHeight + 10)
                    .padding(.horizontal, horizontalPad)
                    .padding(.bottom, 12)
                    .frame(width: 416, height: 364 + state.topCutoutHeight)
                    .background(Color.black)
                    .modifier(IslandClipModifier(style: style))
                    .environment(\.colorScheme, .dark)
            } else {
                contentBody
                    .padding(12)
                    .frame(width: 396, height: 364)
                    .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .id(isIsland)
    }

    private var contentBody: some View {
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
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 2) {
                    filterSegment(title: "Tất cả", isSelected: !state.pinnedOnly) {
                        onTogglePinnedFilter(false)
                    }
                    filterSegment(title: "Ghim", isSelected: state.pinnedOnly) {
                        onTogglePinnedFilter(true)
                    }
                }
                .padding(2)
                .background(.primary.opacity(0.08), in: Capsule())
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
                    isSelected ? Color.primary.opacity(0.14) : Color.clear,
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
                    isSelected ? Color.accentColor : Color.primary.opacity(0.10),
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
                      ? Color.accentColor.opacity(0.22)
                      : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
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

private struct IslandClipModifier: ViewModifier {
    let style: ScreenCutoutGeometry.Style

    func body(content: Content) -> some View {
        switch style {
        case .notch:
            content.clipShape(NotchEarShape(earRadius: 12, bottomRadius: 18))
        case .dynamicIsland, .floatingPill:
            let radius: CGFloat = (style == .dynamicIsland) ? 22 : 18
            content
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        }
    }
}
