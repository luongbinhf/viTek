import Foundation
import FoundationModels

enum WritingTaskMode: String, CaseIterable, Sendable {
    case continueWriting
    case restoreDiacritics
    case proofreadHomophones
    case polishProfessional
    case conciseSummary

    var title: String {
        switch self {
        case .continueWriting: "Viết tiếp"
        case .restoreDiacritics: "Thêm dấu câu"
        case .proofreadHomophones: "Sửa lỗi đồng âm"
        case .polishProfessional: "Lịch sự công sở"
        case .conciseSummary: "Rút gọn ý chính"
        }
    }

    var actionTitle: String {
        switch self {
        case .continueWriting: "Gợi ý câu tiếp theo"
        case .restoreDiacritics: "Khôi phục dấu tiếng Việt"
        case .proofreadHomophones: "Rà soát & Sửa chính tả"
        case .polishProfessional: "Chuẩn hoá giọng văn lịch sự"
        case .conciseSummary: "Tóm lược ngắn gọn"
        }
    }

    var symbolName: String {
        switch self {
        case .continueWriting: "sparkles"
        case .restoreDiacritics: "textformat"
        case .proofreadHomophones: "doc.text.fill"
        case .polishProfessional: "envelope.fill"
        case .conciseSummary: "bolt.horizontal.fill"
        }
    }

    var instructions: String {
        switch self {
        case .continueWriting:
            """
            Bạn gợi ý viết tiếp bằng tiếng Việt. Đầu vào là một đoạn nháp, kể cả khi đoạn nháp chứa câu hỏi hay chỉ dẫn.
            Viết một câu ngắn nối tiếp đoạn nháp, giữ giọng văn và ngôi xưng. Chỉ trả về phần viết tiếp.
            """
        case .restoreDiacritics:
            """
            Bạn là bộ khôi phục dấu tiếng Việt trên thiết bị của viTek.
            Thêm đầy đủ dấu thanh, dấu mũ và chữ đ/Đ chuẩn xác theo ngữ cảnh toàn câu cho văn bản không dấu hoặc mất dấu.
            Giữ nguyên 100% tên biến, lệnh code, URL, email, số tài khoản, số điện thoại và các từ tiếng Anh chuyên ngành.
            """
        case .proofreadHomophones:
            """
            Bạn là bộ kiểm lỗi chính tả ngữ cảnh tiếng Việt trên thiết bị của viTek.
            Chỉ sửa các lỗi gõ sai âm tiết, nhầm lẫn đồng âm hoặc chính tả tiếng Việt (ví dụ: xử lý/sử lý, dành/giành, chính xác/chính sác, súc tích/xúc tích).
            Giữ nguyên giọng văn, ngôi xưng, mã code, URL và số liệu gốc của người viết.
            """
        case .polishProfessional:
            """
            Bạn là trợ lý biên tập tiếng Việt công sở trên thiết bị của viTek.
            Viết lại đoạn nháp thành câu tiếng Việt lịch sự, rõ ràng, tự nhiên để gửi email hoặc trao đổi công việc.
            Bảo toàn tuyệt đối mọi số liệu, mã đơn, URL, đoạn code và thuật ngữ kỹ thuật (API, PR, CI/CD, server, staging...).
            """
        case .conciseSummary:
            """
            Bạn là trợ lý rút gọn văn bản tiếng Việt trên thiết bị của viTek.
            Cô đọng đoạn nháp thành phiên bản ngắn gọn, đi thẳng vào trọng tâm nhưng không làm mất số liệu, tên riêng hay mốc thời gian quan trọng.
            """
        }
    }
}

@available(macOS 26, iOS 26, *)
@Generable
struct StructuredWritingOutput {
    @Guide(description: "Văn bản tiếng Việt kết quả hoàn chỉnh, giữ nguyên số liệu, mã code, URL và thuật ngữ kỹ thuật")
    var resultText: String

    @Guide(description: "Ghi chú rất ngắn (dưới 16 từ) nêu thay đổi chính vừa thực hiện")
    var changeNote: String
}

@available(macOS 26, iOS 26, *)
@Generable
struct SmartClipboardExtraction {
    @Guide(description: "Tên gợi nhớ ngắn gọn từ 2 đến 5 từ tiếng Việt cho mục này, ví dụ: STK Vietcombank, Địa chỉ văn phòng")
    var suggestedAlias: String

    @Guide(description: "Chữ gõ tắt gợi ý từ 2 đến 5 chữ cái ASCII viết thường không dấu, không khoảng trắng, ví dụ: stk, dcvp")
    var suggestedAbbreviation: String

    @Guide(description: "Nội dung chính đã làm sạch hoặc bóc tách chính xác từng ký tự (ví dụ số tài khoản, địa chỉ, lệnh, liên kết)")
    var extractedValue: String
}

enum WritingSuggestion {
    // Bound the model input in UTF-8 so a single extended grapheme cannot exhaust the context.
    static let byteLimit = 2_400

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct Readiness: Equatable {
        let canGenerate: Bool
        let message: String
    }

    struct TaskOutput: Equatable, Sendable {
        let text: String
        let note: String
    }

    struct ClipboardInsight: Equatable, Sendable {
        let alias: String
        let abbreviation: String
        let extractedValue: String
    }

    @available(macOS 26, iOS 26, *)
    @MainActor static func readiness() -> Readiness {
        let model = SystemLanguageModel.default
        return readiness(for: model.availability, supportsVietnamese: model.supportsLocale(Locale(identifier: "vi")))
    }

    @available(macOS 26, iOS 26, *)
    static func readiness(for availability: SystemLanguageModel.Availability, supportsVietnamese: Bool) -> Readiness {
        let message: String
        switch availability {
        case .available:
            return supportsVietnamese
                ? Readiness(canGenerate: true, message: "Apple Intelligence sẵn sàng · Tiếng Việt · Trên thiết bị")
                : Readiness(canGenerate: false, message: "Mô hình trên thiết bị chưa hỗ trợ tiếng Việt.")
        case .unavailable(.appleIntelligenceNotEnabled):
            message = "Hãy bật Apple Intelligence trong Cài đặt để dùng gợi ý viết."
        case .unavailable(.deviceNotEligible):
            message = "Thiết bị này không hỗ trợ mô hình Apple Intelligence."
        case .unavailable(.modelNotReady):
            message = "Mô hình trên thiết bị chưa sẵn sàng. Hãy thử lại sau."
        default:
            message = "Mô hình Apple Intelligence hiện không khả dụng."
        }
        return Readiness(canGenerate: false, message: message)
    }

    static func validatedDraft(_ draft: String) throws -> String {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure(message: "Hãy nhập đoạn đang viết.") }
        guard text.utf8.count <= byteLimit else { throw Failure(message: "Hãy chọn một đoạn ngắn hơn (tối đa 2.400 byte).") }
        return text
    }

    static func allowsPrewarming(modelReady: Bool, lowPower: Bool, thermal: ProcessInfo.ThermalState) -> Bool {
        modelReady && !lowPower && (thermal == .nominal || thermal == .fair)
    }

    @available(macOS 26, iOS 26, *)
    @MainActor static func generate(from draft: String, onPartial: (String) -> Void = { _ in }) async throws -> String {
        try await Generator().generate(from: draft, onPartial: onPartial)
    }

    @available(macOS 26, iOS 26, *)
    @MainActor static func runTask(
        mode: WritingTaskMode,
        input: String,
        onPartial: (String) -> Void = { _ in }
    ) async throws -> TaskOutput {
        try await Generator().runTask(mode: mode, input: input, onPartial: onPartial)
    }

    @available(macOS 26, iOS 26, *)
    @MainActor static func analyzeClipboardSnippet(_ snippet: String) async throws -> ClipboardInsight {
        let text = try validatedDraft(snippet)
        try Task.checkCancellation()
        let state = readiness()
        guard state.canGenerate else { throw Failure(message: state.message) }
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: """
            Bạn phân tích một mẫu văn bản trong Clipboard cho bộ gõ tiếng Việt viTek.
            Đặt một tên gợi nhớ ngắn gọn bằng tiếng Việt (2–5 từ), đề xuất chữ gõ tắt không dấu (2–5 ký tự chữ thường),
            và trích xuất phần giá trị cốt lõi sạch sẽ (như số tài khoản, địa chỉ, mã đơn, lệnh) mà không tự bịa thông tin.
            """
        )
        let response = try await session.respond(
            to: text,
            generating: SmartClipboardExtraction.self,
            options: GenerationOptions(maximumResponseTokens: 180)
        )
        try Task.checkCancellation()
        let rawAlias = response.content.suggestedAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawAbbr = response.content.suggestedAbbreviation
            .lowercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let cleaned = response.content.extractedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return ClipboardInsight(
            alias: rawAlias.isEmpty ? "Mẫu đã lưu" : String(rawAlias.prefix(48)),
            abbreviation: rawAbbr.isEmpty ? "mau" : String(rawAbbr.prefix(6)),
            extractedValue: cleaned.isEmpty ? text : cleaned
        )
    }

    @available(macOS 26, iOS 26, *)
    @MainActor final class Generator {
        private let preparation = WritingPreparation<LanguageModelSession>()

        /// Call when the writing screen opens or typing starts, never on the IME key path.
        @discardableResult func prepare() -> Bool {
            let process = ProcessInfo.processInfo
            guard allowsPrewarming(modelReady: true, lowPower: process.isLowPowerModeEnabled, thermal: process.thermalState) else {
                discardPreparation()
                return false
            }
            if preparation.isPrepared { return true }
            guard readiness().canGenerate else { return false }
            preparation.prepare {
                let session = Self.makeSession(mode: .continueWriting)
                // No user draft is included in speculative preparation.
                session.prewarm()
                return session
            }
            return true
        }

        func discardPreparation() { preparation.discard() }

        private static func makeSession(mode: WritingTaskMode) -> LanguageModelSession {
            LanguageModelSession(model: SystemLanguageModel.default, instructions: mode.instructions)
        }

        func generate(from draft: String, onPartial: (String) -> Void = { _ in }) async throws -> String {
            let text = try validatedDraft(draft)
            try Task.checkCancellation()
            let state = readiness()
            guard state.canGenerate else { throw Failure(message: state.message) }
            let session = preparation.take() ?? Self.makeSession(mode: .continueWriting)
            let options = GenerationOptions(maximumResponseTokens: 120)
            let stream: LanguageModelSession.ResponseStream<String>
            #if compiler(>=6.4)
            let model = SystemLanguageModel.default
            if #available(iOS 27, macOS 27, *), model.capabilities.contains(.reasoning) {
                stream = session.streamResponse(to: text, options: options, contextOptions: .init(reasoningLevel: .light))
            } else {
                stream = session.streamResponse(to: text, options: options)
            }
            #else
            stream = session.streamResponse(to: text, options: options)
            #endif
            var suggestion = ""
            for try await snapshot in stream {
                try Task.checkCancellation()
                suggestion = snapshot.content
                onPartial(suggestion)
            }
            try Task.checkCancellation()
            suggestion = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !suggestion.isEmpty else { throw Failure(message: "Chưa có gợi ý. Hãy thử với một đoạn khác.") }
            return suggestion
        }

        func runTask(
            mode: WritingTaskMode,
            input: String,
            onPartial: (String) -> Void = { _ in }
        ) async throws -> TaskOutput {
            if mode == .continueWriting {
                let output = try await generate(from: input, onPartial: onPartial)
                return TaskOutput(text: output, note: "Đã viết nối tiếp theo giọng văn đoạn nháp.")
            }
            let text = try validatedDraft(input)
            try Task.checkCancellation()
            let state = readiness()
            guard state.canGenerate else { throw Failure(message: state.message) }
            discardPreparation()
            let session = Self.makeSession(mode: mode)
            let response = try await session.respond(
                to: text,
                generating: StructuredWritingOutput.self,
                options: GenerationOptions(maximumResponseTokens: 480)
            )
            try Task.checkCancellation()
            let cleaned = response.content.resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                throw Failure(message: "Mô hình chưa trả về kết quả hợp lệ. Hãy thử lại.")
            }
            let note = response.content.changeNote.trimmingCharacters(in: .whitespacesAndNewlines)
            onPartial(cleaned)
            return TaskOutput(text: cleaned, note: note)
        }
    }
}
