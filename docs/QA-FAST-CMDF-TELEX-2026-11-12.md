# Cmd+F nhả nhanh và Telex rút gọn — 12/11/2026

Bản Release `2026.0.003` đã cài tại `~/Library/Input Methods/viTek.app`. Bản cuối đạt **220 ca UI, 992 assertion, 80 lần nhận gợi ý, 5.168 cặp key-down/up và 1.532 sự kiện modifier**, không retry Cmd+F. Kiểm trên VS Code **1.146.0**, Chrome **157.0.8103.52**, trong cửa sổ/profile QA riêng. Không thực hiện thao tác GitHub.

## Hành vi mới

- `viw` → `viê` trong lúc soạn; `viwtj` → `việt`, `viwts` → `viết`.
- Hỗ trợ `vietwj` → `việt`; cách Telex chuẩn `vieetj` vẫn giữ nguyên.
- `s` vẫn là dấu sắc và có thể đặt trước/sau `w`; chữ hoa theo nguyên âm, không theo modifier.
- `viww` → `viw`, `vieww` → `view`; Backspace xoá chữ đang hiển thị. Quy tắc `aw/ow/uw`, VNI và giữ từ tiếng Anh vẫn được kiểm.
- Tuỳ chọn **Gõ nhanh iê bằng w** mặc định bật, có thể tắt riêng ở Cài đặt → Telex (`quickTelexW`). Từ chưa hoàn chỉnh vẫn theo chính sách khôi phục chính tả khi kết thúc từ.

## Nguyên nhân và thay đổi

### Cmd+F nhả nhanh

Bản trước kiểm Command còn đang giữ để tránh callback IMK trùng đến muộn. Khi nhả toàn bộ shortcut trong khoảng 1 ms, callback đến lúc Command đã nhả nên không chốt trước F; host coi F là sự kiện composition. Chốt vô điều kiện lại có thể cắt ngang từ mới. Phân tích host và các phương án đã loại nằm trong [báo cáo trước](QA-CMDF-2026-11-12.md).

Bản này theo dõi riêng `flagsChanged` bằng CGEventTap trên luồng riêng: mỗi chuyển trạng thái Command lên → xuống có một generation. IMK sử dụng mỗi lần nhấn đúng một lần, không phụ thuộc trạng thái phím tại thời điểm callback; khi keyDown tiếp theo đã đến hoặc controller được kích hoạt lại, generation cũ hết hiệu lực. Tap trả nguyên sự kiện, không nhận phím chữ, không phát lại shortcut và không gọi client từ luồng tap.

Máy kiểm đã có quyền hệ thống cần thiết. Khi không tạo được tap, bộ gõ dùng lại điều kiện Command còn giữ; **ca nhả nhanh chưa được bảo đảm ở môi trường không có tap**. Không tự mở hộp thoại xin quyền. Kiểm logic gồm callback trùng, nhả trước callback, modifier khác, lần nhấn tiếp theo và invalidation khi keyDown tới.

VS Code tự cập nhật trong quá trình QA. Đã đối chứng lại trên cùng **1.146.0**: bản viTek trước sửa vẫn đỏ ở vòng 3, Find không mở và chữ `viêt` được giữ. Bản cuối qua cùng ca với cả Command trái/phải. Không thay binary hoặc keybindings của host.

### Mất tiền tố và mất từ trước Space

Trace Chrome ghi nhận `v` → `vi` → `vie` → `viê` rồi bị thay thành `t`. Log cho thấy offset composition cũ là 1, trong khi caret mới chạy từ 0; giới hạn chờ cache 500 ms hết tại ký tự tiếp theo. Đây là lỗi sản phẩm, không phải phím công cụ bị bỏ.

`DocumentSession` giờ giữ bằng chứng từ hai lần mark/caret cùng tiến một lượng để suy ra vị trí tương đối. Frame đã biết còn đang chờ nhận phải được xét trước vị trí tạm suy ra: nếu đổi vị trí quá sớm, một frame con trỏ cũ trước Space có thể khiến `nam` bị xoá. Hai test hồi quy với `NSTextView` thật và adapter mô phỏng đúng cache/việc Chromium bỏ qua replacement range đều đã đỏ trước sửa, xanh sau sửa. Vị trí suy ra không cho phép ghi vào vùng tuyệt đối; vẫn dùng mark thuộc host. Các test di chuyển caret trong từ vẫn đạt.

Một lượt đối chứng trên bản trung gian còn trả `vieệt ` trong VS Code. Không đủ trace để gán riêng nguyên nhân cho lượt này; giữ log trong báo cáo, không tính là đạt. Sau bản sửa frame cuối, cùng ma trận và chuỗi kết thúc bằng caret rồi chạy lại đều qua.

### Độ tin cậy của runner

- Phím được phát bằng CGEvent virtual key code qua luồng hệ thống, có modifier trái/phải; không paste hay Unicode injection. Mỗi lượt bắt buộc qua đối chứng Telex/VNI `việt việt `.
- Guard đúng PID/cửa sổ trước từng phím; app khác lên trước thì dừng, không tính là lỗi sản phẩm hay lượt đạt.
- Chrome F4 reset có token xác nhận qua Accessibility; giá trị rỗng cũ không còn được coi là reset xong.
- Find được xoá rồi xác nhận rỗng trước khi gõ, tránh kết quả giống lượt trước làm assertion kết thúc sớm. Chrome có thể trả focus về trang khi đóng Find; runner kiểm đúng element gốc và chờ Find đóng trước khi đặt focus để kiểm caret.
- Kiểm nhận gợi ý đợi cả panel và nội dung candidate qua Accessibility. Log một lượt nhận gợi ý thất bại trước thay đổi này được giữ; không dùng retry để biến nó thành lượt đạt.
- Sau khi VS Code mở Release Notes, runner kiểm đúng editor fixture trước khi xoá/gõ.

## Kết quả bản cuối

| Nhóm | Ca | Assertion | Gợi ý nhận | Retry Cmd+F |
|---|---:|---:|---:|---:|
| VS Code, 10 vòng × 7 ca | 70 | 252 | 40 | 0 |
| Chrome, 10 vòng × 7 ca | 70 | 252 | 40 | 0 |
| VS Code Cmd+F trái, nhanh nhất | 20 | 82 | 0 | 0 |
| VS Code Cmd+F phải, nhanh nhất | 20 | 82 | 0 | 0 |
| Chrome Cmd+F trái, nhanh nhất | 20 | 162 | 0 | 0 |
| Chrome Cmd+F phải, nhanh nhất | 20 | 162 | 0 | 0 |

Ma trận gồm burst Telex/VNI, gõ rút gọn `w`/`s`/`j`/chữ hoa, thay selection rồi Backspace, đổi ô, chuỗi gợi ý, hoàn tất API và di chuyển caret. Ca Cmd+F riêng kiểm chữ cũ còn đúng một lần và gõ ngay ở Find; Chrome còn kiểm caret sau đóng Find. Tổng **90 lần Cmd+F mở Find lần đầu**: 50 VS Code, 40 Chrome.

Ca riêng có `--key-pause-us=0 --modifier-hold-ms=0`: không thêm thời gian chờ trước F hay giữ Command sau F-up; key-down/up cách khoảng 1 ms. Ma trận chạy khoảng nghỉ thêm 0/1/5 ms giữa các phím. Đây là thông số phát sự kiện, không phải đo thời gian xử lý bên trong host.

- Swift Package: **175 tests** đạt (Session 117, Engine 56, Repository 2).
- Command press gate: **20.008 assertion** đạt; KeyMap: **20 function keys + 18 biến thể modifier** đạt.
- Release host và installer build với warnings-as-errors đạt; chữ ký strict/deep hợp lệ, hash bản cài trùng payload.
- Diagnostics tắt; gợi ý bật; không còn log thăm dò `[DEBUG-*]` trong source host.

SHA-256 executable:

```text
836975c44d72708e2898ccfa665cf39827359b3e684e1e8fde8a670ca7489ee8
```

Bằng chứng: [reports/qa-fast-cmdf-2026-11-12](../reports/qa-fast-cmdf-2026-11-12/). Chỉ sáu file `final-*.log` được cộng vào tổng 220 ca; các bản trung gian, ca đỏ và lượt thăm dò giữ riêng.

## Chạy lại

```sh
zsh scripts/build_input_qa.sh
open -g -W -n -o /tmp/qa.log build/QAInputDriver.noindex/viTekInputQA.app --args --stress --rounds=10 --pid=<QA_CODE_PID> --wait-focus --physical-modifiers --modifier-hold-ms=0
```

Thêm `--chrome` và PID Chrome QA để chạy ma trận trang `Tests/macOSCompatibility/focus-race.html` (reload trang nếu mới cập nhật fixture). Ca riêng: `--case=focus` cho VS Code, `--case=shortcut` cho Chrome; thêm `--key-pause-us=0 --rounds=20`, và `--right-command` để kiểm Command phải. `--case=quick` kiểm riêng gõ rút gọn.

`open` trả mã 0 không chứng minh QA đạt; phải có dòng `STRESS QA PASSED`. Không suy rộng số đạt này thành bảo đảm cho mọi ứng dụng, quyền hệ thống hoặc tải máy.
