import Foundation
import VitekEngine
import VitekSession

/// Synchronizes typing options, shortcut tables, exception words, pinned/recent clipboard snippets,
/// and learned personal vocabulary across macOS and iOS via Apple's `NSUbiquitousKeyValueStore`.
@MainActor
final class CloudSettingsSync {
    static let shared = CloudSettingsSync()

    private enum CloudKey {
        static let updatedAt = "viTek.sync.updatedAt"
        static let toneStyle = "viTek.sync.toneStyle"
        static let spellCheck = "viTek.sync.spellCheck"
        static let restoreInvalidWords = "viTek.sync.restoreInvalidWords"
        static let quickStartConsonants = "viTek.sync.quickStartConsonants"
        static let quickEndConsonants = "viTek.sync.quickEndConsonants"
        static let keepEnglishWords = "viTek.sync.keepEnglishWords"
        static let shortcutsEnabled = "viTek.sync.shortcutsEnabled"
        static let shortcutsInEnglishMode = "viTek.sync.shortcutsInEnglishMode"
        static let shortcuts = "viTek.sync.shortcuts"
        static let customEnglishWords = "viTek.sync.customEnglishWords"
        static let pinnedClipboard = "viTek.sync.pinnedClipboard"
        static let recentClipboard = "viTek.sync.recentClipboard"
        static let personalUnigrams = "viTek.sync.personalUnigrams"
        static let personalBigrams = "viTek.sync.personalBigrams"
        static let personalTrigrams = "viTek.sync.personalTrigrams"
    }

    private let store = NSUbiquitousKeyValueStore.default
    private var started = false
    private var isApplyingRemote = false
    private var lastAppliedTimestamp: Double = 0
    private var observers: [NSObjectProtocol] = []
    private var pendingPushTask: Task<Void, Never>?

    func start() {
        guard !started else { return }
        started = true
        let external = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pullFromCloud() }
        }
        observers.append(external)

        #if os(iOS)
        let local = NotificationCenter.default.addObserver(
            forName: .vitekLocalSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pushToCloud() }
        }
        observers.append(local)
        #endif

        store.synchronize()
        pullFromCloud()
    }

    func syncNow() {
        pendingPushTask?.cancel()
        pendingPushTask = nil
        store.synchronize()
        pullFromCloud()
        pushToCloudImmediately()
    }

    /// Debounces rapid edits to keep typing & UI snappy.
    func pushToCloud() {
        guard !isApplyingRemote else { return }
        pendingPushTask?.cancel()
        pendingPushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            self?.pushToCloudImmediately()
        }
    }

    private func pushToCloudImmediately() {
        guard !isApplyingRemote else { return }
        #if os(macOS)
        let settings = SettingsStore.shared
        #elseif os(iOS)
        let settings = IOSKeyboardSettings.shared
        #endif
        guard settings.iCloudSyncEnabled else { return }
        let shortcuts = settings.shortcuts.map { ["abbreviation": $0.abbreviation, "expansion": $0.expansion] }
        write(
            toneStyle: settings.toneStyle,
            spellCheck: settings.spellCheck,
            restoreInvalidWords: settings.restoreInvalidWords,
            quickStartConsonants: settings.quickStartConsonants,
            quickEndConsonants: settings.quickEndConsonants,
            keepEnglishWords: settings.keepEnglishWords,
            shortcutsEnabled: settings.shortcutsEnabled,
            shortcutsInEnglishMode: settings.shortcutsInEnglishMode,
            shortcuts: shortcuts,
            customEnglishWords: settings.customEnglishWords,
            pinnedClipboard: settings.syncClipboardPinnedICloud ? settings.clipboardHistory.cloudPinnedSerialized() : nil,
            recentClipboard: settings.syncClipboardRecentICloud ? settings.clipboardHistory.cloudRecentSerialized(limit: 10) : nil,
            personalVocabulary: settings.syncPersonalVocabularyICloud ? settings.personalFrequency.cloudSnapshot(limit: 180) : nil
        )
    }

    private func write(
        toneStyle: ToneStyle,
        spellCheck: Bool,
        restoreInvalidWords: Bool,
        quickStartConsonants: Bool,
        quickEndConsonants: Bool,
        keepEnglishWords: Bool,
        shortcutsEnabled: Bool,
        shortcutsInEnglishMode: Bool,
        shortcuts: [[String: String]],
        customEnglishWords: [String],
        pinnedClipboard: [[String: String]]?,
        recentClipboard: [[String: String]]?,
        personalVocabulary: (unigrams: [String: Int], bigrams: [String: Int], trigrams: [String: Int])?
    ) {
        let now = Date().timeIntervalSince1970
        lastAppliedTimestamp = now
        store.set(toneStyle.rawValue, forKey: CloudKey.toneStyle)
        store.set(spellCheck, forKey: CloudKey.spellCheck)
        store.set(restoreInvalidWords, forKey: CloudKey.restoreInvalidWords)
        store.set(quickStartConsonants, forKey: CloudKey.quickStartConsonants)
        store.set(quickEndConsonants, forKey: CloudKey.quickEndConsonants)
        store.set(keepEnglishWords, forKey: CloudKey.keepEnglishWords)
        store.set(shortcutsEnabled, forKey: CloudKey.shortcutsEnabled)
        store.set(shortcutsInEnglishMode, forKey: CloudKey.shortcutsInEnglishMode)
        store.set(shortcuts, forKey: CloudKey.shortcuts)
        store.set(customEnglishWords, forKey: CloudKey.customEnglishWords)
        if let pinnedClipboard {
            store.set(pinnedClipboard, forKey: CloudKey.pinnedClipboard)
        }
        if let recentClipboard {
            store.set(recentClipboard, forKey: CloudKey.recentClipboard)
        }
        if let personalVocabulary {
            store.set(personalVocabulary.unigrams, forKey: CloudKey.personalUnigrams)
            store.set(personalVocabulary.bigrams, forKey: CloudKey.personalBigrams)
            store.set(personalVocabulary.trigrams, forKey: CloudKey.personalTrigrams)
        }
        store.set(now, forKey: CloudKey.updatedAt)
        store.synchronize()
    }

    func pullFromCloud() {
        let remoteTimestamp = store.double(forKey: CloudKey.updatedAt)
        guard remoteTimestamp > 0, remoteTimestamp > lastAppliedTimestamp else { return }

        #if os(macOS)
        let settings = SettingsStore.shared
        #elseif os(iOS)
        let settings = IOSKeyboardSettings.shared
        #endif
        guard settings.iCloudSyncEnabled else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        lastAppliedTimestamp = remoteTimestamp

        if let rawTone = store.string(forKey: CloudKey.toneStyle), let tone = ToneStyle(rawValue: rawTone) {
            settings.toneStyle = tone
        }
        if store.object(forKey: CloudKey.spellCheck) != nil {
            settings.spellCheck = store.bool(forKey: CloudKey.spellCheck)
        }
        if store.object(forKey: CloudKey.restoreInvalidWords) != nil {
            settings.restoreInvalidWords = store.bool(forKey: CloudKey.restoreInvalidWords)
        }
        if store.object(forKey: CloudKey.quickStartConsonants) != nil {
            settings.quickStartConsonants = store.bool(forKey: CloudKey.quickStartConsonants)
        }
        if store.object(forKey: CloudKey.quickEndConsonants) != nil {
            settings.quickEndConsonants = store.bool(forKey: CloudKey.quickEndConsonants)
        }
        if store.object(forKey: CloudKey.keepEnglishWords) != nil {
            settings.keepEnglishWords = store.bool(forKey: CloudKey.keepEnglishWords)
        }
        if store.object(forKey: CloudKey.shortcutsEnabled) != nil {
            settings.shortcutsEnabled = store.bool(forKey: CloudKey.shortcutsEnabled)
        }
        if store.object(forKey: CloudKey.shortcutsInEnglishMode) != nil {
            settings.shortcutsInEnglishMode = store.bool(forKey: CloudKey.shortcutsInEnglishMode)
        }
        if let rawShortcuts = store.array(forKey: CloudKey.shortcuts) as? [[String: String]] {
            let incoming = rawShortcuts.compactMap { entry -> ShortcutEntry? in
                guard let abbreviation = entry["abbreviation"], let expansion = entry["expansion"] else { return nil }
                return ShortcutEntry(abbreviation: abbreviation, expansion: expansion)
            }
            settings.importShortcuts(incoming)
        }
        if let customWords = store.array(forKey: CloudKey.customEnglishWords) as? [String] {
            settings.customEnglishWords = Self.mergeWords(local: settings.customEnglishWords, remote: customWords)
        }

        let remotePinned = settings.syncClipboardPinnedICloud
            ? (store.array(forKey: CloudKey.pinnedClipboard) as? [[String: String]] ?? [])
            : []
        let remoteRecent = settings.syncClipboardRecentICloud
            ? (store.array(forKey: CloudKey.recentClipboard) as? [[String: String]])
            : nil
        if !remotePinned.isEmpty || remoteRecent != nil {
            settings.mergeClipboardFromCloud(pinned: remotePinned, recent: remoteRecent)
        }

        if settings.syncPersonalVocabularyICloud {
            let u = store.dictionary(forKey: CloudKey.personalUnigrams) as? [String: Int] ?? [:]
            let b = store.dictionary(forKey: CloudKey.personalBigrams) as? [String: Int] ?? [:]
            let t = store.dictionary(forKey: CloudKey.personalTrigrams) as? [String: Int] ?? [:]
            if !u.isEmpty || !b.isEmpty || !t.isEmpty {
                settings.mergePersonalFrequencyFromCloud(PersonalFrequency(unigrams: u, bigrams: b, trigrams: t))
            }
        }
    }

    private static func mergeWords(local: [String], remote: [String]) -> [String] {
        var result = local
        var seen = Set(local.map { $0.lowercased() })
        for word in remote {
            let lower = word.lowercased()
            if seen.insert(lower).inserted {
                result.append(word)
            }
        }
        return result
    }
}
