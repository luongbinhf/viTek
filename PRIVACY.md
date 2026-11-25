# Chính sách Quyền riêng tư / Privacy Policy — viTek

*Cập nhật lần cuối / Last updated: 2026-11-25*

## Tiếng Việt

**viTek** được thiết kế với nguyên tắc quyền riêng tư tuyệt đối trên thiết bị:

1. **Không thu thập dữ liệu người dùng:** viTek không thu thập, không lưu trữ trên máy chủ bên ngoài và không chia sẻ bất kỳ văn bản nào bạn gõ, lịch sử gõ phím, hay thông tin định danh cá nhân nào.
2. **Xử lý 100% trên thiết bị:** Mọi thao tác gõ tiếng Việt (Telex/VNI), kiểm tra chính tả, mở rộng gõ tắt, chuyển mã văn bản, gợi ý từ/Emoji và Apple Intelligence đều chạy hoàn toàn cục bộ trên thiết bị của bạn.
3. **Không cần "Cho phép truy cập đầy đủ" trên iOS/iPadOS:** Phần mở rộng bàn phím `viTekKeyboard` khai báo `RequestsOpenAccess = false` và không có quyền truy cập mạng.
4. **Lưu trữ cục bộ & Đồng bộ iCloud tuỳ chọn:**
   - Tuỳ chọn kiểu gõ, bảng gõ tắt, danh sách từ ngoại lệ và bộ nhớ tần suất từ cục bộ (giới hạn 500 mục, có thể xoá bất cứ lúc nào trong Cài đặt) chỉ được lưu trong `UserDefaults` / App Group trên thiết bị.
   - Nếu bạn bật **Đồng bộ iCloud**, chỉ các tuỳ chọn kiểu gõ, bảng gõ tắt và danh sách từ ngoại lệ cá nhân được đồng bộ qua tài khoản Apple iCloud riêng của bạn (`NSUbiquitousKeyValueStore`). Văn bản đang gõ không bao giờ được đồng bộ.
5. **Không theo dõi (No Tracking):** viTek không tích hợp SDK quảng cáo hay phân tích của bên thứ ba (`NSPrivacyTracking = false`).
6. **Liên hệ:** Mọi thắc mắc về quyền riêng tư vui lòng gửi qua [GitHub Issues](https://github.com/luongbinhf/viTek/issues).

---

## English

**viTek** is built with strict on-device privacy by design:

1. **No Data Collection:** viTek does not collect, transmit to external servers, sell, or share any text you type, keystroke history, or personal identifiers.
2. **100% On-Device Processing:** All Vietnamese typing (Telex/VNI), spell-checking, shortcut expansion, text conversion, word/emoji suggestions, and Apple Intelligence writing features run entirely on your device.
3. **No Full Access Required on iOS/iPadOS:** The `viTekKeyboard` extension declares `RequestsOpenAccess = false` and has no network access.
4. **Local Storage & Optional iCloud Sync:**
   - Typing preferences, shortcuts, personal exception words, and on-device personal frequency counts (capped at 500 entries, clearable anytime in Settings) are stored solely in local `UserDefaults` / App Group storage.
   - If you enable **iCloud Sync**, only your typing settings, shortcuts, and exception words sync through your private Apple iCloud account (`NSUbiquitousKeyValueStore`). Typed text is never synced.
5. **No Tracking:** viTek includes no third-party analytics or advertising SDKs (`NSPrivacyTracking = false`).
6. **Contact:** For privacy questions, please open an issue at [GitHub Issues](https://github.com/luongbinhf/viTek/issues).
