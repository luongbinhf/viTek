# Hướng dẫn phát hành viTek lên App Store (iOS / iPadOS)

> **Lưu ý về nền tảng:**
> - **iOS & iPadOS (`viTekMobile` + `viTekKeyboard` + `viTekWidgets`):** phát hành chính thức qua **TestFlight & App Store**.
> - **macOS (`viTek.app` / `viTekInstaller.app`):** bộ gõ dùng `InputMethodKit` (`~/Library/Input Methods`) không thể chạy trong App Sandbox của Mac App Store, nên phân phối qua **DMG ký Developer ID + Notarization** (`scripts/release.sh` và GitHub Releases).

---

## 1. Danh mục kiểm tra kỹ thuật đã chuẩn bị sẵn trong mã nguồn

- [x] **Số phiên bản chuẩn App Store Connect:** `Apps/iOS/Config/Version.xcconfig` tự động bỏ số `0` đệm đầu (`20261125.1.1` từ `VERSION` `20261125.1.001`).
- [x] **Biểu tượng ứng dụng:** `Apps/iOS/viTek/Assets.xcassets/AppIcon.appiconset/viTek.png` (`1024×1024`, không kênh alpha).
- [x] **Tuân thủ mã hoá xuất khẩu:** `ITSAppUsesNonExemptEncryption = false` trong `Apps/iOS/viTek/Info.plist`.
- [x] **Apple Privacy Manifest:** `Apps/Shared/PrivacyInfo.xcprivacy` khai báo `NSPrivacyTracking = false`, không thu thập dữ liệu, lý do truy cập `UserDefaults` (`CA92.1`, `1C8F.1`).
- [x] **Quyền ứng dụng (Entitlements):** App Group `group.io.github.luongbinhf.viTek` (dùng chung App, Keyboard và Widgets) + iCloud Key-Value Store (`com.apple.developer.ubiquity-kvstore-identifier`) cho `viTekMobile`.
- [x] **Quyền riêng tư bàn phím:** `RequestsOpenAccess = false` — hoạt động hoàn toàn trên thiết bị mà không yêu cầu người dùng bật *Cho phép truy cập đầy đủ*.
- [x] **Bộ ảnh Screenshot App Store tự động:** Chạy `./scripts/capture_appstore_screenshots.sh` để xuất đồng thời cả bản sạch nguyên bản (`dist/appstore-screenshots/raw/`) và bản kèm tiêu đề marketing (`dist/appstore-screenshots/framed/`) ở đúng kích thước chuẩn **iPhone 6.9"** (`1320×2868`) và **iPad Pro 13"** (`2064×2752`, PNG không kênh alpha).

---

## 2. Tạo bản ghi ứng dụng trên App Store Connect (làm 1 lần)

1. Đăng nhập [App Store Connect](https://appstoreconnect.apple.com) bằng tài khoản **Apple Developer Program** (gói trả phí \$99/năm).
2. Vào **Certificates, Identifiers & Profiles** (developer.apple.com):
   - Đăng ký App Group: `group.io.github.luongbinhf.viTek`.
   - Kiểm tra 3 Bundle ID (Xcode Automatic Signing có thể tự tạo khi archive):
     - `io.github.luongbinhf.viTek.mobile` (bật App Groups + iCloud Key-Value Storage)
     - `io.github.luongbinhf.viTek.mobile.keyboard` (bật App Groups)
     - `io.github.luongbinhf.viTek.mobile.widgets` (bật App Groups)
3. Trong **App Store Connect → My Apps → `+` New App**:
   - **Platform:** iOS (hỗ trợ cả iPhone & iPad)
   - **Name:** `viTek - Bộ gõ tiếng Việt` (hoặc `viTek`)
   - **Primary Language:** Vietnamese
   - **Bundle ID:** `io.github.luongbinhf.viTek.mobile`
   - **SKU:** `vitek-ios-2026`

---

## 3. Đóng gói & Tải bản build lên TestFlight / App Store Connect

### Cách A — Trực tiếp bằng Xcode Organizer (nhanh nhất trên máy Mac cá nhân)

```sh
# Thay XXXXXXXXXX bằng Apple Developer Team ID 10 ký tự của bạn
DEVELOPMENT_TEAM=XXXXXXXXXX scripts/archive_ios.sh
open build/viTekMobile-$(scripts/version.sh show).xcarchive
```

Trong **Xcode Organizer**, bấm **Distribute App → App Store Connect → Upload**.

### Cách B — Tự động hoàn toàn qua dòng lệnh bằng App Store Connect API Key

1. Trong **App Store Connect → Users and Access → Integrations → App Store Connect API**, tạo 1 khoá quyền **App Manager**, tải tệp `AuthKey_<KEY_ID>.p8` về `~/.appstoreconnect/private_keys/`.
2. Chạy một lệnh duy nhất:

```sh
DEVELOPMENT_TEAM=XXXXXXXXXX \
ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_YYYYYYYYYY.p8 \
ASC_KEY_ID=YYYYYYYYYY \
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
scripts/archive_ios.sh --upload
```

### Cách C — Tự động qua GitHub Actions (`.github/workflows/appstore.yml`)

Thêm 4 secrets vào **GitHub Repo → Settings → Secrets and variables → Actions**:
- `APPLE_TEAM_ID`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_PRIVATE_KEY_BASE64` (`base64 -i AuthKey_YYYYYYYYYY.p8 | pbcopy`)

Sau đó mở tab **Actions → App Store Connect (iOS / iPadOS) → Run workflow**.

---

## 4. Nội dung đăng tải App Store gợi ý (Copy & Paste)

### Tiếng Việt (Primary)
- **Tên:** `viTek - Bộ gõ tiếng Việt`
- **Phụ đề (≤ 30 ký tự):** `Telex & VNI thông minh, riêng tư`
- **Mô tả:**
  > viTek là bộ gõ tiếng Việt thuần Swift hiện đại dành cho iPhone và iPad, xử lý 100% trên thiết bị và hoạt động đầy đủ ngay cả khi tắt "Cho phép truy cập đầy đủ".
  >
  > **Tính năng nổi bật:**
  > - Tự động nhận diện Telex và VNI theo từng từ, hỗ trợ đặt dấu tự do, kiểu dấu mới (hoà) / cũ (hòa) và gõ tắt phụ âm.
  > - Gõ xen tiếng Anh & lập trình mượt mà: tự động bảo vệ hơn 300 từ tiếng Anh thông dụng, camelCase, snake_case, URL và email.
  > - Bố cục bàn phím thích ứng: chế độ gõ một tay trái/phải khi cầm dọc, chia đôi bàn phím (Split Keyboard) cho màn hình ngang & iPad, vuốt xuống phím chữ để gõ nhanh số và ký hiệu.
  > - Chuyển nhanh Việt ↔ Anh 1 chạm ngay trên bàn phím, tìm kiếm Emoji theo từ khoá tiếng Việt không dấu, bảng gõ tắt hỗ trợ biến ngày/giờ và đồng bộ iCloud.
  > - Tích hợp Apple Shortcuts (chuyển mã VNI/TCVN3/NFC, bỏ dấu), Focus Filter, Widget tương tác và Trung tâm điều khiển.
- **Từ khoá (≤ 100 ký tự):** `bo go tieng viet,telex,vni,ban phim tieng viet,vietnamese keyboard,go tat,split keyboard`
- **URL Chính sách quyền riêng tư:** `https://github.com/luongbinhf/viTek/blob/main/PRIVACY.md`
- **URL Hỗ trợ:** `https://github.com/luongbinhf/viTek/issues`

### Ghi chú cho đội ngũ App Review (Review Notes)
> viTek includes a custom Vietnamese keyboard extension (`viTekKeyboard`) with `RequestsOpenAccess = false`. All typing, spell-checking, shortcut expansion, and word/emoji suggestions run strictly on-device with zero network collection.
>
> **How to test:**
> 1. Enable the keyboard in **Settings → General → Keyboard → Keyboards → Add New Keyboard → viTek**.
> 2. Open the viTek app → **Keyboard** tab → tap the test field and switch to **viTek** via the Globe key.
> 3. Type `vieetj ` (Telex) or `vie65t ` (VNI) to produce `việt `.
> 4. Tap `VI`/`EN` to toggle Vietnamese/English mode; long-press `VI`/`EN` in portrait to cycle One-Handed mode, or rotate to landscape / test on iPad for Split Keyboard mode.
> 5. Tap `😀` → `🔍` and type `tim` to search Vietnamese emojis on-device.
