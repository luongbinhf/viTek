# Tích hợp hệ thống Apple

viTek dùng các API hệ thống cho công việc viết chủ động; xử lý từng phím Telex/VNI vẫn chạy bằng engine cục bộ, không đợi mô hình AI.

Màn hình viết hiện chuẩn bị trước một session khi người dùng mở/bắt đầu nhập, tự bỏ phần chuẩn bị sau 30 giây và khi rời màn hình/background. Không chuẩn bị trước ở Low Power Mode hoặc thermal state serious/critical. Mỗi lần sinh câu lấy một session chưa dùng; không tái dùng transcript bản nháp trước. Trên M5 đã đo giảm trung vị thời gian chờ sau nút bấm từ 1,890 xuống 1,553 giây, với khoảng chuẩn bị 2 giây trong benchmark. Xem [phương pháp, kết quả và giới hạn ANE](QA-APPLE-SILICON-2026-11-13.md).

## Gợi ý viết và Shortcuts

Trên macOS/iOS 26 trở lên, màn hình **Gợi ý viết** dùng `FoundationModels.SystemLanguageModel.default`. Người dùng nhập đoạn nháp rồi chủ động yêu cầu một câu nối tiếp. Kết quả cập nhật trong màn hình khi model trả từng phần; sửa nháp, rời màn hình hoặc bấm Hủy sẽ hủy yêu cầu. Đầu vào tối đa 2.400 byte UTF-8, đầu ra tối đa 120 token.

Ứng dụng kiểm trạng thái model và hỗ trợ tiếng Việt lúc mở, khi trở lại foreground hoặc khi bấm kiểm tra lại. Máy chưa đủ điều kiện, Apple Intelligence đang tắt, model chưa sẵn sàng hoặc chưa hỗ trợ tiếng Việt sẽ có thông báo cụ thể. TextEditor cho phép Writing Tools hệ thống. Không tự bật Apple Intelligence hay thay đổi cài đặt Siri.

Hai App Shortcuts được khai báo cho macOS và iOS:

| Hành động | Đầu vào | Kết quả |
|---|---|---|
| Mở Gợi ý viết | Không | Mở cửa sổ/tab viết của viTek |
| Gợi ý câu tiếp theo | Đoạn đang viết | Trả câu nối tiếp để dùng trong Shortcuts |

Các câu gọi gồm “Mở gợi ý viết trong viTek” và “Viết tiếp với viTek”, cùng bản tiếng Anh. Đây là các hành động tích hợp qua App Intents; mức khám phá/gọi bằng giọng nói phụ thuộc Siri và thiết bị. Không mô tả chúng như một mô hình “Siri AI” riêng của viTek.

## Widget và đường dẫn

Widget iOS **Gõ nhanh tiếng Việt** có cỡ nhỏ/vừa, nhắc `viw`, `viwtj`, `viwts`. Chạm widget mở `vitek://writing`. Chỉ đường dẫn điều hướng này và biến thể có dấu `/` cuối được chấp nhận; query, fragment, tài khoản, port hoặc đường dẫn khác bị bỏ qua. Đoạn nháp không truyền qua URL/widget.

Widget được đóng gói trong ứng dụng iOS. Cần mở ứng dụng đã cài ít nhất một lần để hệ thống khám phá widget. Chưa có widget macOS riêng, ActivityKit Live Activity, Dynamic Island hay đẩy kết quả bằng APNs. Cập nhật trực tiếp hiện là tiến trình và kết quả streaming trong cửa sổ viết.

## Neural Engine và phạm vi xác nhận

Foundation Models quản lý việc chạy mô hình hệ thống. viTek không tuyên bố ép mọi phép tính lên Apple Neural Engine và không thêm một mô hình Core ML chỉ để bật tùy chọn phần cứng. `MLComputeUnits.cpuAndNeuralEngine` áp dụng cho mô hình Core ML tương ứng, không phải một cờ bật cho `SystemLanguageModel`.

Ngày 13/11/2026 đã kiểm sinh câu và cập nhật từng phần trên máy Mac thật, thực thi `ContinueWritingIntent.perform()`, metadata hai App Shortcuts trên hai nền tảng, và ba XCTest UI trên Simulator: tab viết, đường dẫn mở khi app tắt/đang chạy, từ chối URL chứa query. Kiểm Simulator không xác nhận Siri bằng giọng nói, widget trên Home Screen hay hiệu năng Neural Engine trên iPhone thật. Xem [báo cáo QA](QA-TELEX-APPLE-2026-11-13.md) để biết môi trường và bằng chứng.

## Tài liệu Apple

- [App Intents và các hành động hệ thống](https://developer.apple.com/documentation/appintents/creating-your-first-app-intent)
- [AppShortcutsProvider](https://developer.apple.com/documentation/appintents/appshortcutsprovider)
- [Tạo widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Ngôn ngữ của Foundation Models](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [Writing Tools trong SwiftUI](https://developer.apple.com/documentation/swiftui/writingtoolsbehavior)
- [Core ML: CPU và Neural Engine](https://developer.apple.com/documentation/coreml/mlcomputeunits/cpuandneuralengine)
- [Yêu cầu Apple Intelligence](https://support.apple.com/en-vn/121115)
