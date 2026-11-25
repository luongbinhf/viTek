# Apple Intelligence trên Apple Silicon — 13/11/2026

## Thay đổi đã cài

Màn hình viết macOS/iOS chuẩn bị một `LanguageModelSession` khi mở hoặc bắt đầu nhập nháp trong ứng dụng đang hoạt động. Chỉ instructions cố định được đưa vào `prewarm()`, không đưa bản nháp vào bước chuẩn bị. Người dùng bấm gợi ý sẽ lấy session chưa dùng này; yêu cầu sau tạo session khác, không nối lịch sử đoạn trước. Telex/VNI không gọi model trên đường xử lý phím.

Giữ tối đa một session chưa dùng cho mỗi màn hình, hết hạn sau 30 giây. Bỏ phần chuẩn bị khi rời màn hình, chuyển ứng dụng sang background, thay đổi trạng thái nguồn/nhiệt hoặc iOS báo thiếu bộ nhớ. macOS cũng bỏ phần chuẩn bị khi viTek mất active. Không chuẩn bị trước nếu Low Power Mode bật, thermal state serious/critical hoặc model chưa sẵn sàng. Yêu cầu viết chủ động vẫn được phép trong Low Power Mode; không thay đổi cài đặt hệ thống của người dùng. Bỏ tham chiếu của viTek không đồng nghĩa ép hệ điều hành xóa model khỏi bộ nhớ.

App Intent vẫn dùng session riêng cho mỗi lần gọi. Không thêm chờ nhân tạo trước khi sinh câu, không đổi model sang dịch vụ đám mây và không thêm model Core ML chưa được đánh giá chất lượng.

## Đo trên máy thật

Máy kiểm: **MacBook Air Apple M5, RAM 32 GB, macOS 27.2 (26B123)**. `MLComputeDevice.allComputeDevices` trả CPU, GPU Apple M5 và **ANE 16 lõi**. Đây là xác nhận phần cứng có thể truy cập, chưa phải số đo mức sử dụng ANE.

Benchmark gửi câu QA cố định “Sáng nay tôi đi dạo trong công viên.”, xen kẽ 6 lượt không prewarm và 6 lượt có prewarm theo thứ tự ABBA lặp lại. Lượt có prewarm có khoảng dẫn 2 giây, mô phỏng thời gian người dùng soạn nháp; thời gian này được ghi riêng, không tính vào thời gian sau khi bấm gợi ý.

| Phép đo | Kết quả |
|---|---:|
| Trung vị tới phần văn bản đầu tiên, không prewarm | 1,890 s |
| Trung vị tới phần văn bản đầu tiên, có prewarm | 1,553 s |
| Giảm thời gian chờ sau nút bấm trong lượt đo | 17,8% |
| So sánh khi loại yêu cầu đầu tiên của tiến trình | 16,1% |

Đây là thời gian tới **partial không rỗng đầu tiên**, không phải bộ đếm token phần cứng. Các partial của model hiện về gần nhau; output dài 32–61 ký tự. Số mẫu nhỏ, output không cố định và máy còn tác vụ khác, nên không suy rộng phần trăm này cho mọi chip M hoặc mọi đoạn nháp. Nếu cộng cả khoảng chuẩn bị 2 giây, lượt prewarm không có tổng thời gian ngắn hơn; lợi ích là chuyển phần chuẩn bị sang lúc đang soạn. Không đo pin, công suất hay TOPS.

[Log baseline](../reports/qa-apple-silicon-2026-11-13/baseline.log), [log so sánh](../reports/qa-apple-silicon-2026-11-13/comparison.log), [số liệu tính từ log](../reports/qa-apple-silicon-2026-11-13/metrics.json).

## Instruments và ANE

Đã ghi trace **Foundation Models** khi chạy riêng benchmark. 12 session có 124 input token/session và không có lỗi: các session prewarm tái dùng **104 token**, các session đối chứng có **0 cached token**. Đã lưu [metrics số từ Instruments](../reports/qa-apple-silicon-2026-11-13/instruments-inference.json); không đưa prompt/response, transcript hay định danh thiết bị vào artifact này. Trace gốc nằm tại `/tmp/vitek-apple-silicon-qa-profile.trace`, không đưa vào repo.

Trace này xác nhận cache được sử dụng thực tế, nhưng không cung cấp CPU/GPU/ANE utilization. `SystemLanguageModel.default` do runtime Apple quản lý. viTek chưa có model Core ML riêng để cấu hình `MLModelConfiguration.computeUnits`; không gắn tùy chọn đó vào Foundation Models và không quy mức cải thiện ở trên cho riêng ANE. Chưa kiểm trên M1/M2/M3/M4, iPad chip M hay iPhone thật trong lượt này.

## Kiểm tra hành vi

- **1.019 assertion đạt**: không chuẩn bị lại theo từng ký tự, session dùng một lần, không lẫn draft, hết hạn theo deadline, tự giải phóng khi không tương tác, discard và chính sách nguồn/nhiệt. [Log](../reports/qa-apple-silicon-2026-11-13/preparation-tests.log).
- Kiểm input/URL, giới hạn UTF-8, hủy trước khi chạy, sinh câu và `ContinueWritingIntent.perform()` thật đều đạt. [Log](../reports/qa-apple-silicon-2026-11-13/integration.log).
- Nhánh API không dùng reasoning options của compiler mới cũng đã biên dịch và qua 1.019 assertion trên SDK hiện tại; đây không phải kiểm trên máy chạy macOS/iOS 26. [Log nhánh tương thích](../reports/qa-apple-silicon-2026-11-13/compatibility-path-tests.log).
- **3 XCTest UI iOS đạt**: tab viết, mở URL khi app tắt/đang chạy và từ chối query không hợp lệ. [Log](../reports/qa-apple-silicon-2026-11-13/ios-ui-tests.log).
- Cửa sổ macOS của bản cài đã sinh “Tôi thấy thật nhiều điều thú vị xung quanh mình.” từ câu QA. Xóa nháp làm kết quả cũ biến mất và nút generate bị khóa. Nháp kiểm đã dọn rỗng. Đây là kiểm UI AI bằng AX, không tính là kiểm bộ gõ bằng phím hệ thống.
- Release macOS host + installer build đạt với Swift/GCC warnings-as-errors. Có warning của bước metadata extractor ở target không phụ thuộc AppIntents; không phải lỗi biên dịch. iOS app + keyboard + widget + UI tests build đạt. `git diff --check` đạt.

Không chạy lại 180 ca gõ VS Code/Chrome của lượt trước: thay đổi lần này ở chuẩn bị session AI và vòng đời màn hình viết; code engine, document session và Command gate không đổi. Kết quả 180 ca thuộc [bản Telex trước đó](QA-TELEX-APPLE-2026-11-13.md).

## Bản cài và chạy lại

Executable `~/Library/Input Methods/viTek.app/Contents/MacOS/viTek`:

```text
f7a70f4d374177183902b97b4cd8078610cb9acd409eade30f9c36bd4d33385d
```

Hash trùng payload `/tmp/vitek-apple-silicon-release-final/viTek.app`; chữ ký local qua `codesign --verify --deep --strict`. Diagnostics OFF, gợi ý ON. Chưa push GitHub.

```sh
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  Apps/Shared/WritingPreparation.swift Apps/Shared/WritingSuggestion.swift \
  Tests/macOSCompatibility/WritingPreparationCheck.swift \
  -o /tmp/vitek-writing-preparation-check
/tmp/vitek-writing-preparation-check

xcrun swiftc -swift-version 6 -warnings-as-errors -O -parse-as-library \
  Apps/Shared/WritingPreparation.swift Apps/Shared/WritingSuggestion.swift \
  Tests/macOSCompatibility/AppleSiliconWritingBench.swift \
  -o /tmp/vitek-apple-silicon-bench
/tmp/vitek-apple-silicon-bench
```

Benchmark cần model Apple Intelligence tiếng Việt sẵn sàng. Trace bằng Instruments chỉ nên dùng nội dung QA; instrument có thể ghi prompt/response vào trace và system log.

## Nguồn Apple

- [Prewarm session trước khi người dùng yêu cầu](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:))
- [Tối ưu KV cache](https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions)
- [Đo Foundation Models bằng Instruments](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)
- [Liệt kê compute devices qua Core ML](https://developer.apple.com/documentation/coreml/mlcomputedevice/allcomputedevices)
