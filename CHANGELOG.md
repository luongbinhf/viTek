# Nhật ký Thay đổi (Changelog)

Mọi bản phát hành của **viTek** sử dụng quy tắc phiên bản **`YYYYMMDD.X.YYY`** (`macOS` / `GitHub Releases`) và dạng rút gọn bỏ số `0` đệm đầu (`YYYYMMDD.X.Y`) trên **iOS App Store Connect**.

---

## `20261125.1.002` *(iOS `20261125.1.2`)*

### Phân phối & Cập nhật macOS
- **Cập nhật 1 chạm xác minh SHA-256:** Nâng cấp `UpdateChecker` & **Cài đặt → Giới thiệu** để tải trực tiếp `.dmg` từ GitHub Releases, đối chiếu mã băm `SHA-256`, xác minh bundle `Cài viTek.app` và khởi chạy cập nhật nguyên tử.
- **Homebrew Cask chính thức:** Bổ sung `Casks/vitek.rb` và tự động sinh file cask chuẩn có mã `SHA-256` kèm tên tệp DMG chuẩn (`viTek-<version>.dmg`) trong workflow phát hành.

### Cộng đồng & Trang giới thiệu
- **GitHub Pages tương tác (`site/` + `.github/workflows/pages.yml`):** Trang giới thiệu trực quan kèm bộ gõ thử **Telex & VNI trực tiếp trên trình duyệt**, thông số hiệu năng Apple Silicon và liên kết tải phiên bản mới nhất.
- **Bộ tài liệu Open Source song ngữ:** Thêm `README.en.md`, `SECURITY.md`, `CHANGELOG.md`, cập nhật `docs/INSTALL.md` và mẫu Issue báo cáo trường hợp gõ tiếng Việt / tiếng Anh (`typing_case.md`).

### Trải nghiệm gõ macOS, iOS & Engine
- **HUD `VI ↔ EN` Liquid Glass (macOS):** Hiển thị chỉ báo nổi nhỏ (`ModeIndicatorPanel`, tự ẩn sau 0,65s) khi nhấn đúp `⌥` đổi nhanh chế độ Việt/Anh (có nút bật/tắt trong Cài đặt).
- **Công cụ chữ nhanh & Bàn phím cứng (iOS/iPadOS):** Thêm nút `Aa` trên thanh gợi ý bàn phím (`Sửa lỗi font`, `Bỏ dấu`, `CHỮ HOA`, `chữ thường`, `Viết Hoa Đầu Từ`, `Unicode NFC`) và hỗ trợ gõ tiếng Việt/Telex/VNI trực tiếp trên **bàn phím cứng / Magic Keyboard** (`pressesBegan`, phím `Esc` hoàn tác thô).
- **Khử mơ hồ Anh–Việt & Từ vựng:** Mở rộng ngữ cảnh `TypingHabits` (`been`, `soon`, `noon`, `lose` cùng các từ gợi ý tiếng Việt không dấu an toàn) và bổ sung cụm từ thông dụng vào `BuiltinVocabulary`.

---

## `20261125.1.001` *(iOS `20261125.1.1`)*

- Ra mắt công khai **viTek** theo giấy phép **MIT Open Source** trên kho mới `luongbinhf/viTek` với quy tắc phiên bản **`YYYYMMDD.X.YYY`**.
- Thiết kế linh vật **Cú Lạc viTek**, biểu tượng ứng dụng macOS (`AppIcon.icns`) và iOS (`1024×1024` không alpha).
- Khung cài đặt `.DMG` kéo thả trực quan với nền Retina đa phân giải, phím tắt `Applications` và giao diện SwiftUI làm mới trên macOS, iOS & iPadOS.
