# Lộ trình phát triển viTek

Mỗi bản phát hành chính thức được gắn tag theo chuẩn [phiên bản `YYYYMMDD.X.YYY`](ARCHITECTURE.md#8-phiên-bản) kèm kiểm thử tự động và quy trình kiểm duyệt nguồn gốc sạch ([SOURCES.md](../SOURCES.md)).

## Đã hoàn thành

### `20261125.1.001` — Khởi chạy Open Source (MIT) & Bộ nhận diện mới
- [x] Chuyển sang giấy phép **MIT Open Source** với lịch sử commit sạch tại kho công khai `luongbinhf/viTek`.
- [x] Lõi **Swift 6 Native** dùng chung (`VitekEngine` + `VitekSession`), không cầu nối FFI, hỗ trợ Telex/VNI tự động, Smart Token Bypass, `DocumentSession` xác minh UTF-16, gõ tắt động, gợi ý từ/Emoji cục bộ, `TextConverter` và tích hợp Apple Intelligence / Widgets / Focus Filter.
- [x] Thiết kế linh vật **Cú Lạc viTek**, biểu tượng ứng dụng macOS/iOS mới, khung cài đặt `.DMG` Retina kéo thả trực quan và làm mới giao diện macOS / iOS / iPadOS.

### `20261125.1.002` — Phân phối, Trang chủ tương tác & Nâng cấp trải nghiệm gõ
- [x] **Homebrew Cask** chính thức (`Casks/vitek.rb`) + tự động xuất bản tệp cask có `SHA-256` trên GitHub Releases.
- [x] **Cập nhật 1 chạm xác minh `SHA-256`** ngay trong **Cài đặt viTek → Giới thiệu** (`UpdateChecker`).
- [x] **Trang chủ GitHub Pages** (`https://luongbinhf.github.io/viTek/`) tích hợp ô **gõ thử Telex/VNI trực tiếp** trên trình duyệt và bộ tài liệu cộng đồng chuẩn (`README.en.md`, `SECURITY.md`, `CHANGELOG.md`).
- [x] **HUD nổi `VI ↔ EN` Liquid Glass** trên macOS (`ModeIndicatorPanel`) khi nhấn đúp `⌥ Option`.
- [x] **Công cụ chữ nhanh (`Aa`)** và hỗ trợ **bàn phím cứng / Magic Keyboard** (`pressesBegan`) trên bàn phím iOS/iPadOS.
- [x] Mở rộng từ vựng gợi ý (`BuiltinVocabulary`) và khử mơ hồ Anh–Việt theo ngữ cảnh (`been`, `soon`, `noon`, `lose`).

---

## Lộ trình tiếp theo

- [ ] **Ký số & Notarization macOS chính thức:** Cấu hình Apple Developer ID + `notarytool` trên GitHub Actions để tệp `.DMG` mở trực tiếp trên macOS mà không hiện cảnh báo Gatekeeper.
- [ ] **Phát hành TestFlight & App Store (iOS / iPadOS):** Kết nối chứng chỉ `Apple Distribution` và khóa App Store Connect API cho quy trình [APPSTORE.md](APPSTORE.md) để đẩy bản `20261125.1.2` lên TestFlight và App Store.
- [ ] **Từ điển tần suất tiếng Việt giấy phép sạch:** Tích hợp thêm dữ liệu tần suất hợp chuẩn để tăng độ chính xác khi khử mơ hồ giữa từ tiếng Anh ngắn và tiếng Việt có dấu.
- [ ] **Tự động hóa ảnh chụp App Store & kiểm thử mở rộng:** Tự động xuất ảnh màn hình từ UI Tests (iPhone dọc/ngang, iPad Pro Split Keyboard) và mở rộng kiểm thử trên nhiều trình soạn thảo Chromium/Electron hơn ([COMPATIBILITY.md](COMPATIBILITY.md)).
