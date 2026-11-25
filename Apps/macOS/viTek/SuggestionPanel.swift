import AppKit
import SwiftUI

/// The suggestion bar: completions of the word being typed, or predictions of the next word.
/// Uses a non-activating panel so clicking a candidate commits it directly without stealing focus
/// from the host application; `⌥1`–`⌥5` also choose via keyboard (see `VitekInputController`).
///
/// It must not hide text. At the end of a line, the usual place to type, it sits on the line right
/// after the caret, where there is nothing to cover. Inside a line it goes below the line.
@MainActor
enum SuggestionPanel {
    private static var glass: GlassPanel<SuggestionBar>?

    /// `caret` is the caret's line as the client reports it. `fromAccessibility` marks a box read
    /// through the Accessibility API, which covers the whole line rather than hanging below it.
    static func show(
        _ words: [String],
        completing: Bool,
        caret: NSRect,
        inline: Bool,
        fromAccessibility: Bool = false,
        onSelect: @escaping @MainActor (Int) -> Void = { _ in }
    ) {
        guard !words.isEmpty, caret != .zero else { return hide() }
        let bar = SuggestionBar(words: words, completing: completing, onSelect: onSelect)
        let glass = glass ?? GlassPanel(bar, acceptsMouseEvents: true)
        self.glass = glass
        let size = glass.update(bar)
        let screen = NSScreen.screens.first { $0.frame.contains(caret.origin) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame ?? .zero

        // Clients report the caret's line from its top to about the font size; the middle of the
        // glyphs sits around its lower edge (measured in Notes and TextEdit: 1–6 pt below it).
        let textMiddle = fromAccessibility ? caret.midY : caret.minY - 3
        var origin = NSPoint(x: caret.maxX + 10, y: textMiddle - size.height / 2)
        if !inline || origin.x + size.width > screen.maxX - 4 {
            let gap = max(8, caret.height * 0.6) + 4
            origin = NSPoint(x: caret.minX - 6, y: caret.minY - size.height - gap)
            if origin.y < screen.minY + 4 { origin.y = caret.maxY + 6 }
        }
        origin.x = min(max(origin.x, screen.minX + 4), screen.maxX - size.width - 4)
        glass.show(at: NSRect(origin: origin, size: size))
    }

    static func hide() {
        glass?.hide()
    }
}

struct SuggestionBar: View {
    let words: [String]
    let completing: Bool
    let onSelect: @MainActor (Int) -> Void
    @State private var hoveredIndex: Int?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Button {
                    onSelect(index)
                } label: {
                    HStack(spacing: 4) {
                        Text("⌥\(index + 1)")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(word)
                            .font(.system(size: 13, weight: index == 0 ? .semibold : .regular))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        if hoveredIndex == index {
                            Capsule().fill(Color.accentColor.opacity(0.28))
                        } else if index == 0 {
                            Capsule().fill(Color.accentColor.opacity(0.16))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    hoveredIndex = inside ? index : (hoveredIndex == index ? nil : hoveredIndex)
                }
            }
        }
        .padding(3)
        .floatingSurface(in: Capsule())
        .fixedSize()
    }
}
