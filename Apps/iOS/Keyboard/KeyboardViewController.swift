import UIKit
import VitekSession

// MARK: - System Click Audio Input View

private final class AudioFeedbackInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

// MARK: - Zero-Constraint iOS 26 Liquid Glass Keycap Button

private enum KeyRole: Equatable {
    case character
    case modifier
    case prominent
    case activeModifier
}

/// High-performance `UIButton` (`type: .custom`) engineered for 120Hz typing:
/// - Zero Auto Layout constraints (manual `layoutSubviews` math)
/// - Cached `UIBezierPath` `shadowPath` (eliminating offscreen GPU shadow passes)
/// - Instant 0ms touch-down state (`CATransaction.setDisableActions(true)`, no 150ms `.system` fade)
/// - Expanded inter-key touch hit-slop so thumb taps in gaps never drop keystrokes
private final class LiquidKeyCapButton: UIButton {
    var keyRole: KeyRole = .character {
        didSet {
            if oldValue != keyRole { applyAppearance() }
        }
    }

    var keyCornerRadius: CGFloat = 8.5 {
        didSet {
            if oldValue != keyCornerRadius {
                layer.cornerRadius = keyCornerRadius
                cachedShadowBounds = .zero
                setNeedsLayout()
            }
        }
    }

    let flickLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.isUserInteractionEnabled = false
        label.isAccessibilityElement = false
        label.isHidden = true
        return label
    }()

    var hitSlop = UIEdgeInsets(top: -5, left: -3, bottom: -5, right: -3)
    private var cachedShadowBounds: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerCurve = .continuous
        layer.cornerRadius = keyCornerRadius
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0.5
        titleLabel?.textAlignment = .center
        imageView?.contentMode = .scaleAspectFit
        addSubview(flickLabel)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.applyAppearance()
        }
        applyAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyAppearance()
            CATransaction.commit()
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: hitSlop).contains(point)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !flickLabel.isHidden {
            let padX: CGFloat = bounds.width > 40 ? 5 : 3.5
            flickLabel.frame = CGRect(x: bounds.width - 18 - padX, y: 2.5, width: 18, height: 11)
        }
        if bounds.width > 0, bounds.height > 0, cachedShadowBounds != bounds.size {
            cachedShadowBounds = bounds.size
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: keyCornerRadius).cgPath
        }
    }

    func applyAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let pressed = isHighlighted

        switch keyRole {
        case .character:
            if isDark {
                backgroundColor = pressed
                    ? UIColor(white: 0.50, alpha: 0.92)
                    : UIColor(white: 0.35, alpha: 0.76)
                layer.borderWidth = 0.5
                layer.borderColor = UIColor.white.withAlphaComponent(pressed ? 0.28 : 0.16).cgColor
                layer.shadowOpacity = 0.34
            } else {
                backgroundColor = pressed
                    ? UIColor(red: 0.87, green: 0.90, blue: 0.96, alpha: 0.96)
                    : UIColor(white: 1.0, alpha: 0.90)
                layer.borderWidth = 0.5
                layer.borderColor = UIColor.white.withAlphaComponent(0.78).cgColor
                layer.shadowOpacity = 0.18
            }
            setTitleColor(.label, for: .normal)
            tintColor = .label
            flickLabel.textColor = isDark
                ? UIColor.white.withAlphaComponent(0.42)
                : UIColor.black.withAlphaComponent(0.36)

        case .modifier:
            if isDark {
                backgroundColor = pressed
                    ? UIColor(white: 0.38, alpha: 0.86)
                    : UIColor(white: 0.21, alpha: 0.74)
                layer.borderWidth = 0.5
                layer.borderColor = UIColor.white.withAlphaComponent(0.11).cgColor
                layer.shadowOpacity = 0.26
            } else {
                backgroundColor = pressed
                    ? UIColor(white: 1.0, alpha: 0.92)
                    : UIColor(red: 0.66, green: 0.70, blue: 0.77, alpha: 0.44)
                layer.borderWidth = 0.5
                layer.borderColor = UIColor.white.withAlphaComponent(0.52).cgColor
                layer.shadowOpacity = 0.12
            }
            setTitleColor(.label, for: .normal)
            tintColor = .label

        case .activeModifier:
            backgroundColor = pressed
                ? UIColor.white.withAlphaComponent(0.85)
                : UIColor.white
            layer.borderWidth = 0.5
            layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.35).cgColor
            layer.shadowOpacity = 0.22
            setTitleColor(.black, for: .normal)
            tintColor = .black

        case .prominent:
            backgroundColor = pressed
                ? UIColor.systemBlue.withAlphaComponent(0.78)
                : UIColor.systemBlue
            layer.borderWidth = 0.5
            layer.borderColor = UIColor.white.withAlphaComponent(0.34).cgColor
            layer.shadowOpacity = 0.22
            setTitleColor(.white, for: .normal)
            tintColor = .white
        }
    }
}

// MARK: - iOS 26 Liquid Glass Callout Bubble

private final class LiquidKeyCalloutView: UIView {
    private let glassView: UIVisualEffectView
    let label = UILabel()
    private var cachedBounds: CGSize = .zero

    override init(frame: CGRect) {
        let glass = UIGlassEffect(style: .regular)
        glassView = UIVisualEffectView(effect: glass)
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.zPosition = 200
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.18

        glassView.cornerConfiguration = .corners(radius: .fixed(14))
        addSubview(glassView)

        label.font = .systemFont(ofSize: 30, weight: .regular)
        label.textAlignment = .center
        label.textColor = .label
        glassView.contentView.addSubview(label)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        glassView.frame = bounds
        label.frame = bounds
        if bounds.size != cachedBounds, bounds.width > 0 {
            cachedBounds = bounds.size
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
        }
    }
}

// MARK: - Cached SF Symbols

@MainActor
private enum SymbolCache {
    private static var store: [String: UIImage] = [:]

    static func image(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let key = "\(name)_\(Int(size * 10))_\(weight.rawValue)"
        if let cached = store[key] { return cached }
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        if let img = UIImage(systemName: name, withConfiguration: cfg) {
            store[key] = img
            return img
        }
        return nil
    }
}

// MARK: - Keyboard View Controller

final class KeyboardViewController: UIInputViewController {
    private enum ShiftState { case off, once, locked }
    private enum LayoutPage { case letters, numbers, symbols, emoji, clipboard }

    fileprivate enum KeyActionKind {
        case character(primary: Character, lowercase: Character, flick: Character?)
        case shift
        case backspace
        case tabKey
        case dismissKeyboardKey
        case pageToggle        // 123 <-> ABC
        case symbolsToggle     // #+= <-> 123
        case emojiPage
        case globe
        case space(isPrimary: Bool)
        case returnKey
        case splitToggle
        case emojiSearchChar(Character)
        case emojiSearchBackspace
        case emojiSearchSpace
        case emojiSearchClear
    }

    private struct PlacedKey {
        let frame: CGRect
        let title: String?
        let symbol: (name: String, size: CGFloat, weight: UIImage.SymbolWeight)?
        let flick: Character?
        let accLabel: String
        let accID: String?
        let role: KeyRole
        let fontSize: CGFloat
        let fontWeight: UIFont.Weight
        let action: KeyActionKind
    }

    private static let accentVariants: [Character: [String]] = [
        "a": ["ă", "â", "á", "à", "ả", "ã", "ạ"],
        "e": ["ê", "é", "è", "ẻ", "ẽ", "ẹ"],
        "i": ["í", "ì", "ỉ", "ĩ", "ị"],
        "o": ["ô", "ơ", "ó", "ò", "ỏ", "õ", "ọ"],
        "u": ["ư", "ú", "ù", "ủ", "ũ", "ụ"],
        "y": ["ý", "ỳ", "ỷ", "ỹ", "ỵ"],
        "d": ["đ"],
    ]

    private static let flickCharacters: [Character: Character] = [
        "q": "1", "w": "2", "e": "3", "r": "4", "t": "5",
        "y": "6", "u": "7", "i": "8", "o": "9", "p": "0",
        "a": "@", "s": "#", "d": "$", "f": "&", "g": "*",
        "h": "(", "j": ")", "k": "'", "l": "\"",
        "z": "%", "x": "-", "c": "+", "v": "=", "b": "/", "n": ";", "m": ":",
    ]

    // Core Vietnamese session state
    private var session = InputSession()
    private var document: UUID?
    private var displayed = ""
    private let settings = IOSKeyboardSettings.shared
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // Root surfaces (zero nested stack layout for key grid; 1 sizing guide anchors UIInputView height!)
    private let sizingGuideView = UIView()
    private var backdropGlassView: UIVisualEffectView!
    private let topToolbarView = UIView()
    private let keyPlaneView = UIView()
    private let overlayPanelView = UIView()
    private let oneHandedDockView = UIView()
    private var heightConstraint: NSLayoutConstraint?

    // Persistent Top Liquid Glass Toolbar controls (allocated ONCE, updated in-place!)
    private let languagePillButton = UIButton(type: .custom)
    private let smartPasteChipButton = UIButton(type: .system)
    private var candidateButtons: [UIButton] = []
    private var candidateDividers: [UIView] = []
    private let emojiToolbarButton = UIButton(type: .custom)
    private let clipboardToolbarButton = UIButton(type: .custom)
    private let textToolsToolbarButton = UIButton(type: .custom)
    private let splitToolbarButton = UIButton(type: .custom)
    private let emojiSearchQueryLabel = UILabel()
    private let emojiSearchCloseButton = UIButton(type: .custom)
    private var emojiResultButtons: [UIButton] = []

    // One-Handed dock buttons
    private let dockExpandButton = LiquidKeyCapButton(frame: .zero)
    private let dockSwitchSideButton = LiquidKeyCapButton(frame: .zero)

    // Reusable pooled keycaps (allocated on demand once, never destroyed!)
    private var keyPool: [LiquidKeyCapButton] = []
    private var activeKeyActions: [KeyActionKind] = []
    private var letterPoolIndices: [(index: Int, lowercase: Character)] = []
    private var shiftPoolIndices: [Int] = []
    private var spacePoolIndices: [Int] = []

    // Interactive Center Bridge (for unfolded iPhone Duo / wide split mode)
    private var centerBridgeHost: UIView?

    // Floating Liquid Glass preview & accent strip
    private let keyCallout = LiquidKeyCalloutView(frame: .zero)
    private var accentStripView: UIVisualEffectView?

    // Typing & gesture state
    private var shiftState: ShiftState = .off
    private var lastShiftTap: ContinuousClock.Instant?
    private var lastSpaceTap: ContinuousClock.Instant?
    private var page: LayoutPage = .letters
    private var clipboardFilter: ClipboardFilter = .all
    private var dismissedSmartPasteText: String?
    private var cachedPasteboardString: String?
    private var emojiCategoryIndex = 0
    private var emojiSearching = false
    private var emojiSearchQuery = ""
    private var candidates: [WordCandidate] = []
    private var backspaceRepeatTask: Task<Void, Never>?
    private var aneContextTask: Task<Void, Never>?
    private var cachedANEDomain: VocabularyDomain?
    private var spaceTrackpadRemainder: CGFloat = 0
    private var bridgePanRemainder = CGPoint.zero
    private var isLandscapeOverride: Bool?
    private var pendingTransitionSize: CGSize?
    private var manualLanguageOverrideInField: Bool?
    private var lastObservedKeyboardType: UIKeyboardType?
    private var lastObservedReturnKeyType: UIReturnKeyType?
    private var lastLaidOutBounds: CGSize = .zero

    // Multi-touch, slide/flick & Vietnamese Glide Typing tracking
    private var touchStartPointInButton: CGPoint?
    private var activeFlickCharacter: Character?
    private weak var activeSlideButton: LiquidKeyCapButton?
    private let glideTrailLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = UIColor.systemCyan.withAlphaComponent(0.70).cgColor
        layer.lineWidth = 4.5
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.zPosition = 120
        return layer
    }()
    private var isGliding = false
    private var glidePoints: [CGPoint] = []
    private var glideSampledKeys: [Character] = []
    private var glideTotalDistance: CGFloat = 0
    private var lastGlidedInsertionLength = 0

    // MARK: - Lifecycle

    override func loadView() {
        inputView = AudioFeedbackInputView(frame: .zero, inputViewStyle: .keyboard)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = false

        sizingGuideView.translatesAutoresizingMaskIntoConstraints = false
        sizingGuideView.isUserInteractionEnabled = false
        view.addSubview(sizingGuideView)

        let glassEffect = UIGlassEffect(style: .regular)
        let glass = UIVisualEffectView(effect: glassEffect)
        glass.cornerConfiguration = .corners(radius: .fixed(18))
        glass.clipsToBounds = false
        backdropGlassView = glass
        view.addSubview(glass)

        topToolbarView.clipsToBounds = false
        keyPlaneView.clipsToBounds = false
        overlayPanelView.clipsToBounds = true
        overlayPanelView.isHidden = true
        oneHandedDockView.isHidden = true

        view.addSubview(topToolbarView)
        view.addSubview(oneHandedDockView)
        view.addSubview(keyPlaneView)
        view.addSubview(overlayPanelView)
        view.addSubview(keyCallout)
        keyPlaneView.layer.addSublayer(glideTrailLayer)

        setupTopToolbar()
        setupOneHandedDock()

        let safe = view.safeAreaLayoutGuide
        let hc = sizingGuideView.heightAnchor.constraint(equalToConstant: preferredTotalHeight)
        hc.priority = .defaultHigh
        NSLayoutConstraint.activate([
            sizingGuideView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            sizingGuideView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            sizingGuideView.topAnchor.constraint(equalTo: safe.topAnchor),
            sizingGuideView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            hc,
        ])
        heightConstraint = hc

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteboardChanged),
            name: UIPasteboard.changedNotification,
            object: nil
        )

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.styleTopToolbarColors()
        }

        applySettings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isLandscapeOverride = nil
        manualLanguageOverrideInField = nil
        refreshCachedPasteboard()
        applySettings()
        applyKeyboardAppearance()
        if settings.hapticFeedback { haptic.prepare() }
        page = .letters
        emojiSearching = false
        emojiSearchQuery = ""
        shiftState = .off
        updateAutoCapitalization()
        lastLaidOutBounds = .zero
        rebuildActivePlane()
        updateSuggestions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopBackspaceRepeat()
        aneContextTask?.cancel()
        aneContextTask = nil
        dismissAccentStrip()
        hideKeyPreview()
        discardComposition()
        settings.flushPersonalFrequency()
        super.viewWillDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let safeInsets = view.safeAreaInsets
        backdropGlassView.frame = view.bounds.inset(by: UIEdgeInsets(
            top: 2,
            left: max(2, safeInsets.left),
            bottom: max(2, safeInsets.bottom * 0.25),
            right: max(2, safeInsets.right)
        ))

        if size != lastLaidOutBounds {
            lastLaidOutBounds = size
            heightConstraint?.constant = preferredTotalHeight
            layoutRootRegions()
            rebuildActivePlane()
        } else {
            layoutTopToolbar()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        pendingTransitionSize = size
        isLandscapeOverride = size.width > size.height
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.heightConstraint?.constant = self.preferredTotalHeight
            self.lastLaidOutBounds = .zero
            self.layoutRootRegions()
            self.rebuildActivePlane()
        }, completion: { [weak self] _ in
            self?.pendingTransitionSize = nil
        })
    }

    @objc private func handlePasteboardChanged() {
        refreshCachedPasteboard()
    }

    private func refreshCachedPasteboard() {
        guard hasFullAccess else {
            cachedPasteboardString = nil
            return
        }
        if UIPasteboard.general.hasStrings {
            cachedPasteboardString = UIPasteboard.general.string
        } else {
            cachedPasteboardString = nil
        }
    }

    // MARK: - Posture & Ergonomic Metrics

    private var activeContainerSize: CGSize {
        if let pendingTransitionSize { return pendingTransitionSize }
        if view.bounds.width > 0 && view.bounds.height > 0 { return view.bounds.size }
        return view.window?.windowScene?.screen.bounds.size ?? CGSize(width: 393, height: 852)
    }

    private var currentScreenSize: CGSize {
        view.window?.windowScene?.screen.bounds.size ?? activeContainerSize
    }

    private var currentPosture: KeyboardPosture {
        let container = activeContainerSize
        let screen = currentScreenSize
        let verticalCompact = isLandscapeOverride ?? (traitCollection.verticalSizeClass == .compact)
        return KeyboardPosture.classify(
            containerWidth: Double(container.width),
            containerHeight: Double(container.height),
            screenWidth: Double(screen.width),
            screenHeight: Double(screen.height),
            isVerticalCompact: verticalCompact
        )
    }

    private var isPadLayout: Bool {
        traitCollection.userInterfaceIdiom == .pad
            || currentPosture == .duoUnfoldedBook
            || currentPosture == .tabletopWide
    }

    private var isCompactLandscape: Bool {
        currentPosture == .phoneLandscape
    }

    private var effectiveOneHandedMode: IOSKeyboardSettings.OneHandedMode {
        let posture = currentPosture
        guard posture.allowsOneHanded, page != .emoji, page != .clipboard else { return .full }
        return posture == .coverCompact ? settings.coverOneHandedMode : settings.oneHandedMode
    }

    private var isSplitLayoutActive: Bool {
        currentPosture.allowsSplit
            && settings.splitLandscapeKeyboard
            && page != .emoji
            && page != .clipboard
            && !(page == .emoji && emojiSearching)
    }

    private var topBarHeight: CGFloat {
        isCompactLandscape ? 36 : (isPadLayout ? 44 : 40)
    }

    private var preferredKeysHeight: CGFloat {
        let posture = currentPosture
        let base: CGFloat = switch posture {
        case .tabletopWide: 276
        case .duoUnfoldedBook: 252
        case .phoneLandscape: 158
        case .coverCompact: 204
        case .standardPortrait, .dualPaneCompact: 216
        }
        let numberExtra: CGFloat = (settings.showNumberRow && page == .letters)
            ? (posture == .phoneLandscape ? 30 : 42)
            : 0
        return base + numberExtra
    }

    private var preferredTotalHeight: CGFloat {
        topBarHeight + preferredKeysHeight + 8
    }

    private func layoutRootRegions() {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let safe = view.safeAreaInsets
        let sidePad = max(4, safe.left, safe.right)
        let topY: CGFloat = 4
        let barH = topBarHeight

        topToolbarView.frame = CGRect(
            x: sidePad + 2,
            y: topY,
            width: max(0, bounds.width - sidePad * 2 - 4),
            height: barH
        )
        layoutTopToolbar()

        let contentTop = topY + barH + 4
        let contentBottom = max(4, safe.bottom * 0.15)
        let contentH = max(120, bounds.height - contentTop - contentBottom)
        let fullW = max(0, bounds.width - sidePad * 2)

        let oneHanded = effectiveOneHandedMode
        if oneHanded == .full {
            oneHandedDockView.isHidden = true
            let region = CGRect(x: sidePad, y: contentTop, width: fullW, height: contentH)
            keyPlaneView.frame = region
            overlayPanelView.frame = region
        } else {
            oneHandedDockView.isHidden = false
            let dockW: CGFloat = 48
            let gap: CGFloat = 6
            let keyW = max(240, fullW - dockW - gap)
            if oneHanded == .right {
                oneHandedDockView.frame = CGRect(x: sidePad, y: contentTop, width: dockW, height: contentH)
                let region = CGRect(x: sidePad + dockW + gap, y: contentTop, width: keyW, height: contentH)
                keyPlaneView.frame = region
                overlayPanelView.frame = region
            } else {
                let region = CGRect(x: sidePad, y: contentTop, width: keyW, height: contentH)
                keyPlaneView.frame = region
                overlayPanelView.frame = region
                oneHandedDockView.frame = CGRect(x: sidePad + keyW + gap, y: contentTop, width: dockW, height: contentH)
            }
            layoutOneHandedDock()
        }
    }

    // MARK: - Top Liquid Glass Toolbar (Persistent, Zero-Allocation Updates)

    private func setupTopToolbar() {
        // 1. VI / EN Liquid Glass Pill
        languagePillButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        languagePillButton.layer.cornerCurve = .continuous
        languagePillButton.accessibilityLabel = "Chế độ ngôn ngữ"
        languagePillButton.accessibilityIdentifier = "keyboard.languageToggle"
        languagePillButton.addTarget(self, action: #selector(handleLanguagePillTap), for: .touchUpInside)
        let holdLang = UILongPressGestureRecognizer(target: self, action: #selector(handleLanguageLongPress(_:)))
        holdLang.minimumPressDuration = 0.4
        languagePillButton.addGestureRecognizer(holdLang)
        topToolbarView.addSubview(languagePillButton)

        // 2. Smart Paste Capsule
        var smartCfg = UIButton.Configuration.filled()
        smartCfg.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.16)
        smartCfg.baseForegroundColor = .systemBlue
        smartCfg.cornerStyle = .capsule
        smartCfg.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10)
        smartCfg.imagePadding = 5
        smartPasteChipButton.configuration = smartCfg
        smartPasteChipButton.accessibilityIdentifier = "suggestion.smartPaste"
        smartPasteChipButton.isHidden = true
        smartPasteChipButton.addTarget(self, action: #selector(handleSmartPasteTap), for: .touchUpInside)
        topToolbarView.addSubview(smartPasteChipButton)

        // 3. Three persistent QuickType candidate slots + 2 hairlines
        for idx in 0..<3 {
            let btn = UIButton(type: .custom)
            btn.titleLabel?.font = .systemFont(ofSize: 15.5, weight: idx == 0 ? .semibold : .regular)
            btn.titleLabel?.lineBreakMode = .byTruncatingTail
            btn.layer.cornerCurve = .continuous
            btn.layer.cornerRadius = 10
            btn.tag = idx
            btn.accessibilityIdentifier = "suggestion.\(idx)"
            btn.isHidden = true
            btn.addTarget(self, action: #selector(handleCandidateButtonTap(_:)), for: .touchUpInside)
            candidateButtons.append(btn)
            topToolbarView.addSubview(btn)

            if idx < 2 {
                let div = UIView()
                div.isUserInteractionEnabled = false
                div.isHidden = true
                candidateDividers.append(div)
                topToolbarView.addSubview(div)
            }
        }

        // 4. Right Utility Pill Buttons (Emoji, Clipboard, Text Tools, Split)
        func configureToolbarIcon(_ btn: UIButton, symbol: String, label: String, id: String) {
            btn.setImage(SymbolCache.image(symbol, size: 15.5, weight: .medium), for: .normal)
            btn.layer.cornerCurve = .continuous
            btn.layer.cornerRadius = 14
            btn.accessibilityLabel = label
            btn.accessibilityIdentifier = id
            topToolbarView.addSubview(btn)
        }

        configureToolbarIcon(emojiToolbarButton, symbol: "face.smiling", label: "Emoji", id: "keyboard.emojiTop")
        emojiToolbarButton.addTarget(self, action: #selector(handleEmojiToolbarTap), for: .touchUpInside)

        configureToolbarIcon(clipboardToolbarButton, symbol: "doc.on.clipboard", label: "Clipboard", id: "keyboard.clipboard")
        clipboardToolbarButton.addTarget(self, action: #selector(handleClipboardToolbarTap), for: .touchUpInside)

        configureToolbarIcon(textToolsToolbarButton, symbol: "textformat", label: "Công cụ chữ", id: "keyboard.textTools")
        textToolsToolbarButton.showsMenuAsPrimaryAction = true
        let actions: [(String, String, TextConverter.LegacyEncoding)] = [
            ("Sửa lỗi font → Unicode NFC", "bolt.horizontal.fill", .autoToUnicode),
            ("Chuẩn hoá dựng sẵn NFC", "checkmark.circle", .nfdToNFC),
            ("Bỏ dấu tiếng Việt", "textformat", .stripAccents),
            ("Viết Hoa Đầu Từ", "text.alignleft", .titleCase),
            ("CHỮ HOA TIẾNG VIỆT", "shift.fill", .uppercase),
            ("chữ thường tiếng việt", "character", .lowercase),
        ]
        textToolsToolbarButton.menu = UIMenu(
            title: "Công cụ chữ tiếng Việt",
            children: actions.map { title, icon, mode in
                UIAction(title: title, image: UIImage(systemName: icon)) { [weak self] _ in
                    self?.applyTextTransform(mode)
                }
            }
        )

        configureToolbarIcon(splitToolbarButton, symbol: "rectangle.split.2x1", label: "Chia đôi bàn phím", id: "keyboard.splitToggle")
        splitToolbarButton.addTarget(self, action: #selector(handleSplitToggleTap), for: .touchUpInside)

        // 5. Emoji Search bar controls (reused cleanly inside topToolbarView when emojiSearching == true)
        emojiSearchQueryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        emojiSearchQueryLabel.layer.cornerCurve = .continuous
        emojiSearchQueryLabel.layer.cornerRadius = 12
        emojiSearchQueryLabel.layer.masksToBounds = true
        emojiSearchQueryLabel.accessibilityIdentifier = "emoji.searchQuery"
        emojiSearchQueryLabel.isHidden = true
        topToolbarView.addSubview(emojiSearchQueryLabel)

        emojiSearchCloseButton.setTitle("Đóng", for: .normal)
        emojiSearchCloseButton.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
        emojiSearchCloseButton.layer.cornerCurve = .continuous
        emojiSearchCloseButton.layer.cornerRadius = 12
        emojiSearchCloseButton.accessibilityIdentifier = "emoji.closeSearch"
        emojiSearchCloseButton.isHidden = true
        emojiSearchCloseButton.addTarget(self, action: #selector(handleCloseEmojiSearch), for: .touchUpInside)
        topToolbarView.addSubview(emojiSearchCloseButton)

        for idx in 0..<7 {
            let eBtn = UIButton(type: .custom)
            eBtn.titleLabel?.font = .systemFont(ofSize: 22)
            eBtn.accessibilityIdentifier = "emoji.result.\(idx)"
            eBtn.tag = idx
            eBtn.isHidden = true
            eBtn.addTarget(self, action: #selector(handleEmojiSearchResultTap(_:)), for: .touchUpInside)
            emojiResultButtons.append(eBtn)
            topToolbarView.addSubview(eBtn)
        }

        styleTopToolbarColors()
    }

    private func styleTopToolbarColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let vi = session.isVietnamese

        languagePillButton.setTitle(vi ? "VI" : "EN", for: .normal)
        if vi {
            languagePillButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(isDark ? 0.28 : 0.16)
            languagePillButton.setTitleColor(.systemBlue, for: .normal)
            languagePillButton.layer.borderWidth = 0.8
            languagePillButton.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.42).cgColor
        } else {
            languagePillButton.backgroundColor = isDark
                ? UIColor.white.withAlphaComponent(0.12)
                : UIColor.black.withAlphaComponent(0.06)
            languagePillButton.setTitleColor(.secondaryLabel, for: .normal)
            languagePillButton.layer.borderWidth = 0.5
            languagePillButton.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        }

        let pillFill = isDark
            ? UIColor.white.withAlphaComponent(0.11)
            : UIColor.black.withAlphaComponent(0.055)

        for btn in [emojiToolbarButton, textToolsToolbarButton, splitToolbarButton] {
            btn.backgroundColor = pillFill
            btn.tintColor = .label
        }

        let clipActive = (page == .clipboard)
        clipboardToolbarButton.setImage(
            SymbolCache.image(clipActive ? "doc.on.clipboard.fill" : "doc.on.clipboard", size: 15.5, weight: .medium),
            for: .normal
        )
        clipboardToolbarButton.backgroundColor = clipActive ? .systemBlue : pillFill
        clipboardToolbarButton.tintColor = clipActive ? .white : .label

        let emojiActive = (page == .emoji)
        emojiToolbarButton.backgroundColor = emojiActive ? .systemBlue : pillFill
        emojiToolbarButton.tintColor = emojiActive ? .white : .label

        splitToolbarButton.setImage(
            SymbolCache.image(isSplitLayoutActive ? "rectangle.split.2x1.fill" : "rectangle.split.2x1", size: 14.5, weight: .medium),
            for: .normal
        )

        for (idx, btn) in candidateButtons.enumerated() {
            btn.setTitleColor(.label, for: .normal)
            btn.backgroundColor = idx == 0
                ? (isDark ? UIColor.white.withAlphaComponent(0.12) : UIColor.white.withAlphaComponent(0.68))
                : .clear
        }
        for div in candidateDividers {
            div.backgroundColor = UIColor.separator.withAlphaComponent(0.38)
        }

        emojiSearchQueryLabel.backgroundColor = pillFill
        emojiSearchCloseButton.backgroundColor = pillFill
        emojiSearchCloseButton.setTitleColor(.label, for: .normal)
    }

    private func layoutTopToolbar() {
        let bounds = topToolbarView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let pillH = min(30, bounds.height - 4)
        let pillY = (bounds.height - pillH) * 0.5

        if page == .emoji && emojiSearching {
            languagePillButton.isHidden = true
            smartPasteChipButton.isHidden = true
            for btn in candidateButtons { btn.isHidden = true }
            for div in candidateDividers { div.isHidden = true }
            emojiToolbarButton.isHidden = true
            clipboardToolbarButton.isHidden = true
            textToolsToolbarButton.isHidden = true
            splitToolbarButton.isHidden = true
            emojiSearchQueryLabel.isHidden = true
            emojiSearchCloseButton.isHidden = true

            let count = emojiResultButtons.filter { !$0.isHidden }.count
            guard count > 0 else { return }
            let slotW = bounds.width / CGFloat(count)
            for idx in 0..<count {
                emojiResultButtons[idx].frame = CGRect(x: CGFloat(idx) * slotW, y: 0, width: slotW, height: bounds.height)
            }
            return
        }

        for btn in emojiResultButtons { btn.isHidden = true }
        emojiSearchQueryLabel.isHidden = true
        emojiSearchCloseButton.isHidden = true

        // Left: VI / EN capsule
        languagePillButton.isHidden = false
        let langW: CGFloat = 40
        languagePillButton.frame = CGRect(x: 2, y: pillY, width: langW, height: pillH)
        languagePillButton.layer.cornerRadius = pillH * 0.5

        // Right: action pills (Emoji when Globe takes bottom-left, Clipboard, Aa, optional Split)
        let iconW: CGFloat = 32
        let iconGap: CGFloat = 5
        var rightX = bounds.width - 2

        let showSplitInTop = currentPosture.allowsSplit
        splitToolbarButton.isHidden = !showSplitInTop
        if showSplitInTop {
            rightX -= iconW
            splitToolbarButton.frame = CGRect(x: rightX, y: pillY, width: iconW, height: pillH)
            splitToolbarButton.layer.cornerRadius = pillH * 0.5
            rightX -= iconGap
        }

        textToolsToolbarButton.isHidden = false
        rightX -= iconW
        textToolsToolbarButton.frame = CGRect(x: rightX, y: pillY, width: iconW, height: pillH)
        textToolsToolbarButton.layer.cornerRadius = pillH * 0.5
        rightX -= iconGap

        clipboardToolbarButton.isHidden = false
        rightX -= iconW
        clipboardToolbarButton.frame = CGRect(x: rightX, y: pillY, width: iconW, height: pillH)
        clipboardToolbarButton.layer.cornerRadius = pillH * 0.5
        rightX -= iconGap

        // Keep Emoji button in top toolbar whenever Globe occupies the bottom-left slot!
        let showEmojiInTop = needsInputModeSwitchKey
        emojiToolbarButton.isHidden = !showEmojiInTop
        if showEmojiInTop {
            rightX -= iconW
            emojiToolbarButton.frame = CGRect(x: rightX, y: pillY, width: iconW, height: pillH)
            emojiToolbarButton.layer.cornerRadius = pillH * 0.5
            rightX -= iconGap
        }

        // Middle: Smart Paste chip OR up to 3 candidates
        let candStartX = langW + 8
        let candEndX = max(candStartX, rightX - 4)
        let candAvailW = candEndX - candStartX

        guard settings.effectiveShowSuggestions, candAvailW >= 60 else {
            smartPasteChipButton.isHidden = true
            for btn in candidateButtons { btn.isHidden = true }
            for div in candidateDividers { div.isHidden = true }
            return
        }

        if !smartPasteChipButton.isHidden {
            let chipW = min(candAvailW, max(120, smartPasteChipButton.intrinsicContentSize.width + 12))
            if candidates.isEmpty || candAvailW - chipW < 80 {
                smartPasteChipButton.frame = CGRect(x: candStartX, y: pillY, width: chipW, height: pillH)
                for btn in candidateButtons { btn.isHidden = true }
                for div in candidateDividers { div.isHidden = true }
                return
            } else {
                smartPasteChipButton.frame = CGRect(x: candStartX, y: pillY, width: chipW, height: pillH)
                let remStart = candStartX + chipW + 6
                let remW = candEndX - remStart
                let visibleCount = min(2, candidates.count)
                let slotW = remW / CGFloat(max(1, visibleCount))
                for idx in 0..<3 {
                    if idx < visibleCount {
                        candidateButtons[idx].isHidden = false
                        candidateButtons[idx].frame = CGRect(x: remStart + CGFloat(idx) * slotW, y: pillY, width: slotW, height: pillH)
                    } else {
                        candidateButtons[idx].isHidden = true
                    }
                }
                for div in candidateDividers { div.isHidden = true }
                return
            }
        }

        let visibleCount = min(3, candidates.count)
        guard visibleCount > 0 else {
            for btn in candidateButtons { btn.isHidden = true }
            for div in candidateDividers { div.isHidden = true }
            return
        }
        let slotW = candAvailW / CGFloat(visibleCount)
        for idx in 0..<3 {
            if idx < visibleCount {
                candidateButtons[idx].isHidden = false
                candidateButtons[idx].frame = CGRect(
                    x: candStartX + CGFloat(idx) * slotW + 1,
                    y: pillY,
                    width: max(0, slotW - 2),
                    height: pillH
                )
            } else {
                candidateButtons[idx].isHidden = true
            }
        }
        for dIdx in 0..<2 {
            if dIdx + 1 < visibleCount {
                candidateDividers[dIdx].isHidden = false
                candidateDividers[dIdx].frame = CGRect(
                    x: candStartX + CGFloat(dIdx + 1) * slotW,
                    y: (bounds.height - 16) * 0.5,
                    width: 0.5,
                    height: 16
                )
            } else {
                candidateDividers[dIdx].isHidden = true
            }
        }
    }

    // MARK: - One-Handed Dock

    private func setupOneHandedDock() {
        dockExpandButton.keyRole = .modifier
        dockExpandButton.setImage(SymbolCache.image("arrow.up.left.and.arrow.down.right", size: 16, weight: .semibold), for: .normal)
        dockExpandButton.accessibilityLabel = "Bàn phím đầy đủ"
        dockExpandButton.accessibilityIdentifier = "keyboard.expandFull"
        dockExpandButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.setOneHandedPreference(.full)
            self.lastLaidOutBounds = .zero
            self.layoutRootRegions()
            self.rebuildActivePlane()
        }, for: .touchUpInside)
        oneHandedDockView.addSubview(dockExpandButton)

        dockSwitchSideButton.keyRole = .modifier
        dockSwitchSideButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            let next: IOSKeyboardSettings.OneHandedMode = (self.effectiveOneHandedMode == .right) ? .left : .right
            self.setOneHandedPreference(next)
            self.lastLaidOutBounds = .zero
            self.layoutRootRegions()
            self.rebuildActivePlane()
        }, for: .touchUpInside)
        oneHandedDockView.addSubview(dockSwitchSideButton)
    }

    private func layoutOneHandedDock() {
        let b = oneHandedDockView.bounds
        guard b.width > 0, b.height > 0 else { return }
        let btnH: CGFloat = min(54, (b.height - 10) * 0.5)
        let startY = (b.height - (btnH * 2 + 10)) * 0.5
        dockExpandButton.frame = CGRect(x: 2, y: startY, width: b.width - 4, height: btnH)
        dockSwitchSideButton.frame = CGRect(x: 2, y: startY + btnH + 10, width: b.width - 4, height: btnH)

        let targetIsLeft = (effectiveOneHandedMode == .right)
        let sym = targetIsLeft ? "keyboard.onehanded.left" : "keyboard.onehanded.right"
        dockSwitchSideButton.setImage(SymbolCache.image(sym, size: 17, weight: .medium), for: .normal)
        dockSwitchSideButton.accessibilityLabel = targetIsLeft ? "Gõ một tay trái" : "Gõ một tay phải"
    }

    private func setOneHandedPreference(_ mode: IOSKeyboardSettings.OneHandedMode) {
        if currentPosture == .coverCompact {
            settings.coverOneHandedMode = mode
        } else {
            settings.oneHandedMode = mode
        }
    }

    // MARK: - Key Plane Builder (Zero Auto Layout, Pooled Reusable Keycaps)

    private func ensurePoolCapacity(_ count: Int) {
        while keyPool.count < count {
            let btn = LiquidKeyCapButton(frame: .zero)
            btn.tag = keyPool.count
            btn.addTarget(self, action: #selector(handlePoolKeyTouchDown(_:forEvent:)), for: .touchDown)
            btn.addTarget(self, action: #selector(handlePoolKeyTouchDrag(_:forEvent:)), for: [.touchDragInside, .touchDragOutside])
            btn.addTarget(self, action: #selector(handlePoolKeyTouchUpInside(_:forEvent:)), for: .touchUpInside)
            btn.addTarget(self, action: #selector(handlePoolKeyTouchUpOutside(_:forEvent:)), for: .touchUpOutside)
            btn.addTarget(self, action: #selector(handlePoolKeyTouchCancel(_:)), for: .touchCancel)
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePoolKeyLongPress(_:)))
            longPress.minimumPressDuration = 0.34
            longPress.cancelsTouchesInView = false
            btn.addGestureRecognizer(longPress)
            let spacePan = UIPanGestureRecognizer(target: self, action: #selector(handleSpacePan(_:)))
            spacePan.isEnabled = false
            btn.addGestureRecognizer(spacePan)
            keyPool.append(btn)
            keyPlaneView.addSubview(btn)
        }
    }

    private func rebuildActivePlane() {
        dismissAccentStrip()
        hideKeyPreview()
        centerBridgeHost?.removeFromSuperview()
        centerBridgeHost = nil
        styleTopToolbarColors()
        layoutTopToolbar()

        // Overlay pages: Emoji Grid or Clipboard Manager
        if page == .emoji && !emojiSearching {
            keyPlaneView.isHidden = true
            overlayPanelView.isHidden = false
            renderEmojiOverlay()
            return
        }
        if page == .clipboard {
            keyPlaneView.isHidden = true
            overlayPanelView.isHidden = false
            renderClipboardOverlay()
            return
        }

        overlayPanelView.isHidden = true
        for sub in overlayPanelView.subviews { sub.removeFromSuperview() }
        keyPlaneView.isHidden = false

        let planeBounds = keyPlaneView.bounds
        guard planeBounds.width > 40, planeBounds.height > 80 else { return }

        let placed: [PlacedKey]
        if page == .emoji && emojiSearching {
            placed = computeEmojiSearchKeys(in: planeBounds)
        } else if isSplitLayoutActive {
            placed = computeSplitKeys(in: planeBounds)
        } else if traitCollection.userInterfaceIdiom == .pad, page == .letters, planeBounds.width >= 660 {
            placed = computeFullPadProKeys(in: planeBounds)
        } else {
            placed = computeUnifiedAppleKeys(in: planeBounds)
        }

        ensurePoolCapacity(placed.count)
        activeKeyActions = placed.map(\.action)
        letterPoolIndices.removeAll(keepingCapacity: true)
        spacePoolIndices.removeAll(keepingCapacity: true)
        shiftPoolIndices.removeAll(keepingCapacity: true)

        let cornerR: CGFloat = isPadLayout ? 10 : 8.5

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (idx, spec) in placed.enumerated() {
            let btn = keyPool[idx]
            btn.isHidden = false
            btn.keyCornerRadius = cornerR
            btn.frame = spec.frame.integral
            btn.keyRole = spec.role
            btn.accessibilityLabel = spec.accLabel
            btn.accessibilityIdentifier = spec.accID

            // Configure globe target if needed
            btn.removeTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            if case .globe = spec.action {
                btn.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            }

            // Enable pan gesture ONLY on spacebar keys
            if let pan = btn.gestureRecognizers?.compactMap({ $0 as? UIPanGestureRecognizer }).first {
                if case .space = spec.action {
                    pan.isEnabled = true
                } else {
                    pan.isEnabled = false
                }
            }

            if let sym = spec.symbol {
                btn.setTitle(nil, for: .normal)
                btn.setImage(SymbolCache.image(sym.name, size: sym.size, weight: sym.weight), for: .normal)
            } else {
                btn.setImage(nil, for: .normal)
                btn.setTitle(spec.title, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: spec.fontSize, weight: spec.fontWeight)
            }

            if let flick = spec.flick {
                btn.flickLabel.isHidden = false
                btn.flickLabel.text = String(flick)
                btn.flickLabel.font = .systemFont(ofSize: isPadLayout ? 10 : 8.5, weight: .semibold)
            } else {
                btn.flickLabel.isHidden = true
            }

            switch spec.action {
            case .character(_, let lower, _):
                if page == .letters {
                    letterPoolIndices.append((idx, lower))
                }
            case .shift:
                shiftPoolIndices.append(idx)
            case .space:
                spacePoolIndices.append(idx)
            default:
                break
            }
            btn.applyAppearance()
        }

        if placed.count < keyPool.count {
            for idx in placed.count..<keyPool.count {
                keyPool[idx].isHidden = true
            }
        }
        CATransaction.commit()
    }

    // MARK: - Unified Apple iOS 26 Ergonomic Key Geometry (Identical Widths Across Rows 1–3!)

    private func computeUnifiedAppleKeys(in bounds: CGRect) -> [PlacedKey] {
        let W = bounds.width
        let H = bounds.height
        let hGap: CGFloat = isPadLayout ? 8 : 6
        let vGap: CGFloat = isCompactLandscape ? 7 : 10
        let hasNumberRow = settings.showNumberRow && page == .letters
        let totalRows = hasNumberRow ? 5 : 4
        let keyH = max(30, (H - CGFloat(totalRows - 1) * vGap) / CGFloat(totalRows))
        let letterFont: CGFloat = isCompactLandscape ? 19.5 : (isPadLayout ? 23 : 22)

        // Exact 10-column pitch — shared across Row 1, Row 2, and Row 3 on `.letters`!
        let keyW = (W - 9 * hGap) / 10
        var out: [PlacedKey] = []
        out.reserveCapacity(36)
        var rowIndex = 0

        func rowY(_ r: Int) -> CGFloat { CGFloat(r) * (keyH + vGap) }

        // Optional Number Row
        if hasNumberRow {
            let y = rowY(rowIndex)
            for (col, ch) in "1234567890".enumerated() {
                let x = CGFloat(col) * (keyW + hGap)
                let s = String(ch)
                out.append(PlacedKey(
                    frame: CGRect(x: x, y: y, width: keyW, height: keyH),
                    title: s,
                    symbol: nil,
                    flick: nil,
                    accLabel: s,
                    accID: nil,
                    role: .character,
                    fontSize: letterFont - 2,
                    fontWeight: .regular,
                    action: .character(primary: ch, lowercase: ch, flick: nil)
                ))
            }
            rowIndex += 1
        }

        let rowsText: [String] = switch page {
        case .letters: ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        case .numbers: ["1234567890", "-/:;()$&@\"", ".,?!'"]
        case .symbols: ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'"]
        case .emoji, .clipboard: []
        }

        // Row 1 (10 keys)
        if rowsText.count >= 1 {
            let y = rowY(rowIndex)
            for (col, lower) in rowsText[0].enumerated() {
                let primary: Character = (page == .letters && isShifted) ? Character(String(lower).uppercased()) : lower
                let flick = (page == .letters && settings.flickDownSymbols) ? Self.flickCharacters[lower] : nil
                let s = String(primary)
                out.append(PlacedKey(
                    frame: CGRect(x: CGFloat(col) * (keyW + hGap), y: y, width: keyW, height: keyH),
                    title: s,
                    symbol: nil,
                    flick: flick,
                    accLabel: s,
                    accID: nil,
                    role: .character,
                    fontSize: letterFont,
                    fontWeight: .regular,
                    action: .character(primary: primary, lowercase: lower, flick: flick)
                ))
            }
            rowIndex += 1
        }

        // Row 2 (9 keys on `.letters` with exact half-key Apple indent; 10 keys on `.numbers`/`.symbols`)
        if rowsText.count >= 2 {
            let y = rowY(rowIndex)
            let chars = Array(rowsText[1])
            let rowSpan = CGFloat(chars.count) * keyW + CGFloat(max(0, chars.count - 1)) * hGap
            let startX = (W - rowSpan) * 0.5
            for (col, lower) in chars.enumerated() {
                let primary: Character = (page == .letters && isShifted) ? Character(String(lower).uppercased()) : lower
                let flick = (page == .letters && settings.flickDownSymbols) ? Self.flickCharacters[lower] : nil
                let s = String(primary)
                out.append(PlacedKey(
                    frame: CGRect(x: startX + CGFloat(col) * (keyW + hGap), y: y, width: keyW, height: keyH),
                    title: s,
                    symbol: nil,
                    flick: flick,
                    accLabel: s,
                    accID: nil,
                    role: .character,
                    fontSize: letterFont,
                    fontWeight: .regular,
                    action: .character(primary: primary, lowercase: lower, flick: flick)
                ))
            }
            rowIndex += 1
        }

        // Row 3 (Shift/#+= + 7 letter keys or 5 punctuation keys + Backspace)
        if rowsText.count >= 3 {
            let y = rowY(rowIndex)
            let chars = Array(rowsText[2])
            let modW: CGFloat = isPadLayout ? max(56, keyW * 1.25) : max(42, keyW * 1.28)

            // Leading modifier: Shift on `.letters`, `#+=` on `.numbers`, `123` on `.symbols`
            out.append(makeLeadingRow3Spec(frame: CGRect(x: 0, y: y, width: modW, height: keyH)))

            if page == .letters {
                // Exact `keyW` per letter so Z..M align perfectly with Rows 1 & 2!
                let centerSpan = CGFloat(chars.count) * keyW + CGFloat(max(0, chars.count - 1)) * hGap
                let startX = (W - centerSpan) * 0.5
                for (col, lower) in chars.enumerated() {
                    let primary: Character = isShifted ? Character(String(lower).uppercased()) : lower
                    let flick = settings.flickDownSymbols ? Self.flickCharacters[lower] : nil
                    let s = String(primary)
                    out.append(PlacedKey(
                        frame: CGRect(x: startX + CGFloat(col) * (keyW + hGap), y: y, width: keyW, height: keyH),
                        title: s,
                        symbol: nil,
                        flick: flick,
                        accLabel: s,
                        accID: nil,
                        role: .character,
                        fontSize: letterFont,
                        fontWeight: .regular,
                        action: .character(primary: primary, lowercase: lower, flick: flick)
                    ))
                }
            } else {
                // 5 roomy punctuation keys (`. , ? ! '`) between leading modifier and Backspace
                let sideGap: CGFloat = isPadLayout ? 14 : 11
                let availW = W - modW * 2 - sideGap * 2
                let punctW = (availW - CGFloat(chars.count - 1) * hGap) / CGFloat(chars.count)
                let startX = modW + sideGap
                for (col, ch) in chars.enumerated() {
                    let s = String(ch)
                    out.append(PlacedKey(
                        frame: CGRect(x: startX + CGFloat(col) * (punctW + hGap), y: y, width: punctW, height: keyH),
                        title: s,
                        symbol: nil,
                        flick: nil,
                        accLabel: s,
                        accID: nil,
                        role: .character,
                        fontSize: letterFont,
                        fontWeight: .regular,
                        action: .character(primary: ch, lowercase: ch, flick: nil)
                    ))
                }
            }

            // Trailing Backspace
            out.append(PlacedKey(
                frame: CGRect(x: W - modW, y: y, width: modW, height: keyH),
                title: nil,
                symbol: ("delete.left", isPadLayout ? 19 : 18, .medium),
                flick: nil,
                accLabel: "Xoá",
                accID: "keyboard.backspace",
                role: .modifier,
                fontSize: 16,
                fontWeight: .medium,
                action: .backspace
            ))
            rowIndex += 1
        }

        // Row 4 (Bottom Row — Clean Apple iOS 26 Layout: [123] [🌐/😊] [ Wide Spacebar ] [conv?] [Return])
        let y4 = rowY(rowIndex)
        let pageW: CGFloat = isPadLayout ? 58 : 44
        let secW: CGFloat = isPadLayout ? 52 : 42
        let retW: CGFloat = isPadLayout ? 104 : 86

        out.append(PlacedKey(
            frame: CGRect(x: 0, y: y4, width: pageW, height: keyH),
            title: page == .letters ? "123" : "ABC",
            symbol: nil,
            flick: nil,
            accLabel: page == .letters ? "123" : "ABC",
            accID: "keyboard.pageToggle",
            role: .modifier,
            fontSize: 15.5,
            fontWeight: .medium,
            action: .pageToggle
        ))

        let secX = pageW + hGap
        if needsInputModeSwitchKey {
            out.append(PlacedKey(
                frame: CGRect(x: secX, y: y4, width: secW, height: keyH),
                title: nil,
                symbol: ("globe", 18, .medium),
                flick: nil,
                accLabel: "Đổi bàn phím",
                accID: "keyboard.globe",
                role: .modifier,
                fontSize: 16,
                fontWeight: .medium,
                action: .globe
            ))
        } else {
            out.append(PlacedKey(
                frame: CGRect(x: secX, y: y4, width: secW, height: keyH),
                title: nil,
                symbol: ("face.smiling", 18, .medium),
                flick: nil,
                accLabel: "Emoji",
                accID: "keyboard.emoji",
                role: .modifier,
                fontSize: 16,
                fontWeight: .medium,
                action: .emojiPage
            ))
        }

        let convChars = contextConvenienceCharacters()
        let convW: CGFloat = isPadLayout ? 42 : 34
        let totalConvW = convChars.isEmpty ? 0 : CGFloat(convChars.count) * (convW + hGap)

        let spaceX = secX + secW + hGap
        let retX = W - retW
        let spaceW = max(80, retX - totalConvW - hGap - spaceX)

        out.append(PlacedKey(
            frame: CGRect(x: spaceX, y: y4, width: spaceW, height: keyH),
            title: session.isVietnamese ? "Tiếng Việt" : "English",
            symbol: nil,
            flick: nil,
            accLabel: "Dấu cách",
            accID: "keyboard.space",
            role: .character,
            fontSize: 15.5,
            fontWeight: .regular,
            action: .space(isPrimary: true)
        ))

        var cx = spaceX + spaceW + hGap
        for ch in convChars {
            let s = String(ch)
            out.append(PlacedKey(
                frame: CGRect(x: cx, y: y4, width: convW, height: keyH),
                title: s,
                symbol: nil,
                flick: nil,
                accLabel: s,
                accID: nil,
                role: .character,
                fontSize: 18,
                fontWeight: .regular,
                action: .character(primary: ch, lowercase: ch, flick: nil)
            ))
            cx += convW + hGap
        }

        let (retTitle, retProminent) = returnKeySpec()
        out.append(PlacedKey(
            frame: CGRect(x: retX, y: y4, width: retW, height: keyH),
            title: retTitle,
            symbol: nil,
            flick: nil,
            accLabel: retTitle,
            accID: "keyboard.return",
            role: retProminent ? .prominent : .modifier,
            fontSize: 15.5,
            fontWeight: retProminent ? .semibold : .medium,
            action: .returnKey
        ))

        return out
    }

    // MARK: - Full-Size iPad Pro Layout (Collapses Automatically in Floating Keyboard < 660pt!)

    private func computeFullPadProKeys(in bounds: CGRect) -> [PlacedKey] {
        let W = bounds.width
        let H = bounds.height
        let hGap: CGFloat = 8
        let vGap: CGFloat = 10
        let hasNumberRow = settings.showNumberRow
        let totalRows = hasNumberRow ? 5 : 4
        let keyH = max(36, (H - CGFloat(totalRows - 1) * vGap) / CGFloat(totalRows))
        let fontSize: CGFloat = 22
        var out: [PlacedKey] = []
        out.reserveCapacity(42)
        var rowIndex = 0
        func rowY(_ r: Int) -> CGFloat { CGFloat(r) * (keyH + vGap) }

        if hasNumberRow {
            let y = rowY(rowIndex)
            let numW = (W - 9 * hGap) / 10
            for (col, ch) in "1234567890".enumerated() {
                let s = String(ch)
                out.append(PlacedKey(
                    frame: CGRect(x: CGFloat(col) * (numW + hGap), y: y, width: numW, height: keyH),
                    title: s, symbol: nil, flick: nil, accLabel: s, accID: nil,
                    role: .character, fontSize: fontSize - 2, fontWeight: .regular,
                    action: .character(primary: ch, lowercase: ch, flick: nil)
                ))
            }
            rowIndex += 1
        }

        // Row 1: [Tab ⇥] + Q W E R T Y U I O P + [⌫ Backspace]
        let y1 = rowY(rowIndex)
        let tabW: CGFloat = 58
        let delW: CGFloat = 68
        let r1Avail = W - tabW - delW - 11 * hGap
        let keyW = r1Avail / 10

        out.append(PlacedKey(
            frame: CGRect(x: 0, y: y1, width: tabW, height: keyH),
            title: nil, symbol: ("arrow.right.to.line", 17, .medium), flick: nil,
            accLabel: "Tab", accID: "keyboard.tab", role: .modifier,
            fontSize: 15, fontWeight: .medium, action: .tabKey
        ))
        var x1 = tabW + hGap
        for lower in "qwertyuiop" {
            let primary: Character = isShifted ? Character(String(lower).uppercased()) : lower
            let flick = settings.flickDownSymbols ? Self.flickCharacters[lower] : nil
            let s = String(primary)
            out.append(PlacedKey(
                frame: CGRect(x: x1, y: y1, width: keyW, height: keyH),
                title: s, symbol: nil, flick: flick, accLabel: s, accID: nil,
                role: .character, fontSize: fontSize, fontWeight: .regular,
                action: .character(primary: primary, lowercase: lower, flick: flick)
            ))
            x1 += keyW + hGap
        }
        out.append(PlacedKey(
            frame: CGRect(x: W - delW, y: y1, width: delW, height: keyH),
            title: nil, symbol: ("delete.left", 19, .medium), flick: nil,
            accLabel: "Xoá", accID: "keyboard.backspace", role: .modifier,
            fontSize: 16, fontWeight: .medium, action: .backspace
        ))
        rowIndex += 1

        // Row 2: Half-indent + A S D F G H J K L + [; / :] + [Return]
        let y2 = rowY(rowIndex)
        let indent2: CGFloat = 28
        let retW: CGFloat = max(84, W - indent2 - 10 * keyW - 10 * hGap)
        var x2 = indent2
        for lower in "asdfghjkl" {
            let primary: Character = isShifted ? Character(String(lower).uppercased()) : lower
            let flick = settings.flickDownSymbols ? Self.flickCharacters[lower] : nil
            let s = String(primary)
            out.append(PlacedKey(
                frame: CGRect(x: x2, y: y2, width: keyW, height: keyH),
                title: s, symbol: nil, flick: flick, accLabel: s, accID: nil,
                role: .character, fontSize: fontSize, fontWeight: .regular,
                action: .character(primary: primary, lowercase: lower, flick: flick)
            ))
            x2 += keyW + hGap
        }
        let semiChar: Character = isShifted ? ":" : ";"
        out.append(PlacedKey(
            frame: CGRect(x: x2, y: y2, width: keyW, height: keyH),
            title: String(semiChar), symbol: nil, flick: ":", accLabel: String(semiChar), accID: nil,
            role: .character, fontSize: fontSize, fontWeight: .regular,
            action: .character(primary: semiChar, lowercase: ";", flick: ":")
        ))
        let (retTitle, retProminent) = returnKeySpec()
        out.append(PlacedKey(
            frame: CGRect(x: W - retW, y: y2, width: retW, height: keyH),
            title: retTitle, symbol: nil, flick: nil, accLabel: retTitle, accID: "keyboard.return",
            role: retProminent ? .prominent : .modifier, fontSize: 16,
            fontWeight: retProminent ? .semibold : .medium, action: .returnKey
        ))
        rowIndex += 1

        // Row 3: [Left Shift] + Z X C V B N M + [, / !] + [. / ?] + [Right Shift]
        let y3 = rowY(rowIndex)
        let centerSpan3 = 9 * keyW + 8 * hGap
        let shiftW = max(58, (W - centerSpan3 - 2 * hGap) * 0.5)
        out.append(makeLeadingRow3Spec(frame: CGRect(x: 0, y: y3, width: shiftW, height: keyH)))

        var x3 = shiftW + hGap
        for lower in "zxcvbnm" {
            let primary: Character = isShifted ? Character(String(lower).uppercased()) : lower
            let flick = settings.flickDownSymbols ? Self.flickCharacters[lower] : nil
            let s = String(primary)
            out.append(PlacedKey(
                frame: CGRect(x: x3, y: y3, width: keyW, height: keyH),
                title: s, symbol: nil, flick: flick, accLabel: s, accID: nil,
                role: .character, fontSize: fontSize, fontWeight: .regular,
                action: .character(primary: primary, lowercase: lower, flick: flick)
            ))
            x3 += keyW + hGap
        }
        let commaPrimary: Character = isShifted ? "!" : ","
        out.append(PlacedKey(
            frame: CGRect(x: x3, y: y3, width: keyW, height: keyH),
            title: String(commaPrimary), symbol: nil, flick: "!", accLabel: String(commaPrimary), accID: nil,
            role: .character, fontSize: fontSize, fontWeight: .regular,
            action: .character(primary: commaPrimary, lowercase: ",", flick: "!")
        ))
        x3 += keyW + hGap
        let dotPrimary: Character = isShifted ? "?" : "."
        out.append(PlacedKey(
            frame: CGRect(x: x3, y: y3, width: keyW, height: keyH),
            title: String(dotPrimary), symbol: nil, flick: "?", accLabel: String(dotPrimary), accID: nil,
            role: .character, fontSize: fontSize, fontWeight: .regular,
            action: .character(primary: dotPrimary, lowercase: ".", flick: "?")
        ))
        out.append(makeLeadingRow3Spec(frame: CGRect(x: W - shiftW, y: y3, width: shiftW, height: keyH)))
        rowIndex += 1

        // Row 4: [123] + [🌐/😊] + [ Wide Spacebar ] + [123] + [⌨️▾ Dismiss]
        let y4 = rowY(rowIndex)
        let numBtnW: CGFloat = 66
        let sideBtnW: CGFloat = 54
        out.append(PlacedKey(
            frame: CGRect(x: 0, y: y4, width: numBtnW, height: keyH),
            title: "123", symbol: nil, flick: nil, accLabel: "123", accID: "keyboard.pageToggle",
            role: .modifier, fontSize: 16, fontWeight: .medium, action: .pageToggle
        ))
        let secX = numBtnW + hGap
        if needsInputModeSwitchKey {
            out.append(PlacedKey(
                frame: CGRect(x: secX, y: y4, width: sideBtnW, height: keyH),
                title: nil, symbol: ("globe", 18, .medium), flick: nil,
                accLabel: "Đổi bàn phím", accID: "keyboard.globe",
                role: .modifier, fontSize: 16, fontWeight: .medium, action: .globe
            ))
        } else {
            out.append(PlacedKey(
                frame: CGRect(x: secX, y: y4, width: sideBtnW, height: keyH),
                title: nil, symbol: ("face.smiling", 18, .medium), flick: nil,
                accLabel: "Emoji", accID: "keyboard.emoji",
                role: .modifier, fontSize: 16, fontWeight: .medium, action: .emojiPage
            ))
        }
        let spaceX = secX + sideBtnW + hGap
        let rightNumX = W - sideBtnW - hGap - numBtnW
        let spaceW = max(140, rightNumX - hGap - spaceX)
        out.append(PlacedKey(
            frame: CGRect(x: spaceX, y: y4, width: spaceW, height: keyH),
            title: session.isVietnamese ? "Tiếng Việt" : "English",
            symbol: nil, flick: nil, accLabel: "Dấu cách", accID: "keyboard.space",
            role: .character, fontSize: 16, fontWeight: .regular, action: .space(isPrimary: true)
        ))
        out.append(PlacedKey(
            frame: CGRect(x: rightNumX, y: y4, width: numBtnW, height: keyH),
            title: ".?123", symbol: nil, flick: nil, accLabel: ".?123", accID: nil,
            role: .modifier, fontSize: 15, fontWeight: .medium, action: .pageToggle
        ))
        out.append(PlacedKey(
            frame: CGRect(x: W - sideBtnW, y: y4, width: sideBtnW, height: keyH),
            title: nil, symbol: ("keyboard.chevron.compact.down", 18, .medium), flick: nil,
            accLabel: "Ẩn bàn phím", accID: "keyboard.dismiss",
            role: .modifier, fontSize: 16, fontWeight: .medium, action: .dismissKeyboardKey
        ))
        return out
    }

    // MARK: - Split Ergonomic Layout (iPad & Unfolded iPhone Duo + Center Bridge)

    private func computeSplitKeys(in bounds: CGRect) -> [PlacedKey] {
        let W = bounds.width
        let H = bounds.height
        let posture = currentPosture
        let gapW = CGFloat(posture.recommendedBridgeWidth(for: Double(activeContainerSize.width)))
        let halfW = max(120, (W - gapW) * 0.5)
        let rightOriginX = halfW + gapW
        let hGap: CGFloat = isPadLayout ? 7 : 5
        let vGap: CGFloat = isCompactLandscape ? 7 : 9
        let hasNumberRow = settings.showNumberRow && page == .letters
        let totalRows = hasNumberRow ? 5 : 4
        let keyH = max(30, (H - CGFloat(totalRows - 1) * vGap) / CGFloat(totalRows))
        let fontSize: CGFloat = isCompactLandscape ? 18 : 20.5

        if posture.usesInteractiveCenterBridge(for: Double(activeContainerSize.width)) {
            let bridge = makeInteractiveCenterBridgeView(
                frame: CGRect(x: halfW + 6, y: 0, width: max(80, gapW - 12), height: H)
            )
            keyPlaneView.addSubview(bridge)
            centerBridgeHost = bridge
        }

        var out: [PlacedKey] = []
        var rowIndex = 0
        func rowY(_ r: Int) -> CGFloat { CGFloat(r) * (keyH + vGap) }

        func addCluster(_ chars: [Character], originX: CGFloat, clusterW: CGFloat, y: CGFloat) {
            guard !chars.isEmpty else { return }
            let kw = (clusterW - CGFloat(chars.count - 1) * hGap) / CGFloat(chars.count)
            for (idx, lower) in chars.enumerated() {
                let primary: Character = (page == .letters && isShifted) ? Character(String(lower).uppercased()) : lower
                let flick = (page == .letters && settings.flickDownSymbols) ? Self.flickCharacters[lower] : nil
                let s = String(primary)
                out.append(PlacedKey(
                    frame: CGRect(x: originX + CGFloat(idx) * (kw + hGap), y: y, width: kw, height: keyH),
                    title: s,
                    symbol: nil,
                    flick: flick,
                    accLabel: s,
                    accID: nil,
                    role: .character,
                    fontSize: fontSize,
                    fontWeight: .regular,
                    action: .character(primary: primary, lowercase: lower, flick: flick)
                ))
            }
        }

        if hasNumberRow {
            let y = rowY(rowIndex)
            addCluster(Array("12345"), originX: 0, clusterW: halfW, y: y)
            addCluster(Array("67890"), originX: rightOriginX, clusterW: halfW, y: y)
            rowIndex += 1
        }

        let dup = settings.duoDuplicateBoundaryKeys && page == .letters
        let letterPairs: [(String, String)] = dup
            ? [("qwert", "yuiop"), ("asdfg", "ghjkl"), ("zxcvb", "bnm")]
            : [("qwert", "yuiop"), ("asdfg", "hjkl"), ("zxcv", "bnm")]

        let pairs: [(String, String)] = switch page {
        case .letters: letterPairs
        case .numbers: [("12345", "67890"), ("-/:;(", ")$&@\""), (".,?", "!'")]
        case .symbols: [("[]{}#", "%^*+="), ("_\\|~<", ">€£¥•"), (".,?", "!'")]
        case .emoji, .clipboard: []
        }

        for (idx, (leftStr, rightStr)) in pairs.enumerated() {
            let y = rowY(rowIndex)
            if idx == 2 {
                let modW: CGFloat = 44
                out.append(makeLeadingRow3Spec(frame: CGRect(x: 0, y: y, width: modW, height: keyH)))
                addCluster(Array(leftStr), originX: modW + hGap, clusterW: halfW - modW - hGap, y: y)
                addCluster(Array(rightStr), originX: rightOriginX, clusterW: halfW - modW - hGap, y: y)
                out.append(PlacedKey(
                    frame: CGRect(x: W - modW, y: y, width: modW, height: keyH),
                    title: nil,
                    symbol: ("delete.left", 17, .medium),
                    flick: nil,
                    accLabel: "Xoá",
                    accID: "keyboard.backspace",
                    role: .modifier,
                    fontSize: 15,
                    fontWeight: .medium,
                    action: .backspace
                ))
            } else {
                addCluster(Array(leftStr), originX: 0, clusterW: halfW, y: y)
                addCluster(Array(rightStr), originX: rightOriginX, clusterW: halfW, y: y)
            }
            rowIndex += 1
        }

        // Split bottom row
        let y4 = rowY(rowIndex)
        let btnW: CGFloat = 42
        out.append(PlacedKey(
            frame: CGRect(x: 0, y: y4, width: btnW, height: keyH),
            title: page == .letters ? "123" : "ABC",
            symbol: nil,
            flick: nil,
            accLabel: page == .letters ? "123" : "ABC",
            accID: "keyboard.pageToggle",
            role: .modifier,
            fontSize: 15,
            fontWeight: .medium,
            action: .pageToggle
        ))
        let secX = btnW + hGap
        if needsInputModeSwitchKey {
            out.append(PlacedKey(
                frame: CGRect(x: secX, y: y4, width: btnW, height: keyH),
                title: nil,
                symbol: ("globe", 17, .medium),
                flick: nil,
                accLabel: "Đổi bàn phím",
                accID: "keyboard.globe",
                role: .modifier,
                fontSize: 15,
                fontWeight: .medium,
                action: .globe
            ))
        } else {
            out.append(PlacedKey(
                frame: CGRect(x: secX, y: y4, width: btnW, height: keyH),
                title: nil,
                symbol: ("face.smiling", 17, .medium),
                flick: nil,
                accLabel: "Emoji",
                accID: "keyboard.emoji",
                role: .modifier,
                fontSize: 15,
                fontWeight: .medium,
                action: .emojiPage
            ))
        }
        let leftSpaceX = secX + btnW + hGap
        out.append(PlacedKey(
            frame: CGRect(x: leftSpaceX, y: y4, width: max(56, halfW - leftSpaceX), height: keyH),
            title: session.isVietnamese ? "Tiếng Việt" : "English",
            symbol: nil,
            flick: nil,
            accLabel: "Dấu cách",
            accID: "keyboard.space",
            role: .character,
            fontSize: 14.5,
            fontWeight: .regular,
            action: .space(isPrimary: true)
        ))

        let retW: CGFloat = 74
        let dotW: CGFloat = 38
        let rightSpaceW = max(56, halfW - dotW - retW - hGap * 2)
        out.append(PlacedKey(
            frame: CGRect(x: rightOriginX, y: y4, width: rightSpaceW, height: keyH),
            title: session.isVietnamese ? "Tiếng Việt" : "English",
            symbol: nil,
            flick: nil,
            accLabel: "Dấu cách phải",
            accID: "keyboard.rightSpace",
            role: .character,
            fontSize: 14.5,
            fontWeight: .regular,
            action: .space(isPrimary: false)
        ))
        out.append(PlacedKey(
            frame: CGRect(x: rightOriginX + rightSpaceW + hGap, y: y4, width: dotW, height: keyH),
            title: ".",
            symbol: nil,
            flick: nil,
            accLabel: ".",
            accID: nil,
            role: .character,
            fontSize: 18,
            fontWeight: .regular,
            action: .character(primary: ".", lowercase: ".", flick: nil)
        ))
        let (retTitle, retProminent) = returnKeySpec()
        out.append(PlacedKey(
            frame: CGRect(x: W - retW, y: y4, width: retW, height: keyH),
            title: retTitle,
            symbol: nil,
            flick: nil,
            accLabel: retTitle,
            accID: "keyboard.return",
            role: retProminent ? .prominent : .modifier,
            fontSize: 15,
            fontWeight: retProminent ? .semibold : .medium,
            action: .returnKey
        ))

        return out
    }

    private func computeEmojiSearchKeys(in bounds: CGRect) -> [PlacedKey] {
        let W = bounds.width
        let H = bounds.height
        let hGap: CGFloat = 6
        let vGap: CGFloat = 8
        let totalRows = 5
        let keyH = max(28, (H - CGFloat(totalRows - 1) * vGap) / CGFloat(totalRows))
        let keyW = (W - 9 * hGap) / 10
        var out: [PlacedKey] = []

        // Row 0: Search query banner + Close button
        emojiSearchQueryLabel.isHidden = false
        emojiSearchCloseButton.isHidden = false
        let closeW: CGFloat = 64
        emojiSearchQueryLabel.frame = CGRect(x: 0, y: 0, width: W - closeW - hGap, height: keyH)
        emojiSearchCloseButton.frame = CGRect(x: W - closeW, y: 0, width: closeW, height: keyH)
        if emojiSearchQueryLabel.superview !== keyPlaneView {
            keyPlaneView.addSubview(emojiSearchQueryLabel)
            keyPlaneView.addSubview(emojiSearchCloseButton)
        }

        for (rIdx, rowChars) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            let y = CGFloat(rIdx + 1) * (keyH + vGap)
            let chars = Array(rowChars)
            if rIdx == 2 {
                let centerSpan = CGFloat(chars.count) * keyW + CGFloat(chars.count - 1) * hGap
                let startX = (W - centerSpan - 48) * 0.5
                for (col, ch) in chars.enumerated() {
                    let s = String(ch)
                    out.append(PlacedKey(
                        frame: CGRect(x: startX + CGFloat(col) * (keyW + hGap), y: y, width: keyW, height: keyH),
                        title: s, symbol: nil, flick: nil, accLabel: s, accID: nil,
                        role: .character, fontSize: 20, fontWeight: .regular,
                        action: .emojiSearchChar(ch)
                    ))
                }
                out.append(PlacedKey(
                    frame: CGRect(x: W - 44, y: y, width: 44, height: keyH),
                    title: nil, symbol: ("delete.left", 17, .medium), flick: nil,
                    accLabel: "Xoá từ khoá", accID: nil, role: .modifier,
                    fontSize: 16, fontWeight: .medium, action: .emojiSearchBackspace
                ))
            } else {
                let span = CGFloat(chars.count) * keyW + CGFloat(chars.count - 1) * hGap
                let startX = (W - span) * 0.5
                for (col, ch) in chars.enumerated() {
                    let s = String(ch)
                    out.append(PlacedKey(
                        frame: CGRect(x: startX + CGFloat(col) * (keyW + hGap), y: y, width: keyW, height: keyH),
                        title: s, symbol: nil, flick: nil, accLabel: s, accID: nil,
                        role: .character, fontSize: 20, fontWeight: .regular,
                        action: .emojiSearchChar(ch)
                    ))
                }
            }
        }

        let y4 = CGFloat(4) * (keyH + vGap)
        out.append(PlacedKey(
            frame: CGRect(x: 0, y: y4, width: 58, height: keyH),
            title: "ABC", symbol: nil, flick: nil, accLabel: "ABC", accID: nil,
            role: .modifier, fontSize: 15, fontWeight: .medium, action: .pageToggle
        ))
        out.append(PlacedKey(
            frame: CGRect(x: 58 + hGap, y: y4, width: W - 58 - 76 - hGap * 2, height: keyH),
            title: "Cách", symbol: nil, flick: nil, accLabel: "Dấu cách từ khoá", accID: nil,
            role: .character, fontSize: 15, fontWeight: .regular, action: .emojiSearchSpace
        ))
        out.append(PlacedKey(
            frame: CGRect(x: W - 76, y: y4, width: 76, height: keyH),
            title: "Xoá hết", symbol: nil, flick: nil, accLabel: "Xoá hết", accID: nil,
            role: .modifier, fontSize: 14, fontWeight: .medium, action: .emojiSearchClear
        ))

        refreshEmojiSearchUI()
        return out
    }

    private func makeLeadingRow3Spec(frame: CGRect) -> PlacedKey {
        switch page {
        case .letters:
            let sym: String = switch shiftState {
            case .off: "shift"
            case .once: "shift.fill"
            case .locked: "capslock.fill"
            }
            return PlacedKey(
                frame: frame,
                title: nil,
                symbol: (sym, isPadLayout ? 19 : 18, .medium),
                flick: nil,
                accLabel: "Chữ hoa",
                accID: "keyboard.shift",
                role: shiftState == .off ? .modifier : .activeModifier,
                fontSize: 16,
                fontWeight: .medium,
                action: .shift
            )
        case .numbers:
            return PlacedKey(
                frame: frame,
                title: "#+=",
                symbol: nil,
                flick: nil,
                accLabel: "Ký hiệu",
                accID: "keyboard.symbols",
                role: .modifier,
                fontSize: 15,
                fontWeight: .medium,
                action: .symbolsToggle
            )
        case .symbols, .emoji, .clipboard:
            return PlacedKey(
                frame: frame,
                title: "123",
                symbol: nil,
                flick: nil,
                accLabel: "Số",
                accID: "keyboard.numbers",
                role: .modifier,
                fontSize: 15,
                fontWeight: .medium,
                action: .symbolsToggle
            )
        }
    }

    private func returnKeySpec() -> (title: String, isProminent: Bool) {
        let rt = textDocumentProxy.returnKeyType ?? .default
        return switch rt {
        case .go: ("Đi", true)
        case .google, .search, .yahoo: ("Tìm", true)
        case .send: ("Gửi", true)
        case .done: ("Xong", true)
        case .join: ("Tham gia", true)
        case .route: ("Đường đi", true)
        case .next: ("Tiếp", false)
        case .continue: ("Tiếp tục", false)
        default: ("Nhập", false)
        }
    }

    private func contextConvenienceCharacters() -> [Character] {
        guard let kt = textDocumentProxy.keyboardType else { return [] }
        return switch kt {
        case .emailAddress: ["@", "."]
        case .URL: ["/", "."]
        case .twitter: ["@", "#"]
        default: []
        }
    }

    // MARK: - Instant Multi-Touch, Slide-to-Key & Flick-Down Handlers

    @objc private func handlePoolKeyTouchDown(_ sender: LiquidKeyCapButton, forEvent event: UIEvent) {
        let idx = sender.tag
        guard activeKeyActions.indices.contains(idx) else { return }
        let touch = event.allTouches?.first
        touchStartPointInButton = touch?.location(in: sender)
        activeFlickCharacter = nil
        activeSlideButton = sender
        resetGlideTracking()

        switch activeKeyActions[idx] {
        case .character(let primary, let lower, _):
            showKeyPreview(for: sender, text: String(primary))
            if settings.glideTypingEnabled, page == .letters, session.isVietnamese, !isShifted, lower.isLetter,
               let pt = touch?.location(in: keyPlaneView) {
                glidePoints = [pt]
                glideSampledKeys = [lower]
            }
        case .emojiSearchChar(let ch):
            showKeyPreview(for: sender, text: String(ch))
        default:
            break
        }
    }

    @objc private func handlePoolKeyTouchDrag(_ sender: LiquidKeyCapButton, forEvent event: UIEvent) {
        let idx = sender.tag
        guard activeKeyActions.indices.contains(idx),
              let touch = event.allTouches?.first else { return }
        let locInSender = touch.location(in: sender)

        if case .character(let primary, _, let flick) = activeKeyActions[idx] {
            if !isGliding, let flick, let start = touchStartPointInButton,
               locInSender.y - start.y >= 17, abs(locInSender.x - start.x) <= 38 {
                activeFlickCharacter = flick
                activeSlideButton = sender
                showKeyPreview(for: sender, text: String(flick))
                return
            }
            activeFlickCharacter = nil

            let locInPlane = touch.location(in: keyPlaneView)

            // Track continuous Vietnamese Glide path when enabled
            if !glidePoints.isEmpty, let lastPt = glidePoints.last {
                let seg = hypot(locInPlane.x - lastPt.x, locInPlane.y - lastPt.y)
                if seg >= 4 {
                    glideTotalDistance += seg
                    glidePoints.append(locInPlane)
                    if glidePoints.count > 48 { glidePoints.removeFirst(glidePoints.count - 40) }
                }
                if let hovered = characterButton(at: locInPlane),
                   activeKeyActions.indices.contains(hovered.tag),
                   case .character(_, let hLower, _) = activeKeyActions[hovered.tag],
                   hLower.isLetter, glideSampledKeys.last != hLower {
                    glideSampledKeys.append(hLower)
                }

                if !isGliding, glideSampledKeys.count >= 3, glideTotalDistance >= 68 {
                    isGliding = true
                    activeSlideButton?.isHighlighted = false
                    hideKeyPreview()
                }

                if isGliding {
                    updateGlideTrailPath()
                    previewGlideCandidates()
                    return
                }
            }

            // Slide-across-keys tracking (just like Apple's native iOS keyboard!)
            if let hovered = characterButton(at: locInPlane), hovered !== activeSlideButton {
                activeSlideButton?.isHighlighted = false
                hovered.isHighlighted = true
                activeSlideButton = hovered
                if case .character(let hPrimary, _, _) = activeKeyActions[hovered.tag] {
                    showKeyPreview(for: hovered, text: String(hPrimary))
                }
            } else if activeSlideButton === sender {
                if sender.bounds.insetBy(dx: -18, dy: -20).contains(locInSender) {
                    showKeyPreview(for: sender, text: String(primary))
                } else {
                    hideKeyPreview()
                }
            }
        }
    }

    @objc private func handlePoolKeyTouchUpInside(_ sender: LiquidKeyCapButton, forEvent event: UIEvent) {
        hideKeyPreview()
        if isGliding {
            finishGlideCommit()
            return
        }
        defer {
            if let slid = activeSlideButton, slid !== sender { slid.isHighlighted = false }
            activeSlideButton = nil
            touchStartPointInButton = nil
            activeFlickCharacter = nil
            resetGlideTracking()
        }

        if let flick = activeFlickCharacter {
            type(flick)
            return
        }

        let targetButton = activeSlideButton ?? sender
        let idx = targetButton.tag
        guard activeKeyActions.indices.contains(idx) else { return }
        executeKeyAction(activeKeyActions[idx], button: targetButton, event: event)
    }

    @objc private func handlePoolKeyTouchUpOutside(_ sender: LiquidKeyCapButton, forEvent event: UIEvent) {
        hideKeyPreview()
        if isGliding {
            finishGlideCommit()
            return
        }
        defer {
            activeSlideButton?.isHighlighted = false
            activeSlideButton = nil
            touchStartPointInButton = nil
            activeFlickCharacter = nil
            resetGlideTracking()
        }

        if let flick = activeFlickCharacter {
            type(flick)
            return
        }

        if let slid = activeSlideButton, slid !== sender, activeKeyActions.indices.contains(slid.tag) {
            executeKeyAction(activeKeyActions[slid.tag], button: slid, event: event)
        }
    }

    @objc private func handlePoolKeyTouchCancel(_ sender: LiquidKeyCapButton) {
        activeSlideButton?.isHighlighted = false
        activeSlideButton = nil
        touchStartPointInButton = nil
        activeFlickCharacter = nil
        resetGlideTracking()
        hideKeyPreview()
    }

    private func resetGlideTracking() {
        isGliding = false
        glidePoints.removeAll(keepingCapacity: true)
        glideSampledKeys.removeAll(keepingCapacity: true)
        glideTotalDistance = 0
        if glideTrailLayer.path != nil {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            glideTrailLayer.path = nil
            CATransaction.commit()
        }
    }

    private func updateGlideTrailPath() {
        guard glidePoints.count >= 2 else { return }
        let bezier = UIBezierPath()
        bezier.move(to: glidePoints[0])
        for i in 1..<glidePoints.count {
            let prev = glidePoints[i - 1]
            let curr = glidePoints[i]
            let mid = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
            bezier.addQuadCurve(to: mid, controlPoint: prev)
        }
        if let last = glidePoints.last {
            bezier.addLine(to: last)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glideTrailLayer.path = bezier.cgPath
        CATransaction.commit()
    }

    private func currentDecodedGlideWords() -> [WordCandidate] {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let prevWords = before.split(whereSeparator: { !$0.isLetter }).suffix(2).map(String.init)
        let trimmed = before.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        let capFirst = settings.autoCapitalization
            && textDocumentProxy.autocapitalizationType != UITextAutocapitalizationType.none
            && (before.isEmpty || before.hasSuffix("\n") || (before.hasSuffix(" ") && (trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?"))))
        return GlideDecoder.decode(
            sampledKeys: glideSampledKeys,
            previousWords: prevWords,
            domain: cachedANEDomain,
            personal: settings.personalFrequency,
            capitalizeFirst: capFirst,
            limit: 3
        )
    }

    private func previewGlideCandidates() {
        let decoded = currentDecodedGlideWords()
        guard !decoded.isEmpty else { return }
        candidates = decoded
        renderSuggestionsInPlace()
    }

    private func finishGlideCommit() {
        let decoded = currentDecodedGlideWords()
        activeSlideButton?.isHighlighted = false
        activeSlideButton = nil
        touchStartPointInButton = nil
        activeFlickCharacter = nil
        resetGlideTracking()

        guard let top = decoded.first else {
            updateSuggestions()
            return
        }
        triggerFeedback()
        let proxy = textDocumentProxy
        discardComposition()
        let insertion = top.insertion
        let (prev2, prev1) = previousTwoWords(before: proxy.documentContextBeforeInput, excluding: "")
        proxy.insertText(insertion)
        settings.recordPersonalWord(top.text, after: prev1, beforeThat: prev2)
        lastGlidedInsertionLength = insertion.count
        candidates = decoded
        renderSuggestionsInPlace()
    }

    private func characterButton(at pointInPlane: CGPoint) -> LiquidKeyCapButton? {
        for idx in activeKeyActions.indices {
            guard case .character = activeKeyActions[idx] else { continue }
            let btn = keyPool[idx]
            if !btn.isHidden, btn.frame.insetBy(dx: -3, dy: -4).contains(pointInPlane) {
                return btn
            }
        }
        return nil
    }

    private func executeKeyAction(_ action: KeyActionKind, button: LiquidKeyCapButton, event: UIEvent) {
        switch action {
        case .character(let primary, _, _):
            let resolved = resolveTouchedCharacter(primary: primary, button: button, event: event)
            type(resolved)

        case .shift:
            triggerFeedback()
            let now = ContinuousClock.now
            if let last = lastShiftTap, last.duration(to: now) <= .milliseconds(350), shiftState != .locked {
                shiftState = .locked
                lastShiftTap = nil
            } else {
                shiftState = (shiftState == .off) ? .once : .off
                lastShiftTap = now
            }
            updateShiftStateInPlace()

        case .backspace:
            triggerFeedback()
            lastGlidedInsertionLength = 0
            handle(.backspace)

        case .tabKey:
            triggerFeedback()
            lastGlidedInsertionLength = 0
            discardComposition()
            textDocumentProxy.insertText("\t")

        case .dismissKeyboardKey:
            triggerFeedback()
            lastGlidedInsertionLength = 0
            dismissKeyboard()

        case .pageToggle:
            triggerFeedback()
            if page == .emoji {
                emojiSearching = false
                emojiSearchQuery = ""
                page = .letters
            } else {
                page = (page == .letters) ? .numbers : .letters
            }
            shiftState = .off
            heightConstraint?.constant = preferredTotalHeight
            layoutRootRegions()
            rebuildActivePlane()
            updateSuggestions()

        case .symbolsToggle:
            triggerFeedback()
            page = (page == .numbers) ? .symbols : .numbers
            rebuildActivePlane()

        case .emojiPage:
            triggerFeedback()
            page = .emoji
            emojiSearching = false
            rebuildActivePlane()

        case .globe:
            break // Handled directly by UIInputViewController.handleInputModeList

        case .space:
            type(" ")

        case .returnKey:
            type("\n")

        case .splitToggle:
            triggerFeedback()
            settings.splitLandscapeKeyboard.toggle()
            rebuildActivePlane()

        case .emojiSearchChar(let ch):
            triggerFeedback()
            emojiSearchQuery.append(ch)
            refreshEmojiSearchUI()

        case .emojiSearchBackspace:
            triggerFeedback()
            if !emojiSearchQuery.isEmpty {
                emojiSearchQuery.removeLast()
                refreshEmojiSearchUI()
            }

        case .emojiSearchSpace:
            triggerFeedback()
            if !emojiSearchQuery.isEmpty, emojiSearchQuery.last != " " {
                emojiSearchQuery.append(" ")
                refreshEmojiSearchUI()
            }

        case .emojiSearchClear:
            triggerFeedback()
            emojiSearchQuery = ""
            refreshEmojiSearchUI()
        }
    }

    @objc private func handlePoolKeyLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let btn = gesture.view as? LiquidKeyCapButton,
              activeKeyActions.indices.contains(btn.tag) else { return }
        let action = activeKeyActions[btn.tag]

        switch action {
        case .backspace:
            switch gesture.state {
            case .began:
                stopBackspaceRepeat()
                backspaceRepeatTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        guard let self else { break }
                        self.triggerFeedback()
                        self.handle(.backspace)
                        try? await Task.sleep(for: .milliseconds(75))
                    }
                }
            case .ended, .cancelled, .failed:
                stopBackspaceRepeat()
            default:
                break
            }

        case .character(_, let lower, _):
            if gesture.state == .began, page == .letters, let variants = Self.accentVariants[lower] {
                activeFlickCharacter = nil
                touchStartPointInButton = nil
                activeSlideButton = nil
                showAccentStrip(for: variants, above: btn)
            }

        default:
            break
        }
    }

    // MARK: - Fast In-Place Updates (Zero View Rebuilds on Shift / Language Toggle!)

    private func updateShiftStateInPlace() {
        guard page == .letters, !letterPoolIndices.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for sIdx in shiftPoolIndices where keyPool.indices.contains(sIdx) {
            let sym: String = switch shiftState {
            case .off: "shift"
            case .once: "shift.fill"
            case .locked: "capslock.fill"
            }
            let sBtn = keyPool[sIdx]
            sBtn.setImage(SymbolCache.image(sym, size: isPadLayout ? 19 : 18, weight: .medium), for: .normal)
            sBtn.keyRole = shiftState == .off ? .modifier : .activeModifier
        }
        let upper = isShifted
        for (idx, lower) in letterPoolIndices {
            let ch: Character = upper ? Character(String(lower).uppercased()) : lower
            let s = String(ch)
            let btn = keyPool[idx]
            btn.setTitle(s, for: .normal)
            btn.accessibilityLabel = s
            let flick = settings.flickDownSymbols ? Self.flickCharacters[lower] : nil
            activeKeyActions[idx] = .character(primary: ch, lowercase: lower, flick: flick)
        }
        CATransaction.commit()
    }

    private func updateLanguageIndicators() {
        styleTopToolbarColors()
        let spaceTitle = session.isVietnamese ? "Tiếng Việt" : "English"
        for idx in spacePoolIndices where keyPool.indices.contains(idx) {
            keyPool[idx].setTitle(spaceTitle, for: .normal)
        }
    }

    // MARK: - Top Toolbar Actions

    @objc private func handleLanguagePillTap() {
        triggerFeedback()
        if isStructuredASCIIField || settings.focusPreferEnglish {
            let current = manualLanguageOverrideInField ?? session.isVietnamese
            manualLanguageOverrideInField = !current
        } else {
            manualLanguageOverrideInField = nil
            settings.vietnameseEnabled.toggle()
        }
        syncEffectiveLanguageMode()
        updateSuggestions()
    }

    @objc private func handleEmojiToolbarTap() {
        triggerFeedback()
        if page == .emoji {
            emojiSearching = false
            page = .letters
        } else {
            page = .emoji
            emojiSearching = false
        }
        rebuildActivePlane()
    }

    @objc private func handleClipboardToolbarTap() {
        triggerFeedback()
        if page == .clipboard {
            page = .letters
        } else {
            refreshCachedPasteboard()
            page = .clipboard
        }
        rebuildActivePlane()
    }

    @objc private func handleSplitToggleTap() {
        triggerFeedback()
        settings.splitLandscapeKeyboard.toggle()
        rebuildActivePlane()
    }

    @objc private func handleSmartPasteTap() {
        guard let item = currentSmartPasteItem() else { return }
        triggerFeedback()
        discardComposition()
        textDocumentProxy.insertText(item.text)
        settings.recordClipboard(item.text)
        dismissedSmartPasteText = item.text
        updateSuggestions()
    }

    @objc private func handleCandidateButtonTap(_ sender: UIButton) {
        let idx = sender.tag
        guard candidates.indices.contains(idx) else { return }
        acceptSuggestion(candidates[idx])
    }

    @objc private func handleCloseEmojiSearch() {
        triggerFeedback()
        emojiSearching = false
        emojiSearchQuery = ""
        rebuildActivePlane()
        updateSuggestions()
    }

    @objc private func handleEmojiSearchResultTap(_ sender: UIButton) {
        guard let emoji = sender.title(for: .normal), !emoji.isEmpty else { return }
        triggerFeedback()
        discardComposition()
        textDocumentProxy.insertText(emoji)
    }

    // MARK: - Liquid Glass Preview Bubble & Accent Strip

    private func showKeyPreview(for button: UIButton, text: String) {
        let frame = button.convert(button.bounds, to: view)
        let width = max(frame.width + 18, 48)
        let height: CGFloat = 54
        let x = min(max(frame.midX - width * 0.5, 4), view.bounds.width - width - 4)
        // Always float above the finger — never clamp down onto the key itself!
        let y = frame.minY - height - 6
        keyCallout.label.text = text
        keyCallout.frame = CGRect(x: x, y: y, width: width, height: height)
        keyCallout.isHidden = false
        view.bringSubviewToFront(keyCallout)
    }

    private func hideKeyPreview() {
        keyCallout.isHidden = true
    }

    private func showAccentStrip(for variants: [String], above button: UIButton) {
        dismissAccentStrip()
        hideKeyPreview()

        let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        glass.cornerConfiguration = .corners(radius: .fixed(14))
        glass.layer.zPosition = 210
        glass.layer.shadowColor = UIColor.black.cgColor
        glass.layer.shadowOffset = CGSize(width: 0, height: 4)
        glass.layer.shadowRadius = 10
        glass.layer.shadowOpacity = 0.2

        let itemW: CGFloat = 38
        let pad: CGFloat = 6
        let totalW = min(CGFloat(variants.count) * itemW + pad * 2, view.bounds.width - 12)
        let actualItemW = (totalW - pad * 2) / CGFloat(max(1, variants.count))
        let height: CGFloat = 46

        let origin = button.convert(button.bounds, to: view)
        let x = min(max(origin.midX - totalW * 0.5, 6), view.bounds.width - totalW - 6)
        let y = origin.minY - height - 6
        glass.frame = CGRect(x: x, y: y, width: totalW, height: height)
        glass.layer.shadowPath = UIBezierPath(roundedRect: glass.bounds, cornerRadius: 14).cgPath

        for (idx, variant) in variants.enumerated() {
            let title = isShifted ? variant.uppercased() : variant
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 21, weight: .medium)
            btn.setTitleColor(.label, for: .normal)
            btn.frame = CGRect(x: pad + CGFloat(idx) * actualItemW, y: 3, width: actualItemW, height: height - 6)
            btn.addAction(UIAction { [weak self] _ in
                guard let self, let ch = title.first else { return }
                self.type(ch)
            }, for: .touchUpInside)
            glass.contentView.addSubview(btn)
        }

        view.addSubview(glass)
        accentStripView = glass
    }

    private func dismissAccentStrip() {
        accentStripView?.removeFromSuperview()
        accentStripView = nil
    }

    // MARK: - Interactive Center Bridge (Unfolded iPhone Duo / Wide Split)

    private func makeInteractiveCenterBridgeView(frame: CGRect) -> UIView {
        let host = UIView(frame: frame)
        let isDark = traitCollection.userInterfaceStyle == .dark
        host.backgroundColor = isDark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.045)
        host.layer.cornerCurve = .continuous
        host.layer.cornerRadius = 14
        host.layer.borderWidth = 0.5
        host.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor

        let pad: CGFloat = 6
        let innerW = frame.width - pad * 2
        let modeH: CGFloat = 28

        let modes = DuoBridgeMode.allCases
        let tabW = (innerW - CGFloat(modes.count) * 4) / CGFloat(modes.count + 1)
        for (idx, mode) in modes.enumerated() {
            let active = settings.duoCenterBridgeMode == mode
            let btn = LiquidKeyCapButton(frame: CGRect(x: pad + CGFloat(idx) * (tabW + 4), y: pad, width: tabW, height: modeH))
            btn.keyCornerRadius = 8
            btn.keyRole = active ? .prominent : .modifier
            btn.setImage(SymbolCache.image(mode.symbolName, size: 12, weight: .semibold), for: .normal)
            btn.accessibilityLabel = mode.title
            btn.accessibilityIdentifier = "duo.bridge.\(mode.rawValue)"
            btn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.settings.duoCenterBridgeMode = mode
                self.rebuildActivePlane()
            }, for: .touchUpInside)
            host.addSubview(btn)
        }

        let mergeBtn = LiquidKeyCapButton(frame: CGRect(x: pad + CGFloat(modes.count) * (tabW + 4), y: pad, width: tabW, height: modeH))
        mergeBtn.keyCornerRadius = 8
        mergeBtn.keyRole = .modifier
        mergeBtn.setImage(SymbolCache.image("rectangle.split.2x1.fill", size: 12, weight: .medium), for: .normal)
        mergeBtn.accessibilityLabel = "Gộp bàn phím"
        mergeBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.settings.splitLandscapeKeyboard.toggle()
            self.rebuildActivePlane()
        }, for: .touchUpInside)
        host.addSubview(mergeBtn)

        let bodyY = pad + modeH + 6
        let bodyH = max(40, frame.height - bodyY - pad)

        switch settings.duoCenterBridgeMode {
        case .trackpad:
            let navH: CGFloat = 32
            let padArea = UIView(frame: CGRect(x: pad, y: bodyY, width: innerW, height: max(30, bodyH - navH - 5)))
            padArea.backgroundColor = isDark ? UIColor.white.withAlphaComponent(0.06) : UIColor.white.withAlphaComponent(0.55)
            padArea.layer.cornerCurve = .continuous
            padArea.layer.cornerRadius = 10
            padArea.accessibilityLabel = "Bàn rê con trỏ 2D"
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleBridgeTrackpadPan(_:)))
            padArea.addGestureRecognizer(pan)

            let icon = UIImageView(image: SymbolCache.image("dpad", size: 22, weight: .regular))
            icon.tintColor = .secondaryLabel
            icon.frame = CGRect(x: (padArea.bounds.width - 26) * 0.5, y: (padArea.bounds.height - 26) * 0.5, width: 26, height: 26)
            padArea.addSubview(icon)
            host.addSubview(padArea)

            let navY = bodyY + bodyH - navH
            let thirdW = (innerW - 8) / 3
            let leftBtn = LiquidKeyCapButton(frame: CGRect(x: pad, y: navY, width: thirdW, height: navH))
            leftBtn.keyRole = .modifier
            leftBtn.setImage(SymbolCache.image("arrow.left", size: 13, weight: .medium), for: .normal)
            leftBtn.accessibilityLabel = "Sang trái"
            leftBtn.addAction(UIAction { [weak self] _ in
                self?.triggerFeedback()
                self?.discardComposition()
                self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
            }, for: .touchUpInside)
            host.addSubview(leftBtn)

            let rightBtn = LiquidKeyCapButton(frame: CGRect(x: pad + thirdW + 4, y: navY, width: thirdW, height: navH))
            rightBtn.keyRole = .modifier
            rightBtn.setImage(SymbolCache.image("arrow.right", size: 13, weight: .medium), for: .normal)
            rightBtn.accessibilityLabel = "Sang phải"
            rightBtn.addAction(UIAction { [weak self] _ in
                self?.triggerFeedback()
                self?.discardComposition()
                self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            }, for: .touchUpInside)
            host.addSubview(rightBtn)

            let delBtn = LiquidKeyCapButton(frame: CGRect(x: pad + (thirdW + 4) * 2, y: navY, width: thirdW, height: navH))
            delBtn.keyRole = .modifier
            delBtn.setImage(SymbolCache.image("delete.left", size: 14, weight: .medium), for: .normal)
            delBtn.accessibilityLabel = "Xoá nhanh"
            delBtn.addAction(UIAction { [weak self] _ in
                self?.triggerFeedback()
                self?.handle(.backspace)
            }, for: .touchUpInside)
            host.addSubview(delBtn)

        case .numpad:
            let padRows = ["789", "456", "123", ",0."]
            let rGap: CGFloat = 4
            let cellH = (bodyH - CGFloat(padRows.count - 1) * rGap) / CGFloat(padRows.count)
            let cellW = (innerW - 2 * rGap) / 3
            for (rIdx, rowChars) in padRows.enumerated() {
                for (cIdx, ch) in rowChars.enumerated() {
                    let s = String(ch)
                    let btn = LiquidKeyCapButton(frame: CGRect(
                        x: pad + CGFloat(cIdx) * (cellW + rGap),
                        y: bodyY + CGFloat(rIdx) * (cellH + rGap),
                        width: cellW,
                        height: cellH
                    ))
                    btn.keyCornerRadius = 7
                    btn.keyRole = .character
                    btn.setTitle(s, for: .normal)
                    btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
                    btn.addAction(UIAction { [weak self] _ in self?.type(ch) }, for: .touchUpInside)
                    host.addSubview(btn)
                }
            }

        case .clipboard:
            let items = Array(settings.clipboardHistory.items.prefix(3))
            if items.isEmpty {
                let emptyBtn = LiquidKeyCapButton(frame: CGRect(x: pad, y: bodyY, width: innerW, height: min(44, bodyH)))
                emptyBtn.keyRole = .prominent
                emptyBtn.setImage(SymbolCache.image("doc.on.clipboard.fill", size: 15, weight: .semibold), for: .normal)
                emptyBtn.accessibilityLabel = "Dán từ Bộ nhớ tạm"
                emptyBtn.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    self.triggerFeedback()
                    if let text = UIPasteboard.general.string, !text.isEmpty {
                        self.discardComposition()
                        self.textDocumentProxy.insertText(text)
                        self.settings.recordClipboard(text)
                        self.updateSuggestions()
                    }
                }, for: .touchUpInside)
                host.addSubview(emptyBtn)
            } else {
                let rowH = (bodyH - 8) / 3
                for (idx, item) in items.enumerated() {
                    let title = item.alias.isEmpty ? item.preview : item.alias
                    let btn = LiquidKeyCapButton(frame: CGRect(x: pad, y: bodyY + CGFloat(idx) * (rowH + 4), width: innerW, height: rowH))
                    btn.keyCornerRadius = 8
                    btn.keyRole = .character
                    btn.setTitle(title, for: .normal)
                    btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
                    btn.titleLabel?.lineBreakMode = .byTruncatingTail
                    btn.addAction(UIAction { [weak self] _ in
                        guard let self else { return }
                        self.triggerFeedback()
                        self.discardComposition()
                        self.textDocumentProxy.insertText(item.text)
                        self.updateSuggestions()
                    }, for: .touchUpInside)
                    host.addSubview(btn)
                }
            }
        }
        return host
    }

    // MARK: - Scrollable Emoji Picker & Clipboard Overlays

    private func renderEmojiOverlay() {
        for sub in overlayPanelView.subviews { sub.removeFromSuperview() }
        let b = overlayPanelView.bounds
        guard b.width > 40, b.height > 80 else { return }

        let bottomH: CGFloat = 38
        let scrollH = max(40, b.height - bottomH - 6)
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: b.width, height: scrollH))
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        overlayPanelView.addSubview(scroll)

        let categories = EmojiSuggestions.categories
        let selectedIdx = min(max(0, emojiCategoryIndex), max(0, categories.count - 1))
        let emojis = categories[selectedIdx].emojis
        let cols = isPadLayout ? 10 : 8
        let cellW = b.width / CGFloat(cols)
        let cellH: CGFloat = 40
        let rowsCount = (emojis.count + cols - 1) / cols
        scroll.contentSize = CGSize(width: b.width, height: CGFloat(rowsCount) * cellH)

        for (idx, emoji) in emojis.enumerated() {
            let r = idx / cols
            let c = idx % cols
            let btn = UIButton(type: .custom)
            btn.frame = CGRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH, width: cellW, height: cellH)
            btn.setTitle(emoji, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 26)
            btn.accessibilityLabel = emoji
            btn.accessibilityIdentifier = "emoji.\(idx)"
            btn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.discardComposition()
                self.textDocumentProxy.insertText(emoji)
                self.updateSuggestions()
            }, for: .touchUpInside)
            scroll.addSubview(btn)
        }

        // Bottom Liquid Glass Emoji Category Strip: [ABC] [🔍] [categories...] [⌫]
        let barY = b.height - bottomH
        let abcW: CGFloat = 48
        let searchW: CGFloat = 38
        let delW: CGFloat = 44

        let abcBtn = LiquidKeyCapButton(frame: CGRect(x: 0, y: barY, width: abcW, height: bottomH))
        abcBtn.keyRole = .modifier
        abcBtn.setTitle("ABC", for: .normal)
        abcBtn.titleLabel?.font = .systemFont(ofSize: 14.5, weight: .semibold)
        abcBtn.accessibilityLabel = "ABC"
        abcBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.page = .letters
            self.rebuildActivePlane()
        }, for: .touchUpInside)
        overlayPanelView.addSubview(abcBtn)

        let searchBtn = LiquidKeyCapButton(frame: CGRect(x: abcW + 5, y: barY, width: searchW, height: bottomH))
        searchBtn.keyRole = .modifier
        searchBtn.setImage(SymbolCache.image("magnifyingglass", size: 15, weight: .semibold), for: .normal)
        searchBtn.accessibilityLabel = "Tìm Emoji"
        searchBtn.accessibilityIdentifier = "emoji.search"
        searchBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.emojiSearching = true
            self.emojiSearchQuery = ""
            self.rebuildActivePlane()
        }, for: .touchUpInside)
        overlayPanelView.addSubview(searchBtn)

        let catStartX = abcW + searchW + 12
        let catAvailW = max(60, b.width - catStartX - delW - 8)
        let catW = catAvailW / CGFloat(max(1, categories.count))
        for (cIdx, cat) in categories.enumerated() {
            let cBtn = UIButton(type: .custom)
            cBtn.frame = CGRect(x: catStartX + CGFloat(cIdx) * catW, y: barY + 3, width: catW, height: bottomH - 6)
            cBtn.setTitle(cat.title, for: .normal)
            cBtn.titleLabel?.font = .systemFont(ofSize: 13.5, weight: cIdx == selectedIdx ? .bold : .regular)
            cBtn.setTitleColor(cIdx == selectedIdx ? .label : .secondaryLabel, for: .normal)
            cBtn.backgroundColor = cIdx == selectedIdx ? UIColor.secondarySystemFill : .clear
            cBtn.layer.cornerCurve = .continuous
            cBtn.layer.cornerRadius = (bottomH - 6) * 0.5
            cBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.emojiCategoryIndex = cIdx
                self.renderEmojiOverlay()
            }, for: .touchUpInside)
            overlayPanelView.addSubview(cBtn)
        }

        let delBtn = LiquidKeyCapButton(frame: CGRect(x: b.width - delW, y: barY, width: delW, height: bottomH))
        delBtn.keyRole = .modifier
        delBtn.setImage(SymbolCache.image("delete.left", size: 16, weight: .medium), for: .normal)
        delBtn.accessibilityLabel = "Xoá"
        delBtn.addAction(UIAction { [weak self] _ in
            self?.triggerFeedback()
            self?.handle(.backspace)
        }, for: .touchUpInside)
        overlayPanelView.addSubview(delBtn)
    }

    private func renderClipboardOverlay() {
        for sub in overlayPanelView.subviews { sub.removeFromSuperview() }
        let b = overlayPanelView.bounds
        guard b.width > 40, b.height > 80 else { return }
        let isDark = traitCollection.userInterfaceStyle == .dark

        // Row 1: Back to Keyboard + Prominent Paste System Clipboard + Clear Unpinned
        let headerH: CGFloat = 34
        let backBtn = LiquidKeyCapButton(frame: CGRect(x: 0, y: 0, width: 46, height: headerH))
        backBtn.keyRole = .modifier
        backBtn.setImage(SymbolCache.image("keyboard", size: 15.5, weight: .medium), for: .normal)
        backBtn.accessibilityLabel = "Quay lại bàn phím"
        backBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.page = .letters
            self.rebuildActivePlane()
        }, for: .touchUpInside)
        overlayPanelView.addSubview(backBtn)

        let hasUnpinned = !settings.clipboardHistory.unpinnedItems.isEmpty
        let clearW: CGFloat = hasUnpinned ? 42 : 0
        let pasteW = b.width - 46 - 6 - (hasUnpinned ? (clearW + 6) : 0)

        let pasteBtn = LiquidKeyCapButton(frame: CGRect(x: 52, y: 0, width: pasteW, height: headerH))
        pasteBtn.keyRole = .prominent
        pasteBtn.setTitle("  Dán từ Bộ nhớ tạm", for: .normal)
        pasteBtn.setImage(SymbolCache.image("doc.on.clipboard.fill", size: 13.5, weight: .semibold), for: .normal)
        pasteBtn.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
        pasteBtn.accessibilityLabel = "Dán từ Bộ nhớ tạm"
        pasteBtn.accessibilityIdentifier = "clipboard.pasteSystem"
        pasteBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            if let pasteText = UIPasteboard.general.string, !pasteText.isEmpty {
                self.discardComposition()
                self.textDocumentProxy.insertText(pasteText)
                self.settings.recordClipboard(pasteText)
                self.cachedPasteboardString = pasteText
                self.page = .letters
                self.rebuildActivePlane()
                self.updateSuggestions()
            }
        }, for: .touchUpInside)
        overlayPanelView.addSubview(pasteBtn)

        if hasUnpinned {
            let clearBtn = LiquidKeyCapButton(frame: CGRect(x: b.width - clearW, y: 0, width: clearW, height: headerH))
            clearBtn.keyRole = .modifier
            clearBtn.setImage(SymbolCache.image("trash", size: 14, weight: .medium), for: .normal)
            clearBtn.accessibilityLabel = "Xoá mục chưa ghim"
            clearBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.settings.clearUnpinnedClipboard()
                self.renderClipboardOverlay()
            }, for: .touchUpInside)
            overlayPanelView.addSubview(clearBtn)
        }

        // Row 2: Capsule Filter Strip
        let filterY: CGFloat = headerH + 6
        let filterH: CGFloat = 28
        let filters = ClipboardFilter.allCases
        let chipGap: CGFloat = 5
        let chipW = (b.width - CGFloat(filters.count - 1) * chipGap) / CGFloat(filters.count)
        for (idx, chip) in filters.enumerated() {
            let active = chip == clipboardFilter
            let cBtn = UIButton(type: .custom)
            cBtn.frame = CGRect(x: CGFloat(idx) * (chipW + chipGap), y: filterY, width: chipW, height: filterH)
            cBtn.setTitle(" " + chip.title, for: .normal)
            cBtn.setImage(SymbolCache.image(chip.symbolName, size: 11, weight: active ? .semibold : .regular), for: .normal)
            cBtn.titleLabel?.font = .systemFont(ofSize: 11.5, weight: active ? .semibold : .medium)
            cBtn.layer.cornerCurve = .continuous
            cBtn.layer.cornerRadius = filterH * 0.5
            cBtn.backgroundColor = active
                ? UIColor.systemBlue.withAlphaComponent(isDark ? 0.28 : 0.16)
                : (isDark ? UIColor.white.withAlphaComponent(0.10) : UIColor.black.withAlphaComponent(0.055))
            cBtn.setTitleColor(active ? .systemBlue : .label, for: .normal)
            cBtn.tintColor = active ? .systemBlue : .secondaryLabel
            cBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.clipboardFilter = chip
                self.renderClipboardOverlay()
            }, for: .touchUpInside)
            overlayPanelView.addSubview(cBtn)
        }

        let listY = filterY + filterH + 6
        let listH = max(40, b.height - listY)
        let items = Array(settings.clipboardHistory.filter(clipboardFilter).prefix(25))

        guard !items.isEmpty else {
            let emptyLabel = UILabel(frame: CGRect(x: 16, y: listY, width: b.width - 32, height: listH))
            emptyLabel.text = clipboardFilter == .all
                ? "Ghim mẫu văn bản trong ứng dụng viTek hoặc đồng bộ từ Mac qua iCloud"
                : "Chưa có mục nào trong nhóm “\(clipboardFilter.title)”"
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.numberOfLines = 2
            emptyLabel.textAlignment = .center
            overlayPanelView.addSubview(emptyLabel)
            return
        }

        let scroll = UIScrollView(frame: CGRect(x: 0, y: listY, width: b.width, height: listH))
        scroll.showsVerticalScrollIndicator = true
        scroll.alwaysBounceVertical = true
        overlayPanelView.addSubview(scroll)

        let twoCol = b.width >= 520
        let cols = twoCol ? 2 : 1
        let cardGap: CGFloat = 6
        let cardW = (b.width - CGFloat(cols - 1) * cardGap) / CGFloat(cols)
        let cardH: CGFloat = 44
        let rowsCount = (items.count + cols - 1) / cols
        scroll.contentSize = CGSize(width: b.width, height: CGFloat(rowsCount) * (cardH + cardGap))

        for (idx, item) in items.enumerated() {
            let r = idx / cols
            let c = idx % cols
            let cardFrame = CGRect(
                x: CGFloat(c) * (cardW + cardGap),
                y: CGFloat(r) * (cardH + cardGap),
                width: cardW,
                height: cardH
            )
            let card = UIView(frame: cardFrame)
            card.backgroundColor = isDark ? UIColor(white: 0.32, alpha: 0.78) : UIColor(white: 1.0, alpha: 0.90)
            card.layer.cornerCurve = .continuous
            card.layer.cornerRadius = 11
            card.layer.borderWidth = 0.5
            card.layer.borderColor = UIColor.white.withAlphaComponent(isDark ? 0.14 : 0.72).cgColor

            let badge = UIView(frame: CGRect(x: 8, y: 9, width: 26, height: 26))
            badge.backgroundColor = badgeTint(for: item)
            badge.layer.cornerCurve = .continuous
            badge.layer.cornerRadius = 7
            let bIcon = UIImageView(image: SymbolCache.image(item.kind.symbolName, size: 12, weight: .semibold))
            bIcon.tintColor = .white
            bIcon.contentMode = .scaleAspectFit
            bIcon.frame = CGRect(x: 5, y: 5, width: 16, height: 16)
            badge.addSubview(bIcon)
            card.addSubview(badge)

            let textBtn = UIButton(type: .custom)
            textBtn.frame = CGRect(x: 40, y: 2, width: max(40, cardW - 76), height: cardH - 4)
            textBtn.contentHorizontalAlignment = .leading
            let displayTitle = item.alias.isEmpty ? item.preview : "\(item.alias) · \(item.preview)"
            textBtn.setTitle(displayTitle, for: .normal)
            textBtn.setTitleColor(.label, for: .normal)
            textBtn.titleLabel?.font = item.kind.usesMonospacedFont && item.alias.isEmpty
                ? .monospacedSystemFont(ofSize: 12.5, weight: .regular)
                : .systemFont(ofSize: 13.5, weight: item.alias.isEmpty ? .regular : .medium)
            textBtn.titleLabel?.lineBreakMode = .byTruncatingTail
            textBtn.accessibilityIdentifier = "clipboard.item.\(idx)"
            textBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.discardComposition()
                self.textDocumentProxy.insertText(item.text)
                self.page = .letters
                self.rebuildActivePlane()
                self.updateSuggestions()
            }, for: .touchUpInside)
            card.addSubview(textBtn)

            let pinBtn = UIButton(type: .custom)
            pinBtn.frame = CGRect(x: cardW - 34, y: 7, width: 30, height: 30)
            pinBtn.setImage(SymbolCache.image(item.isPinned ? "pin.fill" : "pin", size: 13, weight: .semibold), for: .normal)
            pinBtn.tintColor = item.isPinned ? .systemBlue : .secondaryLabel
            pinBtn.accessibilityLabel = item.isPinned ? "Bỏ ghim" : "Ghim"
            pinBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.settings.togglePinClipboard(item.text)
                self.renderClipboardOverlay()
            }, for: .touchUpInside)
            card.addSubview(pinBtn)

            scroll.addSubview(card)
        }
    }

    private func badgeTint(for item: ClipboardItem) -> UIColor {
        if item.kind == .hexColor, let rgb = item.parsedHexColor {
            return UIColor(red: rgb.redFraction, green: rgb.greenFraction, blue: rgb.blueFraction, alpha: 1)
        }
        return switch item.kind {
        case .url: .systemBlue
        case .email: .systemIndigo
        case .phone: .systemGreen
        case .otp: .systemOrange
        case .hexColor: .systemPink
        case .code: .systemPurple
        case .multiline: .systemTeal
        case .text: .secondaryLabel
        }
    }

    private func refreshEmojiSearchUI() {
        let prompt = emojiSearchQuery.isEmpty ? "  🔍 Gõ tiếng Việt: tim, vui, ca phe…" : "  🔍 \(emojiSearchQuery)"
        emojiSearchQueryLabel.text = prompt
        emojiSearchQueryLabel.textColor = emojiSearchQuery.isEmpty ? .secondaryLabel : .label

        let results = emojiSearchQuery.isEmpty
            ? Array(EmojiSuggestions.categories[0].emojis.prefix(7))
            : EmojiSuggestions.search(emojiSearchQuery, limit: 7)

        for idx in 0..<7 {
            if idx < results.count {
                emojiResultButtons[idx].isHidden = false
                emojiResultButtons[idx].setTitle(results[idx], for: .normal)
            } else {
                emojiResultButtons[idx].isHidden = true
            }
        }
        layoutTopToolbar()
    }

    // MARK: - Gestures (Spacebar Trackpad, Bridge Trackpad, Language Long-Press)

    private func stopBackspaceRepeat() {
        backspaceRepeatTask?.cancel()
        backspaceRepeatTask = nil
    }

    @objc private func handleLanguageLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        triggerFeedback()
        let posture = currentPosture
        if posture.allowsSplit {
            settings.splitLandscapeKeyboard.toggle()
        } else {
            let current = posture == .coverCompact ? settings.coverOneHandedMode : settings.oneHandedMode
            let next: IOSKeyboardSettings.OneHandedMode = switch current {
            case .full: .right
            case .right: .left
            case .left: .full
            }
            setOneHandedPreference(next)
            lastLaidOutBounds = .zero
            layoutRootRegions()
        }
        rebuildActivePlane()
    }

    @objc private func handleSpacePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            spaceTrackpadRemainder = 0
            hideKeyPreview()
            discardComposition()
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            spaceTrackpadRemainder += translation.x
            let step: CGFloat = 10
            let offset = Int(spaceTrackpadRemainder / step)
            if offset != 0 {
                spaceTrackpadRemainder -= CGFloat(offset) * step
                textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
                if settings.hapticFeedback { haptic.impactOccurred() }
            }
        case .ended, .cancelled, .failed:
            spaceTrackpadRemainder = 0
        default:
            break
        }
    }

    @objc private func handleBridgeTrackpadPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            bridgePanRemainder = .zero
            discardComposition()
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            bridgePanRemainder.x += translation.x
            bridgePanRemainder.y += translation.y
            let stepX: CGFloat = 10
            let stepY: CGFloat = 24
            let dx = Int(bridgePanRemainder.x / stepX)
            let dy = Int(bridgePanRemainder.y / stepY)
            if dx != 0 {
                bridgePanRemainder.x -= CGFloat(dx) * stepX
                textDocumentProxy.adjustTextPosition(byCharacterOffset: dx)
                if settings.hapticFeedback { haptic.impactOccurred() }
            }
            if dy != 0 {
                bridgePanRemainder.y -= CGFloat(dy) * stepY
                textDocumentProxy.adjustTextPosition(byCharacterOffset: dy * 32)
                if settings.hapticFeedback { haptic.impactOccurred() }
            }
        case .ended, .cancelled, .failed:
            bridgePanRemainder = .zero
        default:
            break
        }
    }

    // MARK: - Orthography-Guided Edge Touch Assist

    private func resolveTouchedCharacter(primary: Character, button: LiquidKeyCapButton, event: UIEvent) -> Character {
        guard page == .letters, session.isVietnamese, session.engine.isComposing,
              let touch = event.allTouches?.first,
              button.bounds.width > 0 else { return primary }
        let edgeRatio = currentPosture.edgeTouchAssistRatio
        let ratio = Double(touch.location(in: button).x / button.bounds.width)
        guard ratio < edgeRatio || ratio > (1.0 - edgeRatio) else { return primary }

        let targetX = ratio < edgeRatio ? (button.frame.minX - 10) : (button.frame.maxX + 10)
        let probePoint = CGPoint(x: targetX, y: button.frame.midY)
        guard let neighborBtn = characterButton(at: probePoint),
              neighborBtn !== button,
              activeKeyActions.indices.contains(neighborBtn.tag),
              case .character(let neighborChar, _, _) = activeKeyActions[neighborBtn.tag],
              neighborChar.isLetter else {
            return primary
        }

        var primaryEngine = session.engine
        _ = primaryEngine.type(primary)
        let primaryValid = primaryEngine.finish()?.vietnamese != nil
        guard !primaryValid else { return primary }

        var neighborEngine = session.engine
        _ = neighborEngine.type(neighborChar)
        let neighborValid = neighborEngine.finish()?.vietnamese != nil
        return neighborValid ? neighborChar : primary
    }

    // MARK: - Core Vietnamese Input & Zero-Allocation Suggestion Pipeline

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        applyKeyboardAppearance()
        let kt = textDocumentProxy.keyboardType
        let rt = textDocumentProxy.returnKeyType
        if kt != lastObservedKeyboardType || rt != lastObservedReturnKeyType {
            lastObservedKeyboardType = kt
            lastObservedReturnKeyType = rt
            syncEffectiveLanguageMode()
            if page != .emoji && page != .clipboard {
                rebuildActivePlane()
            }
        }
    }

    override func selectionWillChange(_ textInput: (any UITextInput)?) { discardComposition() }
    override func textWillChange(_ textInput: (any UITextInput)?) { discardComposition() }

    private func applyKeyboardAppearance() {
        switch textDocumentProxy.keyboardAppearance {
        case .dark: overrideUserInterfaceStyle = .dark
        case .light: overrideUserInterfaceStyle = .light
        default: overrideUserInterfaceStyle = .unspecified
        }
    }

    private var isStructuredASCIIField: Bool {
        guard let kt = textDocumentProxy.keyboardType else { return false }
        return kt == .URL || kt == .emailAddress || kt == .twitter
    }

    private func syncEffectiveLanguageMode() {
        let targetVietnamese: Bool
        if let manual = manualLanguageOverrideInField {
            targetVietnamese = manual
        } else if isStructuredASCIIField || settings.focusPreferEnglish {
            targetVietnamese = false
        } else {
            targetVietnamese = settings.vietnameseEnabled
        }
        let commands = session.setVietnamese(targetVietnamese)
        if !commands.isEmpty {
            let proxy = textDocumentProxy
            for case .insert(let word) in commands {
                replaceDisplayed(with: word, in: proxy)
                displayed = ""
            }
        }
        updateLanguageIndicators()
    }

    private func applySettings() {
        settings.reload()
        session.engine.options = settings.engineOptions
        session.shortcuts = settings.shortcutTable
        session.shortcutsInEnglishMode = settings.shortcutsInEnglishMode
        lastObservedKeyboardType = textDocumentProxy.keyboardType
        lastObservedReturnKeyType = textDocumentProxy.returnKeyType
        syncEffectiveLanguageMode()
        heightConstraint?.constant = preferredTotalHeight
    }

    private func discardComposition() {
        session.discard()
        displayed = ""
        document = nil
        lastSpaceTap = nil
        clearSuggestions()
    }

    private func triggerFeedback() {
        if settings.keyClickSound { UIDevice.current.playInputClick() }
        if settings.hapticFeedback { haptic.impactOccurred() }
    }

    private var isShifted: Bool { shiftState != .off }

    private func updateAutoCapitalization() {
        guard settings.autoCapitalization, page == .letters, shiftState == .off, displayed.isEmpty else { return }
        guard textDocumentProxy.autocapitalizationType != UITextAutocapitalizationType.none else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: CharacterSet(charactersIn: " "))
        let shouldCapitalize = before.isEmpty
            || before.hasSuffix("\n")
            || (before.hasSuffix(" ") && (trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")))
        if shouldCapitalize { shiftState = .once }
    }

    private func type(_ key: Character) {
        lastGlidedInsertionLength = 0
        dismissAccentStrip()
        triggerFeedback()
        if key == " ", handleDoubleSpacePeriodIfNeeded() {
            updateAutoCapitalization()
            updateShiftStateInPlace()
            updateSuggestions()
            return
        }
        lastSpaceTap = (key == " ") ? .now : nil
        handle(.character(key))
        if shiftState == .once && page == .letters {
            shiftState = .off
            updateShiftStateInPlace()
        } else if key == " " || key == "\n" {
            let previous = shiftState
            updateAutoCapitalization()
            if shiftState != previous { updateShiftStateInPlace() }
        }
    }

    private func handleDoubleSpacePeriodIfNeeded() -> Bool {
        guard settings.doubleSpacePeriod, displayed.isEmpty else { return false }
        let now = ContinuousClock.now
        guard let last = lastSpaceTap, last.duration(to: now) <= .milliseconds(1200) else { return false }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard before.hasSuffix(" ") else { return false }
        let beforeSpace = before.dropLast()
        guard let previousChar = beforeSpace.last, previousChar.isLetter || previousChar.isNumber else { return false }
        textDocumentProxy.deleteBackward()
        textDocumentProxy.insertText(". ")
        lastSpaceTap = nil
        return true
    }

    private func handle(_ event: HostEvent) {
        let proxy = textDocumentProxy
        if document != proxy.documentIdentifier {
            manualLanguageOverrideInField = nil
            syncEffectiveLanguageMode()
        }
        if document != proxy.documentIdentifier || !(proxy.selectedText ?? "").isEmpty ||
            (!displayed.isEmpty && proxy.documentContextBeforeInput?.hasSuffix(displayed) != true) {
            discardComposition()
        }
        document = proxy.documentIdentifier
        if case .character(let key) = event, session.isVietnamese, !session.engine.isComposing,
           session.engine.options.isMarkKey(key), (proxy.selectedText ?? "").isEmpty,
           let before = proxy.documentContextBeforeInput, !before.isEmpty {
            let trailing = String(before.reversed().prefix(while: \.isLetter).reversed())
            if !trailing.isEmpty, session.resume(trailing) {
                displayed = trailing
            }
        }
        let output = session.handle(event)
        for command in output.commands {
            switch command {
            case .mark(let word):
                replaceDisplayed(with: word, in: proxy)
                displayed = word
            case .insert(let word):
                let (prev2, prev1) = previousTwoWords(before: proxy.documentContextBeforeInput, excluding: displayed)
                replaceDisplayed(with: word, in: proxy)
                displayed = ""
                if session.isVietnamese {
                    settings.recordPersonalWord(word, after: prev1, beforeThat: prev2)
                }
            }
        }
        if output.passThrough {
            switch event {
            case .character(let key): proxy.insertText(String(key))
            case .backspace: proxy.deleteBackward()
            case .boundary: break
            }
        }
        updateSuggestions()
    }

    private func replaceDisplayed(with word: String, in proxy: any UITextDocumentProxy) {
        let common = zip(displayed, word).prefix(while: { $0.0 == $0.1 }).count
        for _ in displayed.dropFirst(common) { proxy.deleteBackward() }
        let suffix = word.dropFirst(common)
        if !suffix.isEmpty { proxy.insertText(String(suffix)) }
    }

    private func currentSmartPasteItem() -> ClipboardItem? {
        guard page == .letters, displayed.isEmpty else { return nil }
        guard let item = settings.clipboardHistory.smartPasteCandidate(
            pasteboardText: cachedPasteboardString,
            now: Int(Date().timeIntervalSince1970)
        ), item.text != dismissedSmartPasteText else {
            return nil
        }
        return item
    }

    private func updateSuggestions() {
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        if displayed.isEmpty, context.count >= 10 {
            aneContextTask?.cancel()
            let sample = context
            aneContextTask = Task(priority: .utility) { [weak self] in
                let evaluated = await NeuralContextScorer.shared.evaluateLanguageHint(for: sample)
                let domain = NeuralContextScorer.shared.inferredDomain(for: sample)
                guard !Task.isCancelled, let self, self.displayed.isEmpty else { return }
                self.session.engine.contextHint = evaluated.hint
                self.cachedANEDomain = domain
            }
        } else if context.isEmpty {
            cachedANEDomain = nil
        }

        guard settings.effectiveShowSuggestions, session.isVietnamese else {
            clearSuggestions()
            return
        }

        let prefix = displayed
        let rawPrefix = session.engine.isComposing ? session.engine.rawKeys : nil
        // Zero CoreML blocking on the main thread: uses cached ANE domain or pure-Swift O(1) SemanticRanker!
        let next = Array(WordPrediction.suggest(
            context: context,
            prefix: prefix,
            domain: cachedANEDomain,
            personal: settings.personalFrequency,
            shortcuts: settings.shortcutTable,
            rawPrefix: rawPrefix
        ).prefix(3))
        candidates = next
        renderSuggestionsInPlace()
    }

    private func clearSuggestions() {
        candidates = []
        renderSuggestionsInPlace()
    }

    private func renderSuggestionsInPlace() {
        guard !(page == .emoji && emojiSearching) else { return }

        if let smart = currentSmartPasteItem() {
            var cfg = smartPasteChipButton.configuration ?? UIButton.Configuration.filled()
            cfg.image = SymbolCache.image(smart.kind.symbolName, size: 11.5, weight: .semibold)
            cfg.title = smart.smartChipTitle
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var out = incoming
                out.font = .systemFont(ofSize: 12.5, weight: .semibold)
                return out
            }
            smartPasteChipButton.configuration = cfg
            smartPasteChipButton.accessibilityLabel = smart.smartChipTitle
            smartPasteChipButton.isHidden = false
        } else {
            smartPasteChipButton.isHidden = true
        }

        for idx in 0..<3 {
            if idx < candidates.count {
                candidateButtons[idx].setTitle(candidates[idx].text, for: .normal)
                candidateButtons[idx].accessibilityLabel = candidates[idx].text
            } else {
                candidateButtons[idx].setTitle(nil, for: .normal)
            }
        }
        layoutTopToolbar()
    }

    private func acceptSuggestion(_ candidate: WordCandidate) {
        triggerFeedback()
        let proxy = textDocumentProxy
        let replacement = candidate.appendsSpace ? candidate.text + " " : candidate.text
        if !displayed.isEmpty {
            let (prev2, prev1) = previousTwoWords(before: proxy.documentContextBeforeInput, excluding: displayed)
            replaceDisplayed(with: replacement, in: proxy)
            settings.recordPersonalWord(candidate.text, after: prev1, beforeThat: prev2)
        } else if lastGlidedInsertionLength > 0 {
            for _ in 0..<lastGlidedInsertionLength { proxy.deleteBackward() }
            lastGlidedInsertionLength = 0
            let (prev2, prev1) = previousTwoWords(before: proxy.documentContextBeforeInput, excluding: "")
            proxy.insertText(replacement)
            settings.recordPersonalWord(candidate.text, after: prev1, beforeThat: prev2)
        } else {
            let (prev2, prev1) = previousTwoWords(before: proxy.documentContextBeforeInput, excluding: "")
            proxy.insertText(replacement)
            settings.recordPersonalWord(candidate.text, after: prev1, beforeThat: prev2)
        }
        session.discard()
        displayed = ""
        updateSuggestions()
    }

    private func previousTwoWords(before context: String?, excluding current: String) -> (prev2: String?, prev1: String?) {
        guard let context else { return (nil, nil) }
        let trimmed = context.hasSuffix(current) ? context.dropLast(current.count) : context[...]
        let words = trimmed.split(whereSeparator: { !$0.isLetter })
        let prev1 = words.last.map(String.init)
        let prev2 = words.count >= 2 ? String(words[words.count - 2]) : nil
        return (prev2, prev1)
    }

    private func applyTextTransform(_ mode: TextConverter.LegacyEncoding) {
        triggerFeedback()
        let proxy = textDocumentProxy
        if let selected = proxy.selectedText, !selected.isEmpty {
            discardComposition()
            proxy.insertText(TextConverter.convert(selected, mode: mode))
            updateSuggestions()
            return
        }
        if !displayed.isEmpty {
            let converted = TextConverter.convert(displayed, mode: mode)
            replaceDisplayed(with: converted, in: proxy)
            session.discard()
            displayed = ""
            updateSuggestions()
            return
        }
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else { return }
        let token = String(before.reversed().prefix(while: { !$0.isWhitespace && !$0.isNewline }).prefix(64).reversed())
        guard !token.isEmpty else { return }
        for _ in token { proxy.deleteBackward() }
        proxy.insertText(TextConverter.convert(token, mode: mode))
        updateSuggestions()
    }

    // MARK: - Hardware Keyboard (iPadOS / iOS Magic Keyboard)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key else {
                unhandled.insert(press)
                continue
            }
            if !key.modifierFlags.intersection([.command, .control, .alternate]).isEmpty {
                if session.engine.isComposing { handle(.boundary) }
                unhandled.insert(press)
                continue
            }
            if key.keyCode == .keyboardEscape {
                if session.engine.isComposing, session.engine.composition != session.engine.rawKeys {
                    let commands = session.restoreRawKeys()
                    for case .insert(let raw) in commands {
                        replaceDisplayed(with: raw, in: textDocumentProxy)
                        displayed = ""
                    }
                    updateSuggestions()
                } else {
                    unhandled.insert(press)
                }
                continue
            }
            if key.keyCode == .keyboardDeleteOrBackspace {
                if session.engine.isComposing {
                    handle(.backspace)
                } else {
                    discardComposition()
                    unhandled.insert(press)
                }
                continue
            }
            if key.keyCode == .keyboardReturnOrEnter || key.keyCode == .keyboardTab {
                if session.engine.isComposing { handle(.boundary) }
                unhandled.insert(press)
                continue
            }
            if key.characters.count == 1, let ch = key.characters.first,
               ch == " " || ch.isLetter || ch.isNumber || ch.isPunctuation || ch.isSymbol {
                handle(.character(ch))
                continue
            }
            if session.engine.isComposing { handle(.boundary) }
            unhandled.insert(press)
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }
}
