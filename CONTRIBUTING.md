# Đóng góp cho viTek

viTek là dự án **mã nguồn mở theo giấy phép [MIT](LICENSE)**. Mọi báo lỗi, cải tiến chính tả, tối ưu hiệu năng và Pull Request từ cộng đồng đều được chào đón. Vui lòng đọc [SOURCES.md](SOURCES.md) trước khi thêm dữ liệu hoặc thư viện mới để bảo đảm nguồn gốc sạch.

## Ranh giới module

- `VitekEngine` chỉ phụ thuộc thư viện chuẩn Swift.
- `VitekSession` chỉ phụ thuộc engine; quy tắc chỉnh văn bản và gợi ý có thể kiểm thử ngoài host.
- Host macOS/iOS chuyển sự kiện và thực thi lệnh của session. Logic vòng đời phải có kiểm thử hồi quy tại lớp dùng chung khi có thể.
- Duy trì cấu trúc thư mục hiện có; cập nhật XcodeGen khi đổi vị trí nguồn. Không commit `.xcodeproj` sinh tự động.

## Kiểm trước khi gửi thay đổi

```sh
scripts/version.sh check
swift test
xcodegen generate --spec Apps/macOS/project.yml
xcodebuild -project Apps/macOS/viTek.xcodeproj -scheme viTekInstaller \
  -configuration Debug -derivedDataPath build/DerivedData.noindex \
  CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

Khi sửa đường gõ, chạy thêm `swift run -c release vitek-bench`. Khi sửa host/gợi ý, kiểm trực tiếp theo [COMPATIBILITY.md](docs/COMPATIBILITY.md); ghi ứng dụng, phiên bản, phím gõ, kỳ vọng và kết quả. Không đánh dấu đạt nếu chỉ dán văn bản hoặc điền DOM.

Nếu sandbox chặn cache Swift, đặt `CLANG_MODULE_CACHE_PATH` và `SWIFTPM_MODULECACHE_OVERRIDE` vào thư mục tạm có quyền ghi. Các test Cocoa và build Xcode vẫn cần môi trường macOS phù hợp.

## iOS

```sh
xcodegen generate --spec Apps/iOS/project.yml
```

Mở `Apps/iOS/viTekMobile.xcodeproj`, chọn Simulator hoặc thiết bị. Với thiết bị thật, cấu hình nhóm ký ứng dụng. Xem [harness bàn phím iOS](Apps/iOS/KeyboardTests/README.md).

## Phiên bản và phát hành

`VERSION` là nguồn duy nhất. Dùng `scripts/version.sh bump build` khi chuẩn bị bản phát hành; không sửa riêng `Version.xcconfig`. Cài bản dev qua `CONFIGURATION=Release scripts/install_dev.sh`. Xem [INSTALL.md](docs/INSTALL.md) về DMG, ký và notarization.

## Báo lỗi

Dùng mẫu issue trong `.github/ISSUE_TEMPLATE`. Luôn ghi:

1. Phiên bản viTek, macOS/iOS, ứng dụng và loại ô nhập.
2. Chuỗi phím chính xác, vị trí con trỏ/vùng chọn và thao tác đổi focus.
3. Kết quả mong đợi và thực tế, tần suất tái hiện.
4. Nguồn nhập đang chọn, gợi ý bật/tắt, quyền Trợ năng nếu lỗi vị trí thanh.

Dùng dữ liệu giả. Không đính kèm nội dung công việc riêng tư, mật khẩu, token hoặc toàn bộ log hệ thống.
