# QA phím đến trước focus — 09/11/2026

## Kết luận đã có bằng chứng

- **Host quyết định ô nhận phím tại lúc xử lý sự kiện.** Chrome/ABC: Tab → focusin ô mới → keydown `nam`, nên ô mới nhận đủ `nam`. Khi fixture cố ý chuyển focus sau 150 ms, cả ba keydown đến ô cũ trước focusout; ô cũ giữ đủ `nam`, ô mới trống. Đây là hành vi đúng; IME không được chuyển chữ đã gõ sang ô tương lai.
- **AX focus không phải thời điểm DOM focus.** VS Code/ABC đạt 12/12 lượt `Cmd+F`, `Cmd+A`, `nam` với các khoảng nghỉ yêu cầu 0/20/100/300 ms, mỗi mức 3 lượt. Ba lượt 0 ms vẫn báo AX focus cũ ngay trước khi gửi phím nhưng Find nhận đủ `nam`, editor trống. Sáu lượt viTek đầu cũng đạt trước khi một lượt setup dừng vì focus không đúng; không tính lượt dừng đó là lỗi engine.
- **Có lỗi viTek riêng, không chỉ lỗi công cụ.** Trace DOM Chrome ghi `nam` thành `ama` dù focusin ô mới đã xảy ra trước keydown `n`. Log IME cho thấy callback commit của ô cũ đến sau mark đầu tiên của ô mới. Regression bắt được mất prefix (`nam` → `am`, `vieetj ` → `ieetj `) trước sửa.
- **Một lỗi khác ở phím chức năng:** F1–F20 từng bị KeyMap chuyển thành ký tự private-use, không phải boundary. F4 reset ô/F2 chuyển focus của fixture vì vậy có thể để lại anchor cũ. Kiểm trực tiếp NSEvent: trước sửa 20/20 phím sai, sau sửa 20/20 đạt.

## Sửa trong bản đã cài

1. Hiệu chỉnh native anchor khi caret và marked offset thuộc hai frame khác nhau. Với host không đọc lại được text, chỉ chấp nhận cập nhật độ dài của native revision đang chờ, ngoài vùng caret cũ; tiếp tục ghi qua native mark, không dùng offset chưa xác minh cho absolute replacement. Có test bảo vệ di chuyển caret trong từ.
2. Phân biệt `commitComposition` của host với navigation/deactivation. Callback cũ đến muộn chỉ được bỏ qua trong cửa sổ 500 ms của native transaction mới chưa xác nhận sau boundary; frame mới được ghi nhận để không mất prefix. Giữ loại callback khi hoãn vì reentrancy.
3. F1–F20 trở thành boundary để vô hiệu hóa cache sau shortcut/reset/focus.

Release warnings-as-errors build, codesign verify, **159/159 test** (105 session, 52 engine, 2 repository) và kiểm 20 function keys đạt. SHA-256 executable đã cài: `08374fbd66886f18a177e4e35e8500bea0c14c46462d4f048b46062a22367cef`.

## Trạng thái kiểm UI cuối

**Chưa công nhận ma trận UI cuối hoàn tất.** Bản trung gian đã đạt các ca Tab và phần lớn ca focus trễ, nhưng còn phát hiện lỗi cache đã sửa tiếp. Các lượt sau cùng bị foreground chuyển sang ứng dụng/cửa sổ khác; runner dừng trước phím tiếp theo. Không dùng các lượt đó để suy luận PASS/FAIL sản phẩm.

Đã thử gửi CGEvent trực tiếp tới PID để tránh tranh foreground. Mẫu dương không đạt (`vieetj ` chỉ còn dấu cách), dù log có callback IME với các range NSNotFound. Loại cách gửi này khỏi runner; không dùng làm bằng chứng UI. Runner hiện chỉ gửi virtual key codes qua HID event tap, kiểm PID và đúng tên cửa sổ QA mỗi phím. Đã đề nghị tạm dừng các phiên điều khiển UI khác để tự hoàn thành kiểm VS Code/Chrome; không yêu cầu người dùng gõ thử.

## Tái chạy

- Build app QA: `zsh scripts/build_input_qa.sh`.
- VS Code riêng: mở `viTek-System-QA.txt` bằng `--user-data-dir` riêng, `--disable-extensions --force-renderer-accessibility`.
- Chạy app qua LaunchServices: `open -W -n -o <log> --stderr <error-log> build/QAInputDriver.noindex/viTekInputQA.app --args --race --pid=<PID Code QA> --with-select-all`. Thêm `--abc` chỉ khi kiểm đối chứng ABC; mẫu dương là điều kiện bắt buộc.
- Chrome riêng: mở `Tests/macOSCompatibility/focus-race.html` trong profile QA. Thêm `--race --chrome --pid=<PID Chrome QA>`. `--single` chạy một lượt Tab; thêm `--delayed` cho focus trễ 150 ms. `--sample='vieetj '` kiểm Telex thay cho `nam`.
- Các khoảng nghỉ là yêu cầu của runner, không phải cam kết tốc độ vật lý: kiểm AX và vận chuyển sự kiện còn tốn thời gian. Trace HTML ghi thời gian DOM thực tế, chỉ trên các field fixture.

Bằng chứng nằm trong `reports/focus-race-2026-11-09/`; giữ cả red tests, lỗi UI trung gian, đối chứng ABC và các lượt bị ngắt. Không thay đổi GitHub.
