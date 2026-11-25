import AppKit
import SwiftUI

extension View {
    /// The surface of everything viTek floats over other apps. On macOS 26 and later the panel itself
    /// is Liquid Glass (`GlassPanel`), so the view draws no background of its own; before that it
    /// draws a material with a hairline edge.
    func floatingSurface<S: InsettableShape>(in shape: S) -> some View {
        modifier(FloatingSurface(shape: shape))
    }

    /// The glass button style where the system has it.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
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
    /// Liquid Glass exists from macOS 26.
    static var isAvailable: Bool {
        if #available(macOS 26.0, *) { true } else { false }
    }
}

/// A borderless, non-activating panel for SwiftUI content that floats over other apps. On macOS 26
/// and later the content sits in an `NSGlassEffectView`, the AppKit view that renders Liquid Glass
/// for a window; SwiftUI's `glassEffect` inside a borderless panel does not.
@MainActor
final class GlassPanel<Content: View> {
    let panel: NSPanel
    private let host: NSHostingView<Content>
    private let glass: NSView?

    init(_ content: Content, acceptsMouseEvents: Bool = false) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The window shadow adds a dark outline around the glass capsule.
        panel.hasShadow = false
        panel.ignoresMouseEvents = !acceptsMouseEvents
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        host = NSHostingView(rootView: content)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.contentView = host
            let capsule = NSView()
            capsule.wantsLayer = true
            capsule.layer?.masksToBounds = true
            capsule.addSubview(glass)
            panel.contentView = capsule
            self.glass = glass
        } else {
            panel.contentView = host
            glass = nil
        }
    }

    /// Replaces the content and returns the panel size it needs.
    func update(_ content: Content) -> NSSize {
        host.rootView = content
        return host.fittingSize
    }

    /// Shows the panel at `frame`, rounded into a capsule.
    func show(at frame: NSRect) {
        panel.setFrame(frame, display: true)
        if #available(macOS 26.0, *), let glass = glass as? NSGlassEffectView, let capsule = panel.contentView {
            // The native glass rim darkens at both ends in a transparent window.
            // Keep it outside the visible capsule while AppKit draws the material and its content.
            capsule.layer?.cornerRadius = frame.height / 2
            glass.frame = capsule.bounds.insetBy(dx: -2, dy: -2)
            glass.cornerRadius = glass.frame.height / 2
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
