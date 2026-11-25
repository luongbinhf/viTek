import AppIntents

@available(macOS 26, iOS 26, *)
struct ContinueWritingIntent: AppIntent {
    static let title: LocalizedStringResource = "Gợi ý viết bằng viTek"
    static let description = IntentDescription("Nhận một câu tiếng Việt nối tiếp đoạn nháp bằng mô hình trên thiết bị.")

    @Parameter(title: "Đoạn đang viết")
    var draft: String

    static var parameterSummary: some ParameterSummary { Summary("Viết tiếp \(\.$draft)") }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let suggestion = try await WritingSuggestion.generate(from: draft)
        return .result(value: suggestion)
    }
}
