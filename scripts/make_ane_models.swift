#!/usr/bin/env swift
// Reproducibly trains and compiles viTek's tiny on-device Core ML ANE classifiers from
// project-authored MIT training corpora:
//   1. Apps/Shared/Models/VitekLanguageContext.mlmodelc  ("vi" vs "en" code-switch context)
//   2. Apps/Shared/Models/VitekDomainClassifier.mlmodelc ("technology", "business", "education", "health", "science", "general")
//
// Usage:
//   xcrun swift scripts/make_ane_models.swift

import CoreML
import CreateML
import Foundation
import TabularData

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let modelsDir = root.appendingPathComponent("Apps/Shared/Models", isDirectory: true)
try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

func compileTextClassifier(
    name: String,
    samples: [(text: String, label: String)]
) throws {
    var df = DataFrame()
    df.append(column: Column(name: "text", contents: samples.map(\.text)))
    df.append(column: Column(name: "label", contents: samples.map(\.label)))

    let params = MLTextClassifier.ModelParameters(algorithm: .maxEnt(revision: 1))
    let classifier = try MLTextClassifier(
        trainingData: df,
        textColumn: "text",
        labelColumn: "label",
        parameters: params
    )

    let tempModel = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(name)-\(UUID().uuidString).mlmodel")
    defer { try? FileManager.default.removeItem(at: tempModel) }

    let metadata = MLModelMetadata(
        author: "viTek Contributors",
        shortDescription: "On-device ANE Core ML classifier for \(name) (MIT Open Source)",
        license: "MIT",
        version: "1.0"
    )
    try classifier.write(to: tempModel, metadata: metadata)

    let compiledTemp = try MLModel.compileModel(at: tempModel)
    defer { try? FileManager.default.removeItem(at: compiledTemp) }

    let dest = modelsDir.appendingPathComponent("\(name).mlmodelc", isDirectory: true)
    if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
    }
    try FileManager.default.copyItem(at: compiledTemp, to: dest)
    print("Built \(dest.path)")
}

let languageSamples: [(String, String)] = [
    // Vietnamese (accented & unaccented office/chat/technical Vietnamese)
    ("anh đang họp trên phòng lát gọi lại nhé", "vi"),
    ("gửi bạn báo cáo tài chính quý này để kiểm tra", "vi"),
    ("chúng tôi đang rà soát lại các điều khoản hợp đồng thuê nhà", "vi"),
    ("cảm ơn bạn rất nhiều vì đã hỗ trợ kịp thời", "vi"),
    ("hôm nay thời tiết đẹp mọi người đi làm sớm", "vi"),
    ("cập nhật phiên bản mới cho bộ gõ tiếng Việt trên máy tính", "vi"),
    ("vui lòng chuyển khoản thanh toán hoá đơn theo số tài khoản này", "vi"),
    ("kiểm tra lại danh sách công việc tuần tới trước buổi họp sáng", "vi"),
    ("anh dang hop chut nua nhan lai cho em nhe", "vi"),
    ("nho kiem tra lai bao cao va gui cho khach hang hom nay", "vi"),
    ("chao ban minh gui tai lieu huong dan su dung phan mem", "vi"),
    ("bác sĩ đang khám bệnh và hướng dẫn chế độ dinh dưỡng", "vi"),
    ("sinh viên đại học thực hiện nghiên cứu khoa học và viết luận văn", "vi"),
    ("bảo vệ môi trường và phát triển năng lượng tái tạo bền vững", "vi"),
    ("địa chỉ giao hàng tại tầng mười hai toà nhà trung tâm quận một", "vi"),
    ("mình vừa sửa lỗi hiển thị giao diện bàn phím trên điện thoại", "vi"),
    ("hệ thống cơ sở dữ liệu cần sao lưu định kỳ để bảo mật thông tin", "vi"),
    ("chúc bạn cuối tuần vui vẻ bên gia đình và người thân", "vi"),
    ("xác nhận lịch hẹn phỏng vấn vào chiều thứ sáu tuần này", "vi"),
    ("tối ưu tốc độ xử lý và giảm độ trễ phản hồi trên thiết bị", "vi"),
    // English (engineering, office, email, DevOps, daily English)
    ("please check the server log on production before we deploy", "en"),
    ("run the unit tests and verify zero warnings in continuous integration", "en"),
    ("update the pull request description and merge into main branch", "en"),
    ("configure docker container memory limits and network routing", "en"),
    ("thank you for your feedback we will review the proposal tomorrow", "en"),
    ("schedule a quick team sync meeting this afternoon on zoom", "en"),
    ("set maximum retry count and timeout for the background queue worker", "en"),
    ("the service bus queue reached max capacity under heavy traffic load", "en"),
    ("calculate total tax amount and shipping fee in the checkout box", "en"),
    ("mix the audio tracks and export six channels in raw format", "en"),
    ("we have been working on this feature since early this morning", "en"),
    ("let us see how the new layout renders across browser windows", "en"),
    ("please share the latest design tokens and color palette hex values", "en"),
    ("authentication token expired please sign in again to continue", "en"),
    ("read the documentation carefully before modifying security rules", "en"),
    ("performance benchmark shows lower latency on apple neural engine", "en"),
    ("fix the race condition when switching focus between text fields", "en"),
    ("customer support ticket requires urgent attention from billing team", "en"),
    ("verify sha256 checksum of the release archive before installation", "en"),
    ("all automated checks passed and release artifacts are ready", "en"),
]

let domainSamples: [(String, String)] = [
    // technology
    ("kiểm thử hồi quy mã nguồn hệ thống máy chủ cơ sở dữ liệu và giao diện lập trình", "technology"),
    ("triển khai ứng dụng bảo mật thông tin cấu trúc dữ liệu thuật toán tìm kiếm mạng", "technology"),
    ("tối ưu hiệu năng bộ nhớ đệm xử lý bất đồng bộ trên hệ điều hành", "technology"),
    ("cập nhật phiên bản phần mềm sửa lỗi hiển thị bàn phím và phím tắt hệ thống", "technology"),
    // business
    ("báo cáo tài chính doanh thu thuần lợi nhuận sau thuế và chi phí vận hành", "business"),
    ("điều khoản hợp đồng thuê mặt bằng quản lý dự án chuỗi cung ứng và hóa đơn", "business"),
    ("chuyển khoản ngân hàng thương mại thanh toán công nợ và kế hoạch kinh doanh", "business"),
    ("dịch vụ khách hàng nguồn nhân lực thị trường chứng khoán và quản trị rủi ro", "business"),
    // education
    ("giáo dục đại học chương trình đào tạo phương pháp học tập và luận văn tốt nghiệp", "education"),
    ("học sinh sinh viên nghiên cứu tài liệu tham khảo tư duy phản biện và đánh giá", "education"),
    ("giảng viên hướng dẫn bài giảng kỹ năng giao tiếp và chất lượng giáo dục", "education"),
    // health
    ("chăm sóc sức khỏe khám chữa bệnh tại bệnh viện và điều trị nội trú ngoại trú", "health"),
    ("bác sĩ chẩn đoán triệu chứng lâm sàng xét nghiệm máu bảo hiểm y tế và dinh dưỡng", "health"),
    ("phòng chống dịch bệnh hệ miễn dịch huyết áp nhịp tim và hồ sơ bệnh án", "health"),
    // science
    ("bảo vệ môi trường biến đổi khí hậu năng lượng tái tạo mặt trời và đa dạng sinh học", "science"),
    ("xác suất thống kê phương trình vi phân phân tử hữu cơ dữ liệu thực nghiệm và đo lường", "science"),
    ("nghiên cứu khoa học tài nguyên thiên nhiên phát thải khí nhà kính và chu kỳ tế bào", "science"),
    // general
    ("xin chào cảm ơn bạn rất nhiều hẹn gặp lại vào buổi sáng ngày mai", "general"),
    ("chúc mừng sinh nhật và chúc cuối tuần vui vẻ bên gia đình mọi người", "general"),
    ("hôm nay thời tiết đẹp chúng ta cùng nghỉ ngơi và trò chuyện", "general"),
]

try compileTextClassifier(name: "VitekLanguageContext", samples: languageSamples)
try compileTextClassifier(name: "VitekDomainClassifier", samples: domainSamples)
