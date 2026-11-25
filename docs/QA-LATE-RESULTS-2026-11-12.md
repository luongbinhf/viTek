# Gợi ý đến muộn và timeout bộ cài — 12/11/2026

Đã tự kiểm bằng phím hệ thống trên VS Code và Chrome, sửa một edge case của handshake, cài lại Release và kiểm nhận gợi ý trên cả hai host. Không thực hiện thao tác GitHub.

## Gợi ý đến muộn trên UI

Dùng bản Debug từ cùng source với Release. Hook `Diagnostics.delaySuggestionDelivery` cố ý chờ ngay cả khi tác vụ đã bị hủy, mô phỏng dịch vụ trả kết quả muộn. Các ca đổi ô/caret dùng 2.000 ms; ca đảo thứ tự giữ request cũ ở 2.000 ms và cho request mới trả về sau 300 ms.

| Ca | VS Code | Chrome |
|---|---|---|
| Đối chứng: gõ `cow sowr duwx `, đợi panel rồi ⌥1 | `cơ sở dữ liệu ` | `cơ sở dữ liệu ` |
| Chuyển ô trong lúc đang chờ (Cmd+F / Tab) | Đạt | Đạt |
| Left trong lúc đang chờ | Đạt | Đạt |
| Left rồi Right về đúng caret ban đầu | Đạt | Đạt |
| Gõ tiếp `li`; kết quả mới 300 ms đến trước kết quả cũ 2 giây | Panel mới giữ nguyên, ⌥1 chèn đúng một lần | Panel mới giữ nguyên, ⌥1 chèn đúng một lần |

Ở ba ca hủy do focus/caret, bộ chạy quan sát cửa sổ panel mỗi khoảng 25 ms trong 2,5 giây, kiểm text không đổi và kiểm log xác nhận delivery đã trở về với `cancelled=true`. Ở ca đảo thứ tự, panel mới phải hiện trong tối đa 1 giây rồi tiếp tục hiện qua thời điểm request cũ hoàn tất; ⌥1 phải cho kết quả đúng. Không tái hiện lỗi gợi ý cũ quay lại trong các ca này; không sửa logic gợi ý khi chưa có bằng chứng lỗi.

Runner chỉ dùng virtual key codes qua HID event tap, kiểm foreground PID và cửa sổ fixture trước mỗi phím. Panel được quan sát qua danh sách cửa sổ on-screen của tiến trình viTek; kết quả chèn được đọc lại từ Accessibility của host. Positive control đồng thời xác nhận phím qua IME và panel thực sự có thể nhận được gợi ý. Không dùng riêng ID nguồn nhập làm bằng chứng. Các cửa sổ dùng profile QA riêng.

## Timeout và lỗi đã sửa

Mở rộng `Tests/InstallerSmoke/Check.swift` đã tái hiện lỗi:

```text
Cancelled expired handshake returned instead of throwing
```

Nguyên nhân: `InputMethodConnection.check` chỉ kiểm cancellation bên trong vòng lặp deadline. Với timeout bằng 0, vòng lặp không chạy và tác vụ đã hủy trả `false`, dễ bị diễn giải thành timeout. Đã kiểm cancellation trước khi tạo observer, sau khi nhận callback và trước khi trả timeout. Cùng regression chuyển từ đỏ sang xanh.

Smoke test cuối đạt:

- Responder khởi động sau 4 giây: lần kiểm đầu timeout ở 300 ms, lần tiếp theo kết nối thành công.
- Sai version và sai bundle path bị từ chối; timeout không kết thúc trước deadline.
- Hủy trước khi chạy và hủy với deadline đã hết đều ném `CancellationError`.
- Hai handshake đồng thời với nonce riêng đều thành công.
- Copy/update bundle trong thư mục tạm vẫn đạt, payload thiếu không phá bản cài hiện có.

Kiểm thêm trên **bundle thực sự đã cài**, bằng cùng `Installation.reconnect` mà GUI installer sử dụng:

1. Chuyển khỏi IME, dừng đúng tiến trình bản cài, reconnect: khởi động lạnh và handshake đạt.
2. Bật hook Debug `qaConnectionDropReplies`: reconnect báo đúng lỗi chưa nhận phản hồi sau **8,0297 giây**; executable trước/sau giống hệt.
3. Tắt hook: reconnect thành công.

Đây là kiểm đường xử lý dùng chung với GUI, không phải thao tác bấm nút Thử lại trên cửa sổ installer. Hook bỏ phản hồi chỉ tồn tại trong Debug và mặc định tắt. Hai khóa gây lỗi QA không có trong executable Release theo kiểm tra `strings`.

## Bản cuối và kiểm tra sau cài

- 160 Swift tests đạt (Session 106, Engine 52, Repository 2).
- Debug và Release build với warnings as errors đều thành công.
- Release đã cài tại `~/Library/Input Methods/viTek.app`; codesign strict/deep đạt.
- Khởi động lạnh + handshake của Release đạt.
- Release trên VS Code và Chrome: panel hiện và ⌥1 cho `cơ sở dữ liệu `, không dùng độ trễ QA.
- Đã khôi phục preferences ban đầu: diagnostics tắt, gợi ý bật; xóa khóa delay và drop-reply tạm.

SHA-256 executable Release `2026.0.003`:

```text
8d1e1cb21b250a32d8a16ddf9a3d02cf996beb3941090a863572ed8df755b6ed
```

## Chạy lại và bằng chứng

Log tại [reports/qa-2026-11-12-late](../reports/qa-2026-11-12-late/). File có `delayed-final` là kiểm UI Debug có độ trễ cưỡng bức; `release-*` là kiểm bản cài Release. Log đỏ chỉ thuộc regression trước sửa.

Build runner bằng `zsh scripts/build_input_qa.sh`, sau đó launch qua `open` để dùng quyền Trợ năng đã cấp:

```sh
open -W -n -o /tmp/vitek-suggestions.log build/QAInputDriver.noindex/viTekInputQA.app --args --suggestions --pid=<QA_CODE_PID>
open -W -n -o /tmp/vitek-suggestions-chrome.log build/QAInputDriver.noindex/viTekInputQA.app --args --suggestions --chrome --pid=<QA_CHROME_PID>
```

Phép thử trễ cần bản Debug, diagnostics và gợi ý bật. Thêm `--release-positive` để kiểm nhận gợi ý thông thường trên Release. Runner tự khôi phục giá trị delay trước đó sau lượt chạy.

Build smoke bằng `swiftc -swift-version 6 Apps/macOS/Installer/Installation.swift Apps/Shared/InputMethodConnection.swift Tests/InstallerSmoke/Check.swift -o /tmp/installer-smoke`, rồi truyền đường dẫn `viTekInstaller.app` đã build. `InstalledConnectionCheck.swift` thay cho `Check.swift` tạo phép kiểm chủ động restart bản cài; chỉ dùng `--debug-installed <path>` với Debug, hoặc `--release-installed <path>` để chỉ kiểm khởi động lạnh Release.
