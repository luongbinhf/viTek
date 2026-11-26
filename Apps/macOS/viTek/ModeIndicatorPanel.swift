import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ModeIndicatorState {
    var vietnamese = true
}

/// Brief non-activating Liquid Glass pill shown for 650 ms when switching between Vietnamese and English.
/// Uses fixed size + `@Observable` state to avoid SwiftUI re-measurement on every double-tap.
@MainActor
enum ModeIndicatorPanel {
    private static let pillSize = NSSize(width: 116, height: 32)
    private static let state = ModeIndicatorState()
    private static var glass: GlassPanel<ModeIndicatorBadge>?
    private static var hideTask: Task<Void, Never>?

    static func show(vietnamese: Bool, caret: NSRect) {
        hideTask?.cancel()
        state.vietnamese = vietnamese
        let glass = glass ?? GlassPanel(ModeIndicatorBadge(state: state), acceptsMouseEvents: false)
        self.glass = glass
        let size = pillSize

        let screen = (caret != .zero
            ? NSScreen.screens.first { $0.frame.contains(caret.origin) }?.visibleFrame
            : nil)
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        var origin: NSPoint
        if caret != .zero {
            origin = NSPoint(x: caret.minX, y: caret.maxY + 8)
            if origin.y + size.height > screen.maxY - 6 {
                origin.y = max(screen.minY + 6, caret.minY - size.height - 8)
            }
        } else {
            origin = NSPoint(x: screen.midX - size.width / 2, y: screen.minY + 96)
        }
        origin.x = min(max(origin.x, screen.minX + 6), screen.maxX - size.width - 6)
        origin.y = min(max(origin.y, screen.minY + 6), screen.maxY - size.height - 6)

        glass.show(at: NSRect(origin: origin, size: size))
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            glass.hide()
        }
    }
}

struct ModeIndicatorBadge: View {
    let state: ModeIndicatorState

    var body: some View {
        HStack(spacing: 7) {
            Text(state.vietnamese ? "VI" : "EN")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(state.vietnamese ? .white : .primary)
                .padding(.horizontal, 6.5)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(state.vietnamese ? Color.accentColor : Color.secondary.opacity(0.24))
                )
            Text(state.vietnamese ? "Tiếng Việt" : "English")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: 116, height: 32)
        .floatingSurface(in: Capsule())
    }
}
