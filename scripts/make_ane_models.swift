#!/usr/bin/env swift
// Reproducibly trains and compiles viTek's tiny on-device Core ML ANE classifiers from
// 260 project-authored MIT training samples:
//   1. Apps/Shared/Models/VitekLanguageContext.mlmodelc  ("vi" vs "en" code-switch context — 140 samples)
//   2. Apps/Shared/Models/VitekDomainClassifier.mlmodelc ("technology", "business", "education", "health", "science", "general" — 120 samples)
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
        shortDescription: "On-device ANE Core ML classifier for \(name) (MIT Open Source, \(samples.count) samples)",
        license: "MIT",
        version: "1.1"
    )
    try classifier.write(to: tempModel, metadata: metadata)

    let compiledTemp = try MLModel.compileModel(at: tempModel)
    defer { try? FileManager.default.removeItem(at: compiledTemp) }

    let dest = modelsDir.appendingPathComponent("\(name).mlmodelc", isDirectory: true)
    if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
    }
    try FileManager.default.copyItem(at: compiledTemp, to: dest)
    print("Built \(dest.path) (\(samples.count) training samples)")
}

let languageSamples: [(String, String)] = [
    // Vietnamese — accented office, technical, academic, medical, daily chat (50 samples)
    ("anh đang họp trên phòng lát gọi lại nhé", "vi"),
    ("gửi bạn báo cáo tài chính quý này để kiểm tra", "vi"),
    ("chúng tôi đang rà soát lại các điều khoản hợp đồng thuê nhà", "vi"),
    ("cảm ơn bạn rất nhiều vì đã hỗ trợ kịp thời", "vi"),
    ("hôm nay thời tiết đẹp mọi người đi làm sớm", "vi"),
    ("cập nhật phiên bản mới cho bộ gõ tiếng Việt trên máy tính", "vi"),
    ("vui lòng chuyển khoản thanh toán hoá đơn theo số tài khoản này", "vi"),
    ("kiểm tra lại danh sách công việc tuần tới trước buổi họp sáng", "vi"),
    ("bác sĩ đang khám bệnh và hướng dẫn chế độ dinh dưỡng", "vi"),
    ("sinh viên đại học thực hiện nghiên cứu khoa học và viết luận văn", "vi"),
    ("bảo vệ môi trường và phát triển năng lượng tái tạo bền vững", "vi"),
    ("địa chỉ giao hàng tại tầng mười hai toà nhà trung tâm quận một", "vi"),
    ("mình vừa sửa lỗi hiển thị giao diện bàn phím trên điện thoại", "vi"),
    ("hệ thống cơ sở dữ liệu cần sao lưu định kỳ để bảo mật thông tin", "vi"),
    ("chúc bạn cuối tuần vui vẻ bên gia đình và người thân", "vi"),
    ("xác nhận lịch hẹn phỏng vấn vào chiều thứ sáu tuần này", "vi"),
    ("tối ưu tốc độ xử lý và giảm độ trễ phản hồi trên thiết bị", "vi"),
    ("nhờ anh xem giúp bản thiết kế giao diện trang chủ mới", "vi"),
    ("đơn hàng của quý khách đang được vận chuyển đến bưu cục gần nhất", "vi"),
    ("chương trình đào tạo kỹ sư phần mềm chất lượng cao tại trường", "vi"),
    ("hội đồng quản trị phê duyệt kế hoạch đầu tư mở rộng nhà máy", "vi"),
    ("kết quả xét nghiệm máu cho thấy các chỉ số sức khoẻ bình thường", "vi"),
    ("thời gian bảo hành sản phẩm chính hãng là hai mươi tư tháng", "vi"),
    ("vấn đề này cần thảo luận kỹ hơn với bộ phận pháp chế", "vi"),
    ("mọi dữ liệu cá nhân đều được xử lý trực tiếp ngay trên máy", "vi"),
    ("bạn nhớ mang theo căn cước công dân khi làm thủ tục đăng ký", "vi"),
    ("tài liệu hướng dẫn cài đặt đã được đính kèm trong thư điện tử", "vi"),
    ("chúng ta nên ưu tiên giải quyết các lỗi ảnh hưởng đến người dùng", "vi"),
    ("buổi hội thảo chuyên đề trí tuệ nhân tạo diễn ra vào sáng mai", "vi"),
    ("phần mềm tự động nhận diện kiểu gõ và giữ nguyên từ tiếng Anh", "vi"),
    ("em gửi lại bảng tổng hợp chi phí công tác tháng mười một", "vi"),
    ("hợp đồng lao động có hiệu lực kể từ ngày ký kết chính thức", "vi"),
    ("ngân hàng nhà nước công bố điều chỉnh lãi suất tiền gửi tiết kiệm", "vi"),
    ("trường đại học bách khoa tổ chức ngày hội việc làm cho sinh viên", "vi"),
    ("bệnh viện đa khoa triển khai hồ sơ bệnh án điện tử toàn diện", "vi"),
    ("dự án giao thông đô thị giúp giảm ùn tắc vào giờ cao điểm", "vi"),
    ("anh chị vui lòng phản hồi trước năm giờ chiều hôm nay nhé", "vi"),
    ("mình đang trên đường tới văn phòng khoảng mười phút nữa có mặt", "vi"),
    ("công nghệ xử lý ngôn ngữ tự nhiên hỗ trợ khôi phục dấu chính xác", "vi"),
    ("trân trọng cảm ơn sự hợp tác quý báu của quý đối tác", "vi"),
    ("tối nay cả nhóm đi ăn tối ở quán quen gần công ty nhé", "vi"),
    ("kiến trúc phần mềm tách biệt hoàn toàn giữa nhân xử lý và giao diện", "vi"),
    ("nghiên cứu ứng dụng vật liệu bán dẫn thế hệ mới trong công nghiệp", "vi"),
    ("kế toán trưởng đã đối chiếu công nợ và xuất hoá đơn điện tử", "vi"),
    ("học sinh trung học phổ thông chuẩn bị ôn tập cho kỳ thi quốc gia", "vi"),
    ("chế độ ngủ đủ giấc và tập thể dục giúp tăng cường đề kháng", "vi"),
    ("mẫu văn bản đã ghim được đồng bộ an toàn giữa điện thoại và máy tính", "vi"),
    ("nhấn tổ hợp phím tắt để mở nhanh bảng công cụ ngay tại con trỏ", "vi"),
    ("tốc độ phản hồi từng phím bấm luôn nằm dưới ngưỡng năm mươi micro giây", "vi"),
    ("hẹn gặp lại mọi người trong buổi tổng kết cuối năm của công ty", "vi"),
    // Vietnamese — unaccented chat, SMS, quick notes (20 samples)
    ("anh dang hop chut nua nhan lai cho em nhe", "vi"),
    ("nho kiem tra lai bao cao va gui cho khach hang hom nay", "vi"),
    ("chao ban minh gui tai lieu huong dan su dung phan mem", "vi"),
    ("cam on anh chi da ho tro xu ly nhanh van de nay", "vi"),
    ("chieu nay ba gio hop nhom du an tai phong hop tang nam", "vi"),
    ("vui long chuyen khoan thanh toan hoa don truoc ngay mai", "vi"),
    ("em vua cap nhat lai bang gia va danh sach san pham moi", "vi"),
    ("toi nay ranh khong di uong ca phe noi chuyen chut nhe", "vi"),
    (" nho xem giup minh doan van ban nay co sai chinh ta khong", "vi"),
    ("he thong dang bao tri dinh ky se hoat dong lai sau muoi phut", "vi"),
    ("xin chao quy khach don hang da duoc xac nhan thanh cong", "vi"),
    ("minh dang o san bay chuan bi len chuyen bay luc tam gio", "vi"),
    ("cap nhat phien ban moi nhat de sua loi hien thi tren man hinh", "vi"),
    ("gui ban so tai khoan ngan hang de tien doi chieu cong no", "vi"),
    ("chuc mung sinh nhat chuc ban luon manh khoe va thanh cong", "vi"),
    ("tai khoan cua ban da duoc kich hoat tren thiet bi moi", "vi"),
    ("kiem tra ky cac dieu khoan truoc khi ky hop dong thue nha", "vi"),
    ("ngay mai troi mua nho mang theo ao mua khi di lam som", "vi"),
    ("bao cao doanh thu thang nay tang truong tot so voi quy truoc", "vi"),
    ("hen gap lai ban vao sang thu hai tuan sau tai van phong", "vi"),
    // English — software engineering, DevOps, office, finance, design, academic, daily chat (70 samples)
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
    ("could you please send over the updated quarterly budget spreadsheet", "en"),
    ("our engineering team is migrating the database cluster this weekend", "en"),
    ("make sure every public function has clear documentation comments", "en"),
    ("the client requested a minor revision to the contract terms", "en"),
    ("let me know if you have any questions about the implementation plan", "en"),
    ("memory usage stays well below the strict extension sandbox limit", "en"),
    ("add a regression test case covering compound vowel transitions", "en"),
    ("this endpoint returns paginated results sorted by creation timestamp", "en"),
    ("we should cache compiled models in memory to avoid disk overhead", "en"),
    ("please attach the invoice receipt to your expense reimbursement form", "en"),
    ("the build failed due to a missing environment variable in staging", "en"),
    ("users can toggle between dark mode and light appearance automatically", "en"),
    ("keyboard navigation supports arrow keys number shortcuts and escape", "en"),
    ("on device inference protects user privacy without network requests", "en"),
    ("the quarterly business review presentation starts at ten oclock sharp", "en"),
    ("check whether the webhook signature matches the configured secret key", "en"),
    ("we observed a significant improvement in search ranking accuracy", "en"),
    ("please confirm your attendance for the annual company retreat", "en"),
    ("strict concurrency checking prevents data races across actor boundaries", "en"),
    ("the package manager resolved all dependencies cleanly in release mode", "en"),
    ("shipping carriers reported slight weather delays across the region", "en"),
    ("clinical trial results demonstrated strong safety and efficacy profiles", "en"),
    ("renewable solar and wind capacity expanded rapidly over the decade", "en"),
    ("undergraduate students must complete two laboratory courses each term", "en"),
    ("select text in any editor and press the shortcut to run quick actions", "en"),
    ("the installer copies the bundle directly into the input methods folder", "en"),
    ("this pull request removes deprecated legacy helpers and dead code", "en"),
    ("please double check therecipient email address before sending the wire", "en"),
    ("high frame rate animations feel smooth and responsive on promotion displays", "en"),
    ("each benchmark suite reports exact pass rates in structured json output", "en"),
    ("let us grab coffee downstairs after the standup meeting wraps up", "en"),
    ("the raw sensor stream is buffered and processed in fixed intervals", "en"),
    ("set the default fallback value when configuration keys are absent", "en"),
    ("six nodes in the cluster are healthy and serving read replicas", "en"),
    ("he has already approved the architectural design document yesterday", "en"),
    ("she was reviewing the pull request comments earlier this afternoon", "en"),
    ("do not add unnecessary third party frameworks to the core library", "en"),
    ("the layout adapts seamlessly from compact phones to wide desktop monitors", "en"),
    ("we will publish the release notes and binary archive on github today", "en"),
    ("thank you for contributing to this open source project under mit license", "en"),
    ("check the box below to accept the terms of service and privacy policy", "en"),
    ("the tax calculation module handles value added tax and regional exemptions", "en"),
    ("take the express bus from downtown terminal directly to the airport", "en"),
    ("adjust the vocal mix level slightly so the acoustic guitar stays clear", "en"),
    ("the maximum payload size allowed by the gateway is ten megabytes", "en"),
    ("export raw telemetry counters for offline statistical analysis in python", "en"),
    ("we see consistent sub millisecond latency across all percentile buckets", "en"),
    ("add an index on user identifier and timestamp to speed up queries", "en"),
    ("turn off debug logging before profiling release performance metrics", "en"),
    ("looking forward to hearing your thoughts on the upcoming roadmap", "en"),
]

let domainSamples: [(String, String)] = [
    // technology (20 samples)
    ("kiểm thử hồi quy mã nguồn hệ thống máy chủ cơ sở dữ liệu và giao diện lập trình", "technology"),
    ("triển khai ứng dụng bảo mật thông tin cấu trúc dữ liệu thuật toán tìm kiếm mạng", "technology"),
    ("tối ưu hiệu năng bộ nhớ đệm xử lý bất đồng bộ trên hệ điều hành", "technology"),
    ("cập nhật phiên bản phần mềm sửa lỗi hiển thị bàn phím và phím tắt hệ thống", "technology"),
    ("kiến trúc vi dịch vụ cân bằng tải đám mây và đóng gói ứng dụng máy chủ", "technology"),
    ("biên dịch mã nguồn kiểm tra kiểu tĩnh và ngăn chặn xung đột luồng dữ liệu", "technology"),
    ("mô hình học máy suy luận trực tiếp trên nhân xử lý thần kinh của thiết bị", "technology"),
    ("sao lưu định kỳ cơ sở dữ liệu quan hệ tối ưu chỉ mục truy vấn nhanh", "technology"),
    ("xác thực hai yếu tố mã hoá đầu cuối và quản lý khóa bảo mật hệ thống", "technology"),
    ("tích hợp liên tục tự động chạy bộ kiểm thử đơn vị và đóng gói bản phát hành", "technology"),
    ("giao thức truyền tải mạng phân giải tên miền và cấu hình tường lửa máy chủ", "technology"),
    ("phát triển giao diện người dùng mượt mà tương thích màn hình gập và máy tính bảng", "technology"),
    ("xử lý ngôn ngữ tự nhiên phân loại ngữ cảnh và xếp hạng gợi ý từ vựng", "technology"),
    ("theo dõi nhật ký hệ thống phân tích độ trễ phản hồi và tiêu thụ bộ nhớ", "technology"),
    ("quản lý phiên bản mã nguồn mở hợp nhất nhánh phát triển và đánh dấu phát hành", "technology"),
    ("thiết kế trình biên dịch phân tích cú pháp cây trừu tượng và sinh mã máy", "technology"),
    ("cấu hình bộ định tuyến mạng nội bộ băng thông cao cho trung tâm dữ liệu", "technology"),
    ("khắc phục sự cố tràn bộ đệm và rò rỉ tài nguyên trong tiến trình nền", "technology"),
    ("đồng bộ dữ liệu đám mây an toàn giữa máy tính để bàn và thiết bị di động", "technology"),
    ("xây dựng công cụ dòng lệnh đo kiểm tốc độ xử lý từng phím gõ tiếng Việt", "technology"),

    // business (20 samples)
    ("báo cáo tài chính doanh thu thuần lợi nhuận sau thuế và chi phí vận hành", "business"),
    ("điều khoản hợp đồng thuê mặt bằng quản lý dự án chuỗi cung ứng và hóa đơn", "business"),
    ("chuyển khoản ngân hàng thương mại thanh toán công nợ và kế hoạch kinh doanh", "business"),
    ("dịch vụ khách hàng nguồn nhân lực thị trường chứng khoán và quản trị rủi ro", "business"),
    ("hội đồng quản trị phê duyệt ngân sách đầu tư mở rộng thị trường xuất khẩu", "business"),
    ("đối chiếu sổ phụ ngân hàng quyết toán thuế giá trị gia tăng và thuế thu nhập", "business"),
    ("chiến lược tiếp thị thương hiệu tăng trưởng doanh số bán lẻ quý bốn", "business"),
    ("đàm phán hợp đồng cung ứng nguyên vật liệu và tiến độ giao nhận kho bãi", "business"),
    ("phân tích dòng tiền tự do tỷ suất sinh lời trên vốn chủ sở hữu doanh nghiệp", "business"),
    ("tuyển dụng nhân sự cấp cao đào tạo hội nhập và đánh giá hiệu suất định kỳ", "business"),
    ("xuất hóa đơn điện tử biên bản nghiệm thu bàn giao dịch vụ cho đối tác", "business"),
    ("kiểm toán độc lập rà soát báo cáo hợp nhất và thuyết minh tài chính năm", "business"),
    ("chăm sóc khách hàng thân thiết giải quyết khiếu nại và bảo hành sản phẩm", "business"),
    ("lập dự toán chi phí sản xuất định mức nguyên liệu và giá thành đơn vị", "business"),
    ("huy động vốn trái phiếu doanh nghiệp lãi suất ưu đãi cho dự án hạ tầng", "business"),
    ("thương mại điện tử thanh toán không tiền mặt và tối ưu chi phí vận chuyển", "business"),
    ("ký kết biên bản ghi nhớ hợp tác chiến lược phân phối độc quyền toàn quốc", "business"),
    ("quản lý tồn kho luân chuyển hàng hóa và dự báo nhu cầu tiêu dùng dịp tết", "business"),
    ("bảo hiểm thương mại bồi thường thiệt hại hàng hóa vận tải đường biển", "business"),
    ("tổng kết hoạt động kinh doanh vinh danh tập thể xuất sắc cuối năm tài chính", "business"),

    // education (20 samples)
    ("giáo dục đại học chương trình đào tạo phương pháp học tập và luận văn tốt nghiệp", "education"),
    ("học sinh sinh viên nghiên cứu tài liệu tham khảo tư duy phản biện và đánh giá", "education"),
    ("giảng viên hướng dẫn bài giảng kỹ năng giao tiếp và chất lượng giáo dục", "education"),
    ("biên soạn giáo trình điện tử học liệu mở và bài tập thực hành trực tuyến", "education"),
    ("kỳ thi tuyển sinh trung học phổ thông và xét tuyển đại học chính quy", "education"),
    ("hội đồng chấm khóa luận tốt nghiệp thạc sĩ và bảo vệ đề tài nghiên cứu", "education"),
    ("phát triển năng lực ngoại ngữ tin học và kỹ năng làm việc nhóm cho sinh viên", "education"),
    ("kiểm định chất lượng cơ sở giáo dục theo tiêu chuẩn khu vực và quốc tế", "education"),
    ("học bổng khuyến khích học tập dành cho sinh viên xuất sắc vượt khó", "education"),
    ("phương pháp sư phạm tích cực lấy người học làm trung tâm trong lớp học", "education"),
    ("thư viện số đại học cung cấp cơ sở dữ liệu tạp chí học thuật chuyên ngành", "education"),
    ("chương trình trao đổi sinh viên thực tập doanh nghiệp học kỳ cuối khóa", "education"),
    ("đánh giá kết quả học tập qua dự án thực tế và bài kiểm tra định kỳ", "education"),
    ("bồi dưỡng chuyên môn nghiệp vụ sư phạm cho đội ngũ giáo viên phổ thông", "education"),
    ("hướng nghiệp phân luồng học sinh lựa chọn ngành nghề phù hợp năng lực", "education"),
    ("tổ chức cuộc thi sáng tạo khoa học kỹ thuật dành cho thanh thiếu niên", "education"),
    ("xây dựng môi trường học đường thân thiện an toàn và giàu tính sáng tạo", "education"),
    ("ứng dụng bảng tương tác thông minh trong giảng dạy toán học và vật lý", "education"),
    ("cố vấn học tập hỗ trợ tân sinh viên đăng ký tín chỉ học kỳ đầu tiên", "education"),
    ("lễ trao bằng tốt nghiệp cử nhân kỹ sư và tân khoa xuất sắc toàn khóa", "education"),

    // health (20 samples)
    ("chăm sóc sức khỏe khám chữa bệnh tại bệnh viện và điều trị nội trú ngoại trú", "health"),
    ("bác sĩ chẩn đoán triệu chứng lâm sàng xét nghiệm máu bảo hiểm y tế và dinh dưỡng", "health"),
    ("phòng chống dịch bệnh hệ miễn dịch huyết áp nhịp tim và hồ sơ bệnh án", "health"),
    ("tiêm chủng vắc xin phòng ngừa bệnh truyền nhiễm cho trẻ em và người cao tuổi", "health"),
    ("chẩn đoán hình ảnh chụp cộng hưởng từ siêu âm tim mạch và nội soi tiêu hóa", "health"),
    ("dược sĩ tư vấn liều dùng kháng sinh an toàn tránh tương tác thuốc có hại", "health"),
    ("phục hồi chức năng vật lý trị liệu sau phẫu thuật chấn thương chỉnh hình", "health"),
    ("chế độ dinh dưỡng cân đối giảm muối đường giúp kiểm soát đường huyết ổn định", "health"),
    ("khám sức khỏe tổng quát định kỳ tầm soát sớm các bệnh lý mãn tính", "health"),
    ("cấp cứu ngoại viện hồi sức tích cực và theo dõi chỉ số sinh tồn liên tục", "health"),
    ("sức khỏe tâm thần giấc ngủ sâu và phương pháp giảm căng thẳng nơi làm việc", "health"),
    ("hồ sơ sức khỏe điện tử liên thông kết quả xét nghiệm giữa các tuyến bệnh viện", "health"),
    ("vệ sinh an toàn thực phẩm nguồn nước sạch và phòng ngừa ngộ độc cấp tính", "health"),
    ("chăm sóc thai sản theo dõi sự phát triển thai nhi và dinh dưỡng cho mẹ bầu", "health"),
    ("nhãn khoa đo khúc xạ kiểm tra thị lực và phòng tránh cận thị học đường", "health"),
    ("nha khoa dự phòng lấy cao răng điều trị viêm nha chu và bảo vệ men răng", "health"),
    ("y học dự phòng giám sát dịch tễ cộng đồng và nâng cao thể trạng người dân", "health"),
    ("tập luyện thể dục nhịp điệu đi bộ mỗi ngày cải thiện tuần hoàn tim mạch", "health"),
    ("quy trình kiểm soát nhiễm khuẩn vô trùng tuyệt đối trong phòng phẫu thuật", "health"),
    ("hội chẩn chuyên khoa xây dựng phác đồ điều trị cá thể hóa cho bệnh nhân", "health"),

    // science (20 samples)
    ("bảo vệ môi trường biến đổi khí hậu năng lượng tái tạo mặt trời và đa dạng sinh học", "science"),
    ("xác suất thống kê phương trình vi phân phân tử hữu cơ dữ liệu thực nghiệm và đo lường", "science"),
    ("nghiên cứu khoa học tài nguyên thiên nhiên phát thải khí nhà kính và chu kỳ tế bào", "science"),
    ("vật lý lượng tử quang phổ nguyên tử chất bán dẫn siêu dẫn nhiệt độ thấp", "science"),
    ("công nghệ sinh học giải trình tự hệ gen biểu hiện protein và enzyme xúc tác", "science"),
    ("thiên văn học quan sát hệ ngoại hành tinh bức xạ vũ trụ qua kính viễn vọng", "science"),
    ("hóa học vật liệu tổng hợp polymer phân hủy sinh học thân thiện môi trường", "science"),
    ("địa chất thủy văn dự báo dòng chảy lưu vực sông và xâm nhập mặn đồng bằng", "science"),
    ("hệ sinh thái rừng ngập mặn hấp thụ carbon và bảo tồn loài quý hiếm", "science"),
    ("toán học ứng dụng tối ưu hóa tổ hợp mô phỏng số và phân tích chuỗi thời gian", "science"),
    ("năng lượng điện gió ngoài khơi pin lưu trữ nhiên liệu hydro xanh bền vững", "science"),
    ("hải dương học khảo sát rạn san hô nhiệt độ bề mặt biển và dòng hải lưu", "science"),
    ("khoa học khí quyển mô hình dự báo bão mưa lớn bằng vệ tinh viễn thám", "science"),
    ("vi sinh vật học phân lập chủng vi khuẩn cố định đạm cải tạo đất nông nghiệp", "science"),
    ("cơ học chất lỏng động lực học khí động và truyền nhiệt trong thiết bị trao đổi", "science"),
    ("khoa học thần kinh nhận thức cơ chế ghi nhớ và dẫn truyền xung điện sinh học", "science"),
    ("phân tích sai số chuẩn kiểm định giả thuyết thống kê trong thí nghiệm đối chứng", "science"),
    ("công nghệ nano chế tạo màng lọc phân tử xử lý kim loại nặng trong nước thải", "science"),
    ("nông nghiệp công nghệ cao giống cây trồng chịu hạn thích ứng biến đổi khí hậu", "science"),
    ("công bố bài báo quốc tế phản biện đồng cấp và chia sẻ bộ dữ liệu thực nghiệm", "science"),

    // general (20 samples)
    ("xin chào cảm ơn bạn rất nhiều hẹn gặp lại vào buổi sáng ngày mai", "general"),
    ("chúc mừng sinh nhật và chúc cuối tuần vui vẻ bên gia đình mọi người", "general"),
    ("hôm nay thời tiết đẹp chúng ta cùng nghỉ ngơi và trò chuyện", "general"),
    ("sáng nay uống một ly cà phê sữa đá rồi bắt đầu ngày làm việc mới", "general"),
    ("cuối tuần cả nhà dự định đi dạo công viên và nấu bữa cơm sum họp", "general"),
    ("cảm ơn cậu đã nhắc lịch nhé lát nữa xong việc mình ghé qua liền", "general"),
    ("trời chiều mát mẻ đạp xe quanh hồ ngắm hoàng hôn rất dễ chịu", "general"),
    ("nhớ mặc thêm áo ấm vì tối nay không khí lạnh bắt đầu tràn về", "general"),
    ("mình vừa đọc xong một cuốn sách rất hay muốn giới thiệu cho bạn", "general"),
    ("chúc chuyến đi du lịch của gia đình bạn thật nhiều niềm vui và kỷ niệm", "general"),
    ("bữa trưa nay mình ăn bún chả ở quán nhỏ đầu ngõ gần nhà", "general"),
    ("lâu rồi chưa gặp nhau hôm nào rảnh tụ tập ăn tối trò chuyện nhé", "general"),
    ("chúc mừng năm mới an khang thịnh vượng vạn sự như ý bên người thân", "general"),
    ("nhờ bạn nhận giúp bưu phẩm ở quầy lễ tân dưới sảnh chung cư nhé", "general"),
    ("mình đang nghe danh sách nhạc nhẹ nhàng thư giãn sau giờ làm việc", "general"),
    ("chiều chủ nhật dọn dẹp lại góc bàn làm việc gọn gàng và trồng thêm cây xanh", "general"),
    ("tối thứ bảy rủ nhau đi xem bộ phim điện ảnh mới ra rạp gần đây", "general"),
    ("cảm ơn mọi người đã gửi lời hỏi thăm và động viên ấm áp", "general"),
    ("đường về nhà chiều nay thông thoáng nên mình về sớm hơn mọi hôm", "general"),
    ("chúc bạn một ngày mới tràn đầy năng lượng tích cực và niềm vui", "general"),
]

try compileTextClassifier(name: "VitekLanguageContext", samples: languageSamples)
try compileTextClassifier(name: "VitekDomainClassifier", samples: domainSamples)
