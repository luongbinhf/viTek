import AppKit
import SwiftUI

extension View {
    /// The surface of everything viTek floats over other apps. On macOS 26+ the panel itself
    /// is Liquid Glass (`GlassPanel`), so the view draws no background of its own; before that it
    /// draws a material with a hairline edge.
    func floatingSurface<S: InsettableShape>(in shape: S) -> some View {
        modifier(FloatingSurface(shape: shape))
    }

    /// Secondary Liquid Glass button style where available.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Primary accented Liquid Glass button style where available.
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Interactive Liquid Glass capsule pill for filter chips on macOS 26/27+.
    @ViewBuilder
    func glassFilterChip(isSelected: Bool) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                self.glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            self.background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                in: Capsule()
            )
        }
    }
}

private struct FloatingSurface<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if LiquidGlass.isAvailable {
            content
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08)))
                .padding(6)
        }
    }
}

enum LiquidGlass {
    static var isAvailable: Bool {
        if #available(macOS 26.0, *) { true } else { false }
    }
}

enum GlassCornerStyle: Equatable {
    /// Single-row pills (`SuggestionPanel`, `ModeIndicatorPanel`).
    case capsule
    /// Multi-row cards (`ClipboardPanel`, `QuickActionPanel`) with a fixed continuous corner radius
    /// so header and footer text are never clipped by an oversized half-height capsule arc.
    case rounded(CGFloat)
}

/// A borderless, non-activating panel for SwiftUI content that floats over other apps. On macOS 26/27+
/// the content sits in an `NSGlassEffectView` configured for either a capsule pill or a continuous
/// rounded card.
@MainActor
final class GlassPanel<Content: View> {
    let panel: NSPanel
    let cornerStyle: GlassCornerStyle
    private let host: NSHostingView<Content>
    private let glass: NSView?

    init(_ content: Content, cornerStyle: GlassCornerStyle = .capsule, acceptsMouseEvents: Bool = false) {
        self.cornerStyle = cornerStyle
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Single-line capsules skip window shadow to avoid dark end-caps; multi-row cards keep a subtle shadow.
        panel.hasShadow = (cornerStyle != .capsule)
        panel.ignoresMouseEvents = !acceptsMouseEvents
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        host = NSHostingView(rootView: content)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.contentView = host
            let container = NSView()
            container.wantsLayer = true
            container.layer?.masksToBounds = true
            container.layer?.cornerCurve = .continuous
            container.addSubview(glass)
            panel.contentView = container
            self.glass = glass
        } else {
            panel.contentView = host
            glass = nil
        }
    }

    /// Replaces the content and returns the exact fitting size needed without clipping.
    func update(_ content: Content) -> NSSize {
        host.rootView = content
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// Positions and displays the panel using its configured corner geometry.
    func show(at frame: NSRect) {
        panel.setFrame(frame, display: true)
        if #available(macOS 26.0, *), let glass = glass as? NSGlassEffectView, let container = panel.contentView {
            switch cornerStyle {
            case .capsule:
                container.layer?.cornerRadius = frame.height / 2
                glass.frame = container.bounds.insetBy(dx: -2, dy: -2)
                glass.cornerRadius = glass.frame.height / 2
            case .rounded(let radius):
                container.layer?.cornerRadius = radius
                glass.frame = container.bounds
                glass.cornerRadius = radius
            }
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
