<div align="center">

<p>
  <img src="assets/brand/vitek-logo.png" alt="Logo viTek" width="96" height="96">
  &nbsp;&nbsp;&nbsp;
  <img src="assets/brand/vitek-mascot.png" alt="Linh vật viTek (Cú Lạc)" width="112" height="112">
</p>

# viTek

**Bộ gõ tiếng Việt 100% Swift 6 Native · Mã nguồn mở cho hệ sinh thái Apple**

**🇻🇳 Tiếng Việt** | **[🇬🇧 English](README.en.md)**

[Trang chủ & Gõ thử](https://luongbinhf.github.io/viTek/) · [Tải về](https://github.com/luongbinhf/viTek/releases) · [Tài liệu](docs/README.md) · [Bảo mật](SECURITY.md) · [Changelog](CHANGELOG.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-0B66E4.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B%20%7C%20iOS%20%26%20iPadOS%2026%2B-053A8F.svg)](#cài-đặt-nhanh)
[![Swift](https://img.shields.io/badge/Swift-6.0%20Strict-F05138.svg)](Package.swift)
[![Release](https://img.shields.io/badge/Release-20261125.1.002-F7B529.svg)](https://github.com/luongbinhf/viTek/releases)
[![Live Demo](https://img.shields.io/badge/GitHub%20Pages-Gõ%20thử%20trực%20tuyến-16A34A.svg)](https://luongbinhf.github.io/viTek/)

</div>

---

**viTek** là bộ gõ tiếng Việt **100% Swift 6 Native** dành riêng cho **macOS 14+** và **iOS / iPadOS 26+**. Lõi xử lý (`VitekEngine`) và phiên soạn thảo (`VitekSession`) dùng chung hoàn toàn trên thiết bị — không cầu nối FFI, không cần quyền Trợ năng để gõ, không thu thập hay gửi văn bản đang gõ ra ngoài.

Gõ thử chuỗi `vieetj vie65t reset server userName github.com ` → kết quả mong đợi: **`việt việt reset server userName github.com `**.

## Vì sao chọn viTek? (6 Ưu điểm cốt lõi)

1. **100% Swift 6 Native — Không cầu nối FFI:** Một lõi thuần Swift duy nhất cho macOS, iOS và iPadOS; kiểm tra nghiêm ngặt `SWIFT_STRICT_CONCURRENCY = complete` với 0 cảnh báo.
2. **Gõ không cần quyền Trợ năng (macOS) & Không cần Full Access (iOS):** Không cài đặt `CGEventTap` toàn cục (không rủi ro keylogger); bàn phím iOS hoạt động đầy đủ kể cả khi tắt *Cho phép truy cập đầy đủ* (`RequestsOpenAccess = false`).
3. **Bảo vệ Tiếng Anh & Code thông minh:** Giữ nguyên hơn **304 từ tiếng Anh** thông dụng, khử mơ hồ theo ngữ cảnh (`been`, `soon`, `noon`, `lose`, `as`/`á`) và **Smart Token Bypass** cho `camelCase`, `snake_case`, URL, email, `self.view`.
4. **Ổn định trên Web, Chrome & Electron:** Giao thức `DocumentSession` xác minh vùng UTF-16 trước khi sửa chữ, tương thích inline autocomplete trên Chrome/Safari/Spotlight và không dùng Backspace giả.
5. **Tốc độ dưới micro-giây trên Apple Silicon:** Lõi gõ phím **0,88 µs** p50 (**2,54 µs** p99); gợi ý từ & Emoji cục bộ **20,5 µs** p50 (**72,9 µs** p99) — nhanh hơn >100× một khung hình 120Hz.
6. **Mã nguồn mở MIT, Dữ liệu sạch & Cập nhật SHA-256:** Không sao chép mã hay từ điển của bộ gõ khác ([SOURCES.md](SOURCES.md)); hỗ trợ cập nhật 1 chạm có xác minh mã băm **SHA-256**.

## Tính năng chính

| Nhóm | Tính năng & Hành vi nổi bật |
|---|---|
| **1. Bộ gõ Song ngữ Thông minh** | Tự nhận **Telex & VNI** theo từng từ · Chuyển nhanh **`VI ↔ EN`** 0 ms (`⌥⌥` kèm **HUD Liquid Glass** trên macOS / phím `VI/EN` trên iOS) · Đặt dấu tự do, kiểu dấu mới (`hoà`) / cũ (`hòa`), tuỳ chọn gõ tắt phụ âm đầu/cuối · Sửa từ vừa chốt · Bấm **`Esc`** hoàn tác ngay về phím gốc · Tự tắt tiếng Việt theo app (Terminal, iTerm2, Warp, Ghostty, Alacritty, Kitty) & **Apple Focus Filter** |
| **2. Gõ tắt, Gợi ý Từ/Emoji & iCloud** | Giữ kiểu chữ hoa (`ko` / `Ko` / `KO`), mẫu nhiều dòng, biến động **`{{date}}` / `{{time}}` / `{{datetime}}`**, gõ tắt cả khi tắt tiếng Việt, nhập **viTek / UniKey / OpenKey / CSV** · Kho gợi ý cục bộ + tìm kiếm **Emoji tiếng Việt có dấu / không dấu** + học tần suất cá nhân (`PersonalFrequency`) · Đồng bộ tuỳ chọn & gõ tắt macOS ↔ iOS qua iCloud |
| **3. Công cụ Chuyển mã & Hệ sinh thái Apple** | `TextConverter` thuần Swift tự nhận diện & sửa lỗi font (**`VNI Windows` / `TCVN3` → `Unicode NFC`**), chuẩn hoá NFC, bỏ dấu, đổi **`CHỮ HOA` / `chữ thường` / `Viết Hoa Đầu Từ`** qua menu Clipboard macOS, nút **`Aa`** trên bàn phím iOS và **Apple Shortcuts** · Tích hợp **Apple Intelligence** (`FoundationModels`), Interactive Widgets & Control Center |
| **4. Bàn phím iOS & iPadOS Thích ứng** | Bố cục **gõ một tay (trái / phải)** khi cầm dọc · **Chia đôi bàn phím (Split Keyboard)** hai cụm ngón cái khi xoay ngang & trên iPad · **Vuốt xuống phím chữ** gõ nhanh số/ký hiệu · Hỗ trợ **bàn phím cứng / Magic Keyboard** (`pressesBegan`) · Tự tối ưu cho ô URL/Email, phím Return theo ngữ cảnh, giữ **`⌫`** xoá liên tục, kéo **Dấu cách** di chuyển con trỏ |

> **Ghi chú quyền Trợ năng (macOS):** Gõ tiếng Việt, sửa từ vừa chốt và tự tắt tiếng Việt theo ứng dụng **không cần** quyền Trợ năng. Quyền này chỉ cần nếu bạn bật thanh gợi ý từ trong Chrome/Electron để đọc toạ độ con trỏ qua `AccessibilityCaret`.

## Cài đặt nhanh

<div align="center">
  <img src="assets/brand/dmg-background@2x.png" alt="Khung cài đặt DMG trực quan của viTek" width="600">
</div>

- **macOS (Homebrew Cask):**
  ```sh
  brew tap luongbinhf/vitek https://github.com/luongbinhf/viTek
  brew install --cask luongbinhf/vitek/vitek
  ```
- **macOS (.DMG trực quan):** Tải `viTek-20261125.1.002.dmg` tại [GitHub Releases](https://github.com/luongbinhf/viTek/releases), kéo **Cài viTek** vào `Applications` rồi mở một lần để bật nguồn nhập **viTek** (`🌐` hoặc `⌃ Space`). Xem thêm [hướng dẫn macOS](docs/INSTALL.md).
- **Build từ mã nguồn (macOS):** `CONFIGURATION=Release scripts/install_dev.sh` (yêu cầu Apple Silicon, Xcode SDK macOS 26+ và XcodeGen).
- **iPhone & iPad:** Tạo project Xcode bằng `xcodegen generate --spec Apps/iOS/project.yml`, build lên thiết bị hoặc xem [hướng dẫn App Store / TestFlight](docs/APPSTORE.md), sau đó bật **viTek** trong **Cài đặt → Cài đặt chung → Bàn phím → Bàn phím**.

## Quy tắc phiên bản (`YYYYMMDD.X.YYY`) & Hiệu năng

- **Định dạng phát hành:** `YYYYMMDD` (ngày phát hành) · `X` (đợt phát hành trong ngày) · `YYY` (số build 3 chữ số trên macOS/GitHub Releases, vd. **`20261125.1.002`**; tự động bỏ số `0` đệm đầu trên iOS App Store Connect: **`20261125.1.2`**).

```sh
scripts/version.sh check                  # Kiểm tra đồng bộ macOS, iOS và Casks/vitek.rb
swift test                                # Chạy toàn bộ unit tests
swift run vitek "Tooi yeeu tieengs Vieetj"
swift run -c release vitek-bench          # Benchmark lõi gõ phím (Apple Silicon: 0,88 µs p50 / 2,54 µs p99)
swift run -c release vitek-prediction-bench # Benchmark gợi ý cục bộ (20,5 µs p50 / 72,9 µs p99)
scripts/release.sh --local                # Đóng gói DMG local kiểm thử
```

## Cấu trúc dự án

| Đường dẫn | Trách nhiệm |
|---|---|
| `Sources/VitekEngine` | Chính tả tiếng Việt, Telex/VNI, khử mơ hồ Anh–Việt & Smart Bypass (Swift thuần, không Foundation) |
| `Sources/VitekSession` | `DocumentSession`, `InputSession`, gõ tắt động, gợi ý từ, `EmojiSuggestions`, `PersonalFrequency` & `TextConverter` |
| `Sources/vitek-*` | CLI (`vitek`), benchmark phím (`vitek-bench`), benchmark gợi ý (`vitek-prediction-bench`) & công cụ từ vựng |
| `Apps/macOS` | Host InputMethodKit (`viTek`), HUD `VI ↔ EN`, cửa sổ Cài đặt Liquid Glass, `UpdateChecker` SHA-256 & `viTekInstaller` |
| `Apps/iOS` | App `viTekMobile`, bàn phím `viTekKeyboard` (công cụ `Aa`, bàn phím cứng, Split/1 tay), `viTekWidgets` & `UITests` |
| `Apps/Shared` | Apple Intelligence (`WritingView`), `AppIntents`, `CloudSettingsSync`, `IOSKeyboardSettings`, `BrandMascot`, `PrivacyInfo.xcprivacy` |
| `Tests` | Unit tests Engine/Session/Repository, Cocoa harness, Installer smoke test & kiểm thử tương thích macOS |
| `Casks` & `site` | Homebrew Cask (`Casks/vitek.rb`) & trang chủ GitHub Pages tương tác (`site/`) |
| `assets/brand` & `scripts` | Bộ nhận diện Cú Lạc + Logo + nền DMG Retina (`assets/brand/`) & script build/đóng gói/kiểm tra phiên bản |
| `docs` | Kiến trúc, đặc tả engine, UX, cài đặt, hướng dẫn App Store, lộ trình & ma trận tương thích |

## Đóng góp & Giấy phép

Hoan nghênh mọi đóng góp và báo lỗi — xem [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), [PRIVACY.md](PRIVACY.md) và [mục lục tài liệu](docs/README.md).

**viTek** được phát hành mã nguồn mở theo **[Giấy phép MIT](LICENSE)** (`Copyright © 2026 Binh Luong / viTek Contributors`).
