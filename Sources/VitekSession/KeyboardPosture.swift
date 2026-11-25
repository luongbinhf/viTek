/// Ergonomic hardware posture classification for standard iPhones, iPads, and dual-screen / foldable
/// iPhone Duo form factors. Pure Swift (no UIKit/Foundation) so tests run across all platforms.
public enum KeyboardPosture: String, Sendable, Equatable, CaseIterable {
    /// Narrow outer cover display (e.g. ~340–384 pt portrait).
    case coverCompact
    /// Standard iPhone portrait (~390–430 pt).
    case standardPortrait
    /// Narrow app pane inside side-by-side Split View / Slide Over while the full screen is wide.
    case dualPaneCompact
    /// Standard iPhone landscape.
    case phoneLandscape
    /// Unfolded book-style dual-screen / foldable display (~540–899 pt wide, near-square ratio).
    case duoUnfoldedBook
    /// Wide unfolded / iPad / tabletop deck (>= 900 pt wide).
    case tabletopWide

    public var allowsSplit: Bool {
        switch self {
        case .phoneLandscape, .duoUnfoldedBook, .tabletopWide: true
        case .coverCompact, .standardPortrait, .dualPaneCompact: false
        }
    }

    public var allowsOneHanded: Bool {
        switch self {
        case .coverCompact, .standardPortrait, .dualPaneCompact: true
        case .phoneLandscape, .duoUnfoldedBook, .tabletopWide: false
        }
    }

    public var supportsUtilityDeck: Bool {
        switch self {
        case .duoUnfoldedBook, .tabletopWide: true
        default: false
        }
    }

    public var edgeTouchAssistRatio: Double {
        switch self {
        case .coverCompact, .dualPaneCompact: 0.27
        default: 0.22
        }
    }

    public var labelTitle: String {
        switch self {
        case .coverCompact: "Màn ngoài gọn"
        case .standardPortrait: "iPhone dọc"
        case .dualPaneCompact: "Đa nhiệm chia đôi"
        case .phoneLandscape: "Ngang"
        case .duoUnfoldedBook: "Mở gập Duo"
        case .tabletopWide: "Rộng / Đặt bàn"
        }
    }

    /// Classifies the active hardware posture from container dimensions, physical screen dimensions, and trait compactness.
    public static func classify(
        containerWidth: Double,
        containerHeight: Double,
        screenWidth: Double,
        screenHeight: Double,
        isVerticalCompact: Bool
    ) -> KeyboardPosture {
        let w = containerWidth > 0 ? containerWidth : screenWidth
        let minScreen = min(screenWidth, screenHeight)
        let maxScreen = max(screenWidth, screenHeight)

        // Side-by-side multitasking on an unfolded Duo or iPad shrinks the keyboard container while
        // the underlying display remains wide; always prefer full-width single-pane keys there.
        if w > 0, w < 480, minScreen >= 500, maxScreen >= 620 {
            return .dualPaneCompact
        }

        if w > 0, w < 385, !isVerticalCompact {
            return .coverCompact
        }

        if w >= 900 {
            return .tabletopWide
        }

        if w >= 540, minScreen >= 500 {
            return .duoUnfoldedBook
        }

        if isVerticalCompact || w >= 540 {
            return .phoneLandscape
        }

        return .standardPortrait
    }

    /// Computes a comfortable center gap over the hinge so each thumb cluster stays within ~255–305 pt.
    public func recommendedBridgeWidth(for containerWidth: Double) -> Double {
        let safeW = containerWidth > 0 ? containerWidth : 744
        switch self {
        case .duoUnfoldedBook:
            let clusterBudget = min(304.0, max(254.0, safeW * 0.39))
            return min(184.0, max(116.0, safeW - clusterBudget * 2.0))
        case .tabletopWide:
            return min(220.0, max(148.0, safeW * 0.19))
        case .phoneLandscape:
            return 64.0
        case .coverCompact, .standardPortrait, .dualPaneCompact:
            return 0.0
        }
    }

    public func usesInteractiveCenterBridge(for containerWidth: Double) -> Bool {
        recommendedBridgeWidth(for: containerWidth) >= 112.0
    }
}

/// Interactive center-bridge tool displayed over the hinge when split layout is active on Duo / wide screens.
public enum DuoBridgeMode: String, Sendable, Equatable, CaseIterable {
    case trackpad
    case numpad
    case clipboard

    public var title: String {
        switch self {
        case .trackpad: "Rê con trỏ"
        case .numpad: "Bàn phím số"
        case .clipboard: "Clipboard"
        }
    }

    public var symbolName: String {
        switch self {
        case .trackpad: "dpad"
        case .numpad: "number.square.fill"
        case .clipboard: "doc.on.clipboard.fill"
        }
    }
}
