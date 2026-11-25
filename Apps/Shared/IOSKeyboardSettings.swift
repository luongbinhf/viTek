#if os(iOS)
import Foundation
import Observation
import VitekEngine
import VitekSession

/// Shared preferences between the iOS container app (`viTekMobile`) and the keyboard extension
/// (`viTekKeyboard`) via an Apple App Group container, with graceful fallback to `.standard`.
@MainActor @Observable
final class IOSKeyboardSettings {
    static let appGroupID = "group.io.github.luongbinhf.viTek"
    static let shared = IOSKeyboardSettings()

    enum OneHandedMode: String, Sendable, CaseIterable {
        case full
        case left
        case right
    }

    struct Shortcut: Identifiable, Equatable, Hashable {
        let id = UUID()
        var abbreviation: String
        var expansion: String
    }

    private enum Key: String {
        case toneStyle, spellCheck, restoreInvalidWords, keepEnglishWords
        case quickStartConsonants, quickEndConsonants
        case vietnameseEnabled, shortcutsInEnglishMode
        case oneHandedMode, splitLandscapeKeyboard, flickDownSymbols
        case showSuggestions, hapticFeedback, keyClickSound
        case autoCapitalization, doubleSpacePeriod, showNumberRow
        case shortcutsEnabled, shortcuts, iCloudSyncEnabled, customEnglishWords
        case focusPreferEnglish, focusHideSuggestions
        case personalUnigrams, personalBigrams, personalTrigrams
        case clipboardHistoryEnabled, syncClipboardPinnedICloud, syncClipboardRecentICloud
        case syncPersonalVocabularyICloud, clipboardItems
    }

    var toneStyle: ToneStyle { didSet { save(toneStyle.rawValue, .toneStyle) } }
    var spellCheck: Bool { didSet { save(spellCheck, .spellCheck) } }
    var restoreInvalidWords: Bool { didSet { save(restoreInvalidWords, .restoreInvalidWords) } }
    var quickStartConsonants: Bool { didSet { save(quickStartConsonants, .quickStartConsonants) } }
    var quickEndConsonants: Bool { didSet { save(quickEndConsonants, .quickEndConsonants) } }
    var keepEnglishWords: Bool { didSet { save(keepEnglishWords, .keepEnglishWords) } }
    var vietnameseEnabled: Bool { didSet { save(vietnameseEnabled, .vietnameseEnabled, syncCloud: false) } }
    var shortcutsInEnglishMode: Bool { didSet { save(shortcutsInEnglishMode, .shortcutsInEnglishMode) } }
    var oneHandedMode: OneHandedMode { didSet { save(oneHandedMode.rawValue, .oneHandedMode, syncCloud: false) } }
    var splitLandscapeKeyboard: Bool { didSet { save(splitLandscapeKeyboard, .splitLandscapeKeyboard, syncCloud: false) } }
    var flickDownSymbols: Bool { didSet { save(flickDownSymbols, .flickDownSymbols, syncCloud: false) } }
    var showSuggestions: Bool { didSet { save(showSuggestions, .showSuggestions) } }
    var hapticFeedback: Bool { didSet { save(hapticFeedback, .hapticFeedback) } }
    var keyClickSound: Bool { didSet { save(keyClickSound, .keyClickSound) } }
    var autoCapitalization: Bool { didSet { save(autoCapitalization, .autoCapitalization) } }
    var doubleSpacePeriod: Bool { didSet { save(doubleSpacePeriod, .doubleSpacePeriod) } }
    var showNumberRow: Bool { didSet { save(showNumberRow, .showNumberRow, syncCloud: false) } }
    var shortcutsEnabled: Bool { didSet { save(shortcutsEnabled, .shortcutsEnabled) } }
    var shortcuts: [Shortcut] {
        didSet { save(shortcuts.map { ["abbreviation": $0.abbreviation, "expansion": $0.expansion] }, .shortcuts) }
    }
    var iCloudSyncEnabled: Bool { didSet { save(iCloudSyncEnabled, .iCloudSyncEnabled, syncCloud: false) } }
    var customEnglishWords: [String] { didSet { save(customEnglishWords, .customEnglishWords) } }
    var focusPreferEnglish: Bool { didSet { save(focusPreferEnglish, .focusPreferEnglish, syncCloud: false) } }
    var focusHideSuggestions: Bool { didSet { save(focusHideSuggestions, .focusHideSuggestions, syncCloud: false) } }
    var clipboardHistoryEnabled: Bool { didSet { save(clipboardHistoryEnabled, .clipboardHistoryEnabled, syncCloud: false) } }
    var syncClipboardPinnedICloud: Bool { didSet { save(syncClipboardPinnedICloud, .syncClipboardPinnedICloud, syncCloud: false) } }
    var syncClipboardRecentICloud: Bool { didSet { save(syncClipboardRecentICloud, .syncClipboardRecentICloud, syncCloud: false) } }
    var syncPersonalVocabularyICloud: Bool { didSet { save(syncPersonalVocabularyICloud, .syncPersonalVocabularyICloud, syncCloud: false) } }
    var effectiveShowSuggestions: Bool { showSuggestions && !focusHideSuggestions }
    private(set) var personalFrequency: PersonalFrequency
    private(set) var clipboardHistory: ClipboardHistory

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var personalFlushTask: Task<Void, Never>?

    init(defaults: UserDefaults = UserDefaults(suiteName: IOSKeyboardSettings.appGroupID) ?? .standard) {
        self.defaults = defaults
        let fallback = EngineOptions()
        func bool(_ key: Key, _ defaultValue: Bool) -> Bool {
            defaults.object(forKey: key.rawValue) as? Bool ?? defaultValue
        }
        toneStyle = defaults.string(forKey: Key.toneStyle.rawValue).flatMap(ToneStyle.init) ?? fallback.toneStyle
        spellCheck = bool(.spellCheck, fallback.spellCheck)
        restoreInvalidWords = bool(.restoreInvalidWords, fallback.restoreInvalidWords)
        quickStartConsonants = bool(.quickStartConsonants, fallback.quickStartConsonants)
        quickEndConsonants = bool(.quickEndConsonants, fallback.quickEndConsonants)
        keepEnglishWords = bool(.keepEnglishWords, fallback.keepEnglishWords)
        vietnameseEnabled = bool(.vietnameseEnabled, true)
        shortcutsInEnglishMode = bool(.shortcutsInEnglishMode, false)
        oneHandedMode = defaults.string(forKey: Key.oneHandedMode.rawValue).flatMap(OneHandedMode.init) ?? .full
        splitLandscapeKeyboard = bool(.splitLandscapeKeyboard, true)
        flickDownSymbols = bool(.flickDownSymbols, true)
        showSuggestions = bool(.showSuggestions, true)
        hapticFeedback = bool(.hapticFeedback, true)
        keyClickSound = bool(.keyClickSound, true)
        autoCapitalization = bool(.autoCapitalization, false)
        doubleSpacePeriod = bool(.doubleSpacePeriod, true)
        showNumberRow = bool(.showNumberRow, false)
        shortcutsEnabled = bool(.shortcutsEnabled, true)
        let stored = defaults.array(forKey: Key.shortcuts.rawValue) as? [[String: String]] ?? []
        shortcuts = stored.compactMap { entry in
            guard let abbreviation = entry["abbreviation"], let expansion = entry["expansion"] else { return nil }
            return Shortcut(abbreviation: abbreviation, expansion: expansion)
        }
        iCloudSyncEnabled = bool(.iCloudSyncEnabled, true)
        customEnglishWords = defaults.stringArray(forKey: Key.customEnglishWords.rawValue) ?? []
        focusPreferEnglish = bool(.focusPreferEnglish, false)
        focusHideSuggestions = bool(.focusHideSuggestions, false)
        clipboardHistoryEnabled = bool(.clipboardHistoryEnabled, true)
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
            quickStartConsonants: quickStartConsonants,
            quickEndConsonants: quickEndConsonants,
            keepEnglishWords: keepEnglishWords,
            customEnglishWords: Set(customEnglishWords.map { $0.lowercased() })
        )
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

    var shortcutTable: Shortcuts {
        guard shortcutsEnabled else { return Shortcuts() }
        var table: [String: String] = [:]
        for shortcut in shortcuts {
            let abbreviation = shortcut.abbreviation.trimmingCharacters(in: .whitespaces)
            guard !abbreviation.isEmpty, !abbreviation.contains(" "), !shortcut.expansion.isEmpty else { continue }
            table[abbreviation.lowercased()] = shortcut.expansion
        }
        return Shortcuts(table, timestampProvider: { IOSKeyboardSettings.currentMacroTimestamp() })
    }

    var shortcutEntries: [ShortcutEntry] {
        shortcuts.map { ShortcutEntry(abbreviation: $0.abbreviation, expansion: $0.expansion) }
    }

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

    /// Refreshes values from the shared App Group defaults when the keyboard extension appears.
    func reload() {
        isLoading = true
        defer { isLoading = false }
        let fallback = EngineOptions()
        func bool(_ key: Key, _ defaultValue: Bool) -> Bool {
            defaults.object(forKey: key.rawValue) as? Bool ?? defaultValue
        }
        toneStyle = defaults.string(forKey: Key.toneStyle.rawValue).flatMap(ToneStyle.init) ?? fallback.toneStyle
        spellCheck = bool(.spellCheck, fallback.spellCheck)
        restoreInvalidWords = bool(.restoreInvalidWords, fallback.restoreInvalidWords)
        quickStartConsonants = bool(.quickStartConsonants, fallback.quickStartConsonants)
        quickEndConsonants = bool(.quickEndConsonants, fallback.quickEndConsonants)
        keepEnglishWords = bool(.keepEnglishWords, fallback.keepEnglishWords)
        vietnameseEnabled = bool(.vietnameseEnabled, true)
        shortcutsInEnglishMode = bool(.shortcutsInEnglishMode, false)
        oneHandedMode = defaults.string(forKey: Key.oneHandedMode.rawValue).flatMap(OneHandedMode.init) ?? .full
        splitLandscapeKeyboard = bool(.splitLandscapeKeyboard, true)
        flickDownSymbols = bool(.flickDownSymbols, true)
        showSuggestions = bool(.showSuggestions, true)
        hapticFeedback = bool(.hapticFeedback, true)
        keyClickSound = bool(.keyClickSound, true)
        autoCapitalization = bool(.autoCapitalization, false)
        doubleSpacePeriod = bool(.doubleSpacePeriod, true)
        showNumberRow = bool(.showNumberRow, false)
        shortcutsEnabled = bool(.shortcutsEnabled, true)
        let stored = defaults.array(forKey: Key.shortcuts.rawValue) as? [[String: String]] ?? []
        shortcuts = stored.compactMap { entry in
            guard let abbreviation = entry["abbreviation"], let expansion = entry["expansion"] else { return nil }
            return Shortcut(abbreviation: abbreviation, expansion: expansion)
        }
        iCloudSyncEnabled = bool(.iCloudSyncEnabled, true)
        customEnglishWords = defaults.stringArray(forKey: Key.customEnglishWords.rawValue) ?? []
        focusPreferEnglish = bool(.focusPreferEnglish, false)
        focusHideSuggestions = bool(.focusHideSuggestions, false)
        clipboardHistoryEnabled = bool(.clipboardHistoryEnabled, true)
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

    private func save(_ value: Any, _ key: Key, syncCloud: Bool = true) {
        guard !isLoading else { return }
        defaults.set(value, forKey: key.rawValue)
        if syncCloud, iCloudSyncEnabled {
            NotificationCenter.default.post(name: .vitekLocalSettingsDidChange, object: nil)
        }
    }

    func recordPersonalWord(_ word: String, after previous: String? = nil, beforeThat: String? = nil) {
        personalFrequency.record(word: word, after: previous, beforeThat: beforeThat)
        personalFlushTask?.cancel()
        personalFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
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
            NotificationCenter.default.post(name: .vitekLocalSettingsDidChange, object: nil)
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

    func recordClipboard(_ text: String, timestamp: Int = Int(Date().timeIntervalSince1970)) {
        guard clipboardHistoryEnabled, clipboardHistory.record(text, timestamp: timestamp) else { return }
        persistClipboard(syncCloud: iCloudSyncEnabled && syncClipboardRecentICloud)
    }

    func addPinnedClipboard(_ text: String, timestamp: Int = Int(Date().timeIntervalSince1970)) {
        guard clipboardHistory.addPinned(text, timestamp: timestamp) else { return }
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
        if syncCloud {
            NotificationCenter.default.post(name: .vitekLocalSettingsDidChange, object: nil)
        }
    }
}

extension Notification.Name {
    static let vitekLocalSettingsDidChange = Notification.Name("io.github.luongbinhf.viTek.localSettingsDidChange")
}
#endif
