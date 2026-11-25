import AppKit
import Carbon
import InputMethodKit
import VitekEngine
import VitekSession

/// IMK guarantees callbacks on the main thread. The box crosses only the synchronous
/// assumeIsolated trampoline; no client or NSEvent is sent to a worker task.
private struct IMKCallback<Value>: @unchecked Sendable { let value: Value }

/// Main-thread IMK adapter. DocumentSession owns verified committed edits and native fallback.
/// No synthetic Backspace, global key tap, or Accessibility permission is needed for typing.
@MainActor @objc(VitekInputController)
final class VitekInputController: IMKInputController {
    private var document = DocumentSession()
    private var commandPress = CommandPressGate()
    private var session: InputSession {
        get { document.session }
        set { document.session = newValue }
    }
    private var loadedRevision = -1
    private weak var activeClient: AnyObject?
    private var isEditing = false
    private var pendingCommit = false
    private var pendingCommitIsHostRequest = false
    private let settings = SettingsStore.shared
    /// Read between words, like the engine options, to keep composition styling consistent.
    private var underlines = false
    private var suggestions: [WordCandidate] = []
    /// The suggestions complete the word being typed, rather than predict the next one.
    private var suggestionsComplete = false
    /// What viTek has seen typed into this field since the caret last jumped: the context for
    /// suggestions in clients that cannot read their text back (Chromium, Electron).
    private var typedContext = ""
    /// Chromium suggestion positioning retains the Accessibility path measured for these clients;
    /// that tree catches up after the app's next frame, so suggestions wait for typing to pause.
    private var caretHidden = false
    private var suggestionTask: Task<Void, Never>?
    private var suggestionCaret: Int?
    private var suggestionRequests = SuggestionRequest()
    private var suggestionTicket: SuggestionRequest.Ticket?
    private var optionDownAlone = false
    private var lastSoloOptionRelease: ContinuousClock.Instant?

    nonisolated override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown]).rawValue)
    }

    nonisolated override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        let callback = IMKCallback(value: (self, sender))
        MainActor.assumeIsolated { callback.value.0.activate(callback.value.1) }
    }

    private func activate(_ sender: Any?) {
        commandPress.reset(to: CommandModifierMonitor.shared.snapshot.generation)
        hideSuggestions()
        guard !isEditing else { pendingCommit = true; pendingCommitIsHostRequest = false; return }
        document.resetForFocusChange()
        loadSettings()
        guard let client = sender as? IMKTextInput else { return Diagnostics.log("activate: no client") }
        activeClient = client as AnyObject
        applyAppLanguage(for: client.bundleIdentifier())
        caretHidden = AppCompatibility.isChromium(client.bundleIdentifier())
        typedContext = ""
        Diagnostics.log("activate \(client.bundleIdentifier() ?? "?") transactionalInput=true "
                        + "caretHidden=\(caretHidden) caret=\(client.selectedRange())")
    }

    nonisolated override func deactivateServer(_ sender: Any!) {
        let callback = IMKCallback(value: (self, sender))
        MainActor.assumeIsolated {
            Diagnostics.log("deactivate")
            callback.value.0.commit(to: callback.value.1)
            callback.value.0.hideSuggestions()
            callback.value.0.activeClient = nil
            callback.value.0.typedContext = ""
        }
        super.deactivateServer(sender)
    }

    nonisolated override func commitComposition(_ sender: Any!) {
        let callback = IMKCallback(value: (self, sender))
        MainActor.assumeIsolated {
            Diagnostics.log("commitComposition request")
            callback.value.0.commit(to: callback.value.1, hostRequest: true)
            callback.value.0.hideSuggestions()
            callback.value.0.typedContext = ""
        }
    }

    nonisolated override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        let callback = IMKCallback(value: (self, event, sender))
        return MainActor.assumeIsolated { callback.value.0.handleEvent(callback.value.1, sender: callback.value.2) }
    }

    private func handleEvent(_ event: NSEvent?, sender: Any?) -> Bool {
        guard let event, let client = sender as? IMKTextInput, !isEditing else { return false }
        isEditing = true
        defer {
            isEditing = false
            if pendingCommit {
                let hostRequest = pendingCommitIsHostRequest
                pendingCommit = false
                pendingCommitIsHostRequest = false
                commit(to: sender, hostRequest: hostRequest)
            }
        }
        if activeClient !== (client as AnyObject) {
            document.resetForFocusChange()
            activeClient = client as AnyObject
            applyAppLanguage(for: client.bundleIdentifier())
            caretHidden = AppCompatibility.isChromium(client.bundleIdentifier())
            typedContext = ""
            hideSuggestions()
        }
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            commit(to: sender)
            hideSuggestions()
            typedContext = ""
            return false
        }
        if event.type == .flagsChanged {
            handleOptionDoubleTap(event, sender: sender, client: client)
            // Commit before Chromium classifies the shortcut keyDown. Consume the
            // actual press once, even when it was released before this callback.
            let press = CommandModifierMonitor.shared.snapshot(at: event.timestamp)
            let isCommandDown = KeyMap.endsCompositionBeforeShortcut(for: event, commandIsCurrentlyDown: true)
            let fresh = press.available ? commandPress.consumeIf(isCommandDown, generation: press.generation)
                : KeyMap.endsCompositionBeforeShortcut(for: event,
                    commandIsCurrentlyDown: CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand))
            if fresh {
                _ = document.handle(.boundary, client: adapter(client))
                hideSuggestions()
                typedContext = ""
            }
            return false
        }
        guard event.type == .keyDown else { return false }
        optionDownAlone = false
        // Ordinary text callbacks can lag behind the tap, even with renewed IMK
        // timestamps. They must not consume the next Command press.
        commandPress.recordKey(command: event.modifierFlags.contains(.command),
                               generation: CommandModifierMonitor.shared.snapshot(at: event.timestamp).generation)
        let intact = document.reconcile(with: adapter(client))
        if !intact { hideSuggestions(); typedContext = "" }
        if acceptSuggestion(for: event, client: client) { return true }
        // Pressing Escape while composing a word with Vietnamese marks immediately restores
        // the raw typed keys in place instead of committing the marked text.
        if event.keyCode == 0x35,
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           session.engine.isComposing,
           session.engine.composition != session.engine.rawKeys {
            let raw = session.engine.rawKeys
            if document.accept(raw, client: adapter(client)) {
                hideSuggestions()
                typedContext += raw
                return true
            }
        }
        if !session.engine.isComposing {
            loadSettings()
            applyAppLanguage(for: client.bundleIdentifier())
            session.engine.habits = settings.habits(in: client.bundleIdentifier())
        }
        let hostEvent = KeyMap.hostEvent(for: event)
        Diagnostics.log("before client=\(ObjectIdentifier(client as AnyObject).hashValue) "
                        + "caret=\(client.selectedRange()) marked=\(client.markedRange()) \(document.debugDescription)")
        if intact, case .character(let key) = hostEvent, settings.editPreviousWord,
           !session.engine.isComposing, session.engine.options.isMarkKey(key) {
            resumeWord(before: client)
        }
        let output = document.handle(hostEvent, client: adapter(client))
        recordTypingEvidence(in: client)
        Diagnostics.log("edit \(output.commands.map(Self.describe)) pass=\(output.passThrough) "
                        + "transactionalInput=true caret=\(client.selectedRange()) \(document.debugDescription)")
        remember(hostEvent, output)
        if case .boundary = hostEvent { hideSuggestions() }
        else { scheduleSuggestions() }
        return !output.passThrough
    }

    /// Keeps `typedContext` in step with what reached the field: committed words, and the spaces and
    /// punctuation passed through. A key that moves the caret starts it over.
    private func remember(_ event: HostEvent, _ output: SessionOutput) {
        for case .insert(let text) in output.commands { typedContext += text }
        guard output.passThrough else { return }
        switch event {
        case .character(let key): typedContext.append(key)
        case .backspace: if !typedContext.isEmpty { typedContext.removeLast() }
        case .boundary: typedContext = ""
        }
        if typedContext.count > WordPrediction.contextLimit {
            typedContext = String(typedContext.suffix(WordPrediction.contextLimit))
        }
    }

    /// Picks up changes from the input menu or the settings window, between words only, so a
    /// setting never changes how the word being typed reads.
    private func applyAppLanguage(for bundleID: String?) {
        let vietnamese = !settings.isExcluded(app: bundleID)
        _ = session.setVietnamese(vietnamese)
    }

    private func loadSettings() {
        guard loadedRevision != settings.revision else { return }
        loadedRevision = settings.revision
        session.engine.options = settings.engineOptions
        session.shortcuts = settings.shortcutTable
        session.shortcutsInEnglishMode = settings.shortcutsInEnglishMode
        underlines = settings.underlineComposition
    }

    private func handleOptionDoubleTap(_ event: NSEvent, sender: Any?, client: IMKTextInput) {
        guard settings.quickToggleOptionDoubleTap, event.keyCode == 58 || event.keyCode == 61 else {
            optionDownAlone = false
            return
        }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if mods == .option {
            optionDownAlone = true
        } else if mods.isEmpty, optionDownAlone {
            optionDownAlone = false
            let now = ContinuousClock.now
            if let last = lastSoloOptionRelease, last.duration(to: now) <= .milliseconds(380) {
                lastSoloOptionRelease = nil
                _ = document.handle(.boundary, client: adapter(client))
                hideSuggestions()
                typedContext = ""
                settings.vietnameseEnabled.toggle()
                applyAppLanguage(for: client.bundleIdentifier())
                if settings.showModeSwitchHUD {
                    ModeIndicatorPanel.show(vietnamese: settings.vietnameseEnabled, caret: clientCaretRect(client))
                }
            } else {
                lastSoloOptionRelease = now
            }
        } else {
            optionDownAlone = false
        }
    }

    /// Resumes the verified word right before the caret, so a mark key edits it
    /// (`viêt` then `j` → việt). Does nothing unless the client reports its text consistently: the
    /// caret is a plain insertion point, the word ends at the caret and is not followed by a letter,
    /// and reading the word's own range gives the same word back.
    private func resumeWord(before client: IMKTextInput) {
        let caret = client.selectedRange()
        guard caret.location != NSNotFound, caret.length == 0, caret.location > 0 else { return }
        let lookBack = min(caret.location, 16)
        guard let before = client.attributedSubstring(from: NSRange(location: caret.location - lookBack, length: lookBack))?
                .string, (before as NSString).length == lookBack
        else { return }
        let word = String(before.reversed().prefix(while: \.isLetter).reversed())
        let length = (word as NSString).length
        // A word that fills the whole look-back may start further left; leave it alone.
        guard length > 0, length < lookBack || lookBack == caret.location else { return }
        if let next = client.attributedSubstring(from: NSRange(location: caret.location, length: 1))?.string,
           next.first?.isLetter == true {
            return
        }
        let range = NSRange(location: caret.location - length, length: length)
        guard let verifiedRange = DocumentRange(range.location, range.length) else { return }
        _ = document.resume(word, range: verifiedRange, client: adapter(client))
    }

    /// The caret as a plain insertion point, or nil when the client has a selection or cannot tell.
    private func insertionPoint(of client: IMKTextInput) -> Int? {
        let selection = client.selectedRange()
        guard selection.location >= 0, selection.location != NSNotFound, selection.length == 0 else { return nil }
        return selection.location
    }

    private func recordTypingEvidence(in client: IMKTextInput) {
        if let evidence = session.engine.takeTypingEvidence() {
            settings.observe(evidence, in: client.bundleIdentifier())
        }
    }

    private func clientCaretRect(_ client: IMKTextInput) -> NSRect {
        let selection = client.selectedRange()
        let index = selection.location == NSNotFound ? 0 : selection.location
        var actual = NSRange(location: NSNotFound, length: 0)
        let atCaret = client.firstRect(forCharacterRange: NSRange(location: index, length: 0), actualRange: &actual)
        if Self.isOnScreen(atCaret) { return atCaret }
        if index > 0 {
            let before = client.firstRect(forCharacterRange: NSRange(location: index - 1, length: 1), actualRange: &actual)
            if Self.isOnScreen(before) { return NSRect(x: before.maxX, y: before.minY, width: 0, height: before.height) }
        }
        var line = NSRect.zero
        _ = client.attributes(forCharacterIndex: max(index - 1, 0), lineHeightRectangle: &line)
        return Self.isOnScreen(line) ? line : .zero
    }

    /// A believable line box: finite, a sensible height, on one of the screens.
    private static func isOnScreen(_ rect: NSRect) -> Bool {
        guard rect.origin.x.isFinite, rect.origin.y.isFinite, rect.height > 1, rect.height < 400 else { return false }
        return NSScreen.screens.contains { $0.frame.insetBy(dx: -40, dy: -40).contains(rect.origin) }
    }

    private func commit(to sender: Any!, hostRequest: Bool = false) {
        guard let client = sender as? IMKTextInput, activeClient === (client as AnyObject) else { return }
        guard !isEditing else {
            pendingCommitIsHostRequest = pendingCommit ? pendingCommitIsHostRequest && hostRequest : hostRequest
            pendingCommit = true
            return
        }
        isEditing = true
        Diagnostics.log("commit hostRequest=\(hostRequest) caret=\(client.selectedRange()) marked=\(client.markedRange()) \(document.debugDescription)")
        if hostRequest { document.commitComposition(client: adapter(client)) }
        else { document.interrupt(client: adapter(client)) }
        isEditing = false
        pendingCommit = false
        pendingCommitIsHostRequest = false
    }

    @MainActor private func adapter(_ client: any IMKTextInput) -> IMKDocumentClient {
        IMKDocumentClient(client: client, styledText: { self.markedText($0) })
    }

    /// A command without its text, for `Diagnostics`.
    private static func describe(_ command: HostCommand) -> String {
        switch command {
        case .insert(let text): "insert(\(text.utf16.count))"
        case .mark(let text): "mark(\(text.utf16.count))"
        }
    }

    /// IMK transports the clause highlight separately from the AppKit underline.
    private func markedText(_ text: String) -> NSAttributedString {
        if !underlines {
            return NSAttributedString(string: text, attributes: [
                .markedClauseSegment: kTSMHiliteNoHilite,
                .underlineStyle: caretHidden ? NSUnderlineStyle.single.rawValue : 0,
                .underlineColor: NSColor.clear
            ])
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        let style = mark(forStyle: kTSMHiliteConvertedText, at: range) as? [NSAttributedString.Key: Any] ?? [:]
        return NSAttributedString(string: text, attributes: style)
    }

    // MARK: Suggestions

    /// Only the latest key may publish a bar. IMK and panel access stay on the main thread,
    /// while the two workers receive only values and never hold an IMK client.
    private func scheduleSuggestions() {
        hideSuggestions()
        guard settings.effectiveShowSuggestions, session.isVietnamese else { return }
        perform(#selector(startSuggestionTask), with: nil, afterDelay: caretHidden ? 0.12 : 0)
    }

    // IMK schedules this selector on its main run loop after the key reaches the client.
    @MainActor @objc private func startSuggestionTask() {
        suggestionTask = Task(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            await self?.updateSuggestions()
        }
    }

    @MainActor private func updateSuggestions() async {
        guard let client = client(), activeClient === (client as AnyObject),
              let snapshot = suggestionSnapshot(client) else { return }
        let caret = snapshot.caret
        let ticket = suggestionRequests.begin(snapshot)
        let prefix = session.engine.isComposing ? session.engine.composition : ""
        // The field's own text when it can be read back and ends with the word being typed;
        // otherwise what viTek typed into it.
        var context = typedContext + prefix
        let readBack = snapshot.context
        if let text = readBack, !text.isEmpty, text.hasSuffix(prefix) {
            context = text
        }
        Diagnostics.log("suggest: prefix=\(prefix.count) readBack=\(readBack.map { "\($0.count)" } ?? "nil") "
                        + "context=\(context.count) endsWithSpace=\(context.last?.isWhitespace == true)")
        guard prefix.isEmpty ? context.last?.isWhitespace == true && context.count > 1 : !context.isEmpty
        else { return hideSuggestions() }
        let personal = settings.personalFrequency
        let words = await WordCompletions.shared.words(context: context, prefix: prefix, personal: personal)
        #if DEBUG
        await Diagnostics.delaySuggestionDelivery()
        #endif
        Diagnostics.log("suggest: completed candidates=\(words.count) cancelled=\(Task.isCancelled)")
        guard !Task.isCancelled, !words.isEmpty else { return }
        let line: NSRect
        if caretHidden {
            let bundleID = client.bundleIdentifier()
            var position = await AccessibilityCaret.rect(inAppWith: bundleID)
            if case .waitingForFocus = position, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                position = await AccessibilityCaret.rect(inAppWith: bundleID)
            }
            guard case .found(let rect) = position, Self.isOnScreen(rect) else { return }
            line = rect
        } else {
            line = clientCaretRect(client)
        }
        guard !Task.isCancelled, line != .zero, settings.effectiveShowSuggestions,
              activeClient === (client as AnyObject),
              let current = suggestionSnapshot(client),
              suggestionRequests.isCurrent(ticket, snapshot: current) else { return }
        let next = client.attributedSubstring(from: NSRange(location: caret, length: 1))?.string ?? ""
        suggestions = words
        suggestionsComplete = !prefix.isEmpty
        suggestionCaret = caret
        suggestionTicket = ticket
        SuggestionPanel.show(
            words.map(\.text),
            completing: suggestionsComplete,
            caret: line,
            inline: next.isEmpty || next == "\n" || next == "\r",
            fromAccessibility: caretHidden,
            onSelect: { [weak self] index in
                self?.commitSuggestion(at: index)
            }
        )
    }

    private func hideSuggestions() {
        suggestionRequests.invalidate()
        suggestionTicket = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startSuggestionTask), object: nil)
        suggestionTask?.cancel()
        suggestionTask = nil
        guard !suggestions.isEmpty else { return }
        suggestions = []
        suggestionCaret = nil
        SuggestionPanel.hide()
    }

    private func suggestionSnapshot(_ client: IMKTextInput) -> SuggestionRequest.Snapshot? {
        guard let caret = insertionPoint(of: client) else { return nil }
        let count = min(caret, WordPrediction.contextLimit)
        let text = client.attributedSubstring(from: NSRange(location: caret - count, length: count))?.string
        return .init(client: ObjectIdentifier(client as AnyObject), caret: caret,
                     prefix: session.engine.isComposing ? session.engine.composition : "",
                     context: text?.utf16.count == count ? text : nil)
    }

    /// Explicit shortcuts (`⌥1`–`⌥5`) or clicking the non-activating suggestion bar accept candidates;
    /// Tab always belongs to the host application.
    private func acceptSuggestion(for event: NSEvent, client: IMKTextInput) -> Bool {
        guard !suggestions.isEmpty, settings.effectiveShowSuggestions, session.isVietnamese else { return false }
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let digits: [UInt16] = [0x12, 0x13, 0x14, 0x15, 0x17]
        let index: Int
        if flags == .option, let digit = digits.firstIndex(of: event.keyCode) {
            index = digit
        } else {
            if event.keyCode == 0x35 { hideSuggestions() }
            return false
        }
        return commitSuggestion(at: index, explicitClient: client)
    }

    @discardableResult
    private func commitSuggestion(at index: Int, explicitClient: IMKTextInput? = nil) -> Bool {
        guard suggestions.indices.contains(index),
              let targetClient = explicitClient ?? (activeClient as? IMKTextInput),
              activeClient === (targetClient as AnyObject),
              let ticket = suggestionTicket, let snapshot = suggestionSnapshot(targetClient),
              suggestionRequests.isCurrent(ticket, snapshot: snapshot) else {
            hideSuggestions()
            return false
        }
        let candidate = suggestions[index]
        let text = candidate.insertion
        guard document.accept(text, client: adapter(targetClient)) else {
            hideSuggestions()
            return false
        }
        let prev = typedContext.split(whereSeparator: \.isWhitespace).last.map(String.init)
        settings.recordPersonalWord(candidate.text, after: prev)
        typedContext += text
        scheduleSuggestions()
        return true
    }

    // MARK: Input menu

    /// Rebuilt every time the menu opens, so the check marks follow the settings.
    nonisolated override func menu() -> NSMenu! {
        let owner = IMKCallback(value: self)
        return MainActor.assumeIsolated { IMKCallback(value: owner.value.makeMenu()) }.value
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let modeTitle = settings.vietnameseEnabled ? "Gõ tiếng Việt (nhấn đúp ⌥ để chuyển EN)" : "Đang tạm chuyển tiếng Anh (nhấn đúp ⌥ để bật VI)"
        menu.addItem(item(modeTitle, #selector(toggleVietnameseEnabled(_:)), on: settings.vietnameseEnabled))
        menu.addItem(.separator())
        menu.addItem(item("Đặt dấu kiểu mới (hoà, thuý)", #selector(toggleToneStyle(_:)),
                          on: settings.toneStyle == .modern))
        menu.addItem(item("Kiểm tra chính tả", #selector(toggleSpellCheck(_:)), on: settings.spellCheck))
        menu.addItem(item("Gõ tắt", #selector(toggleShortcuts(_:)), on: settings.shortcutsEnabled))
        menu.addItem(item("Gợi ý từ", #selector(toggleSuggestions(_:)), on: settings.showSuggestions))
        menu.addItem(.separator())
        menu.addItem(makeClipboardSubmenuItem())
        menu.addItem(.separator())
        if #available(macOS 26, *) {
            menu.addItem(item("Gợi ý viết…", #selector(showWriting(_:)), on: false))
        }
        menu.addItem(item("Hướng dẫn nhanh…", #selector(showGuide(_:)), on: false))
        menu.addItem(item("Cài đặt viTek…", #selector(showPreferences(_:)), on: false))
        return menu
    }

    private func makeClipboardSubmenuItem() -> NSMenuItem {
        let submenu = NSMenu(title: "Công cụ Clipboard")
        func subItem(_ title: String, _ action: Selector) -> NSMenuItem {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            return entry
        }
        submenu.addItem(subItem("Tự động sửa lỗi font → Unicode", #selector(autoConvertClipboard(_:))))
        submenu.addItem(subItem("Chuẩn hoá Unicode dựng sẵn (NFC)", #selector(normalizeClipboardNFC(_:))))
        submenu.addItem(subItem("Bỏ dấu tiếng Việt", #selector(stripClipboardAccents(_:))))
        submenu.addItem(.separator())
        submenu.addItem(subItem("Chuyển mã VNI Windows → Unicode", #selector(convertClipboardVNI(_:))))
        submenu.addItem(subItem("Chuyển mã TCVN3 (ABC) → Unicode", #selector(convertClipboardTCVN3(_:))))
        submenu.addItem(.separator())
        submenu.addItem(subItem("CHỮ HOA TIẾNG VIỆT", #selector(uppercaseClipboard(_:))))
        submenu.addItem(subItem("chữ thường tiếng việt", #selector(lowercaseClipboard(_:))))
        submenu.addItem(subItem("Viết Hoa Đầu Từ", #selector(titleCaseClipboard(_:))))
        let root = NSMenuItem(title: "Công cụ Clipboard", action: nil, keyEquivalent: "")
        root.submenu = submenu
        return root
    }

    private func transformClipboard(using mode: TextConverter.LegacyEncoding) {
        let pasteboard = NSPasteboard.general
        guard let current = pasteboard.string(forType: .string), !current.isEmpty else { return }
        let converted = TextConverter.convert(current, mode: mode)
        pasteboard.clearContents()
        pasteboard.setString(converted, forType: .string)
    }

    @objc private func autoConvertClipboard(_ sender: Any?) { transformClipboard(using: .autoToUnicode) }
    @objc private func normalizeClipboardNFC(_ sender: Any?) { transformClipboard(using: .nfdToNFC) }
    @objc private func stripClipboardAccents(_ sender: Any?) { transformClipboard(using: .stripAccents) }
    @objc private func convertClipboardVNI(_ sender: Any?) { transformClipboard(using: .vniWindows) }
    @objc private func convertClipboardTCVN3(_ sender: Any?) { transformClipboard(using: .tcvn3) }
    @objc private func uppercaseClipboard(_ sender: Any?) { transformClipboard(using: .uppercase) }
    @objc private func lowercaseClipboard(_ sender: Any?) { transformClipboard(using: .lowercase) }
    @objc private func titleCaseClipboard(_ sender: Any?) { transformClipboard(using: .titleCase) }

    private func item(_ title: String, _ action: Selector, on: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.state = on ? .on : .off
        return item
    }

    @objc private func toggleVietnameseEnabled(_ sender: Any?) {
        settings.vietnameseEnabled.toggle()
        if !settings.vietnameseEnabled { hideSuggestions() }
        if settings.showModeSwitchHUD {
            ModeIndicatorPanel.show(vietnamese: settings.vietnameseEnabled, caret: .zero)
        }
    }
    @objc private func toggleToneStyle(_ sender: Any?) {
        settings.toneStyle = settings.toneStyle == .modern ? .traditional : .modern
    }
    @objc private func toggleSpellCheck(_ sender: Any?) { settings.spellCheck.toggle() }
    @objc private func toggleShortcuts(_ sender: Any?) { settings.shortcutsEnabled.toggle() }
    @objc private func toggleSuggestions(_ sender: Any?) {
        settings.showSuggestions.toggle()
        if !settings.showSuggestions { hideSuggestions() }
    }

    @available(macOS 26, *)
    @objc private func showWriting(_ sender: Any?) {
        var draft = ""
        if let client = client() {
            let selection = client.selectedRange()
            if selection.location != NSNotFound, (1...WritingSuggestion.byteLimit).contains(selection.length),
               let selected = client.attributedSubstring(from: selection)?.string, selected.utf16.count == selection.length {
                draft = selected
            }
        }
        WritingWindow.show(draft: draft)
    }

    nonisolated override func showPreferences(_ sender: Any!) {
        MainActor.assumeIsolated { SettingsWindow.show() }
    }

    @objc private func showGuide(_ sender: Any?) {
        SettingsWindow.show(page: .welcome)
    }
}

