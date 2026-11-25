/// Seed vocabulary authored for viTek. These are editorial priorities, not measured frequencies.
/// Keep additions reviewable; coverage is evaluated separately from correctness.
enum BuiltinVocabulary {
    static let technicalTokens = """
    API SDK SQL HTTP HTTPS JSON OAuth2 Unicode UTF-8 CI/CD CPU GPU ANE RAM SSD URL URI HTML CSS XML
    REST GraphQL WebSocket TypeScript JavaScript Python Swift SwiftUI Kotlin Rust Docker Kubernetes
    PostgreSQL SQLite Redis Git GitHub GitLab Linux macOS iOS Xcode TCP IP DNS TLS SSL SSH JWT UUID
    ASCII UTF-16 YAML TOML CSV PDF NFC NFD SIMD CoreML AppKit UIKit FoundationModels
    XcodeGen WidgetKit SwiftData Observation TestFlight CloudKit Metal iPadOS watchOS visionOS
    """.split(whereSeparator: \.isWhitespace).map(String.init)

    static let entries: [VocabularyEntry] = {
        var result = """
        người những nhiều nhưng được đường đang trong trước trường thông thường thành thời thế thể theo thêm
        không khác khi chỉ cho chưa chính chương chuyển chuyện chuyên chúng chung chuẩn chất chọn chức chữ
        Việt việc viết với và vào vậy về văn vẫn vận vùng vừa vui vấn vị vì ví vững
        là lại làm lên lúc luôn lớn lần lời lợi lượng loại liệu liên lý lấy lưu lập
        một mọi mới muốn mình mức mục mình mà máy mạng mã mẫu mặt mang mạnh mở mỗi môi
        các cách cần cũng còn cùng cuộc cuối của có công còn cảm cấp câu cái càng cả cơ cộng
        dữ dụng dùng dự đến đều để điều định điểm được đời đổi đối đồng động đầu đưa đủ đúng điện
        học hành hàng hỏi hợp hoạt hoàn hội hướng hiểu hiện hình hệ hỗ hôm hơn hết hàm hiệu
        tốt tôi từng tự từ toàn tính tiến tiếp tiếng tìm tin tình tại tạo tên tác tăng tất tài tập tâm
        quả quan quản quá quyết quyền quy quỹ quốc quá khứ khả khoa khách khác kiểm kết kiến kinh kỹ khỏe
        sản sách sau sẽ sự số sở sống so sánh sử suất sinh sức sáng sửa siêu sâu
        bằng bạn bản bảo báo biết bình bên bộ bước bao bắt bền bối bốn bức bờ
        phần phải phân phát phép phương phòng phụ phù phức phong phối phạm phản phục pháp phí
        rất ra rằng riêng rồi rõ ràng rủi rút rừng
        năm ngày ngành ngay nhà nhóm nhỏ như nào này nơi nhận người nhu nhất nhanh nhờ nhập nghiên nhiệm
        ứng ưu ý yêu yếu an ăn anh ảnh áp ảo âm ấy ít ít ước ủy uống
        độ đa đạt đặt đó đóng đọc đơn đáng đoạn dân danh diện duy dịch doanh dành đầy đám dám
        kiểm khách khởi khai khái khoảng khối khung kết khoán khảo khám
        lượng luận luồng lược lực luật lịch lỗi lệnh lớp lần lời lúa
        truy truyền triển trực trạng trách trúc trung tri thức thực thiết thiếu thử thu thuận thương thị thuốc
        giảm giải giao giới giá giữ gian gì giám giờ gặp gần gọi ghi giỏi giai giáo
        vẹn vượt vết vệ vững vốn vật vòng
        nguồn ngữ nghiên nghiệm nguyên ngắn nghĩa nghề ngoài ngân ngược
        bán biển biến bệnh bảng báo buổi bài bại bậc
        tuần tháng phút giây năm sáng chiều tối đêm tuần tự xanh trắng đỏ
        mạnh mềm cứng rộng hẹp xa gần dễ khó an toàn ổn định
        cảm ơn chào xin hẹn gặp chúc mừng sẵn sàng
        """.split(whereSeparator: \.isWhitespace).map { VocabularyEntry(String($0), priority: 150) }
        // Everyday completions should not lose to a technical syllable merely because it
        // occurs inside a specialist phrase. Phrase evidence still has a much larger score.
        result += """
        người những nhiều được trong không trước trường thông thường thành thời theo chính chuyển chuyện
        chúng chuẩn chất việc viết văn với một mọi muốn mình các cách cần cũng cùng của công cảm
        dữ dụng dùng đến đều để điều định điểm đổi đối đồng động học hành hỏi hợp hướng hiện hình
        tốt tôi từng toàn tính tiến tiếp tiếng tìm tin tình tại tạo quan quản kiểm kết kiến kinh
        phần phải phân phát phương phù rất riêng rồi năm ngày ngành nhà nhóm như nhận nhất nhanh
        """.split(whereSeparator: \.isWhitespace).map { VocabularyEntry(String($0), priority: 400) }
        result += technicalTokens.map { VocabularyEntry($0, domain: .technology, priority: 240) }
        func phrases(_ text: String, _ domain: VocabularyDomain, priority: Int = 200) {
            result += text.split(separator: "\n").map { VocabularyEntry(String($0), domain: domain, priority: priority) }
        }
        phrases("""
        cơ sở dữ liệu
        trí tuệ nhân tạo
        học máy
        mã nguồn
        kiểm thử hồi quy
        kiểm thử tích hợp
        kiểm thử đơn vị
        giao diện lập trình
        bảo mật thông tin
        xác thực đa yếu tố
        phân tích dữ liệu
        hệ điều hành
        bộ nhớ đệm
        quản lý bộ nhớ
        ngôn ngữ lập trình
        kiến trúc phần mềm
        phát triển phần mềm
        triển khai ứng dụng
        xử lý bất đồng bộ
        điều kiện tranh chấp
        kiểm soát phiên bản
        mã hóa đầu cuối
        kết nối mạng
        tốc độ xử lý
        thời gian phản hồi
        quyền truy cập
        chuỗi ký tự
        cấu trúc dữ liệu
        thuật toán tìm kiếm
        giá trị trả về
        tham số đầu vào
        biến môi trường
        hàm bất đồng bộ
        con trỏ văn bản
        gợi ý từ
        gợi ý ngữ cảnh
        từ điển tiếng Việt
        xử lý ngôn ngữ tự nhiên
        dấu thanh tiếng Việt
        khôi phục dữ liệu
        sao lưu dữ liệu
        đồng bộ dữ liệu
        tính toàn vẹn dữ liệu
        máy chủ cơ sở dữ liệu
        mô hình ngôn ngữ
        mạng nơ ron
        bộ gõ tiếng Việt
        """, .technology, priority: 250)
        phrases("""
        quản lý dự án
        quản lý chất lượng
        đảm bảo chất lượng
        doanh thu thuần
        chi phí vận hành
        báo cáo tài chính
        dòng tiền
        chuỗi cung ứng
        hợp đồng lao động
        bảo hiểm xã hội
        báo cáo kết quả
        kết quả kinh doanh
        lợi nhuận sau thuế
        thuế giá trị gia tăng
        ngân hàng thương mại
        kế hoạch kinh doanh
        quản trị rủi ro
        dịch vụ khách hàng
        nguồn nhân lực
        vốn chủ sở hữu
        tăng trưởng kinh tế
        thị trường chứng khoán
        tài sản cố định
        hàng tồn kho
        năng lực cạnh tranh
        quản lý sản phẩm
        trải nghiệm người dùng
        quyền sở hữu trí tuệ
        điều khoản hợp đồng
        phát triển bền vững
        """, .business)
        phrases("""
        giáo dục đại học
        nghiên cứu khoa học
        phương pháp nghiên cứu
        phương pháp học tập
        chương trình đào tạo
        kết quả học tập
        kiểm tra đánh giá
        kiến thức cơ bản
        kỹ năng giao tiếp
        tư duy phản biện
        tài liệu tham khảo
        học sinh trung học
        học tập suốt đời
        chất lượng giáo dục
        luận văn tốt nghiệp
        """, .education)
        phrases("""
        chăm sóc sức khỏe
        khám sức khỏe
        sức khỏe tinh thần
        khám chữa bệnh
        bệnh viện
        bệnh nhân
        bác sĩ chuyên khoa
        phác đồ điều trị
        điều trị nội trú
        điều trị ngoại trú
        hồ sơ bệnh án
        bảo hiểm y tế
        cơ sở y tế
        chẩn đoán hình ảnh
        triệu chứng lâm sàng
        xét nghiệm máu
        phòng chống dịch bệnh
        chế độ dinh dưỡng
        hoạt động thể chất
        hệ miễn dịch
        huyết áp cao
        nhịp tim
        """, .health)
        phrases("""
        bảo vệ môi trường
        biến đổi khí hậu
        năng lượng tái tạo
        năng lượng mặt trời
        phát thải khí nhà kính
        đa dạng sinh học
        tài nguyên thiên nhiên
        xác suất thống kê
        phương trình vi phân
        phân tử hữu cơ
        nguyên tử hydro
        dữ liệu thực nghiệm
        độ chính xác
        sai số đo lường
        chu kỳ tế bào
        """, .science)
        phrases("""
        xin chào
        cảm ơn
        rất cảm ơn
        chúc mừng
        hẹn gặp lại
        hôm nay
        ngày mai
        ngày hôm qua
        buổi sáng
        buổi chiều
        buổi tối
        thời tiết hôm nay
        mọi người
        cuộc sống
        gia đình
        công việc
        thời gian
        có thể
        không thể
        chúng tôi
        chúng ta
        các bạn
        làm việc
        nghỉ ngơi
        sẵn sàng
        an toàn
        rõ ràng
        phù hợp
        lựa chọn
        quyết định
        cảm ơn bạn
        cảm ơn nhiều
        trân trọng cảm ơn
        xin lỗi vì sự bất tiện
        chúc cuối tuần vui vẻ
        chúc mừng năm mới
        chúc mừng sinh nhật
        để mình kiểm tra
        gửi bạn tài liệu
        cập nhật tiến độ
        họp trực tuyến
        lịch họp hôm nay
        kế hoạch tuần tới
        phản hồi sớm nhé
        đồng ý với đề xuất
        cần hỗ trợ thêm
        giao diện người dùng
        trải nghiệm người dùng
        tối ưu hiệu năng
        bản phát hành mới
        tự động hóa kiểm tra
        sửa lỗi hiển thị
        đồng bộ đám mây
        bàn phím tiếng Việt
        phím tắt hệ thống
        chúc bạn ngày mới vui vẻ
        hoàn thành đúng hạn
        báo cáo tuần này
        tổng hợp thông tin
        xác nhận lịch hẹn
        gửi lời cảm ơn
        làm việc từ xa
        phát triển mã nguồn mở
        gõ tiếng Việt nhanh
        kiểm tra chính tả
        từ điển cá nhân
        chuyển mã văn bản
        bảo vệ quyền riêng tư
        cập nhật phiên bản mới
        hướng dẫn sử dụng
        thông báo hệ thống
        mật khẩu bảo mật
        tài khoản cá nhân
        kết nối ổn định
        chia sẻ màn hình
        ghi chú cuộc họp
        danh sách công việc
        mở rộng tính năng
        trạng thái hoạt động
        tìm kiếm nhanh chóng
        """, .general)
        return result
    }()
}
