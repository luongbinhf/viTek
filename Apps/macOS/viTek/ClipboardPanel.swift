import AppKit
import SwiftUI
import VitekSession

/// Floating Liquid Glass quick-paste popup (`⌃⌥V`), supporting 1–9 number selection and click-to-paste.
@MainActor
enum ClipboardPanel {
    private static var glass: GlassPanel<ClipboardPopupView>?
    private static var activeItems: [ClipboardItem] = []
    private static var activePaste: (@MainActor (String) -> Void)?
    private(set) static var isVisible = false

    static func toggle(caret: NSRect, onPaste: @escaping @MainActor (String) -> Void) {
        if isVisible {
            hide()
            return
        }
        show(caret: caret, onPaste: onPaste)
    }

    static func show(caret: NSRect, onPaste: @escaping @MainActor (String) -> Void) {
        ClipboardMonitor.shared.checkPasteboard()
        let items = Array(SettingsStore.shared.clipboardHistory.items.prefix(9))
        activeItems = items
        activePaste = onPaste

        let view = ClipboardPopupView(
            items: items,
            onSelect: { text in
                hide()
                onPaste(text)
            },
            onTogglePin: { text in
                SettingsStore.shared.togglePinClipboard(text)
                if isVisible {
                    show(caret: caret, onPaste: onPaste)
                }
            },
            onManage: {
                hide()
                SettingsWindow.show(page: .clipboard)
            },
            onClose: {
                hide()
            }
        )

        let glass = glass ?? GlassPanel(view, acceptsMouseEvents: true)
        self.glass = glass
        let size = glass.update(view)
        let screen = (caret != .zero
            ? NSScreen.screens.first { $0.frame.contains(caret.origin) }?.visibleFrame
            : nil)
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        var origin: NSPoint
        if caret != .zero {
            origin = NSPoint(x: caret.minX, y: caret.minY - size.height - 8)
            if origin.y < screen.minY + 8 {
                origin.y = min(screen.maxY - size.height - 8, caret.maxY + 8)
            }
        } else {
            origin = NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
        origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - size.height - 8)

        isVisible = true
        glass.show(at: NSRect(origin: origin, size: size))
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
        glass?.hide()
    }
}

struct ClipboardPopupView: View {
    let items: [ClipboardItem]
    let onSelect: @MainActor (String) -> Void
    let onTogglePin: @MainActor (String) -> Void
    let onManage: @MainActor () -> Void
    let onClose: @MainActor () -> Void
    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Clipboard", systemImage: "doc.on.clipboard")
                    .font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("1–9 để dán · Esc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Quản lý…") {
                    onManage()
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)

            Divider()

            if items.isEmpty {
                Text("Chưa có mục Clipboard nào. Sao chép văn bản hoặc ghim mẫu trong Cài đặt.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.text) { idx, item in
                        HStack(spacing: 8) {
                            Button {
                                onSelect(item.text)
                            } label: {
                                HStack(spacing: 8) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18, height: 18)
                                        .background(Color.secondary.opacity(0.16), in: Circle())
                                    if item.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.caption2)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    Text(item.preview)
                                        .font(.system(size: 12.5))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                onTogglePin(item.text)
                            } label: {
                                Image(systemName: item.isPinned ? "pin.slash" : "pin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help(item.isPinned ? "Bỏ ghim" : "Ghim lên đầu")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            if hoveredIndex == idx {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                            }
                        }
                        .onHover { inside in
                            hoveredIndex = inside ? idx : (hoveredIndex == idx ? nil : hoveredIndex)
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 344)
        .floatingSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fixedSize()
    }
}
