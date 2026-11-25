import AppIntents
import Foundation

/// Integrates viTek with Apple Focus modes (e.g. Coding, Work, Gaming) on macOS 14+ and iOS 17+.
/// Users can configure a Focus in System Settings -> Focus -> Focus Filters to automatically
/// switch viTek to English pass-through or hide the suggestion bar while that Focus is active.
@available(macOS 14.0, iOS 17.0, *)
struct VitekFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Chế độ gõ viTek"
    static let description: IntentDescription? = IntentDescription(
        "Tự động tạm chuyển sang gõ tiếng Anh hoặc ẩn thanh gợi ý từ khi bật Chế độ Tập trung."
    )

    @Parameter(title: "Tạm chuyển sang gõ tiếng Anh", default: false)
    var preferEnglishMode: Bool

    @Parameter(title: "Ẩn thanh gợi ý từ", default: false)
    var hideSuggestions: Bool

    var displayRepresentation: DisplayRepresentation {
        var parts: [String] = []
        if preferEnglishMode { parts.append("Gõ tiếng Anh") }
        if hideSuggestions { parts.append("Ẩn gợi ý từ") }
        let subtitle = parts.isEmpty ? "Giữ cài đặt mặc định" : parts.joined(separator: " · ")
        return DisplayRepresentation(title: "Chế độ gõ viTek", subtitle: "\(subtitle)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.apply(preferEnglishMode: preferEnglishMode, hideSuggestions: hideSuggestions)
        return .result()
    }

    @MainActor
    static func refreshCurrent() async {
        if let active = try? await VitekFocusFilter.current {
            apply(preferEnglishMode: active.preferEnglishMode, hideSuggestions: active.hideSuggestions)
        }
    }

    @MainActor
    private static func apply(preferEnglishMode: Bool, hideSuggestions: Bool) {
        #if os(macOS)
        let settings = SettingsStore.shared
        if settings.focusPreferEnglish != preferEnglishMode {
            settings.focusPreferEnglish = preferEnglishMode
        }
        if settings.focusHideSuggestions != hideSuggestions {
            settings.focusHideSuggestions = hideSuggestions
        }
        #elseif os(iOS)
        let settings = IOSKeyboardSettings.shared
        if settings.focusPreferEnglish != preferEnglishMode {
            settings.focusPreferEnglish = preferEnglishMode
        }
        if settings.focusHideSuggestions != hideSuggestions {
            settings.focusHideSuggestions = hideSuggestions
        }
        #endif
    }
}
