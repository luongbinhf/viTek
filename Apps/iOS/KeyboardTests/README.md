# Kiểm thử bàn phím viTek trên Simulator

KeyboardLab là app thử riêng có hai ô `UITextField`. XCUITest nhấn từng nút của bàn phím viTek và đọc lại văn bản từ ô nhập, kể cả vị trí dấu cách. Nút **Move before last character** đặt con trỏ ngay trước ký tự cuối mà không đổi ô. Không dùng `typeText` vì thao tác đó không kiểm tra các phím của extension.

1. Từ gốc repo, chạy `xcodegen generate --spec Apps/iOS/project.yml` và `xcodegen generate --spec Apps/iOS/KeyboardTests/project.yml`.
2. Mở project `Apps/iOS/viTekMobile.xcodeproj`, chọn scheme **viTekMobile**, chạy bản cần thử trên Simulator.
3. Trong **Settings → General → Keyboard → Keyboards → Add New Keyboard**, bật **viTek**. Nếu vừa cài lại app, kiểm tra viTek vẫn nằm trong danh sách. Dùng bàn phím ảo của Simulator để các phím của extension xuất hiện trên màn hình.
4. Mở project `Apps/iOS/KeyboardTests/KeyboardLab.xcodeproj`, chọn scheme **KeyboardLab**, dùng đúng Simulator vừa bật viTek và chạy **Product → Test**. Để chạy bằng dòng lệnh, đặt `SIMULATOR_ID` bằng UDID của Simulator rồi chạy từ gốc repo:

   ```sh
   xcodebuild -project Apps/iOS/KeyboardTests/KeyboardLab.xcodeproj \
     -scheme KeyboardLab -destination "platform=iOS Simulator,id=${SIMULATOR_ID}" \
     -parallel-testing-enabled NO test
   ```

Bộ thử yêu cầu phím **Dấu cách** của viTek xuất hiện. Nếu chỉ thấy bàn phím hệ thống, chọn viTek bằng nút quả địa cầu và chạy lại.

Khi quay lại ô đầu, UIKit có thể tự chọn toàn bộ từ. Ca thử gõ nối đặt con trỏ ở cuối chữ trước khi nhấn dấu cách. Ca thử gõ đè chọn riêng `iệ` trong `việt`, nhấn `ddas` và yêu cầu kết quả là `vđát`.
