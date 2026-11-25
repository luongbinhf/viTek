import Foundation
import VitekEngine
import VitekSession

/// Synchronizes typing options, shortcut tables, and personal exception words across macOS and iOS
/// using Apple's `NSUbiquitousKeyValueStore`. Uses debounced writes to avoid blocking the main
/// thread during rapid edits, and union-merges shortcuts/custom words on pull to prevent offline
/// additions on another device from being overwritten.
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

    /// Debounces rapid setting edits (e.g. typing in shortcut fields) to keep the main thread snappy.
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
            customEnglishWords: settings.customEnglishWords
        )
        #elseif os(iOS)
        let settings = IOSKeyboardSettings.shared
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
            customEnglishWords: settings.customEnglishWords
        )
        #endif
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
        customEnglishWords: [String]
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
        store.set(now, forKey: CloudKey.updatedAt)
        store.synchronize()
    }

    func pullFromCloud() {
        let remoteTimestamp = store.double(forKey: CloudKey.updatedAt)
        guard remoteTimestamp > 0, remoteTimestamp > lastAppliedTimestamp else { return }

        #if os(macOS)
        let settings = SettingsStore.shared
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
        #elseif os(iOS)
        let settings = IOSKeyboardSettings.shared
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
        #endif
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
