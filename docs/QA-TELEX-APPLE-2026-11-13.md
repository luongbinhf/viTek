# QA Telex rút gọn và tích hợp Apple — 13/11/2026

## Phạm vi

Kiểm xung đột `w/s` với tiếng Anh, nhấn lặp, Backspace, gõ nhanh, chuyển ô, di chuyển con trỏ và nhận gợi ý trên VS Code/Chrome. Tích hợp Apple Intelligence, App Intents/Shortcuts, Writing Tools và widget iOS. Không push hay mở PR GitHub.

Môi trường: macOS 27.2 (26B123), Xcode 27.2, VS Code 1.146.0, Chrome 157.0.8103.52. iOS UI chạy trên Simulator iOS 27.0; deployment target của tính năng AI/widget là 26.0, có kiểm khả dụng thực tế của model/ngôn ngữ.

## Lỗi engine đã sửa

`view`, `views` trước sửa có thể hiện theo cách đọc tiếng Việt khi đang soạn; Backspace thao tác lên chuỗi ẩn thay vì chữ người dùng đang thấy. Chỉ khôi phục khi Space không sửa được lỗi này. Khi bật giữ tiếng Anh, `view` được giữ nguyên ngay trong composition; các hậu tố `views`, `viewer`, `viewing` giữ tiền tố đang thấy. Backspace từ `view` thành `vie`, từ `views` thành `view`; gõ lại không mất/lặp chữ. Nhấn `w` lần nữa vẫn hủy dấu như trước (`vieww` → `view`). `swiss` được bổ sung vào bảo vệ từ có phím thanh lặp, tránh mất một `s`.

`viw` → `viê`, `viwtj` → `việt`, `viwts` → `viết`, `vietwj` → `việt` vẫn hoạt động. Khi giữ tiếng Anh, `viewtj` được đọc nguyên văn; muốn dùng biến thể này cho `việt` phải tắt giữ tiếng Anh. Xem [đặc tả engine](ENGINE.md).

Ca tái hiện trước sửa có **22 assertion lỗi**; sau sửa toàn bộ **178 Swift tests** đạt (117 session, 59 engine, 2 repository). Các test bao gồm hai chế độ tự nhận/fixed Telex, chữ hoa, hậu tố tiếng Anh, hủy dấu, xóa và gõ lại. Bằng chứng: [đỏ](../reports/qa-telex-apple-2026-11-13/engine-red.log), [xanh](../reports/qa-telex-apple-2026-11-13/engine-green.log).

## Cmd+A nhanh và thứ tự callback

Ma trận Chrome phát hiện Cmd+A ngay sau `view⌫w` hoặc `view⌫` đôi lúc chỉ chốt composition, chưa chọn hết. DOM ghi `meta=true` cho `a`; không phải công cụ quên modifier. Log IMK cho thấy callback chữ thường đã nhìn thấy generation Command mới, rồi callback Command đầu tiên bị coi là đã xử lý.

Đã sửa gate để chỉ phím có Command mới xác nhận đã đi qua ranh giới shortcut. Callback chữ thường không được tiêu thụ lượt Command kế tiếp. Lịch sử 32 lần nhấn gắn timestamp giúp callback cũ không mượn lượt mới; trạng thái đã xử lý chỉ tiến, không lùi. Tap vẫn chỉ quan sát `flagsChanged`, không quan sát nội dung phím chữ. Đường không có quyền theo dõi modifier giữ fallback hiện có.

Hai ca đỏ độc lập kiểm phím cũ tiêu thụ lượt tương lai và callback chữ với timestamp mới; **20.017 assertion** xanh kiểm nhấn/nhả nhanh, callback lặp, callback đến sai thứ tự và giới hạn lịch sử. Bằng chứng: [thứ tự callback thực tế](../reports/qa-telex-apple-2026-11-13/command-callback-order.log), [ca đỏ](../reports/qa-telex-apple-2026-11-13/command-text-event-red.log), [ca xanh](../reports/qa-telex-apple-2026-11-13/command-green.log).

## Phân biệt công cụ với sản phẩm

Bộ chạy gửi keycode qua HID với Command trái/phải thực sự nhấn rồi nhả, đọc AX từ đúng PID/cửa sổ và có positive control `vieetj vie65t ` → `việt việt `. Không dùng paste/DOM fill làm bằng chứng IME. Đổi foreground/cửa sổ sẽ dừng trước phím kế tiếp.

Reset Chrome ban đầu dùng F4 để xóa DOM khi còn native composition, nên commit đến sau có thể ghi chữ trở lại. Bước dọn nay chọn hết bằng Cmd+A, đợi AX xác nhận toàn bộ vùng chọn, Backspace rồi đợi ô rỗng trước F4. Chính bước xác nhận này phát hiện lỗi Cmd+A nêu trên; không retry Cmd+A để che lỗi. [Log reset DOM](../reports/qa-telex-apple-2026-11-13/chrome-reset-dom-failure.log) và [log shortcut lỗi](../reports/qa-telex-apple-2026-11-13/chrome-command-red.log) được lưu riêng.

## Bản cài và kiểm UI cuối

Bản cài `2026.0.003` ở `~/Library/Input Methods/viTek.app`, ký ad-hoc local, hash SHA-256 executable:

```text
bb5a6955a52558ae4942420073bf476bc99c172bc3cbf809e5b00c3b51904984
```

Hash trùng payload cuối `/tmp/vitek-telex-1113-release-final/viTek.app`; `codesign --verify --deep --strict` đạt. Diagnostics đã tắt, gợi ý vẫn bật. Các lượt kiểm ban đầu và các lượt bị đổi foreground/đóng cửa sổ không cộng vào số đạt của bản cuối.

| Lượt trên bản cuối | Ca | Assertion | Nhận gợi ý | Retry shortcut |
|---|---:|---:|---:|---:|
| [VS Code, ma trận 10 vòng](../reports/qa-telex-apple-2026-11-13/vscode-final-matrix.log) | 80 | 782 | 40 | 0 |
| [Chrome, ma trận 10 vòng](../reports/qa-telex-apple-2026-11-13/chrome-final-matrix.log) | 80 | 1.073 | 40 | 0 |
| [VS Code, Command phải, nhả ngay](../reports/qa-telex-apple-2026-11-13/vscode-right-command.log) | 10 | 42 | 0 | 0 |
| [Chrome Find, Command phải, nhả ngay](../reports/qa-telex-apple-2026-11-13/chrome-right-command.log) | 10 | 93 | 0 | 0 |
| **Tổng** | **180** | **1.990** | **80** | **0** |

Ma trận gồm burst 10 từ, Telex rút gọn, tiếng Anh/lặp/Backspace, thay vùng chọn, chuyển ô, chuỗi gợi ý, API hoa và sửa giữa từ. Mỗi ca tiếng Anh có 11 từ kiểm lúc soạn + sau Space và 10 chuỗi xóa/gõ lại. Tốc độ nghỉ giữa phím luân phiên 0/1/5 ms; phím xuống giữ 1 ms. Command không giữ thêm sau shortcut. Có **30 lần Cmd+F thành công lần đầu**: 20 VS Code (trái/phải), 10 Chrome (phải). Kiểm này xác nhận các fixture và môi trường trên, không suy rộng thành mọi host/timing.

## Apple và hiệu năng

- macOS Release host + installer build thành công với warnings là lỗi; iOS app, keyboard và widget build thành công.
- Foundation Models trên máy Mac thật báo sẵn sàng tiếng Việt, sinh câu với **4 partial snapshots**, **47 ký tự**; `ContinueWritingIntent.perform()` trả kết quả thật. Kiểm URL, trạng thái khả dụng, giới hạn UTF-8, đoạn rỗng và hủy trước khi chạy đều đạt. [Log](../reports/qa-telex-apple-2026-11-13/apple-runtime.log).
- Cửa sổ macOS thật mở qua `vitek://writing`, hiển thị model sẵn sàng; nhập đoạn nháp cố định rồi bấm Gợi ý trả câu thật. Xóa nháp làm kết quả cũ biến mất và nút bị khóa lại. [Quan sát UI](../reports/qa-telex-apple-2026-11-13/macos-writing-ui.md).
- Metadata hai App Shortcuts tồn tại trên macOS và iOS. [Metadata kiểm chứng](../reports/qa-telex-apple-2026-11-13/app-intents-metadata.json).
- **3 XCTest UI iOS đạt**: tab viết hiển thị trạng thái model/nút khóa khi đoạn rỗng; URL mở tab viết khi app tắt/đang chạy; URL chứa query bị bỏ qua. [Log](../reports/qa-telex-apple-2026-11-13/ios-navigation.log).
- Installer smoke đạt: copy/update, timeout rồi reconnect, hủy deadline, nonce đồng thời, từ chối sai version/path. [Log](../reports/qa-telex-apple-2026-11-13/installer-smoke.log).
- Benchmark **52.400 phím**: p50 **0,71 µs**, p99 **2,96 µs**, trong ngân sách p99 < 50 µs. Đây là tốc độ engine/session, không phải độ trễ vẽ chữ của Chrome hay tốc độ AI. [Log](../reports/qa-telex-apple-2026-11-13/benchmark.log).

Siri bằng giọng nói, widget trên Home Screen và Neural Engine trên iPhone thật chưa được xác nhận. Không có ActivityKit Live Activity/Dynamic Island trong bản này; “cập nhật trực tiếp” hiện là streaming trong màn hình viết. Xem [phạm vi tích hợp Apple](APPLE-INTEGRATION.md).
