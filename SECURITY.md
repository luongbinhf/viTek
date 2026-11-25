# Chính sách Bảo mật & Quyền riêng tư (Security Policy)

## Cam kết cốt lõi

**viTek** là bộ gõ tiếng Việt chạy **100% cục bộ trên thiết bị**:

- **Không thu thập văn bản đang gõ:** Toàn bộ xử lý Telex/VNI, chính tả, gõ tắt và gợi ý từ/Emoji (`VitekEngine`, `VitekSession`) thực thi hoàn toàn trong tiến trình của bộ gõ, không gửi dữ liệu gõ phím ra máy chủ bên ngoài.
- **iOS / iPadOS (`RequestsOpenAccess = false`):** Bàn phím hoạt động đầy đủ ngay cả khi người dùng tắt *Cho phép truy cập đầy đủ*.
- **macOS (`InputMethodKit`):** Không cài đặt global keylogger (`CGEventTap`) để gõ tiếng Việt. Quyền Trợ năng (`Accessibility`) hoàn toàn tuỳ chọn và chỉ dùng để đọc toạ độ con trỏ hiển thị thanh gợi ý trong Chromium/Electron.
- **Cập nhật xác minh SHA-256:** Chức năng kiểm tra và tải bản cập nhật từ GitHub Releases luôn kiểm tra mã băm **SHA-256** và định danh bundle của `Cài viTek.app` trước khi mở bộ cài.

## Phiên bản được hỗ trợ

| Phiên bản | Trạng thái |
|---|---|
| Mới nhất (`YYYYMMDD.X.YYY` trên nhánh `main`) | Được hỗ trợ & vá lỗi bảo mật |
| Các bản phát hành cũ hơn | Không còn nhận bản vá riêng (vui lòng cập nhật bản mới nhất) |

## Báo cáo lỗ hổng bảo mật

Vui lòng **không** mở Issue công khai cho các lỗ hổng bảo mật (chèn mã, vượt sandbox, rò rỉ dữ liệu bộ nhớ đệm/clipboard, giả mạo bản cập nhật).

Thay vào đó, hãy gửi báo cáo riêng tư qua **GitHub Security Advisories**:
- Truy cập: https://github.com/luongbinhf/viTek/security/advisories/new
- Đính kèm phiên bản macOS/iOS, số phiên bản viTek (`VERSION`), mô tả cách tái hiện và mức độ ảnh hưởng.

Chúng tôi sẽ phản hồi xác nhận trong vòng **48 giờ** và phát hành bản vá kèm ghi nhận người báo cáo (nếu bạn đồng ý).
