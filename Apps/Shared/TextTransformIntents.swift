import AppIntents
import VitekSession

@available(macOS 14.0, iOS 17.0, *)
enum VietnameseTransformKind: String, AppEnum {
    case autoToUnicode
    case normalizeNFC
    case stripAccents
    case vniWindowsToUnicode
    case tcvn3ToUnicode
    case titleCase

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Kiểu chuyển đổi tiếng Việt")
    static let caseDisplayRepresentations: [VietnameseTransformKind: DisplayRepresentation] = [
        .autoToUnicode: "Tự động sửa lỗi font → Unicode",
        .normalizeNFC: "Chuẩn hoá Unicode dựng sẵn (NFC)",
        .stripAccents: "Bỏ dấu tiếng Việt",
        .vniWindowsToUnicode: "VNI Windows → Unicode",
        .tcvn3ToUnicode: "TCVN3 (ABC) → Unicode",
        .titleCase: "Viết Hoa Đầu Từ",
    ]

    var engineMode: TextConverter.LegacyEncoding {
        switch self {
        case .autoToUnicode: .autoToUnicode
        case .normalizeNFC: .nfdToNFC
        case .stripAccents: .stripAccents
        case .vniWindowsToUnicode: .vniWindows
        case .tcvn3ToUnicode: .tcvn3
        case .titleCase: .titleCase
        }
    }
}

@available(macOS 14.0, iOS 17.0, *)
struct ConvertVietnameseTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Chuyển mã & Chuẩn hoá tiếng Việt"
    static let description = IntentDescription("Chuẩn hoá Unicode NFC, bỏ dấu tiếng Việt, hoặc chuyển mã VNI Windows / TCVN3 sang Unicode.")

    @Parameter(title: "Văn bản")
    var text: String

    @Parameter(title: "Thao tác", default: .normalizeNFC)
    var kind: VietnameseTransformKind

    static var parameterSummary: some ParameterSummary {
        Summary("Chuyển \(\.$text) sang \(\.$kind)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: TextConverter.convert(text, mode: kind.engineMode))
    }
}

@available(macOS 14.0, iOS 17.0, *)
struct StripVietnameseAccentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Bỏ dấu tiếng Việt"
    static let description = IntentDescription("Loại bỏ dấu thanh, dấu mũ và chữ đ/Đ trong văn bản tiếng Việt, giữ nguyên chữ hoa/thường.")

    @Parameter(title: "Văn bản")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Bỏ dấu \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: TextConverter.stripVietnameseAccents(text))
    }
}

@available(macOS 26.0, iOS 26.0, *)
struct RestoreVietnameseDiacriticsIntent: AppIntent {
    static let title: LocalizedStringResource = "Khôi phục dấu tiếng Việt bằng AI"
    static let description = IntentDescription("Thêm lại đầy đủ dấu tiếng Việt theo ngữ cảnh toàn câu bằng mô hình Apple Intelligence cục bộ trên thiết bị.")

    @Parameter(title: "Văn bản không dấu")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Khôi phục dấu tiếng Việt cho \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try await WritingSuggestion.runTask(mode: .restoreDiacritics, input: text)
        return .result(value: output.text)
    }
}

@available(macOS 26.0, iOS 26.0, *)
struct ProofreadVietnameseIntent: AppIntent {
    static let title: LocalizedStringResource = "Sửa chính tả tiếng Việt bằng AI"
    static let description = IntentDescription("Rà soát và sửa lỗi chính tả đồng âm tiếng Việt trên thiết bị mà vẫn giữ nguyên ý nghĩa, code và số liệu.")

    @Parameter(title: "Văn bản cần kiểm tra")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Sửa chính tả tiếng Việt cho \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try await WritingSuggestion.runTask(mode: .proofreadHomophones, input: text)
        return .result(value: output.text)
    }
}
