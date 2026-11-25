import AppIntents

@available(macOS 26, iOS 26, *)
struct OpenWritingIntent: AppIntent {
    static let title: LocalizedStringResource = "Mở Gợi ý viết"
    static let description = IntentDescription("Mở viTek để soạn tiếng Việt và xem gợi ý trực tiếp.")
    static let openAppWhenRun = true

    @MainActor func perform() async throws -> some IntentResult {
        WritingRoute.shared.open()
        return .result()
    }
}

@available(macOS 26, iOS 26, *)
struct WritingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenWritingIntent(), phrases: [
            "Mở gợi ý viết trong \(.applicationName)", "Open writing in \(.applicationName)"
        ], shortTitle: "Mở Gợi ý viết", systemImageName: "square.and.pencil")
        AppShortcut(intent: ContinueWritingIntent(), phrases: [
            "Viết tiếp với \(.applicationName)", "Continue writing with \(.applicationName)"
        ], shortTitle: "Gợi ý câu tiếp theo", systemImageName: "text.append")
        AppShortcut(intent: ConvertVietnameseTextIntent(), phrases: [
            "Chuẩn hoá tiếng Việt bằng \(.applicationName)", "Normalize Vietnamese with \(.applicationName)"
        ], shortTitle: "Chuyển mã tiếng Việt", systemImageName: "character.textbox")
        AppShortcut(intent: StripVietnameseAccentsIntent(), phrases: [
            "Bỏ dấu tiếng Việt bằng \(.applicationName)", "Strip Vietnamese accents with \(.applicationName)"
        ], shortTitle: "Bỏ dấu tiếng Việt", systemImageName: "textformat.abc")
    }
}
