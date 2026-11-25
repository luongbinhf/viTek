# Lộ trình

Mỗi mốc kết thúc bằng một bản build gắn tag theo [quy tắc phiên bản](ARCHITECTURE.md#8-phiên-bản). Mỗi tính năng mới có đặc tả và test trước khi vào sản phẩm.

## M0 — Khung dự án · `2026.0.001`

- [x] Repo, `SOURCES.md`, tài liệu kiến trúc và engine
- [x] Engine thuần Swift: chính tả, Telex/VNI, dấu tự do, huỷ, khôi phục từ không phải tiếng Việt, Backspace
- [x] `VitekSession` + `SimulatedTextField` + CLI `vitek`
- [x] Host macOS IMK tối thiểu, build Swift 6 strict concurrency
- [x] CI GitHub Actions: `scripts/version.sh check`, `swift test`, XcodeGen + `xcodebuild` với warning là lỗi (`.github/workflows/ci.yml`). Đã chạy các bước trên máy local; chưa chạy trên GitHub vì repo chưa có remote

## M1 — Gõ hằng ngày trên máy nhóm · `2026.0.0xx`

- [ ] Kiểm thử thủ công trên TextEdit, Safari, Chrome, Notes, Xcode, Terminal, VS Code, Slack; ghi mọi lỗi marked text kèm cách tái hiện. TextEdit đã qua: gõ dấu, đ, kiểu dấu mới, khôi phục `server`, Backspace giữa từ
- [x] Benchmark engine `vitek-bench`: p99 1,3–2,2 µs/phím, dưới ngân sách 50 µs khoảng 25 lần; làm nóng bảng tra lúc khởi động
- [x] Icon Input Source: PDF vector template, sắc nét ở mọi cỡ (`scripts/make_input_icon.swift`)
- [x] Menu nguồn nhập: kiểu dấu, chính tả, gõ tắt, mở cài đặt
- [x] Logo ứng dụng `AppIcon.icns` (nền trắng, phím "Vi" xanh; `make_app_icon.swift ... key`), hiện trong Finder và trang Giới thiệu
- [ ] Tên hiển thị tiếng Việt/Anh
- [x] Script cài đặt cho máy dev: `scripts/install_dev.sh` (build → `~/Library/Input Methods` → dừng tiến trình đang chạy)

## M2 — Bản công khai đầu tiên · `2026.1.001`

- [x] Cửa sổ cài đặt SwiftUI dạng thanh bên (Bắt đầu, Kiểu gõ, Thói quen gõ, Gõ tắt, Từ điển, Giới thiệu; docs/UX.md), lưu bằng `UserDefaults`, áp dụng từ từ tiếp theo
- [x] Gõ tắt: bảng quản lý trong cài đặt, bật/tắt
- [x] Gõ tắt: nhập/xuất tệp văn bản (ARCHITECTURE §9)
- [x] Tự nhận Telex/VNI theo từ, học điểm ưu tiên từ các từ đã chốt theo ứng dụng
- [ ] Kiểm tra gõ tự động, lưu và xóa thói quen trong nhiều ứng dụng macOS thật
  - TextEdit 1.21, macOS 27.2 — người dùng chọn viTek và gõ tay `vieetj vie65t`, hai từ đều thành “việt” sau dấu cách.
  - Chrome 156.0.8078.80, macOS 27.2 — gửi từng phím `vieetj vie65t reset server ` vào textarea của trang HTML cục bộ, đọc lại được `việt việt reset server `.
  - VS Code 1.143.1, macOS 27.2 — người dùng gõ tay cùng chuỗi trong editor và xác nhận `việt việt reset server`. Khi công cụ gửi phím vào cửa sổ nền, cả VS Code và TextEdit từng trả kết quả khác với thao tác gõ trực tiếp.
  - Trên bản macOS đã cài, trang **Thói quen gõ** hiện 3 ứng dụng. Bấm **Xóa thói quen đã học** đưa bộ đếm về 0, vô hiệu hóa nút và xóa khóa `typingScores` trong UserDefaults. Sau khi học lại, giao diện và kho lưu cùng ghi nhận 1 ứng dụng. Nút xóa áp dụng cho mọi ứng dụng.
  - Kiểm tra riêng với hai hồ sơ thử và cùng giao diện cài đặt: một tiến trình mới đọc lại hai cách gõ `as` thành `á` và `as`. Sau khi xóa qua giao diện, tiến trình mới đọc được 0 hồ sơ và cả hai trả về `as`.
  - Khi gõ tay người dùng báo `server á`. Có thể tái hiện bằng lõi Release đang cài với điểm Telex ban đầu +3. Trên bản mã nguồn có xét từ liền trước, `server as` giữ nguyên và `vieetj as` thành `việt á` ở cả ba mức điểm thử −2, 0, +3. Cần kiểm lại hai chuỗi này trong ứng dụng thật khi cập nhật bản cài.
- [ ] Ký Developer ID, notarize, DMG: `scripts/release.sh` đã có; chưa chạy với danh tính và tài khoản notarize thật
- [ ] Sparkle + appcast: cần khoá EdDSA mới của chủ dự án
- [x] [Hướng dẫn cài đặt bản macOS từ mã nguồn](INSTALL.md)

## M3 — Thông minh hơn

- [x] Giữ nguyên từ tiếng Anh thông dụng khi gõ Telex (`test`, `reset`, `boss`), bật/tắt trong cài đặt
- [ ] Từ điển tần suất tiếng Việt có giấy phép sạch, để mở rộng danh sách từ tiếng Anh mà không lấy mất chữ Việt thông dụng
- [x] Sửa từ vừa chốt khi con trỏ đứng ngay sau từ (`resume` + `attributedSubstring` + `replacementRange`), bật/tắt trong Kiểu gõ
- [ ] Kiểm sửa từ vừa chốt trên Safari, Chrome, VS Code, Slack (các ứng dụng web và Electron có thể trả văn bản quanh con trỏ không chính xác)
- [x] Gợi ý từ: hoàn tất từ đang gõ và đoán từ tiếp theo bằng mô hình tiếng Việt có sẵn của macOS (`NSSpellChecker`), chạy trên máy; từ 2026.0.003 chỉ ⌥1–⌥5, Tab luôn tới ứng dụng
- [x] Lịch sử: đã thử gõ trực tiếp không gạch chân (`DirectEditor`). Từ `2026.0.002`, thay bằng native marked composition để giữ nguyên từ khi mất readback; gạch chân chỉ là kiểu hiển thị
- [x] `2026.0.002`: mọi ứng dụng dùng cùng native marked composition; bỏ danh sách phân loại ứng dụng cho cơ chế gõ
- [x] Kiểm khả năng đọc lại ngay ở ô trống; fallback theo lần kích hoạt, không ghi nhớ lỗi theo cả ứng dụng; chặn vùng UTF-16 không hợp lệ (2026-11-04)
- [x] Tái hiện mất readback giữa từ trên Cocoa bằng routing cũ; sửa bằng native writer và thêm test Telex/VNI, Backspace, thay vùng chọn, chốt hai lần
- [ ] Chạy toàn bộ [ma trận tương thích](COMPATIBILITY.md) trên `2026.0.002` trong ứng dụng thật; ghi riêng kết quả từng ứng dụng
- [x] Thanh gợi ý dùng Liquid Glass (macOS 26+); thanh nằm cùng dòng sau con trỏ khi ở cuối dòng
- [x] Kiểm marked text trong Electron (DeepSeek Harness): gõ được, gạch chân mảnh, không nền xanh; nhật ký chẩn đoán xác nhận từng phím
- [x] Kiểm trong Claude: gõ được sau khi mở lại Claude (Claude đã chạy suốt các lần viTek bị dừng); nhật ký chẩn đoán xác nhận kích hoạt và marked text
- [x] Lịch sử: Electron gõ trực tiếp trong DeepSeek Harness; bản `2026.0.002` dùng native composition thống nhất
- [x] Chromium/Electron không báo vị trí con trỏ khi gõ trực tiếp (`firstRect` trả rác, khung dòng chỉ chỗ bất kỳ, đã đo): thanh gợi ý lấy vị trí qua Trợ năng (`AccessibilityCaret`); chưa có quyền thì không hiện thanh
- [x] Kiểm thanh gợi ý qua Trợ năng trong DeepSeek Harness: nằm ngay sau con trỏ khi gõ dở và sau dấu cách; quyền giữ qua các lần build dev (ký lại theo mã định danh, build vào thư mục `.noindex`)
- [ ] Kiểm thanh gợi ý qua Trợ năng trong Claude, Chrome; cần xác nhận thanh hiện ngay cả khi dừng gõ sau phím đầu. Khi cây Trợ năng chưa có ô đang gõ (-25212), viTek đã hẹn hỏi lại một lần sau 120 ms
- [x] Bản 2026.0.002: kiểm phím thực tế Chrome 156 và VS Code 1.143.1, Telex/VNI/Anh, đổi thanh và Backspace; Chrome còn qua đổi ô giữa từ (xem COMPATIBILITY.md)
- [x] `2026.0.002`: kiểm ô nháp Claude, DeepSeek Harness, Antigravity, Grok Bot và Cursor; Telex/VNI, đổi thanh, Backspace và chốt từ đạt (xem COMPATIBILITY.md)
- [ ] Kiểm Qoder khi hộp thoại hệ thống không giữ tiêu điểm; lượt hiện tại chưa hợp lệ. Slack chưa có trên máy trong danh sách Electron đã kiểm
- [x] `2026.0.002`: native composition cập nhật `viêt` → `việt` ngay trước Space trên input Chrome và editor VS Code; chưa khái quát sang mọi editor Chromium
- [ ] Ứng dụng Chromium/Electron không tự nối lại với viTek sau khi viTek khởi động lại (khi cập nhật): tìm cách để chúng nối lại mà không phải mở lại
- [x] Gợi ý Emoji thuần Swift theo từ khoá Việt/Anh tích hợp vào `VitekSession` (dùng chung macOS & iOS)
- [x] Đồng bộ cài đặt & gõ tắt qua iCloud (`NSUbiquitousKeyValueStore`) và hỗ trợ nhập gõ tắt UniKey / OpenKey / CSV
- [x] Bản địa hoá song ngữ Việt/Anh bằng String Catalog (`Apps/Shared/Localizable.xcstrings`)

## M4 — Bàn phím iOS

- [x] Keyboard extension dùng `VitekSession` để tự nhận Telex/VNI, gợi ý từ & emoji cục bộ, gõ tắt, rung/âm phím hệ thống, giữ Xoá để xoá liên tục, kéo Dấu cách di chuyển con trỏ và đồng bộ cài đặt qua App Group
- [x] App chứa extension với hướng dẫn bật bàn phím, ô gõ thử, màn hình Cài đặt & quản lý Gõ tắt
- [x] [Kiểm trực tiếp trên Simulator iOS 27](../Apps/iOS/KeyboardTests/README.md): Telex/VNI, chốt bằng dấu cách, sửa giữa từ, gõ đè vùng chọn và đổi qua lại giữa hai ô nhập
- [x] Bảng chọn Emoji (`😀`) có thanh tìm kiếm từ khoá tiếng Việt có dấu / không dấu (`🔍`)
- [ ] Kiểm trên iPhone thật khi đổi ô nhập, di chuyển con trỏ và chuyển sang bàn phím khác giữa từ
- [x] Tách cấu hình phiên bản `Apps/iOS/Config/Version.xcconfig` bỏ số 0 đệm đầu (`2026.1.3`) để tuân thủ quy tắc App Store Connect, giữ `2026.1.003` cho macOS
- [x] Công cụ chuyển mã thuần Swift `TextConverter` (NFC, bỏ dấu, VNI Windows, TCVN3) trên menu Clipboard macOS & Apple Shortcuts, kèm Apple Focus Filter (`VitekFocusFilter`) và kiểm tra cập nhật GitHub Releases 1 chạm

## M5 — Mở nguồn công khai (MIT Open Source) · `20261125.1.001`

- [x] Chuyển sang giấy phép **MIT License**, làm mới lịch sử commit sạch trên kho công khai `luongbinhf/viTek` và quy tắc phiên bản mới `YYYYMMDD.X.YYY` (`20261125.1.001` macOS / `20261125.1.1` iOS).
- [x] Thiết kế lại bộ nhận diện thương hiệu: linh vật **Cú Lạc viTek** + biểu tượng ứng dụng macOS (`AppIcon.icns`) & iOS (`1024×1024` RGB không alpha).
- [x] Khung cài đặt `.DMG` kéo thả trực quan phong cách Docker / GitHub / Google (nền Retina `@1x`/`@2x` đa phân giải `dmg-background.tiff`, phím tắt `Applications`, biểu tượng ổ đĩa tuỳ chỉnh và layout Finder tự động).
- [x] Làm mới giao diện SwiftUI cho `viTekInstaller`, `SettingsWindow` (macOS) và `viTekMobile` (iOS/iPadOS) tích hợp linh vật Cú Lạc & liên kết mã nguồn mở.

## 2026.0.003 — Giao dịch sửa chữ và kết nối nguồn nhập

- [x] `DocumentSession` dùng chung trong host macOS và harness Cocoa: vùng UTF-16 có xác minh, chữ đã chốt trước Space khi host hỗ trợ đọc văn bản, native fallback khi không hỗ trợ.
- [x] Ca hồi quy: xoá sau khi chuyển con trỏ, chọn một phần từ, callback chốt tới muộn, đổi client, emoji, mất readback, ứng dụng tự sửa chữ và host giữ vùng chọn sau thay thế; frame cũ, xoá/gõ lại, sửa anchor native và chuyển từ qua Space.
- [x] Điều hướng/mouse-down/đổi focus giữ cách viết đang hiển thị, không tự mở rộng gõ tắt hoặc trả phím thô.
- [x] GUI và dev installer dùng chung đường cập nhật nguyên tử, dừng phiên cũ trước thay bundle, không force-kill menu agent.
- [x] Handshake nonce + phiên bản + đường dẫn server; kiểm hai tiến trình thật, từ chối phiên bản và đường dẫn sai; CLI xử lý đúng run loop nhận phản hồi.
- [x] Trang thử có ô tìm kiếm nhận committed input và gợi ý trước Space.
- [ ] Xác nhận đầy đủ bằng thao tác người dùng trong Chrome, Safari, Electron; tách lỗi công cụ gửi phím/tiêu điểm khỏi lỗi bộ gõ.
- [ ] Xác định từng nguyên nhân viTek bị xám; không xem nguồn nhập được chọn hoặc handshake server là bằng chứng mọi ô nhập đã hoạt động.
