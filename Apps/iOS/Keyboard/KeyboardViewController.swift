import UIKit
import VitekSession

/// Native input view subclass enabling system keyboard click audio via `UIDevice.current.playInputClick()`.
private final class AudioFeedbackInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

/// Keep unfinished words as ordinary text so UIKit can move the caret without cancelling them.
final class KeyboardViewController: UIInputViewController {
    private enum ShiftState { case off, once, locked }
    private enum LayoutPage { case letters, numbers, symbols, emoji, clipboard }
    private enum KeyRole { case character, modifier, prominent }

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

    private static let characterKeyFill = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.31, alpha: 0.94)
            : UIColor(white: 1.0, alpha: 0.96)
    }

    private static let modifierKeyFill = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.19, alpha: 0.92)
            : UIColor(red: 0.67, green: 0.70, blue: 0.75, alpha: 0.52)
    }

    private var session = InputSession()
    private var document: UUID?
    private var displayed = ""
    private let outerStack = UIStackView()
    private let leftDockStrip = UIStackView()
    private let rightDockStrip = UIStackView()
    private let rootStack = UIStackView()
    private let topBar = UIStackView()
    private let suggestionBar = UIStackView()
    private let clipboardButton = UIButton(type: .system)
    private let textToolsButton = UIButton(type: .system)
    private let rows = UIStackView()
    private var shiftState: ShiftState = .off
    private var lastShiftTap: ContinuousClock.Instant?
    private var lastSpaceTap: ContinuousClock.Instant?
    private var page: LayoutPage = .letters
    private var clipboardFilter: ClipboardFilter = .all
    private var dismissedSmartPasteText: String?
    private var emojiCategoryIndex = 0
    private var emojiSearching = false
    private var emojiSearchQuery = ""
    private weak var emojiQueryButton: UIButton?
    private var candidates: [WordCandidate] = []
    private let settings = IOSKeyboardSettings.shared
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var suggestionHeightConstraint: NSLayoutConstraint?
    private var keysHeightConstraint: NSLayoutConstraint?
    private var backspaceRepeatTask: Task<Void, Never>?
    private var spaceTrackpadRemainder: CGFloat = 0
    private var bridgePanRemainder = CGPoint.zero
    private var isLandscapeOverride: Bool?
    private var pendingTransitionSize: CGSize?
    private var manualLanguageOverrideInField: Bool?
    private var lastObservedKeyboardType: UIKeyboardType?
    private var lastObservedReturnKeyType: UIReturnKeyType?

    // Flick-down tracking per touch sequence.
    private var touchStartPoint: CGPoint?
    private var activeFlickCharacter: Character?

    /// Cached letter buttons, shift button, language button & spacebars for zero-rebuild 120Hz updates.
    private var letterButtons: [(button: UIButton, lowercase: Character)] = []
    private weak var shiftButton: UIButton?
    private weak var languageButton: UIButton?
    private var spaceButtons: [UIButton] = []

    // Floating key preview bubble and vowel accent strip.
    private let keyPreview: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textAlignment = .center
        label.textColor = .label
        label.backgroundColor = .secondarySystemBackground
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor.separator.cgColor
        label.isHidden = true
        return label
    }()
    private var accentStrip: UIStackView?

    override func loadView() {
        inputView = AudioFeedbackInputView(frame: .zero, inputViewStyle: .keyboard)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applySettings()

        outerStack.axis = .horizontal
        outerStack.spacing = 4
        outerStack.alignment = .fill
        outerStack.distribution = .fill
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        configureDockStrip(leftDockStrip, isLeftExpand: true, targetMode: .left)
        configureDockStrip(rightDockStrip, isLeftExpand: false, targetMode: .right)

        rootStack.axis = .vertical
        rootStack.spacing = 4
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        topBar.axis = .horizontal
        topBar.spacing = 6
        topBar.alignment = .fill
        topBar.distribution = .fill
        topBar.translatesAutoresizingMaskIntoConstraints = false

        suggestionBar.axis = .horizontal
        suggestionBar.spacing = 6
        suggestionBar.distribution = .fillEqually
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        suggestionBar.setContentHuggingPriority(.defaultLow, for: .horizontal)

        configureClipboardButton()
        configureTextToolsButton()

        rows.axis = .vertical
        rows.spacing = 5
        rows.distribution = .fillEqually
        rows.translatesAutoresizingMaskIntoConstraints = false

        topBar.addArrangedSubview(suggestionBar)
        topBar.addArrangedSubview(clipboardButton)
        topBar.addArrangedSubview(textToolsButton)
        rootStack.addArrangedSubview(topBar)
        rootStack.addArrangedSubview(rows)

        outerStack.addArrangedSubview(leftDockStrip)
        outerStack.addArrangedSubview(rootStack)
        outerStack.addArrangedSubview(rightDockStrip)

        let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        glass.cornerConfiguration = .corners(radius: .fixed(8))
        glass.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glass)
        glass.contentView.addSubview(outerStack)
        view.addSubview(keyPreview)

        let safe = view.safeAreaLayoutGuide
        let suggestionHeight = topBar.heightAnchor.constraint(equalToConstant: settings.effectiveShowSuggestions ? 34 : 0)
        suggestionHeightConstraint = suggestionHeight
        let keysHeight = rows.heightAnchor.constraint(equalToConstant: preferredKeysHeight)
        keysHeight.priority = .defaultHigh
        keysHeightConstraint = keysHeight

        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            glass.topAnchor.constraint(equalTo: safe.topAnchor),
            glass.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            outerStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 3),
            outerStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -3),
            outerStack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 5),
            outerStack.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -3),
            suggestionHeight,
            keysHeight,
        ])
        updateDockStripVisibility()
    }

    private func symbolImage(_ name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return UIImage(systemName: name, withConfiguration: cfg)
    }

    private func setOneHandedPreference(_ mode: IOSKeyboardSettings.OneHandedMode) {
        if currentPosture == .coverCompact {
            settings.coverOneHandedMode = mode
        } else {
            settings.oneHandedMode = mode
        }
    }

    private func configureDockStrip(
        _ strip: UIStackView,
        isLeftExpand: Bool,
        targetMode: IOSKeyboardSettings.OneHandedMode
    ) {
        strip.axis = .vertical
        strip.spacing = 8
        strip.distribution = .fillEqually
        strip.translatesAutoresizingMaskIntoConstraints = false
        strip.widthAnchor.constraint(equalToConstant: 42).isActive = true

        let expandBtn = UIButton(type: .system)
        expandBtn.setImage(symbolImage("arrow.up.left.and.arrow.down.right", pointSize: 16, weight: .semibold), for: .normal)
        expandBtn.tintColor = .label
        expandBtn.backgroundColor = Self.modifierKeyFill
        expandBtn.layer.cornerRadius = 8
        expandBtn.accessibilityLabel = "Bàn phím đầy đủ"
        expandBtn.accessibilityIdentifier = "keyboard.expandFull"
        expandBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.setOneHandedPreference(.full)
            self.updateDockStripVisibility()
            self.renderKeys()
        }, for: .touchUpInside)

        let switchBtn = UIButton(type: .system)
        let switchSymbol = targetMode == .left ? "keyboard.onehanded.left" : "keyboard.onehanded.right"
        let switchLabel = targetMode == .left ? "Gõ một tay trái" : "Gõ một tay phải"
        switchBtn.setImage(symbolImage(switchSymbol, pointSize: 17, weight: .medium), for: .normal)
        switchBtn.tintColor = .secondaryLabel
        switchBtn.backgroundColor = Self.modifierKeyFill
        switchBtn.layer.cornerRadius = 8
        switchBtn.accessibilityLabel = switchLabel
        switchBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.setOneHandedPreference(targetMode)
            self.updateDockStripVisibility()
            self.renderKeys()
        }, for: .touchUpInside)
        _ = isLeftExpand

        strip.addArrangedSubview(expandBtn)
        strip.addArrangedSubview(switchBtn)
    }

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

    private var isLandscapeLayout: Bool {
        if let override = isLandscapeOverride { return override }
        if traitCollection.verticalSizeClass == .compact { return true }
        let b = activeContainerSize
        return b.width > 0 && b.height > 0 && b.width > b.height
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
    }

    private var showsUtilityDeck: Bool {
        settings.duoTabletopUtilityBar && currentPosture.supportsUtilityDeck && page == .letters
    }

    private var preferredKeysHeight: CGFloat {
        let posture = currentPosture
        let base: CGFloat = switch posture {
        case .tabletopWide: 280
        case .duoUnfoldedBook: 256
        case .phoneLandscape: 162
        case .coverCompact: 202
        case .standardPortrait, .dualPaneCompact: 214
        }
        let numberExtra: CGFloat = (settings.showNumberRow && page == .letters)
            ? (posture == .phoneLandscape ? 28 : 38)
            : 0
        let deckExtra: CGFloat = showsUtilityDeck ? 30 : 0
        return base + numberExtra + deckExtra
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Preserve active Vietnamese composition (`session` & `displayed`) across fold/unfold/rotation!
        pendingTransitionSize = size
        isLandscapeOverride = size.width > size.height
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.rows.spacing = (self.currentPosture == .phoneLandscape) ? 4 : 5
            self.updateDockStripVisibility()
            self.renderKeys()
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.pendingTransitionSize = nil
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isLandscapeOverride = nil
        manualLanguageOverrideInField = nil
        applySettings()
        applyKeyboardAppearance()
        rows.spacing = (isLandscapeLayout && !isPadLayout) ? 4 : 5
        keysHeightConstraint?.constant = preferredKeysHeight
        if settings.hapticFeedback { haptic.prepare() }
        page = .letters
        emojiSearching = false
        emojiSearchQuery = ""
        shiftState = .off
        updateAutoCapitalization()
        updateDockStripVisibility()
        renderKeys()
        updateSuggestions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopBackspaceRepeat()
        dismissAccentStrip()
        hideKeyPreview()
        discardComposition()
        settings.flushPersonalFrequency()
        super.viewWillDisappear(animated)
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        applyKeyboardAppearance()
        let kt = textDocumentProxy.keyboardType
        let rt = textDocumentProxy.returnKeyType
        if kt != lastObservedKeyboardType || rt != lastObservedReturnKeyType {
            lastObservedKeyboardType = kt
            lastObservedReturnKeyType = rt
            syncEffectiveLanguageMode()
            if page != .emoji { renderKeys() }
        }
    }

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
        let showBar = settings.effectiveShowSuggestions
        topBar.isHidden = !showBar
        suggestionBar.isHidden = !showBar
        clipboardButton.isHidden = !showBar || (page == .emoji && emojiSearching)
        textToolsButton.isHidden = !showBar || (page == .emoji && emojiSearching)
        suggestionHeightConstraint?.constant = showBar ? 34 : 0
        keysHeightConstraint?.constant = preferredKeysHeight
        updateDockStripVisibility()
    }

    private func configureClipboardButton() {
        clipboardButton.setTitle(nil, for: .normal)
        clipboardButton.setImage(symbolImage("doc.on.clipboard", pointSize: 15, weight: .medium), for: .normal)
        clipboardButton.tintColor = .label
        clipboardButton.backgroundColor = .secondarySystemFill
        clipboardButton.layer.cornerRadius = 6
        clipboardButton.accessibilityLabel = "Clipboard"
        clipboardButton.accessibilityIdentifier = "keyboard.clipboard"
        clipboardButton.translatesAutoresizingMaskIntoConstraints = false
        clipboardButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        clipboardButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            self.page = (self.page == .clipboard) ? .letters : .clipboard
            self.renderKeys()
        }, for: .touchUpInside)
    }

    private func configureTextToolsButton() {
        textToolsButton.setTitle(nil, for: .normal)
        textToolsButton.setImage(symbolImage("textformat", pointSize: 15, weight: .semibold), for: .normal)
        textToolsButton.tintColor = .label
        textToolsButton.backgroundColor = .secondarySystemFill
        textToolsButton.layer.cornerRadius = 6
        textToolsButton.accessibilityLabel = "Công cụ chữ"
        textToolsButton.accessibilityIdentifier = "keyboard.textTools"
        textToolsButton.showsMenuAsPrimaryAction = true
        textToolsButton.translatesAutoresizingMaskIntoConstraints = false
        textToolsButton.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let actions: [(String, TextConverter.LegacyEncoding)] = [
            ("Sửa lỗi font → Unicode", .autoToUnicode),
            ("Chuẩn hoá Unicode NFC", .nfdToNFC),
            ("Bỏ dấu tiếng Việt", .stripAccents),
            ("CHỮ HOA", .uppercase),
            ("chữ thường", .lowercase),
            ("Viết Hoa Đầu Từ", .titleCase),
        ]
        textToolsButton.menu = UIMenu(
            title: "Công cụ chữ",
            children: actions.map { title, mode in
                UIAction(title: title) { [weak self] _ in
                    self?.applyTextTransform(mode)
                }
            }
        )
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

    private func updateDockStripVisibility() {
        let mode = effectiveOneHandedMode
        leftDockStrip.isHidden = (mode != .right)
        rightDockStrip.isHidden = (mode != .left)
    }

    private func discardComposition() {
        session.discard()
        displayed = ""
        document = nil
        lastSpaceTap = nil
        clearSuggestions()
    }

    override func selectionWillChange(_ textInput: (any UITextInput)?) { discardComposition() }
    override func textWillChange(_ textInput: (any UITextInput)?) { discardComposition() }

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
        dismissAccentStrip()
        triggerFeedback()
        if key == " ", handleDoubleSpacePeriodIfNeeded() {
            updateAutoCapitalization()
            updateShiftKeyTitles()
            updateSuggestions()
            return
        }
        lastSpaceTap = (key == " ") ? .now : nil
        handle(.character(key))
        if shiftState == .once && page == .letters {
            shiftState = .off
            updateShiftKeyTitles()
        } else if key == " " || key == "\n" {
            let previous = shiftState
            updateAutoCapitalization()
            if shiftState != previous { updateShiftKeyTitles() }
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

    // MARK: - On-device Suggestions (VitekSession)

    private func updateSuggestions() {
        guard settings.effectiveShowSuggestions, session.isVietnamese else { return clearSuggestions() }
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let prefix = displayed
        let rawPrefix = session.engine.isComposing ? session.engine.rawKeys : nil
        let next = Array(WordPrediction.suggest(
            context: context,
            prefix: prefix,
            personal: settings.personalFrequency,
            shortcuts: settings.shortcutTable,
            rawPrefix: rawPrefix
        ).prefix(3))
        candidates = next
        renderSuggestions()
    }

    private func previousTwoWords(before context: String?, excluding current: String) -> (prev2: String?, prev1: String?) {
        guard let context else { return (nil, nil) }
        let trimmed = context.hasSuffix(current) ? context.dropLast(current.count) : context[...]
        let words = trimmed.split(whereSeparator: { !$0.isLetter })
        let prev1 = words.last.map(String.init)
        let prev2 = words.count >= 2 ? String(words[words.count - 2]) : nil
        return (prev2, prev1)
    }

    private func clearSuggestions() {
        candidates = []
        renderSuggestions()
    }

    private func renderSuggestions() {
        guard !(page == .emoji && emojiSearching) else { return }
        for view in suggestionBar.arrangedSubviews { view.removeFromSuperview() }
        guard settings.effectiveShowSuggestions else { return }

        if page == .letters && displayed.isEmpty {
            let livePaste = hasFullAccess ? UIPasteboard.general.string : nil
            if let smartItem = settings.clipboardHistory.smartPasteCandidate(
                pasteboardText: livePaste,
                now: Int(Date().timeIntervalSince1970)
            ), smartItem.text != dismissedSmartPasteText {
                var cfg = UIButton.Configuration.filled()
                cfg.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.16)
                cfg.baseForegroundColor = .systemBlue
                cfg.cornerStyle = .capsule
                cfg.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
                cfg.imagePadding = 4
                cfg.image = symbolImage(smartItem.kind.symbolName, pointSize: 11.5, weight: .semibold)
                cfg.title = smartItem.smartChipTitle
                cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var out = incoming
                    out.font = .systemFont(ofSize: 12.5, weight: .semibold)
                    return out
                }
                let chip = UIButton(configuration: cfg)
                chip.titleLabel?.lineBreakMode = .byTruncatingTail
                chip.accessibilityLabel = smartItem.smartChipTitle
                chip.accessibilityIdentifier = "suggestion.smartPaste"
                chip.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    self.triggerFeedback()
                    self.discardComposition()
                    self.textDocumentProxy.insertText(smartItem.text)
                    self.settings.recordClipboard(smartItem.text)
                    self.dismissedSmartPasteText = smartItem.text
                    self.updateSuggestions()
                }, for: .touchUpInside)
                suggestionBar.addArrangedSubview(chip)
            }
        }

        for (index, candidate) in candidates.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(candidate.text, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: index == 0 ? .semibold : .regular)
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = index == 0 ? .secondarySystemFill : .clear
            button.layer.cornerRadius = 6
            button.accessibilityIdentifier = "suggestion.\(index)"
            button.addAction(UIAction { [weak self] _ in
                self?.acceptSuggestion(candidate)
            }, for: .touchUpInside)
            suggestionBar.addArrangedSubview(button)
        }
    }

    private func acceptSuggestion(_ candidate: WordCandidate) {
        triggerFeedback()
        let proxy = textDocumentProxy
        let (prev2, prev1) = previousTwoWords(before: proxy.documentContextBeforeInput, excluding: displayed)
        let replacement = candidate.appendsSpace ? candidate.text + " " : candidate.text
        if !displayed.isEmpty {
            replaceDisplayed(with: replacement, in: proxy)
        } else {
            proxy.insertText(replacement)
        }
        settings.recordPersonalWord(candidate.text, after: prev1, beforeThat: prev2)
        session.discard()
        displayed = ""
        updateSuggestions()
    }

    // MARK: - Key Preview & Vowel Accent Long-Press

    private func showKeyPreview(for button: UIButton, text: String) {
        let frame = button.convert(button.bounds, to: view)
        let width = max(frame.width + 12, 42)
        let height: CGFloat = 48
        let x = min(max(frame.midX - width / 2, 4), view.bounds.width - width - 4)
        let y = max(frame.minY - height - 6, 2)
        keyPreview.text = text
        keyPreview.frame = CGRect(x: x, y: y, width: width, height: height)
        keyPreview.isHidden = false
        view.bringSubviewToFront(keyPreview)
    }

    private func hideKeyPreview() {
        keyPreview.isHidden = true
    }

    private func showAccentStrip(for variants: [String], above button: UIButton) {
        dismissAccentStrip()
        hideKeyPreview()
        let strip = UIStackView()
        strip.axis = .horizontal
        strip.spacing = 4
        strip.distribution = .fillEqually
        strip.backgroundColor = .secondarySystemBackground
        strip.layer.cornerRadius = 10
        strip.layer.borderWidth = 0.5
        strip.layer.borderColor = UIColor.separator.cgColor
        strip.isLayoutMarginsRelativeArrangement = true
        strip.layoutMargins = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)

        for variant in variants {
            let title = isShifted ? variant.uppercased() : variant
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
            btn.setTitleColor(.label, for: .normal)
            btn.addAction(UIAction { [weak self] _ in
                guard let self, let ch = title.first else { return }
                self.type(ch)
            }, for: .touchUpInside)
            strip.addArrangedSubview(btn)
        }

        let width = min(CGFloat(variants.count) * 38 + 16, view.bounds.width - 12)
        let height: CGFloat = 44
        let origin = button.convert(button.bounds, to: view)
        let x = min(max(origin.midX - width / 2, 6), view.bounds.width - width - 6)
        let y = max(origin.minY - height - 6, 2)
        strip.frame = CGRect(x: x, y: y, width: width, height: height)
        view.addSubview(strip)
        accentStrip = strip
    }

    private func dismissAccentStrip() {
        accentStrip?.removeFromSuperview()
        accentStrip = nil
    }

    // MARK: - Gestures (Long-Press Backspace, One-Handed Cycle & Spacebar Trackpad)

    @objc private func handleBackspaceLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            stopBackspaceRepeat()
            backspaceRepeatTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    guard let self else { break }
                    self.triggerFeedback()
                    self.handle(.backspace)
                    try? await Task.sleep(for: .milliseconds(80))
                }
            }
        case .ended, .cancelled, .failed:
            stopBackspaceRepeat()
        default:
            break
        }
    }

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
            updateDockStripVisibility()
        }
        renderKeys()
    }

    @objc private func handleSpacePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            spaceTrackpadRemainder = 0
            discardComposition()
        case .changed:
            let translation = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            spaceTrackpadRemainder += translation.x
            let step: CGFloat = 12
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

    // MARK: - Keyboard Layout (Portrait, One-Handed, Landscape & iPad Split)

    private func renderKeys() {
        dismissAccentStrip()
        hideKeyPreview()
        letterButtons.removeAll(keepingCapacity: true)
        spaceButtons.removeAll(keepingCapacity: true)
        shiftButton = nil
        languageButton = nil
        for row in rows.arrangedSubviews { row.removeFromSuperview() }
        updateDockStripVisibility()
        keysHeightConstraint?.constant = preferredKeysHeight

        let spacing: CGFloat = isPadLayout ? 6 : 4

        clipboardButton.setImage(
            symbolImage(page == .clipboard ? "doc.on.clipboard.fill" : "doc.on.clipboard", pointSize: 15, weight: .medium),
            for: .normal
        )
        clipboardButton.tintColor = (page == .clipboard) ? .white : .label
        clipboardButton.backgroundColor = (page == .clipboard) ? .systemBlue : .secondarySystemFill
        if page == .emoji {
            renderEmojiPicker(spacing: spacing)
            return
        }
        if page == .clipboard {
            renderClipboardPicker(spacing: spacing)
            return
        }

        if showsUtilityDeck {
            renderUtilityDeckBar(spacing: spacing)
        }

        if isSplitLayoutActive {
            renderSplitLayout(spacing: spacing)
        } else {
            renderStandardLayout(spacing: spacing)
        }
        updateLanguageIndicators()
    }

    private func renderUtilityDeckBar(spacing: CGFloat) {
        let deck = UIStackView()
        deck.axis = .horizontal
        deck.spacing = spacing
        deck.alignment = .fill
        deck.distribution = .fill
        deck.translatesAutoresizingMaskIntoConstraints = false
        deck.heightAnchor.constraint(equalToConstant: 26).isActive = true
        rows.addArrangedSubview(deck)

        func addDeckIcon(_ symbol: String, label: String, width: CGFloat = 38, action: @escaping (KeyboardViewController) -> Void) {
            let btn = makeSymbolButton(symbol, pointSize: 13, label: label, role: .modifier, action: action)
            btn.widthAnchor.constraint(equalToConstant: width).isActive = true
            deck.addArrangedSubview(btn)
        }

        addDeckIcon("escape", label: "Hoàn tác thô (Esc)") { kb in
            kb.triggerFeedback()
            if kb.session.engine.isComposing, kb.session.engine.composition != kb.session.engine.rawKeys {
                let commands = kb.session.restoreRawKeys()
                for case .insert(let raw) in commands {
                    kb.replaceDisplayed(with: raw, in: kb.textDocumentProxy)
                    kb.displayed = ""
                }
                kb.updateSuggestions()
            }
        }
        addDeckIcon("arrow.right.to.line", label: "Tab") { kb in
            kb.triggerFeedback()
            kb.discardComposition()
            kb.textDocumentProxy.insertText("\t")
        }
        addDeckIcon("arrow.uturn.backward", label: "Xoá cả từ") { kb in
            kb.triggerFeedback()
            if !kb.displayed.isEmpty {
                for _ in kb.displayed { kb.textDocumentProxy.deleteBackward() }
                kb.discardComposition()
            } else if let before = kb.textDocumentProxy.documentContextBeforeInput, !before.isEmpty {
                var count = 0
                for ch in before.reversed() {
                    if ch.isWhitespace && count > 0 { break }
                    count += 1
                }
                for _ in 0..<max(1, count) { kb.textDocumentProxy.deleteBackward() }
            }
            kb.updateSuggestions()
        }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        deck.addArrangedSubview(spacer)

        let badge = UILabel()
        badge.text = "  \(currentPosture.labelTitle)  "
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = .secondaryLabel
        badge.textAlignment = .center
        badge.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.65)
        badge.layer.cornerRadius = 6
        badge.layer.masksToBounds = true
        deck.addArrangedSubview(badge)

        let boundaryBtn = makeButton(
            settings.duoDuplicateBoundaryKeys ? "G·B ✓" : "G·B",
            label: "Lặp phím ranh giới G & B",
            role: settings.duoDuplicateBoundaryKeys ? .prominent : .modifier
        ) { kb in
            kb.triggerFeedback()
            kb.settings.duoDuplicateBoundaryKeys.toggle()
            kb.renderKeys()
        }
        boundaryBtn.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
        boundaryBtn.widthAnchor.constraint(equalToConstant: 50).isActive = true
        deck.addArrangedSubview(boundaryBtn)

        addDeckIcon("arrow.left", label: "Sang trái", width: 34) { kb in
            kb.triggerFeedback()
            kb.discardComposition()
            kb.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        }
        addDeckIcon("arrow.right", label: "Sang phải", width: 34) { kb in
            kb.triggerFeedback()
            kb.discardComposition()
            kb.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        }
    }

    private func renderStandardLayout(spacing: CGFloat) {
        if settings.showNumberRow && page == .letters {
            let numberRow = addRow(spacing: spacing)
            for digit in "1234567890" {
                addCharacterKey(String(digit), secondary: nil, to: numberRow)
            }
        }

        let layout: [String] = switch page {
        case .letters: ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        case .numbers: ["1234567890", "-/:;()$&@", ".,?!'"]
        case .symbols: ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'"]
        case .emoji, .clipboard: []
        }

        for (index, letters) in layout.enumerated() {
            if index == 2 {
                let outerRow = UIStackView()
                outerRow.axis = .horizontal
                outerRow.spacing = isPadLayout ? 10 : 7
                outerRow.alignment = .fill
                outerRow.distribution = .fill
                rows.addArrangedSubview(outerRow)

                let modWidth: CGFloat = isPadLayout ? 56 : 42
                let leadingMod = makeLeadingRow2Button()
                leadingMod.widthAnchor.constraint(equalToConstant: modWidth).isActive = true
                outerRow.addArrangedSubview(leadingMod)

                let centerCluster = UIStackView()
                centerCluster.axis = .horizontal
                centerCluster.spacing = spacing
                centerCluster.distribution = .fillEqually
                populateCharacterCluster(letters: letters, into: centerCluster)
                outerRow.addArrangedSubview(centerCluster)

                let backspace = makeBackspaceButton()
                backspace.widthAnchor.constraint(equalToConstant: modWidth).isActive = true
                outerRow.addArrangedSubview(backspace)
            } else {
                let row = addRow(spacing: spacing)
                if index == 1 && page == .letters {
                    let inset: CGFloat = isPadLayout ? 24 : (effectiveOneHandedMode == .full ? 14 : 8)
                    row.isLayoutMarginsRelativeArrangement = true
                    row.layoutMargins = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
                }
                populateCharacterCluster(letters: letters, into: row)
            }
        }

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = spacing
        bottom.alignment = .fill
        bottom.distribution = .fill
        rows.addArrangedSubview(bottom)

        let compactWidth: CGFloat = isPadLayout ? 50 : 38
        let pageBtn = makePageToggleButton()
        pageBtn.widthAnchor.constraint(equalToConstant: isPadLayout ? 54 : 42).isActive = true
        bottom.addArrangedSubview(pageBtn)

        let emojiBtn = makeEmojiButton()
        emojiBtn.widthAnchor.constraint(equalToConstant: compactWidth).isActive = true
        bottom.addArrangedSubview(emojiBtn)

        let langBtn = makeLanguageToggleButton()
        langBtn.widthAnchor.constraint(equalToConstant: isPadLayout ? 48 : 38).isActive = true
        bottom.addArrangedSubview(langBtn)

        if needsInputModeSwitchKey {
            let globe = makeGlobeButton()
            globe.widthAnchor.constraint(equalToConstant: compactWidth).isActive = true
            bottom.addArrangedSubview(globe)
        }

        let space = makeSpaceButton(isPrimary: true)
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)
        space.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bottom.addArrangedSubview(space)

        for ch in contextConvenienceCharacters() {
            let conv = makeButton(String(ch), label: String(ch), role: .character) { kb in
                kb.type(ch)
            }
            conv.widthAnchor.constraint(equalToConstant: isPadLayout ? 42 : 32).isActive = true
            bottom.addArrangedSubview(conv)
        }

        if currentPosture.allowsSplit {
            let splitBtn = makeSplitToggleButton(isSplit: false)
            splitBtn.widthAnchor.constraint(equalToConstant: compactWidth).isActive = true
            bottom.addArrangedSubview(splitBtn)
        }

        let ret = makeReturnButton()
        ret.widthAnchor.constraint(equalToConstant: isPadLayout ? 88 : 68).isActive = true
        bottom.addArrangedSubview(ret)
    }

    private func renderSplitLayout(spacing: CGFloat) {
        let posture = currentPosture
        let containerWidth = Double(activeContainerSize.width)
        let gapWidth = CGFloat(posture.recommendedBridgeWidth(for: containerWidth))
        let duplicateBoundary = settings.duoDuplicateBoundaryKeys && page == .letters

        let letterPairs: [(String, String)] = duplicateBoundary
            ? [("qwert", "yuiop"), ("asdfg", "ghjkl"), ("zxcvb", "bnm")]
            : [("qwert", "yuiop"), ("asdfg", "hjkl"), ("zxcv", "bnm")]

        let pairs: [(String, String)] = switch page {
        case .letters: letterPairs
        case .numbers: [("12345", "67890"), ("-/:;(", ")$&@\""), (".,?", "!'")]
        case .symbols: [("[]{}#", "%^*+="), ("_\\|~<", ">€£¥•"), (".,?", "!'")]
        case .emoji, .clipboard: []
        }

        if posture.usesInteractiveCenterBridge(for: containerWidth) {
            let splitShell = UIStackView()
            splitShell.axis = .horizontal
            splitShell.spacing = 0
            splitShell.alignment = .fill
            splitShell.distribution = .fill
            rows.addArrangedSubview(splitShell)

            let leftColumn = UIStackView()
            leftColumn.axis = .vertical
            leftColumn.spacing = spacing
            leftColumn.distribution = .fillEqually

            let rightColumn = UIStackView()
            rightColumn.axis = .vertical
            rightColumn.spacing = spacing
            rightColumn.distribution = .fillEqually

            let bridgeView = makeInteractiveCenterBridgeView(width: gapWidth, spacing: spacing)

            splitShell.addArrangedSubview(leftColumn)
            splitShell.addArrangedSubview(bridgeView)
            splitShell.addArrangedSubview(rightColumn)
            leftColumn.widthAnchor.constraint(equalTo: rightColumn.widthAnchor).isActive = true

            func makeClusterRow() -> UIStackView {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = spacing
                row.distribution = .fillEqually
                return row
            }

            if settings.showNumberRow && page == .letters {
                let leftNum = makeClusterRow()
                let rightNum = makeClusterRow()
                populateCharacterCluster(letters: "12345", into: leftNum)
                populateCharacterCluster(letters: "67890", into: rightNum)
                leftColumn.addArrangedSubview(leftNum)
                rightColumn.addArrangedSubview(rightNum)
            }

            for (index, (leftLetters, rightLetters)) in pairs.enumerated() {
                let leftRow = makeClusterRow()
                let rightRow = makeClusterRow()
                if index == 2 {
                    leftRow.addArrangedSubview(makeLeadingRow2Button())
                    populateCharacterCluster(letters: leftLetters, into: leftRow)
                    populateCharacterCluster(letters: rightLetters, into: rightRow)
                    rightRow.addArrangedSubview(makeBackspaceButton())
                } else {
                    populateCharacterCluster(letters: leftLetters, into: leftRow)
                    populateCharacterCluster(letters: rightLetters, into: rightRow)
                }
                leftColumn.addArrangedSubview(leftRow)
                rightColumn.addArrangedSubview(rightRow)
            }

            let leftBottom = UIStackView()
            leftBottom.axis = .horizontal
            leftBottom.spacing = spacing
            leftBottom.distribution = .fill

            let rightBottom = UIStackView()
            rightBottom.axis = .horizontal
            rightBottom.spacing = spacing
            rightBottom.distribution = .fill

            let btnW: CGFloat = isPadLayout ? 44 : 36
            let pageBtn = makePageToggleButton()
            pageBtn.widthAnchor.constraint(equalToConstant: btnW).isActive = true
            leftBottom.addArrangedSubview(pageBtn)

            let emojiBtn = makeEmojiButton()
            emojiBtn.widthAnchor.constraint(equalToConstant: btnW).isActive = true
            leftBottom.addArrangedSubview(emojiBtn)

            let langBtn = makeLanguageToggleButton()
            langBtn.widthAnchor.constraint(equalToConstant: btnW).isActive = true
            leftBottom.addArrangedSubview(langBtn)

            let leftSpace = makeSpaceButton(isPrimary: true)
            leftSpace.setContentHuggingPriority(.defaultLow, for: .horizontal)
            leftBottom.addArrangedSubview(leftSpace)

            let rightSpace = makeSpaceButton(isPrimary: false)
            rightSpace.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rightBottom.addArrangedSubview(rightSpace)

            if needsInputModeSwitchKey {
                let globe = makeGlobeButton()
                globe.widthAnchor.constraint(equalToConstant: btnW).isActive = true
                rightBottom.addArrangedSubview(globe)
            } else {
                let dot = makeButton(".", label: ".", role: .character) { $0.type(".") }
                dot.widthAnchor.constraint(equalToConstant: btnW).isActive = true
                rightBottom.addArrangedSubview(dot)
            }

            let ret = makeReturnButton()
            ret.widthAnchor.constraint(equalToConstant: isPadLayout ? 72 : 56).isActive = true
            rightBottom.addArrangedSubview(ret)

            leftColumn.addArrangedSubview(leftBottom)
            rightColumn.addArrangedSubview(rightBottom)
            return
        }

        // Compact phone-landscape split layout
        if settings.showNumberRow && page == .letters {
            let (left, right) = addSplitRow(spacing: spacing, gapWidth: gapWidth)
            populateCharacterCluster(letters: "12345", into: left)
            populateCharacterCluster(letters: "67890", into: right)
        }

        for (index, (leftLetters, rightLetters)) in pairs.enumerated() {
            let (left, right) = addSplitRow(spacing: spacing, gapWidth: gapWidth)
            if index == 2 {
                let lead = makeLeadingRow2Button()
                left.addArrangedSubview(lead)
                populateCharacterCluster(letters: leftLetters, into: left)
                populateCharacterCluster(letters: rightLetters, into: right)
                let back = makeBackspaceButton()
                right.addArrangedSubview(back)
            } else {
                populateCharacterCluster(letters: leftLetters, into: left)
                populateCharacterCluster(letters: rightLetters, into: right)
            }
        }

        let bottomContainer = UIStackView()
        bottomContainer.axis = .horizontal
        bottomContainer.spacing = 0
        bottomContainer.alignment = .fill
        bottomContainer.distribution = .fill
        rows.addArrangedSubview(bottomContainer)

        let leftBottom = UIStackView()
        leftBottom.axis = .horizontal
        leftBottom.spacing = spacing
        leftBottom.distribution = .fill

        let centerBridge = UIStackView()
        centerBridge.axis = .horizontal
        centerBridge.alignment = .fill
        centerBridge.distribution = .fillEqually
        centerBridge.isLayoutMarginsRelativeArrangement = true
        centerBridge.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        centerBridge.widthAnchor.constraint(equalToConstant: gapWidth).isActive = true

        let rightBottom = UIStackView()
        rightBottom.axis = .horizontal
        rightBottom.spacing = spacing
        rightBottom.distribution = .fill

        bottomContainer.addArrangedSubview(leftBottom)
        bottomContainer.addArrangedSubview(centerBridge)
        bottomContainer.addArrangedSubview(rightBottom)
        leftBottom.widthAnchor.constraint(equalTo: rightBottom.widthAnchor).isActive = true

        let btnW: CGFloat = 36
        let pageBtn = makePageToggleButton()
        pageBtn.widthAnchor.constraint(equalToConstant: btnW).isActive = true
        leftBottom.addArrangedSubview(pageBtn)

        let emojiBtn = makeEmojiButton()
        emojiBtn.widthAnchor.constraint(equalToConstant: btnW).isActive = true
        leftBottom.addArrangedSubview(emojiBtn)

        let langBtn = makeLanguageToggleButton()
        langBtn.widthAnchor.constraint(equalToConstant: btnW).isActive = true
        leftBottom.addArrangedSubview(langBtn)

        let leftSpace = makeSpaceButton(isPrimary: true)
        leftSpace.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftBottom.addArrangedSubview(leftSpace)

        centerBridge.addArrangedSubview(makeSplitToggleButton(isSplit: true))

        let rightSpace = makeSpaceButton(isPrimary: false)
        rightSpace.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rightBottom.addArrangedSubview(rightSpace)

        if needsInputModeSwitchKey {
            let globe = makeGlobeButton()
            globe.widthAnchor.constraint(equalToConstant: btnW).isActive = true
            rightBottom.addArrangedSubview(globe)
        } else {
            let dot = makeButton(".", label: ".", role: .character) { $0.type(".") }
            dot.widthAnchor.constraint(equalToConstant: btnW).isActive = true
            rightBottom.addArrangedSubview(dot)
        }

        let ret = makeReturnButton()
        ret.widthAnchor.constraint(equalToConstant: 58).isActive = true
        rightBottom.addArrangedSubview(ret)
    }

    private func makeInteractiveCenterBridgeView(width: CGFloat, spacing: CGFloat) -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.widthAnchor.constraint(equalToConstant: width).isActive = true

        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 6
        card.alignment = .fill
        card.distribution = .fill
        card.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.52)
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        card.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(card)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 6),
            card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -6),
            card.topAnchor.constraint(equalTo: wrapper.topAnchor),
            card.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])

        // Top mode selector bar + Split Merge button
        let modeBar = UIStackView()
        modeBar.axis = .horizontal
        modeBar.spacing = 4
        modeBar.distribution = .fillEqually
        modeBar.heightAnchor.constraint(equalToConstant: 26).isActive = true
        for mode in DuoBridgeMode.allCases {
            let isActive = settings.duoCenterBridgeMode == mode
            let btn = makeSymbolButton(
                mode.symbolName,
                pointSize: 12,
                weight: .semibold,
                label: mode.title,
                role: isActive ? .prominent : .modifier
            ) { kb in
                kb.triggerFeedback()
                kb.settings.duoCenterBridgeMode = mode
                kb.renderKeys()
            }
            btn.accessibilityIdentifier = "duo.bridge.\(mode.rawValue)"
            modeBar.addArrangedSubview(btn)
        }
        let mergeBtn = makeSplitToggleButton(isSplit: true)
        modeBar.addArrangedSubview(mergeBtn)
        card.addArrangedSubview(modeBar)

        switch settings.duoCenterBridgeMode {
        case .trackpad:
            let pad = UIView()
            pad.backgroundColor = UIColor.tertiarySystemBackground.withAlphaComponent(0.55)
            pad.layer.cornerRadius = 8
            pad.accessibilityLabel = "Bàn rê con trỏ 2D"
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleBridgeTrackpadPan(_:)))
            pad.addGestureRecognizer(pan)

            let iconView = UIImageView(image: symbolImage("arrow.up.and.down.and.arrow.left.and.right", pointSize: 22, weight: .regular))
            iconView.tintColor = .secondaryLabel
            iconView.translatesAutoresizingMaskIntoConstraints = false
            let caption = UILabel()
            caption.text = "Rê con trỏ"
            caption.font = .systemFont(ofSize: 11, weight: .medium)
            caption.textColor = .secondaryLabel
            caption.translatesAutoresizingMaskIntoConstraints = false
            pad.addSubview(iconView)
            pad.addSubview(caption)
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: pad.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: pad.centerYAnchor, constant: -10),
                caption.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
                caption.centerXAnchor.constraint(equalTo: pad.centerXAnchor),
            ])
            card.addArrangedSubview(pad)

            let quickNav = UIStackView()
            quickNav.axis = .horizontal
            quickNav.spacing = 4
            quickNav.distribution = .fillEqually
            quickNav.heightAnchor.constraint(equalToConstant: 32).isActive = true
            quickNav.addArrangedSubview(makeSymbolButton("arrow.left", pointSize: 13, label: "Sang trái", role: .modifier) { kb in
                kb.triggerFeedback()
                kb.discardComposition()
                kb.textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
            })
            quickNav.addArrangedSubview(makeSymbolButton("arrow.right", pointSize: 13, label: "Sang phải", role: .modifier) { kb in
                kb.triggerFeedback()
                kb.discardComposition()
                kb.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            })
            quickNav.addArrangedSubview(makeBackspaceButton())
            card.addArrangedSubview(quickNav)

        case .numpad:
            let padRows = ["789", "456", "123", ",0."]
            let grid = UIStackView()
            grid.axis = .vertical
            grid.spacing = spacing
            grid.distribution = .fillEqually
            for rowChars in padRows {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = spacing
                row.distribution = .fillEqually
                for ch in rowChars {
                    let s = String(ch)
                    let btn = makeButton(s, label: s, role: .character) { kb in
                        kb.type(ch)
                    }
                    btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
                    row.addArrangedSubview(btn)
                }
                grid.addArrangedSubview(row)
            }
            card.addArrangedSubview(grid)

        case .clipboard:
            let col = UIStackView()
            col.axis = .vertical
            col.spacing = 4
            col.distribution = .fillEqually
            let quickItems = Array(settings.clipboardHistory.items.prefix(3))
            if quickItems.isEmpty {
                let emptyBtn = makeSymbolButton("doc.on.clipboard.fill", pointSize: 15, label: "Dán từ Bộ nhớ tạm", role: .prominent) { kb in
                    kb.triggerFeedback()
                    if let text = UIPasteboard.general.string, !text.isEmpty {
                        kb.discardComposition()
                        kb.textDocumentProxy.insertText(text)
                        kb.settings.recordClipboard(text)
                        kb.updateSuggestions()
                    }
                }
                col.addArrangedSubview(emptyBtn)
            } else {
                for item in quickItems {
                    let title = item.alias.isEmpty ? item.preview : item.alias
                    let btn = makeButton(title, label: title, role: .character) { kb in
                        kb.triggerFeedback()
                        kb.discardComposition()
                        kb.textDocumentProxy.insertText(item.text)
                        kb.updateSuggestions()
                    }
                    var cfg = UIButton.Configuration.plain()
                    cfg.image = symbolImage(item.kind.symbolName, pointSize: 11.5, weight: .semibold)
                    cfg.imagePadding = 5
                    cfg.title = title
                    cfg.baseForegroundColor = .label
                    cfg.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
                    btn.configuration = cfg
                    btn.contentHorizontalAlignment = .leading
                    btn.titleLabel?.lineBreakMode = .byTruncatingTail
                    col.addArrangedSubview(btn)
                }
            }
            card.addArrangedSubview(col)
        }

        return wrapper
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

    private func populateCharacterCluster(letters: String, into cluster: UIStackView) {
        for letter in letters {
            let title = (isShifted && page == .letters) ? String(letter).uppercased() : String(letter)
            let secondary = (page == .letters && settings.flickDownSymbols) ? Self.flickCharacters[letter] : nil
            let button = addCharacterKey(title, secondary: secondary, to: cluster)
            if page == .letters {
                letterButtons.append((button, letter))
                if let variants = Self.accentVariants[letter] {
                    let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleAccentLongPress(_:)))
                    hold.minimumPressDuration = 0.35
                    button.accessibilityHint = variants.joined(separator: ",")
                    button.addGestureRecognizer(hold)
                }
            }
        }
    }

    private func contextConvenienceCharacters() -> [Character] {
        guard let kt = textDocumentProxy.keyboardType else { return [] }
        switch kt {
        case .emailAddress: return ["@", "."]
        case .URL: return ["/", "."]
        case .twitter: return ["@", "#"]
        default: return []
        }
    }

    // MARK: - Key Builders

    private func makeLeadingRow2Button() -> UIButton {
        switch page {
        case .letters:
            let shiftSymbol: String = switch shiftState {
            case .off: "shift"
            case .once: "shift.fill"
            case .locked: "capslock.fill"
            }
            let btn = makeSymbolButton(
                shiftSymbol,
                pointSize: 17,
                weight: .medium,
                label: "Chữ hoa",
                role: shiftState == .off ? .modifier : .prominent
            ) { keyboard in
                keyboard.triggerFeedback()
                let now = ContinuousClock.now
                if let last = keyboard.lastShiftTap, last.duration(to: now) <= .milliseconds(350),
                   keyboard.shiftState != .locked {
                    keyboard.shiftState = .locked
                    keyboard.lastShiftTap = nil
                } else {
                    keyboard.shiftState = (keyboard.shiftState == .off) ? .once : .off
                    keyboard.lastShiftTap = now
                }
                keyboard.updateShiftKeyTitles()
            }
            shiftButton = btn
            return btn
        case .numbers:
            return makeButton("#+=", label: "Ký hiệu", role: .modifier) { keyboard in
                keyboard.triggerFeedback()
                keyboard.page = .symbols
                keyboard.renderKeys()
            }
        case .symbols, .emoji, .clipboard:
            return makeButton("123", label: "Số", role: .modifier) { keyboard in
                keyboard.triggerFeedback()
                keyboard.page = .numbers
                keyboard.renderKeys()
            }
        }
    }

    private func makeBackspaceButton() -> UIButton {
        let backspace = makeSymbolButton("delete.left", pointSize: 17, weight: .medium, label: "Xoá", role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            keyboard.handle(.backspace)
        }
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleBackspaceLongPress(_:)))
        longPress.minimumPressDuration = 0.35
        backspace.addGestureRecognizer(longPress)
        return backspace
    }

    private func makePageToggleButton() -> UIButton {
        makeButton(page == .letters ? "123" : "ABC", label: page == .letters ? "123" : "ABC", role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            keyboard.page = (keyboard.page == .letters) ? .numbers : .letters
            keyboard.shiftState = .off
            keyboard.renderKeys()
        }
    }

    private func makeEmojiButton() -> UIButton {
        makeSymbolButton("face.smiling", pointSize: 17, weight: .medium, label: "Emoji", role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            keyboard.page = .emoji
            keyboard.renderKeys()
        }
    }

    private func makeLanguageToggleButton() -> UIButton {
        let code = session.isVietnamese ? "VI" : "EN"
        let btn = makeButton(code, label: "Chế độ ngôn ngữ", role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            if keyboard.isStructuredASCIIField || keyboard.settings.focusPreferEnglish {
                let current = keyboard.manualLanguageOverrideInField ?? keyboard.session.isVietnamese
                keyboard.manualLanguageOverrideInField = !current
            } else {
                keyboard.manualLanguageOverrideInField = nil
                keyboard.settings.vietnameseEnabled.toggle()
            }
            keyboard.syncEffectiveLanguageMode()
            keyboard.updateSuggestions()
        }
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        btn.accessibilityIdentifier = "keyboard.languageToggle"
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleLanguageLongPress(_:)))
        hold.minimumPressDuration = 0.4
        btn.addGestureRecognizer(hold)
        languageButton = btn
        return btn
    }

    private func makeGlobeButton() -> UIButton {
        let globe = styledButton(title: "", label: "Đổi bàn phím", role: .modifier)
        globe.setTitle(nil, for: .normal)
        globe.setImage(symbolImage("globe", pointSize: 17, weight: .medium), for: .normal)
        globe.tintColor = .label
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        return globe
    }

    private func makeSpaceButton(isPrimary: Bool) -> UIButton {
        let title = session.isVietnamese ? "Tiếng Việt" : "English"
        let label = isPrimary ? "Dấu cách" : "Dấu cách phải"
        let space = makeButton(title, label: label, role: .character) { $0.type(" ") }
        space.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        if !isPrimary {
            space.accessibilityIdentifier = "keyboard.rightSpace"
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSpacePan(_:)))
        space.addGestureRecognizer(pan)
        spaceButtons.append(space)
        return space
    }

    private func makeSplitToggleButton(isSplit: Bool) -> UIButton {
        let symbol = isSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
        let label = isSplit ? "Gộp bàn phím" : "Chia đôi bàn phím"
        let btn = makeSymbolButton(symbol, pointSize: 14, weight: .medium, label: label, role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            keyboard.settings.splitLandscapeKeyboard.toggle()
            keyboard.renderKeys()
        }
        btn.accessibilityIdentifier = "keyboard.splitToggle"
        return btn
    }

    private func makeReturnButton() -> UIButton {
        let rt = textDocumentProxy.returnKeyType ?? .default
        let (title, isProminent): (String, Bool) = switch rt {
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
        let btn = makeButton(title, label: title, role: isProminent ? .prominent : .modifier) { $0.type("\n") }
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: isProminent ? .semibold : .medium)
        btn.accessibilityIdentifier = "keyboard.return"
        return btn
    }

    private func updateLanguageIndicators() {
        let vi = session.isVietnamese
        languageButton?.setTitle(vi ? "VI" : "EN", for: .normal)
        languageButton?.setTitleColor(vi ? .systemBlue : .secondaryLabel, for: .normal)
        let spaceTitle = vi ? "Tiếng Việt" : "English"
        for space in spaceButtons {
            space.setTitle(spaceTitle, for: .normal)
        }
    }

    // MARK: - Emoji Picker & Search

    private func renderEmojiPicker(spacing: CGFloat) {
        if emojiSearching {
            renderEmojiSearchKeyboard(spacing: spacing)
            return
        }
        let showBar = settings.effectiveShowSuggestions
        topBar.isHidden = !showBar
        suggestionBar.isHidden = !showBar
        clipboardButton.isHidden = !showBar
        textToolsButton.isHidden = !showBar
        suggestionHeightConstraint?.constant = showBar ? 34 : 0

        let categories = EmojiSuggestions.categories
        let selectedIndex = min(max(0, emojiCategoryIndex), max(0, categories.count - 1))
        let categoryRow = addRow(spacing: spacing)
        let searchBtn = makeSymbolButton("magnifyingglass", pointSize: 15, weight: .semibold, label: "Tìm Emoji", role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            keyboard.emojiSearching = true
            keyboard.emojiSearchQuery = ""
            keyboard.renderKeys()
        }
        categoryRow.addArrangedSubview(searchBtn)
        searchBtn.accessibilityIdentifier = "emoji.search"
        for (idx, category) in categories.enumerated() {
            let button = addKey(category.title, role: .modifier, to: categoryRow) { keyboard in
                keyboard.triggerFeedback()
                keyboard.emojiCategoryIndex = idx
                keyboard.renderKeys()
            }
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: idx == selectedIndex ? .semibold : .regular)
            button.backgroundColor = idx == selectedIndex ? .secondarySystemFill : .clear
            button.layer.shadowOpacity = 0
        }

        let emojis = categories[selectedIndex].emojis
        let perRow = isPadLayout ? 9 : 6
        for rowStart in stride(from: 0, to: emojis.count, by: perRow) {
            let slice = emojis[rowStart..<min(rowStart + perRow, emojis.count)]
            let emojiRow = addRow(spacing: spacing)
            for (offset, emoji) in slice.enumerated() {
                let btn = addKey(emoji, label: emoji, role: .character, to: emojiRow) { keyboard in
                    keyboard.triggerFeedback()
                    keyboard.discardComposition()
                    keyboard.textDocumentProxy.insertText(emoji)
                    keyboard.updateSuggestions()
                }
                btn.titleLabel?.font = .systemFont(ofSize: 24)
                btn.backgroundColor = .clear
                btn.layer.shadowOpacity = 0
                btn.accessibilityIdentifier = "emoji.\(rowStart + offset)"
            }
        }

        let bottom = addRow(spacing: spacing)
        addKey("ABC", role: .modifier, to: bottom) { keyboard in
            keyboard.triggerFeedback()
            keyboard.page = .letters
            keyboard.renderKeys()
        }
        let sp = addKey("Dấu cách", label: "Dấu cách", role: .character, to: bottom) { $0.type(" ") }
        sp.titleLabel?.font = .systemFont(ofSize: 15)
        addKey("⌫", label: "Xoá", role: .modifier, to: bottom) { keyboard in
            keyboard.triggerFeedback()
            keyboard.handle(.backspace)
        }
    }

    private func renderEmojiSearchKeyboard(spacing: CGFloat) {
        topBar.isHidden = false
        suggestionBar.isHidden = false
        clipboardButton.isHidden = true
        textToolsButton.isHidden = true
        suggestionHeightConstraint?.constant = 34

        let headerRow = addRow(spacing: spacing)
        headerRow.distribution = .fill
        let queryBtn = UIButton(type: .system)
        queryBtn.contentHorizontalAlignment = .leading
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        queryBtn.configuration = config
        queryBtn.backgroundColor = .secondarySystemFill
        queryBtn.layer.cornerRadius = 6
        queryBtn.accessibilityIdentifier = "emoji.searchQuery"
        queryBtn.isUserInteractionEnabled = false
        headerRow.addArrangedSubview(queryBtn)
        emojiQueryButton = queryBtn

        let closeBtn = addKey("Đóng", role: .modifier, to: headerRow) { keyboard in
            keyboard.triggerFeedback()
            keyboard.emojiSearching = false
            keyboard.emojiSearchQuery = ""
            keyboard.renderKeys()
            keyboard.updateSuggestions()
        }
        closeBtn.widthAnchor.constraint(equalToConstant: 64).isActive = true
        closeBtn.accessibilityIdentifier = "emoji.closeSearch"

        for (rowIdx, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            let row = addRow(spacing: spacing)
            for ch in letters {
                let s = String(ch)
                addKey(s, role: .character, to: row) { keyboard in
                    keyboard.triggerFeedback()
                    keyboard.emojiSearchQuery.append(ch)
                    keyboard.refreshEmojiSearchUI()
                }
            }
            if rowIdx == 2 {
                addKey("⌫", label: "Xoá từ khoá", role: .modifier, to: row) { keyboard in
                    keyboard.triggerFeedback()
                    if !keyboard.emojiSearchQuery.isEmpty {
                        keyboard.emojiSearchQuery.removeLast()
                        keyboard.refreshEmojiSearchUI()
                    }
                }
            }
        }

        let bottom = addRow(spacing: spacing)
        addKey("ABC", role: .modifier, to: bottom) { keyboard in
            keyboard.triggerFeedback()
            keyboard.emojiSearching = false
            keyboard.emojiSearchQuery = ""
            keyboard.page = .letters
            keyboard.renderKeys()
            keyboard.updateSuggestions()
        }
        addKey("Cách", label: "Dấu cách từ khoá", role: .character, to: bottom) { keyboard in
            keyboard.triggerFeedback()
            if !keyboard.emojiSearchQuery.isEmpty, keyboard.emojiSearchQuery.last != " " {
                keyboard.emojiSearchQuery.append(" ")
                keyboard.refreshEmojiSearchUI()
            }
        }
        addKey("Xoá hết", role: .modifier, to: bottom) { keyboard in
            keyboard.triggerFeedback()
            keyboard.emojiSearchQuery = ""
            keyboard.refreshEmojiSearchUI()
        }

        refreshEmojiSearchUI()
    }

    // MARK: - Inline Clipboard Picker (Scrollable Cards + Semantic Icons + Filters)

    private func badgeTint(for item: ClipboardItem) -> UIColor {
        if item.kind == .hexColor, let rgb = item.parsedHexColor {
            return UIColor(red: rgb.redFraction, green: rgb.greenFraction, blue: rgb.blueFraction, alpha: 1)
        }
        switch item.kind {
        case .url: return .systemBlue
        case .email: return .systemIndigo
        case .phone: return .systemGreen
        case .otp: return .systemOrange
        case .hexColor: return .systemPink
        case .code: return .systemPurple
        case .multiline: return .systemTeal
        case .text: return .secondaryLabel
        }
    }

    private func makeClipboardKindBadgeView(for item: ClipboardItem) -> UIView {
        let badge = UIView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.backgroundColor = badgeTint(for: item)
        badge.layer.cornerRadius = 7
        badge.layer.cornerCurve = .continuous
        badge.isUserInteractionEnabled = false
        if item.kind == .hexColor {
            badge.layer.borderWidth = 1
            badge.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        }
        let iconView = UIImageView(image: symbolImage(item.kind.symbolName, pointSize: 12.5, weight: .semibold))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(iconView)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 26),
            badge.heightAnchor.constraint(equalToConstant: 26),
            iconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        return badge
    }

    private func renderClipboardPicker(spacing: CGFloat) {
        let showBar = settings.effectiveShowSuggestions
        topBar.isHidden = !showBar
        suggestionBar.isHidden = !showBar
        clipboardButton.isHidden = !showBar
        textToolsButton.isHidden = !showBar
        suggestionHeightConstraint?.constant = showBar ? 34 : 0

        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = spacing
        header.distribution = .fill
        header.heightAnchor.constraint(equalToConstant: 32).isActive = true
        rows.addArrangedSubview(header)

        let backBtn = makeSymbolButton("keyboard", pointSize: 15, weight: .medium, label: "Quay lại bàn phím", role: .modifier) { keyboard in
            keyboard.triggerFeedback()
            keyboard.page = .letters
            keyboard.renderKeys()
        }
        backBtn.widthAnchor.constraint(equalToConstant: 48).isActive = true
        header.addArrangedSubview(backBtn)

        let pasteBtn = UIButton(type: .system)
        var pasteCfg = UIButton.Configuration.filled()
        pasteCfg.baseBackgroundColor = .systemBlue
        pasteCfg.baseForegroundColor = .white
        pasteCfg.cornerStyle = .medium
        pasteCfg.image = symbolImage("doc.on.clipboard.fill", pointSize: 13.5, weight: .semibold)
        pasteCfg.imagePadding = 6
        pasteCfg.title = "Dán bộ nhớ tạm"
        pasteCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13.5, weight: .semibold)
            return out
        }
        pasteBtn.configuration = pasteCfg
        pasteBtn.accessibilityLabel = "Dán từ Bộ nhớ tạm"
        pasteBtn.accessibilityIdentifier = "clipboard.pasteSystem"
        pasteBtn.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.triggerFeedback()
            if let pasteText = UIPasteboard.general.string, !pasteText.isEmpty {
                self.discardComposition()
                self.textDocumentProxy.insertText(pasteText)
                self.settings.recordClipboard(pasteText)
                self.page = .letters
                self.renderKeys()
                self.updateSuggestions()
            }
        }, for: .touchUpInside)
        header.addArrangedSubview(pasteBtn)

        if !settings.clipboardHistory.unpinnedItems.isEmpty {
            let clearBtn = makeSymbolButton("trash", pointSize: 14, weight: .medium, label: "Xoá mục chưa ghim", role: .modifier) { keyboard in
                keyboard.triggerFeedback()
                keyboard.settings.clearUnpinnedClipboard()
                keyboard.renderKeys()
            }
            clearBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
            header.addArrangedSubview(clearBtn)
        }

        // Category filter chip strip
        let filterRow = UIStackView()
        filterRow.axis = .horizontal
        filterRow.spacing = 5
        filterRow.distribution = .fillEqually
        filterRow.heightAnchor.constraint(equalToConstant: 28).isActive = true
        rows.addArrangedSubview(filterRow)
        for chip in ClipboardFilter.allCases {
            let isActive = chip == clipboardFilter
            var cfg = UIButton.Configuration.filled()
            cfg.baseBackgroundColor = isActive ? UIColor.systemBlue.withAlphaComponent(0.18) : Self.modifierKeyFill
            cfg.baseForegroundColor = isActive ? .systemBlue : .label
            cfg.cornerStyle = .capsule
            cfg.image = symbolImage(chip.symbolName, pointSize: 11, weight: isActive ? .semibold : .regular)
            cfg.imagePadding = 4
            cfg.title = chip.title
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var out = incoming
                out.font = .systemFont(ofSize: 11.5, weight: isActive ? .semibold : .medium)
                return out
            }
            let chipBtn = UIButton(configuration: cfg)
            chipBtn.accessibilityLabel = chip.title
            chipBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.clipboardFilter = chip
                self.renderKeys()
            }, for: .touchUpInside)
            filterRow.addArrangedSubview(chipBtn)
        }

        let items = Array(settings.clipboardHistory.filter(clipboardFilter).prefix(25))
        if items.isEmpty {
            let hintBtn = UIButton(type: .system)
            hintBtn.setTitle(
                clipboardFilter == .all
                    ? "Ghim mẫu văn bản trong app viTek hoặc đồng bộ từ Mac qua iCloud"
                    : "Không có mục nào thuộc nhóm “\(clipboardFilter.title)”",
                for: .normal
            )
            hintBtn.titleLabel?.font = .systemFont(ofSize: 13)
            hintBtn.titleLabel?.numberOfLines = 2
            hintBtn.titleLabel?.textAlignment = .center
            hintBtn.setTitleColor(.secondaryLabel, for: .normal)
            hintBtn.isUserInteractionEnabled = false
            rows.addArrangedSubview(hintBtn)
            return
        }

        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = true
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        rows.addArrangedSubview(scroll)

        let listStack = UIStackView()
        listStack.axis = .vertical
        listStack.spacing = 6
        listStack.alignment = .fill
        listStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(listStack)
        NSLayoutConstraint.activate([
            listStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            listStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            listStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            listStack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])

        func makeClipboardCard(item: ClipboardItem, index: Int) -> UIView {
            let card = UIStackView()
            card.axis = .horizontal
            card.spacing = 8
            card.alignment = .center
            card.backgroundColor = Self.characterKeyFill
            card.layer.cornerRadius = isPadLayout ? 9 : 7
            card.layer.cornerCurve = .continuous
            card.isLayoutMarginsRelativeArrangement = true
            card.layoutMargins = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 6)
            card.heightAnchor.constraint(equalToConstant: 40).isActive = true

            card.addArrangedSubview(makeClipboardKindBadgeView(for: item))

            let textBtn = UIButton(type: .system)
            textBtn.contentHorizontalAlignment = .leading
            var cfg = UIButton.Configuration.plain()
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2)
            cfg.title = item.alias.isEmpty ? item.preview : item.alias
            if !item.alias.isEmpty {
                cfg.subtitle = item.preview
            }
            cfg.titleLineBreakMode = .byTruncatingTail
            cfg.subtitleLineBreakMode = .byTruncatingTail
            cfg.baseForegroundColor = .label
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var out = incoming
                out.font = !item.alias.isEmpty
                    ? .systemFont(ofSize: 13, weight: .semibold)
                    : (item.kind.usesMonospacedFont ? .monospacedSystemFont(ofSize: 12.5, weight: .regular) : .systemFont(ofSize: 13.5))
                return out
            }
            textBtn.configuration = cfg
            textBtn.accessibilityIdentifier = "clipboard.item.\(index)"
            textBtn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.discardComposition()
                self.textDocumentProxy.insertText(item.text)
                self.page = .letters
                self.renderKeys()
                self.updateSuggestions()
            }, for: .touchUpInside)
            card.addArrangedSubview(textBtn)

            let pinBtn = makeSymbolButton(
                item.isPinned ? "pin.fill" : "pin",
                pointSize: 13,
                weight: .semibold,
                label: item.isPinned ? "Bỏ ghim" : "Ghim",
                role: .modifier
            ) { keyboard in
                keyboard.triggerFeedback()
                keyboard.settings.togglePinClipboard(item.text)
                keyboard.renderKeys()
            }
            pinBtn.backgroundColor = .clear
            pinBtn.tintColor = item.isPinned ? .systemBlue : .secondaryLabel
            pinBtn.widthAnchor.constraint(equalToConstant: 30).isActive = true
            pinBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true
            card.addArrangedSubview(pinBtn)
            return card
        }

        let twoColumn = activeContainerSize.width >= 520
        if twoColumn {
            for idx in stride(from: 0, to: items.count, by: 2) {
                let pairRow = UIStackView()
                pairRow.axis = .horizontal
                pairRow.spacing = 6
                pairRow.distribution = .fillEqually
                pairRow.addArrangedSubview(makeClipboardCard(item: items[idx], index: idx))
                if idx + 1 < items.count {
                    pairRow.addArrangedSubview(makeClipboardCard(item: items[idx + 1], index: idx + 1))
                } else {
                    let spacer = UIView()
                    pairRow.addArrangedSubview(spacer)
                }
                listStack.addArrangedSubview(pairRow)
            }
        } else {
            for (idx, item) in items.enumerated() {
                listStack.addArrangedSubview(makeClipboardCard(item: item, index: idx))
            }
        }
    }

    private func refreshEmojiSearchUI() {
        let prompt = emojiSearchQuery.isEmpty ? "🔍 Tìm: tim, vui, tra sua, viet…" : "🔍 \(emojiSearchQuery)"
        emojiQueryButton?.setTitle(prompt, for: .normal)
        emojiQueryButton?.setTitleColor(emojiSearchQuery.isEmpty ? .secondaryLabel : .label, for: .normal)

        for view in suggestionBar.arrangedSubviews { view.removeFromSuperview() }
        let results = emojiSearchQuery.isEmpty
            ? Array(EmojiSuggestions.categories[0].emojis.prefix(7))
            : EmojiSuggestions.search(emojiSearchQuery, limit: 7)
        for (idx, emoji) in results.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(emoji, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 22)
            btn.accessibilityIdentifier = "emoji.result.\(idx)"
            btn.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                self.triggerFeedback()
                self.discardComposition()
                self.textDocumentProxy.insertText(emoji)
            }, for: .touchUpInside)
            suggestionBar.addArrangedSubview(btn)
        }
    }

    /// Updates letter keycaps and Shift icon in-place without rebuilding UIStackView/UIButton trees.
    private func updateShiftKeyTitles() {
        guard page == .letters, !letterButtons.isEmpty else { return }
        let symbol: String = switch shiftState {
        case .off: "shift"
        case .once: "shift.fill"
        case .locked: "capslock.fill"
        }
        shiftButton?.setTitle(nil, for: .normal)
        shiftButton?.setImage(symbolImage(symbol, pointSize: 17, weight: .medium), for: .normal)
        shiftButton?.tintColor = shiftState == .off ? .label : .white
        shiftButton?.backgroundColor = shiftState == .off ? Self.modifierKeyFill : .systemBlue
        let upper = isShifted
        for entry in letterButtons {
            let title = upper ? String(entry.lowercase).uppercased() : String(entry.lowercase)
            entry.button.setTitle(title, for: .normal)
            entry.button.accessibilityLabel = title
        }
    }

    @objc private func handleAccentLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let button = gesture.view as? UIButton,
              let raw = button.accessibilityHint, !raw.isEmpty else { return }
        activeFlickCharacter = nil
        touchStartPoint = nil
        let variants = raw.split(separator: ",").map(String.init)
        showAccentStrip(for: variants, above: button)
    }

    @discardableResult
    private func addCharacterKey(_ title: String, secondary: Character?, to row: UIStackView) -> UIButton {
        let button = styledButton(title: title, label: nil, role: .character)
        if let secondary {
            let sub = UILabel()
            sub.text = String(secondary)
            sub.font = .systemFont(ofSize: isPadLayout ? 10 : 8.5, weight: .medium)
            sub.textColor = .secondaryLabel
            sub.isUserInteractionEnabled = false
            sub.isAccessibilityElement = false
            sub.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(sub)
            NSLayoutConstraint.activate([
                sub.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
                sub.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
            ])
        }
        row.addArrangedSubview(button)
        button.addTarget(self, action: #selector(handleCharacterTouchDown(_:forEvent:)), for: .touchDown)
        button.addTarget(self, action: #selector(handleCharacterTouchDrag(_:forEvent:)), for: [.touchDragInside, .touchDragOutside])
        button.addTarget(self, action: #selector(handleCharacterKeyUp(_:forEvent:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(handleCharacterTouchUpOutside(_:forEvent:)), for: .touchUpOutside)
        button.addTarget(self, action: #selector(handleCharacterTouchCancel(_:)), for: .touchCancel)
        return button
    }

    @objc private func handleCharacterTouchDown(_ sender: UIButton, forEvent event: UIEvent) {
        touchStartPoint = event.allTouches?.first?.location(in: sender)
        activeFlickCharacter = nil
        if let liveTitle = sender.title(for: .normal) {
            showKeyPreview(for: sender, text: liveTitle)
        }
    }

    @objc private func handleCharacterTouchDrag(_ sender: UIButton, forEvent event: UIEvent) {
        guard let liveTitle = sender.title(for: .normal),
              let lower = liveTitle.lowercased().first,
              let current = event.allTouches?.first?.location(in: sender) else { return }
        if settings.flickDownSymbols, page == .letters,
           let start = touchStartPoint,
           current.y - start.y >= 18, abs(current.x - start.x) <= 36,
           let flick = Self.flickCharacters[lower] {
            activeFlickCharacter = flick
            showKeyPreview(for: sender, text: String(flick))
        } else if sender.bounds.insetBy(dx: -16, dy: -16).contains(current) {
            activeFlickCharacter = nil
            showKeyPreview(for: sender, text: liveTitle)
        } else {
            activeFlickCharacter = nil
            hideKeyPreview()
        }
    }

    @objc private func handleCharacterKeyUp(_ sender: UIButton, forEvent event: UIEvent) {
        hideKeyPreview()
        defer {
            touchStartPoint = nil
            activeFlickCharacter = nil
        }
        if let flick = activeFlickCharacter {
            type(flick)
            return
        }
        guard let title = sender.title(for: .normal), let primary = title.first else { return }
        let resolved = resolveTouchedCharacter(primary: primary, button: sender, event: event)
        type(resolved)
    }

    @objc private func handleCharacterTouchUpOutside(_ sender: UIButton, forEvent event: UIEvent) {
        hideKeyPreview()
        defer {
            touchStartPoint = nil
            activeFlickCharacter = nil
        }
        if let flick = activeFlickCharacter {
            type(flick)
        }
    }

    @objc private func handleCharacterTouchCancel(_ sender: UIButton) {
        touchStartPoint = nil
        activeFlickCharacter = nil
        hideKeyPreview()
    }

    /// Orthography-guided touch bias: when a finger lands within the outer 22% horizontal edge of
    /// a letter key, prefer the adjacent key in the same row if the primary key would fail
    /// Vietnamese syllable rules while the neighbor keeps a valid Vietnamese composition.
    private func resolveTouchedCharacter(primary: Character, button: UIButton, event: UIEvent) -> Character {
        guard page == .letters, session.isVietnamese, session.engine.isComposing,
              let touch = event.allTouches?.first,
              let row = button.superview as? UIStackView,
              let idx = row.arrangedSubviews.firstIndex(of: button),
              button.bounds.width > 0 else { return primary }
        let edgeRatio = currentPosture.edgeTouchAssistRatio
        let ratio = Double(touch.location(in: button).x / button.bounds.width)
        let neighborIndex: Int?
        if ratio < edgeRatio, idx > 0 {
            neighborIndex = idx - 1
        } else if ratio > (1.0 - edgeRatio), idx + 1 < row.arrangedSubviews.count {
            neighborIndex = idx + 1
        } else {
            return primary
        }
        guard let nIdx = neighborIndex,
              let neighborButton = row.arrangedSubviews[nIdx] as? UIButton,
              let neighborTitle = neighborButton.title(for: .normal),
              neighborTitle.count == 1, let neighbor = neighborTitle.first, neighbor.isLetter else {
            return primary
        }
        var primaryEngine = session.engine
        _ = primaryEngine.type(primary)
        let primaryValid = primaryEngine.finish()?.vietnamese != nil
        guard !primaryValid else { return primary }

        var neighborEngine = session.engine
        _ = neighborEngine.type(neighbor)
        let neighborValid = neighborEngine.finish()?.vietnamese != nil
        return neighborValid ? neighbor : primary
    }

    private func addRow(spacing: CGFloat = 4) -> UIStackView {
        let row = UIStackView()
        row.distribution = .fillEqually
        row.spacing = spacing
        rows.addArrangedSubview(row)
        return row
    }

    private func addSplitRow(spacing: CGFloat, gapWidth: CGFloat) -> (left: UIStackView, right: UIStackView) {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 0
        container.alignment = .fill
        container.distribution = .fill

        let left = UIStackView()
        left.distribution = .fillEqually
        left.spacing = spacing

        let spacer = UIView()
        spacer.backgroundColor = .clear
        spacer.widthAnchor.constraint(equalToConstant: gapWidth).isActive = true

        let right = UIStackView()
        right.distribution = .fillEqually
        right.spacing = spacing

        container.addArrangedSubview(left)
        container.addArrangedSubview(spacer)
        container.addArrangedSubview(right)
        left.widthAnchor.constraint(equalTo: right.widthAnchor).isActive = true
        rows.addArrangedSubview(container)
        return (left, right)
    }

    private func styledButton(title: String, label: String?, role: KeyRole) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        let fontSize: CGFloat = title.count > 3 ? 15 : (isLandscapeLayout && !isPadLayout ? 19 : 21)
        button.titleLabel?.font = .systemFont(ofSize: fontSize, weight: role == .character ? .regular : .medium)
        switch role {
        case .character:
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = Self.characterKeyFill
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.layer.shadowRadius = 0
            button.layer.shadowOpacity = 0.25
        case .modifier:
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = Self.modifierKeyFill
        case .prominent:
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
        }
        button.layer.cornerRadius = isPadLayout ? 8 : 6
        button.accessibilityLabel = label ?? title
        return button
    }

    private func makeButton(
        _ title: String,
        label: String? = nil,
        role: KeyRole,
        action: @escaping (KeyboardViewController) -> Void
    ) -> UIButton {
        let button = styledButton(title: title, label: label, role: role)
        button.addAction(UIAction { [weak self] _ in
            if let self { action(self) }
        }, for: .touchUpInside)
        return button
    }

    private func makeSymbolButton(
        _ symbolName: String,
        pointSize: CGFloat,
        weight: UIImage.SymbolWeight = .medium,
        label: String,
        role: KeyRole,
        action: @escaping (KeyboardViewController) -> Void
    ) -> UIButton {
        let button = styledButton(title: "", label: label, role: role)
        button.setTitle(nil, for: .normal)
        button.setImage(symbolImage(symbolName, pointSize: pointSize, weight: weight), for: .normal)
        button.tintColor = (role == .prominent) ? .white : .label
        button.addAction(UIAction { [weak self] _ in
            if let self { action(self) }
        }, for: .touchUpInside)
        return button
    }

    @discardableResult
    private func addKey(
        _ title: String,
        label: String? = nil,
        role: KeyRole = .modifier,
        to row: UIStackView,
        action: @escaping (KeyboardViewController) -> Void
    ) -> UIButton {
        let button = makeButton(title, label: label, role: role, action: action)
        row.addArrangedSubview(button)
        return button
    }
}
