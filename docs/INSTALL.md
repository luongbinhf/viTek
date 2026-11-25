# Cài viTek trên macOS

Bản build hiện tại dành cho máy Mac dùng chip Apple silicon, chạy macOS 13 trở lên. Để build từ mã nguồn, máy dùng để build cần Xcode có SDK macOS 26 trở lên và XcodeGen.

## Cài từ DMG

1. Mở tệp DMG và nhấp đúp **Cài viTek**. Bộ cài chép viTek vào thư mục nguồn nhập của tài khoản hiện tại rồi yêu cầu macOS bật viTek.
2. Nếu macOS hỏi có cho phép dùng nguồn nhập mới, chọn cho phép. Khi thấy **Đã bật viTek**, gõ thử `vieetj` hoặc `vie65t`, nhấn dấu cách rồi chọn **Xong**. Bạn có thể tháo DMG.

viTek tự nhận Telex và VNI. Muốn chỉnh dấu, gõ tắt hoặc gợi ý, mở **Cài đặt viTek…** từ menu nguồn nhập lúc cần. Nếu macOS chưa bật nguồn nhập, bộ cài có nút **Mở cài đặt Bàn phím** và **Thử lại**.

## Cài từ mã nguồn

1. Mở Terminal tại thư mục dự án, nơi có tệp `Package.swift`.
2. Chạy `xcodebuild -version` và `xcodegen --version` để kiểm tra công cụ. Nếu thiếu XcodeGen và đã có Homebrew, chạy `brew install xcodegen`.
3. Để dùng hằng ngày, chạy `CONFIGURATION=Release scripts/install_dev.sh` để cài bản tối ưu cho Apple silicon. Khi thành công, Terminal in dòng `Installed` và đường dẫn tới `~/Library/Input Methods/viTek.app`.
4. Lệnh cài đăng ký, chọn viTek và xác nhận server phản hồi đúng phiên bản/đường dẫn. Nếu macOS hỏi bật nguồn nhập, cho phép rồi thử lại.
5. Nếu macOS chưa nhận viTek, trong **Cài đặt hệ thống → Bàn phím → Nhập văn bản**, chọn **Sửa…**, bấm **+**, tìm **viTek** trong nhóm **Tiếng Việt** rồi thêm nguồn nhập. Chỉ đăng xuất/đăng nhập nếu nguồn nhập vẫn chưa xuất hiện sau các bước này.

## Kiểm tra trong TextEdit

Mở một tài liệu mới và chọn **viTek** trong menu nguồn nhập của macOS. Gõ `vieetj vie65t reset server` rồi nhấn dấu cách. Kết quả là **việt việt reset server**. Trong **Cài đặt viTek → Thói quen gõ**, bạn có thể xóa các điểm ưu tiên viTek đã học theo ứng dụng.

## Thanh gợi ý trong Chrome, Claude, Slack và VS Code

Để hiện gợi ý cạnh con trỏ, mở **Cài đặt viTek… → Kiểu gõ**, bật gợi ý rồi chọn **Cấp quyền…**. Bật viTek trong **Quyền riêng tư & Bảo mật → Trợ năng** của macOS. Quyền này là tuỳ chọn cho việc định vị thanh gợi ý. Bạn có thể gõ tiếng Việt khi chưa cấp quyền.

## Cập nhật và gỡ

- **Cập nhật từ DMG.** Mở DMG mới rồi chạy **Cài viTek**. Bộ cài kiểm bản mới, rời phiên nhập cũ, chờ server dừng rồi thay ứng dụng nguyên tử; giữ các tùy chọn và gõ tắt đã lưu. Sau đó kiểm server mới trả lời đúng phiên bản và đường dẫn trước khi báo đã bật.
- **Cập nhật bản dev.** Chạy lại lệnh cài ở bước 3 từ mã nguồn mới. Nếu một cửa sổ Chrome hoặc Electron đang mở vẫn chưa nhận phím qua viTek, chọn lại viTek trong chính cửa sổ đó. Nếu vẫn chưa được, thoát ứng dụng rồi mở lại.
- **Gỡ.** Chuyển sang nguồn nhập khác, bỏ viTek khỏi danh sách nguồn nhập ở mục Bàn phím. Trong Finder, nhấn **Command + Shift + G**, nhập `~/Library/Input Methods/`, chuyển `viTek.app` vào Thùng rác rồi đăng xuất và đăng nhập lại.


## Tạo DMG

Dùng `scripts/release.sh --local` để tạo DMG ký ad-hoc cho máy phát triển. Bản phân phối dùng `scripts/release.sh` với Developer ID và hồ sơ notarization như ghi ở đầu script. DMG và mã SHA-256 nằm trong `dist/`.

Từ 2026.0.003, script dev dùng cùng đường cập nhật với bộ cài, không `pkill` viTek hay dừng menu nguồn nhập. Lỗi cài đặt trả về mã lỗi và thông báo; bản cài không bị xoá trước khi payload mới đã được kiểm. Handshake xác nhận server đang sống, còn ô gõ thử xác nhận việc nhận phím trong ứng dụng. Một client giữ kết nối cũ có thể vẫn cần chọn lại nguồn nhập hoặc mở lại ứng dụng; các ô hạn chế nguồn nhập cần kiểm riêng.
