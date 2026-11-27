import Foundation
import Observation
import VitekEngine
import VitekSession

/// The user's settings, saved in the input method's defaults. One store per process, shared by the
/// input menu, the settings window and every text field's controller.
@MainActor @Observable
final class SettingsStore {
    static let shared = SettingsStore()

    enum OverlayPlacement: String, CaseIterable, Sendable {
        case notchIsland
        case caret
    }

    struct Shortcut: Identifiable, Equatable {
        let id = UUID()
        var abbreviation: String
        var expansion: String
    }

    static let defaultExcludedBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "org.alacritty",
        "net.kovidgoyal.kitty",
    ]

    private enum Key: String {
        case toneStyle, spellCheck, restoreInvalidWords, standaloneW, quickTelexW, bracketVowels, keepEnglishWords
        case quickStartConsonants, quickEndConsonants, smartTypoRecovery
        case shortcutsEnabled, shortcuts, shortcutsInEnglishMode, editPreviousWord, underlineComposition, showSuggestions
        case vietnameseEnabled, quickToggleOptionDoubleTap, showModeSwitchHUD
        case typingScores, iCloudSyncEnabled, customEnglishWords, excludedBundleIDs
        case overlayPlacement, rememberAppMode, perAppModes, clipboardCopyToast, notchHoverClipboard
        case focusPreferEnglish, focusHideSuggestions
        case personalUnigrams, personalBigrams, personalTrigrams
        case clipboardHistoryEnabled, syncClipboardPinnedICloud, syncClipboardRecentICloud
        case syncPersonalVocabularyICloud, clipboardItems
    }

    var toneStyle: ToneStyle { didSet { save(toneStyle.rawValue, .toneStyle) } }
    var spellCheck: Bool { didSet { save(spellCheck, .spellCheck) } }
    var restoreInvalidWords: Bool { didSet { save(restoreInvalidWords, .restoreInvalidWords) } }
    var standaloneW: Bool { didSet { save(standaloneW, .standaloneW) } }
    var quickTelexW: Bool { didSet { save(quickTelexW, .quickTelexW) } }
    var bracketVowels: Bool { didSet { save(bracketVowels, .bracketVowels) } }
    var quickStartConsonants: Bool { didSet { save(quickStartConsonants, .quickStartConsonants) } }
    var quickEndConsonants: Bool { didSet { save(quickEndConsonants, .quickEndConsonants) } }
    var keepEnglishWords: Bool { didSet { save(keepEnglishWords, .keepEnglishWords) } }
    var smartTypoRecovery: Bool { didSet { save(smartTypoRecovery, .smartTypoRecovery) } }
    /// A mark key typed right after a word edits that word (`viêt` + `j` → việt).
    var editPreviousWord: Bool { didSet { save(editPreviousWord, .editPreviousWord) } }
    /// Show the word being typed as underlined marked text instead of ordinary text.
    var underlineComposition: Bool { didSet { save(underlineComposition, .underlineComposition) } }
    /// Show completions and next-word predictions under the caret.
    var showSuggestions: Bool { didSet { save(showSuggestions, .showSuggestions) } }
    var vietnameseEnabled: Bool { didSet { save(vietnameseEnabled, .vietnameseEnabled, syncCloud: false) } }
    var quickToggleOptionDoubleTap: Bool { didSet { save(quickToggleOptionDoubleTap, .quickToggleOptionDoubleTap, syncCloud: false) } }
    var showModeSwitchHUD: Bool { didSet { save(showModeSwitchHUD, .showModeSwitchHUD, syncCloud: false) } }
    var shortcutsEnabled: Bool { didSet { save(shortcutsEnabled, .shortcutsEnabled) } }
    var shortcutsInEnglishMode: Bool { didSet { save(shortcutsInEnglishMode, .shortcutsInEnglishMode) } }
    var shortcuts: [Shortcut] {
        didSet { save(shortcuts.map { ["abbreviation": $0.abbreviation, "expansion": $0.expansion] }, .shortcuts) }
    }
    var iCloudSyncEnabled: Bool { didSet { save(iCloudSyncEnabled, .iCloudSyncEnabled, syncCloud: false) } }
    var customEnglishWords: [String] { didSet { save(customEnglishWords, .customEnglishWords) } }
    var excludedBundleIDs: [String] {
        didSet {
            excludedBundleIDSet = Set(excludedBundleIDs)
            save(excludedBundleIDs, .excludedBundleIDs, syncCloud: false)
        }
    }
    var focusPreferEnglish: Bool { didSet { save(focusPreferEnglish, .focusPreferEnglish, syncCloud: false) } }
    var focusHideSuggestions: Bool { didSet { save(focusHideSuggestions, .focusHideSuggestions, syncCloud: false) } }
    var clipboardHistoryEnabled: Bool {
        didSet {
            save(clipboardHistoryEnabled, .clipboardHistoryEnabled, syncCloud: false)
            DynamicIslandPanel.updateHoverMonitoring()
        }
    }
    var overlayPlacement: OverlayPlacement { didSet { save(overlayPlacement.rawValue, .overlayPlacement, syncCloud: false) } }
    var rememberAppMode: Bool { didSet { save(rememberAppMode, .rememberAppMode, syncCloud: false) } }
    var clipboardCopyToast: Bool { didSet { save(clipboardCopyToast, .clipboardCopyToast, syncCloud: false) } }
    var notchHoverClipboard: Bool {
        didSet {
            save(notchHoverClipboard, .notchHoverClipboard, syncCloud: false)
            DynamicIslandPanel.updateHoverMonitoring()
        }
    }
    private(set) var perAppModes: [String: Bool]
    var syncClipboardPinnedICloud: Bool { didSet { save(syncClipboardPinnedICloud, .syncClipboardPinnedICloud, syncCloud: false) } }
    var syncClipboardRecentICloud: Bool { didSet { save(syncClipboardRecentICloud, .syncClipboardRecentICloud, syncCloud: false) } }
    var syncPersonalVocabularyICloud: Bool { didSet { save(syncPersonalVocabularyICloud, .syncPersonalVocabularyICloud, syncCloud: false) } }
    var effectiveShowSuggestions: Bool { showSuggestions && !focusHideSuggestions }
    private(set) var personalFrequency: PersonalFrequency
    private(set) var clipboardHistory: ClipboardHistory

    private(set) var typingScores: [String: [String: Int]]

    /// Bumped on every change, so a controller can tell cheaply that it must reload.
    @ObservationIgnored private(set) var revision = 0
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var excludedBundleIDSet: Set<String> = []
    @ObservationIgnored private var personalFlushTask: Task<Void, Never>?
    @ObservationIgnored private var typingScoresFlushTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = EngineOptions()
        func bool(_ key: Key, _ fallback: Bool) -> Bool { defaults.object(forKey: key.rawValue) as? Bool ?? fallback }
        toneStyle = defaults.string(forKey: Key.toneStyle.rawValue).flatMap(ToneStyle.init) ?? fallback.toneStyle
        spellCheck = bool(.spellCheck, fallback.spellCheck)
        restoreInvalidWords = bool(.restoreInvalidWords, fallback.restoreInvalidWords)
        standaloneW = bool(.standaloneW, fallback.standaloneW)
        quickTelexW = bool(.quickTelexW, fallback.quickTelexW)
        bracketVowels = bool(.bracketVowels, fallback.bracketVowels)
        quickStartConsonants = bool(.quickStartConsonants, fallback.quickStartConsonants)
        quickEndConsonants = bool(.quickEndConsonants, fallback.quickEndConsonants)
        keepEnglishWords = bool(.keepEnglishWords, fallback.keepEnglishWords)
        smartTypoRecovery = bool(.smartTypoRecovery, fallback.smartTypoRecovery)
        editPreviousWord = bool(.editPreviousWord, true)
        underlineComposition = bool(.underlineComposition, false)
        showSuggestions = bool(.showSuggestions, false)
        vietnameseEnabled = bool(.vietnameseEnabled, true)
        quickToggleOptionDoubleTap = bool(.quickToggleOptionDoubleTap, true)
        showModeSwitchHUD = bool(.showModeSwitchHUD, true)
        shortcutsEnabled = bool(.shortcutsEnabled, true)
        shortcutsInEnglishMode = bool(.shortcutsInEnglishMode, false)
        let stored = defaults.array(forKey: Key.shortcuts.rawValue) as? [[String: String]] ?? []
        shortcuts = stored.compactMap { entry in
            guard let abbreviation = entry["abbreviation"], let expansion = entry["expansion"] else { return nil }
            return Shortcut(abbreviation: abbreviation, expansion: expansion)
        }
        typingScores = defaults.dictionary(forKey: Key.typingScores.rawValue) as? [String: [String: Int]] ?? [:]
        iCloudSyncEnabled = bool(.iCloudSyncEnabled, true)
        customEnglishWords = defaults.stringArray(forKey: Key.customEnglishWords.rawValue) ?? []
        let initialExcluded = defaults.stringArray(forKey: Key.excludedBundleIDs.rawValue) ?? Self.defaultExcludedBundleIDs
        excludedBundleIDs = initialExcluded
        excludedBundleIDSet = Set(initialExcluded)
        focusPreferEnglish = bool(.focusPreferEnglish, false)
        focusHideSuggestions = bool(.focusHideSuggestions, false)
        clipboardHistoryEnabled = bool(.clipboardHistoryEnabled, true)
        overlayPlacement = defaults.string(forKey: Key.overlayPlacement.rawValue)
            .flatMap(OverlayPlacement.init) ?? .notchIsland
        rememberAppMode = bool(.rememberAppMode, true)
        clipboardCopyToast = bool(.clipboardCopyToast, true)
        notchHoverClipboard = bool(.notchHoverClipboard, true)
        perAppModes = defaults.dictionary(forKey: Key.perAppModes.rawValue) as? [String: Bool] ?? [:]
        syncClipboardPinnedICloud = bool(.syncClipboardPinnedICloud, true)
        syncClipboardRecentICloud = bool(.syncClipboardRecentICloud, false)
        syncPersonalVocabularyICloud = bool(.syncPersonalVocabularyICloud, true)
        let unigrams = defaults.dictionary(forKey: Key.personalUnigrams.rawValue) as? [String: Int] ?? [:]
        let bigrams = defaults.dictionary(forKey: Key.personalBigrams.rawValue) as? [String: Int] ?? [:]
        let trigrams = defaults.dictionary(forKey: Key.personalTrigrams.rawValue) as? [String: Int] ?? [:]
        personalFrequency = PersonalFrequency(unigrams: unigrams, bigrams: bigrams, trigrams: trigrams)
        let savedClipboard = defaults.array(forKey: Key.clipboardItems.rawValue) as? [[String: String]] ?? []
        clipboardHistory = ClipboardHistory(serialized: savedClipboard)
    }

    var engineOptions: EngineOptions {
        EngineOptions(
            automaticallyDetectsMethod: true,
            toneStyle: toneStyle,
            spellCheck: spellCheck,
            restoreInvalidWords: restoreInvalidWords,
            standaloneW: standaloneW,
            bracketVowels: bracketVowels,
            quickStartConsonants: quickStartConsonants,
            quickEndConsonants: quickEndConsonants,
            keepEnglishWords: keepEnglishWords,
            quickTelexW: quickTelexW,
            smartTypoRecovery: smartTypoRecovery,
            customEnglishWords: Set(customEnglishWords.map { $0.lowercased() })
        )
    }

    func effectiveVietnamese(for bundleID: String?) -> Bool {
        if focusPreferEnglish { return false }
        if let bundleID, excludedBundleIDSet.contains(bundleID) { return false }
        if rememberAppMode, let bundleID, let saved = perAppModes[bundleID] {
            return saved
        }
        return vietnameseEnabled
    }

    func setVietnamese(_ enabled: Bool, for bundleID: String?) {
        vietnameseEnabled = enabled
        if rememberAppMode, let bundleID, !excludedBundleIDSet.contains(bundleID) {
            perAppModes[bundleID] = enabled
            defaults.set(perAppModes, forKey: Key.perAppModes.rawValue)
        }
        revision += 1
    }

    func forgetPerAppModes() {
        perAppModes = [:]
        defaults.removeObject(forKey: Key.perAppModes.rawValue)
        revision += 1
    }

    func isExcluded(app bundleID: String?) -> Bool {
        !effectiveVietnamese(for: bundleID)
    }

    nonisolated static func currentMacroTimestamp() -> MacroTimestamp {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        return MacroTimestamp(
            year: c.year ?? 2026,
            month: c.month ?? 1,
            day: c.day ?? 1,
            hour: c.hour ?? 0,
            minute: c.minute ?? 0
        )
    }

    /// The shortcuts the session expands. Rows with an empty side or a space in the abbreviation are
    /// still being edited and do not count; of two rows with the same abbreviation, the lower wins.
    var shortcutTable: Shortcuts {
        guard shortcutsEnabled else { return Shortcuts() }
        var table: [String: String] = [:]
        for shortcut in shortcuts {
            let abbreviation = shortcut.abbreviation.trimmingCharacters(in: .whitespaces)
            guard !abbreviation.isEmpty, !abbreviation.contains(" "), !shortcut.expansion.isEmpty else { continue }
            table[abbreviation.lowercased()] = shortcut.expansion
        }
        return Shortcuts(table, timestampProvider: { SettingsStore.currentMacroTimestamp() })
    }

    func habits(in app: String?) -> TypingHabits {
        let scores = app.flatMap { typingScores[$0] }
        return TypingHabits(telexScore: scores?["telex"] ?? 0, vniScore: scores?["vni"] ?? 0)
    }

    func observe(_ evidence: TypingHabits.Evidence, in app: String?) {
        guard let app else { return }
        let previous = habits(in: app)
        var habits = previous
        habits.observe(evidence)
        guard habits != previous else { return }
        typingScores[app] = ["telex": habits.telexScore, "vni": habits.vniScore]
        guard typingScoresFlushTask == nil else { return }
        typingScoresFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2), tolerance: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.typingScoresFlushTask = nil
            self.defaults.set(self.typingScores, forKey: Key.typingScores.rawValue)
        }
    }

    func forgetTypingHabits() {
        typingScoresFlushTask?.cancel()
        typingScoresFlushTask = nil
        typingScores = [:]
        defaults.removeObject(forKey: Key.typingScores.rawValue)
    }

    func recordPersonalWord(_ word: String, after previous: String? = nil, beforeThat: String? = nil) {
        personalFrequency.record(word: word, after: previous, beforeThat: beforeThat)
        guard personalFlushTask == nil else { return }
        personalFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3), tolerance: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flushPersonalFrequency()
        }
    }

    func flushPersonalFrequency() {
        personalFlushTask?.cancel()
        personalFlushTask = nil
        defaults.set(personalFrequency.unigrams, forKey: Key.personalUnigrams.rawValue)
        defaults.set(personalFrequency.bigrams, forKey: Key.personalBigrams.rawValue)
        defaults.set(personalFrequency.trigrams, forKey: Key.personalTrigrams.rawValue)
        if iCloudSyncEnabled && syncPersonalVocabularyICloud {
            CloudSettingsSync.shared.pushToCloud()
        }
    }

    func forgetPersonalFrequency() {
        personalFlushTask?.cancel()
        personalFlushTask = nil
        personalFrequency.reset()
        defaults.removeObject(forKey: Key.personalUnigrams.rawValue)
        defaults.removeObject(forKey: Key.personalBigrams.rawValue)
        defaults.removeObject(forKey: Key.personalTrigrams.rawValue)
    }

    func mergePersonalFrequencyFromCloud(_ remote: PersonalFrequency) {
        let before = personalFrequency
        personalFrequency.merge(remote)
        guard personalFrequency != before else { return }
        defaults.set(personalFrequency.unigrams, forKey: Key.personalUnigrams.rawValue)
        defaults.set(personalFrequency.bigrams, forKey: Key.personalBigrams.rawValue)
        defaults.set(personalFrequency.trigrams, forKey: Key.personalTrigrams.rawValue)
    }

    // MARK: Clipboard

    @discardableResult
    func recordClipboard(_ text: String, timestamp: Int = Int(Date().timeIntervalSince1970)) -> Bool {
        guard clipboardHistoryEnabled, clipboardHistory.record(text, timestamp: timestamp) else { return false }
        persistClipboard(syncCloud: iCloudSyncEnabled && syncClipboardRecentICloud)
        return true
    }

    func addPinnedClipboard(_ text: String, alias: String = "", timestamp: Int = Int(Date().timeIntervalSince1970)) {
        guard clipboardHistory.addPinned(text, alias: alias, timestamp: timestamp) else { return }
        persistClipboard(syncCloud: iCloudSyncEnabled && syncClipboardPinnedICloud)
    }

    func updateClipboardItem(oldText: String, newText: String, alias: String, isPinned: Bool? = nil) {
        guard clipboardHistory.updateItem(
            oldText: oldText,
            newText: newText,
            alias: alias,
            isPinned: isPinned,
            timestamp: Int(Date().timeIntervalSince1970)
        ) else { return }
        persistClipboard(syncCloud: iCloudSyncEnabled && (syncClipboardPinnedICloud || syncClipboardRecentICloud))
    }

    func movePinnedClipboard(from sourceIndex: Int, to destinationIndex: Int) {
        clipboardHistory.movePinned(from: sourceIndex, to: destinationIndex)
        persistClipboard(syncCloud: iCloudSyncEnabled && syncClipboardPinnedICloud)
    }

    func togglePinClipboard(_ text: String) {
        clipboardHistory.togglePin(text: text)
        persistClipboard(syncCloud: iCloudSyncEnabled && (syncClipboardPinnedICloud || syncClipboardRecentICloud))
    }

    func removeClipboard(_ text: String) {
        clipboardHistory.remove(text: text)
        persistClipboard(syncCloud: false)
    }

    func clearUnpinnedClipboard() {
        clipboardHistory.clearUnpinned()
        persistClipboard(syncCloud: false)
    }

    func clearAllClipboard() {
        clipboardHistory.clearAll()
        persistClipboard(syncCloud: false)
    }

    func mergeClipboardFromCloud(pinned: [[String: String]], recent: [[String: String]]?) {
        let before = clipboardHistory
        clipboardHistory.mergeCloud(pinned: pinned, recent: recent)
        guard clipboardHistory != before else { return }
        defaults.set(clipboardHistory.serialized(), forKey: Key.clipboardItems.rawValue)
    }

    private func persistClipboard(syncCloud: Bool) {
        defaults.set(clipboardHistory.serialized(), forKey: Key.clipboardItems.rawValue)
        revision += 1
        if syncCloud {
            CloudSettingsSync.shared.pushToCloud()
        }
    }

    // MARK: Shortcut files

    var shortcutEntries: [ShortcutEntry] {
        shortcuts.map { ShortcutEntry(abbreviation: $0.abbreviation, expansion: $0.expansion) }
    }

    /// Adds the entries, replacing the expansion of an abbreviation the list already has.
    /// Returns how many were added and how many replaced.
    @discardableResult
    func importShortcuts(_ entries: [ShortcutEntry]) -> (added: Int, replaced: Int) {
        var list = shortcuts
        var added = 0, replaced = 0
        for entry in entries {
            let key = entry.abbreviation.lowercased()
            if let index = list.lastIndex(where: { $0.abbreviation.trimmingCharacters(in: .whitespaces).lowercased() == key }) {
                if list[index].expansion != entry.expansion { replaced += 1 }
                list[index].expansion = entry.expansion
            } else {
                list.append(Shortcut(abbreviation: entry.abbreviation, expansion: entry.expansion))
                added += 1
            }
        }
        shortcuts = list
        return (added, replaced)
    }

    private func save(_ value: Any, _ key: Key, syncCloud: Bool = true) {
        defaults.set(value, forKey: key.rawValue)
        revision += 1
        if syncCloud, iCloudSyncEnabled {
            CloudSettingsSync.shared.pushToCloud()
        }
    }
}
