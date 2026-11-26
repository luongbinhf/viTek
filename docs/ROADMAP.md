# Lộ trình phát triển viTek

Mỗi bản phát hành chính thức được gắn tag theo chuẩn [phiên bản `YYYYMMDD.X.YYY`](ARCHITECTURE.md#8-phiên-bản) kèm kiểm thử tự động và quy trình kiểm duyệt nguồn gốc sạch ([SOURCES.md](../SOURCES.md)).

## Đã hoàn thành

### `20261126.1.003` — Tinh gọn Toàn diện macOS/iOS, Hiệu năng Runtime & Bảo vệ Từ ngắn Lập trình
- [x] Thiết kế lại popup Clipboard (`⌃⌥V`) & công cụ chữ/AI (`⌃⌥A`) sang kiến trúc `@Observable` 1 cột cố định (0 lần resize khi nhấn `↑`/`↓` hay di chuột), cố định kích thước `ModeIndicatorPanel` (`0 ms`), lược bỏ cập nhật thừa ở `SuggestionPanel` và lọc khoá bí mật/API token tự động trong `ClipboardMonitor`.
- [x] Tinh gọn Cài đặt macOS (7 → 5 mục: *Bộ gõ, Gõ tắt, Clipboard, Từ điển, Giới thiệu*) và đồng bộ tối giản trên iOS (`ViTekApp`); tối ưu tra cứu ứng dụng loại trừ `O(1)` (`Set<String>`) và gom (debounce/coalesce) ghi `UserDefaults` trong `SettingsStore`.
- [x] Bảo vệ thêm các từ ngắn hay xung đột Telex (`docs`, `cors`, `diff`, `buff`, `seen`/`boom`) và mở rộng `vitek-eval` lên 42 trường hợp đạt **100%** (`p50: 0,92 µs`, `p99: 1,96 µs`).

### `20261126.1.001` — Chống đảo phím >100 WPM, Gõ lướt `GlideDecoder`, iPad Pro Layout & Kiểm định App Store
- [x] Khôi phục hoán vị phím tốc độ cao (`smartTypoRecovery` trong `VitekEngine`: `tieegns` → `tiếng`, `mihnf` → `mình`, `nguiowf` → `người`) bảo toàn tuyệt đối từ tiếng Anh.
- [x] Bộ giải mã gõ lướt nối chữ tiếng Việt thuần Swift (`GlideDecoder`) kèm vệt sáng Liquid Glass 120Hz, bố cục **iPad Pro đầy đủ** (`Tab`, `;/:`, `, / !`, `. / ?`, tự thu gọn trong Floating Keyboard) và nâng cấp `TypingWidget` iOS 26.
- [x] Đồng bộ 100% Liquid Glass cho `ShortcutsPage` & `Cài viTek.app` trên macOS, bổ sung `scripts/verify_appstore.sh` và `scripts/run_keyboard_lab.sh`.

### `20261125.1.005` — Bộ Render Bàn phím iOS 26 Liquid Glass 120Hz & Thiết kế lại Ứng dụng iOS
- [x] Kiến trúc lại `KeyboardViewController` sang render khung trực tiếp (`< 0,5 ms`, 0 Auto Layout), tái sử dụng bộ nhớ phím (`LiquidKeyCapButton` + `shadowPath`), phản hồi chạm `0 ms`, hỗ trợ trượt chọn phím và bóng phóng đại `UIGlassEffect`.
- [x] Căn chỉnh công thái học chuẩn Apple iOS 26: đồng nhất bề rộng phím chữ cả 3 hàng, đưa viên nang `VI/EN` & công cụ nhanh lên thanh trên để mở rộng phím **Dấu cách chính giữa**, loại bỏ nghẽn IPC `UIPasteboard` và `CoreML` trên luồng chính.
- [x] Thiết kế lại toàn diện ứng dụng `ViTekApp` & `WritingView` theo chuẩn iOS 26 Liquid Glass (`tabBarMinimizeBehavior(.onScrollDown)`, thẻ `.glassEffect`, `GlassEffectContainer` và huy hiệu màu Cài đặt).

### `20261125.1.004` — Nhân gõ nâng cao, ANE + Apple Intelligence trên máy, Clipboard Swift 27 & iPhone Duo
- [x] Chuyển đổi hai chiều mượt `uô ↔ ươ`, gõ nhanh `yw`/`uyw` → `yê`/`uyê` và bộ đo lường chất lượng tự động `vitek-eval`.
- [x] Tích hợp mô hình **ANE Core ML (`20 KB`)** phân loại ngữ cảnh câu song ngữ ngoài luồng phím nóng, `SemanticRanker` xếp hạng ngữ nghĩa dài hạn và 5 chế độ **Apple Intelligence `@Generable`**.
- [x] Bảng tác vụ nhanh tại con trỏ **`⌃⌥A`** (`QuickActionPanel`), tự động gợi ý gõ tắt từ cụm hay gõ (`SuggestedShortcut`), làm mới giao diện **Clipboard Liquid Glass Swift 27** (`GlassCornerStyle.rounded(16)`, `GlassEffectContainer`) và tư thế bàn phím gập **iPhone Duo** (`KeyboardPosture`).

### `20261125.1.003` — Quản lý Clipboard, Đồng bộ iCloud mở rộng & Tiên đoán 3-từ
- [x] `ClipboardHistory` thuần Swift tìm kiếm không dấu, `ClipboardMonitor` bỏ qua mật khẩu, popup Liquid Glass **`⌃⌥V`** macOS, tab Clipboard + phím **`📋`** trên bàn phím iOS.
- [x] Mở rộng `CloudSettingsSync`: đồng bộ mẫu Clipboard ghim, tuỳ chọn Clipboard gần đây và bộ nhớ từ vựng cá nhân `1–3` từ qua iCloud.
- [x] Tiên đoán **Trigram 3 từ**, **gợi ý mở rộng gõ tắt trực tiếp** và phím chọn nhanh **`⌥ Space`** trên macOS.

### `20261125.1.002` — Phân phối, Trang chủ tương tác & Nâng cấp trải nghiệm gõ
- [x] **Homebrew Cask** chính thức (`Casks/vitek.rb`) + tự động xuất bản tệp cask có `SHA-256` trên GitHub Releases.
- [x] **Cập nhật 1 chạm xác minh `SHA-256`** ngay trong **Cài đặt viTek → Giới thiệu** (`UpdateChecker`).
- [x] **Trang chủ GitHub Pages** (`https://luongbinhf.github.io/viTek/`) tích hợp ô **gõ thử Telex/VNI trực tiếp** trên trình duyệt và bộ tài liệu cộng đồng chuẩn (`README.en.md`, `SECURITY.md`, `CHANGELOG.md`).
- [x] **HUD nổi `VI ↔ EN` Liquid Glass** trên macOS (`ModeIndicatorPanel`) khi nhấn đúp `⌥ Option`.
- [x] **Công cụ chữ nhanh (`Aa`)** và hỗ trợ **bàn phím cứng / Magic Keyboard** (`pressesBegan`) trên bàn phím iOS/iPadOS.
- [x] Mở rộng từ vựng gợi ý (`BuiltinVocabulary`) và khử mơ hồ Anh–Việt theo ngữ cảnh (`been`, `soon`, `noon`, `lose`).

### `20261125.1.001` — Khởi chạy Open Source (MIT) & Bộ nhận diện mới
- [x] Chuyển sang giấy phép **MIT Open Source** với lịch sử commit sạch tại kho công khai `luongbinhf/viTek`.
- [x] Lõi **Swift 6 Native** dùng chung (`VitekEngine` + `VitekSession`), không cầu nối FFI, hỗ trợ Telex/VNI tự động, Smart Token Bypass, `DocumentSession` xác minh UTF-16, gõ tắt động, gợi ý từ/Emoji cục bộ, `TextConverter` và tích hợp Apple Intelligence / Widgets / Focus Filter.
- [x] Thiết kế linh vật **Cú Lạc viTek**, biểu tượng ứng dụng macOS/iOS mới, khung cài đặt `.DMG` Retina kéo thả trực quan và làm mới giao diện macOS / iOS / iPadOS.

---

## Lộ trình tiếp theo

- [ ] **Ký số & Notarization macOS chính thức:** Cấu hình Apple Developer ID + `notarytool` trên GitHub Actions để tệp `.DMG` mở trực tiếp trên macOS mà không hiện cảnh báo Gatekeeper.
- [ ] **Phát hành TestFlight & App Store (iOS / iPadOS):** Kết nối chứng chỉ `Apple Distribution` và khóa App Store Connect API cho quy trình [APPSTORE.md](APPSTORE.md) để đẩy bản phát hành mới nhất lên TestFlight và App Store.
- [ ] **Từ điển tần suất tiếng Việt giấy phép sạch:** Tích hợp thêm dữ liệu tần suất hợp chuẩn để tăng độ chính xác khi khử mơ hồ giữa từ tiếng Anh ngắn và tiếng Việt có dấu.
- [ ] **Tự động hóa ảnh chụp App Store & kiểm thử mở rộng:** Tự động xuất ảnh màn hình từ UI Tests (iPhone dọc/ngang, iPad Pro Split Keyboard) và mở rộng kiểm thử trên nhiều trình soạn thảo Chromium/Electron hơn ([COMPATIBILITY.md](COMPATIBILITY.md)).
