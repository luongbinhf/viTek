import AppKit
import SwiftUI

/// Resolves the physical Notch, OLED Dynamic Island pill cutout, or fallback top-center floating pill
/// using AppKit `NSScreen` safe-area and auxiliary corner metrics.
@MainActor
struct ScreenCutoutGeometry: Equatable {
    enum Style: Equatable {
        case notch
        case dynamicIsland
        case floatingPill
    }

    let screenFrame: NSRect
    let visibleFrame: NSRect
    let cutoutRect: NSRect
    let style: Style

    static func resolve(for caret: NSRect = .zero) -> ScreenCutoutGeometry {
        let mouseLocation = NSEvent.mouseLocation
        let screen = (caret != .zero
            ? NSScreen.screens.first { $0.frame.insetBy(dx: -20, dy: -20).contains(caret.origin) }
            : nil)
            ?? NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else {
            let fallback = NSRect(x: 0, y: 0, width: 1280, height: 800)
            return ScreenCutoutGeometry(
                screenFrame: fallback,
                visibleFrame: fallback,
                cutoutRect: NSRect(x: fallback.midX, y: fallback.maxY - 38, width: 0, height: 32),
                style: .floatingPill
            )
        }

        let insets = screen.safeAreaInsets
        if insets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX {
            let width = right.minX - left.maxX
            let height = insets.top
            let rect = NSRect(x: left.maxX, y: screen.frame.maxY - height, width: width, height: height)
            let style: Style = (width < 160) ? .dynamicIsland : .notch
            return ScreenCutoutGeometry(
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                cutoutRect: rect,
                style: style
            )
        }

        return ScreenCutoutGeometry(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            cutoutRect: NSRect(x: screen.frame.midX, y: screen.visibleFrame.maxY - 38, width: 0, height: 32),
            style: .floatingPill
        )
    }

    /// Returns the global screen rect of the physical hardware cutout when present (`nil` on non-cutout displays).
    static func physicalCutoutRect(at mouseLocation: NSPoint) -> NSRect? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            return nil
        }
        let insets = screen.safeAreaInsets
        guard insets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              right.minX > left.maxX else {
            return nil
        }
        return NSRect(
            x: left.maxX,
            y: screen.frame.maxY - insets.top,
            width: right.minX - left.maxX,
            height: insets.top
        )
    }
}

/// Top-flush Notch / Expanded Drawer silhouette with smooth outward top-corner ear fillets
/// and continuous bottom corners so pure-black `#000000` merges tangentially into the physical bezel.
struct NotchEarShape: Shape {
    var earRadius: CGFloat = 10
    var bottomRadius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let ear = min(earRadius, rect.width * 0.12, rect.height * 0.45)
        let bottom = min(bottomRadius, max(4, (rect.width - ear * 2) * 0.45), rect.height * 0.5)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right outward concave top ear
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - ear, y: rect.minY + ear),
            control: CGPoint(x: rect.maxX - ear, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - ear, y: rect.maxY - bottom))
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - ear - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX - ear, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + ear + bottom, y: rect.maxY))
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + ear, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX + ear, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + ear, y: rect.minY + ear))
        // Left outward concave top ear
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + ear, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
