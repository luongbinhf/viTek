# Cài viTek trên macOS

Bản build hiện tại dành cho máy Mac dùng chip **Apple Silicon**, chạy **macOS 14.0 (Sonoma)** trở lên. Để build từ mã nguồn, máy build cần Xcode SDK macOS 26+ và XcodeGen.

## Cách 1 — Cài từ DMG kéo thả trực quan

1. Tải `viTek-<version>.dmg` mới nhất tại [GitHub Releases](https://github.com/luongbinhf/viTek/releases).
2. Mở tệp `.dmg`, kéo **Cài viTek** sang **Applications** để lưu trên máy, rồi mở **Cài viTek**.
3. Bộ cài kiểm tra chữ ký bundle, cài nguyên tử `viTek.app` vào `~/Library/Input Methods/` và bật nguồn nhập **viTek**. Nếu macOS hỏi cho phép dùng nguồn nhập mới, hãy đồng ý.
4. Khi thấy **Đã cài và bật viTek thành công!**, gõ thử `vieetj` hoặc `vie65t` rồi nhấn dấu cách để ra “việt”, sau đó bấm **Hoàn tất**.

> **Lưu ý Gatekeeper (khi dùng bản ad-hoc chưa gắn Developer ID):** Nếu macOS báo tệp tải từ Internet không xác minh được nhà phát triển, kéo **Cài viTek** vào `Applications` rồi chạy lệnh sau một lần trong Terminal trước khi mở:
> ```sh
> xattr -dr com.apple.quarantine "/Applications/Cài viTek.app"
> ```

## Cách 2 — Cài bằng Homebrew Cask

```sh
brew tap luongbinhf/vitek https://github.com/luongbinhf/viTek
brew install --cask luongbinhf/vitek/vitek
```

Sau khi cài xong, mở **Cài viTek** trong `/Applications` một lần để kích hoạt nguồn nhập tiếng Việt.

## Cách 3 — Build từ mã nguồn

1. Mở Terminal tại thư mục dự án, nơi có tệp `Package.swift`.
2. Chạy `xcodebuild -version` và `xcodegen --version` để kiểm tra công cụ (cài XcodeGen bằng `brew install xcodegen`).
3. Chạy `CONFIGURATION=Release scripts/install_dev.sh` để cài bản tối ưu vào `~/Library/Input Methods/viTek.app`.
4. Nếu macOS chưa tự bật nguồn nhập, vào **Cài đặt hệ thống → Bàn phím → Nhập văn bản**, chọn **Sửa… → +**, tìm **viTek** trong nhóm **Tiếng Việt** rồi thêm vào.

## Kiểm tra trong TextEdit

Chọn **viTek** trên thanh menu nguồn nhập (`🌐` hoặc `⌃ Space`), mở TextEdit và gõ `vieetj vie65t reset server ` → kết quả mong đợi là **`việt việt reset server `**. Trong **Cài đặt viTek → Thói quen gõ**, bạn có thể xem hoặc xóa điểm ưu tiên Telex/VNI đã học theo từng ứng dụng.

## Thanh gợi ý trong Chrome, Claude, Slack và VS Code

Để hiện thanh gợi ý từ ngay cạnh con trỏ trong các ứng dụng Chromium/Electron, mở **Cài đặt viTek… → Kiểu gõ**, bật **Gợi ý từ** rồi bấm **Cấp quyền…** (chỉ là tuỳ chọn để đọc vị trí con trỏ qua Trợ năng; gõ tiếng Việt bình thường không cần quyền này).

## Cập nhật và Gỡ bỏ

- **Cập nhật 1 chạm trong ứng dụng:** Mở **Cài đặt viTek… → Giới thiệu → Kiểm tra bản cập nhật…**, bấm **Cập nhật bản mới** để viTek tự tải DMG, xác minh mã **SHA-256** và mở **Cài viTek** cập nhật nguyên tử.
- **Cập nhật bằng DMG / Homebrew:** Mở DMG mới hoặc chạy `brew upgrade --cask vitek` rồi mở **Cài viTek**; mọi cấu hình, gõ tắt và thói quen đã lưu được giữ nguyên.
- **Gỡ cài đặt:** Chuyển sang nguồn nhập khác (ABC), xoá viTek khỏi **Cài đặt hệ thống → Bàn phím → Nhập văn bản**, sau đó xoá `/Applications/Cài viTek.app` và `~/Library/Input Methods/viTek.app` (hoặc chạy `brew uninstall --zap --cask vitek`).

## Tạo DMG phát hành

- `scripts/release.sh --local`: đóng gói DMG ký ad-hoc `dist/viTek-<version>-local.dmg` cho máy dev.
- `scripts/release.sh --adhoc`: đóng gói DMG ký ad-hoc `dist/viTek-<version>.dmg` và sinh chữ ký `SHA-256`.
- `scripts/release.sh`: đóng gói bản ký Developer ID + Notarization (`DEVELOPER_ID_APPLICATION`, `DEVELOPMENT_TEAM`, `NOTARY_PROFILE`).
