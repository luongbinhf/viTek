# Kiểm tra tương thích gõ tiếng Việt trên macOS, iOS & iPadOS

## Kiến trúc tương thích

- **`DocumentSession` (xác minh vùng UTF-16):** Ưu tiên chèn chữ đã chốt bằng `insertText` khi đọc lại được chính xác vùng chọn và văn bản đang sở hữu, giúp các ô tìm kiếm, omnibox trình duyệt và trình soạn thảo phản hồi ngay mà không cần chờ dấu cách. Không dùng Backspace giả lập hay phát lại phím.
- **`NativeCompositionWriter` (đường tương thích native):** Khi ứng dụng không đọc lại được văn bản (như một số ô WebView/Terminal/Electron), viTek chuyển mượt sang `setMarkedText` / `insertText` chuẩn của Cocoa `IMKTextInput` và giữ khung đối chiếu có giới hạn khi renderer cập nhật bất đồng bộ.
- **`CommandModifierMonitor`:** Khi có quyền hệ thống phù hợp, tap chỉ đọc `flagsChanged` (không đọc phím chữ) để chốt từ kịp thời trước các tổ hợp `⌘` nhả nhanh như `⌘F`, `⌘C`, `⌘S`.
- **`AccessibilityCaret`:** Chỉ dùng (tuỳ chọn) để đọc toạ độ con trỏ hiển thị thanh gợi ý trong các ứng dụng Chromium/Electron. Việc gõ tiếng Việt không cần quyền Trợ năng.
- **iOS & iPadOS (`UIInputViewController`):** Hỗ trợ đầy đủ cả bàn phím cảm ứng lẫn bàn phím cứng / Magic Keyboard qua `pressesBegan` (`Esc` hoàn tác thô).

Tham chiếu giao thức:
- [Apple — IMKInputController.replacementRange()](https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller/replacementrange())
- [Chromium — RenderWidgetHostViewCocoa](https://raw.githubusercontent.com/chromium/chromium/main/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm)

---

## Kiểm thử tự động

Chạy toàn bộ bộ kiểm thử lõi, phiên soạn, chính tả, gợi ý, Clipboard và kiểm tra định dạng phiên bản:

```sh
scripts/version.sh check
swift test
```

Khi môi trường sandbox giới hạn ghi bên ngoài thư mục dự án:

```sh
mkdir -p .build/task-module-cache .build/task-cache
CLANG_MODULE_CACHE_PATH="$PWD/.build/task-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/task-module-cache" \
swift test --disable-sandbox --cache-path "$PWD/.build/task-cache"
```

Biên dịch host và bộ cài macOS (coi cảnh báo là lỗi):

```sh
xcodegen generate --spec Apps/macOS/project.yml
xcodebuild -project Apps/macOS/viTek.xcodeproj -scheme viTekInstaller \
  -configuration Debug -derivedDataPath build/Compatibility.noindex \
  CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

Kiểm tra cài đặt nguyên tử và handshake hai tiến trình thật: `Tests/InstallerSmoke/Check.swift`.

---

## Ma trận tương thích

| Nhóm | Ứng dụng / bề mặt | Đường xử lý | Ghi chú kỹ thuật |
|---|---|---|---|
| **Cocoa** | TextEdit, Notes, Xcode | `DocumentSession` / Native IMK | Sửa từ đã chốt (`viêt\| + j` → `việt`), gợi ý trực tiếp |
| **WebKit** | Safari (`input`, `textarea`, `contenteditable`, Omnibox) | `DocumentSession` / Native IMK | Nhận gợi ý ngay trên thanh địa chỉ, không lặp tiền tố |
| **Chromium** | Chrome, Edge (`input`, `textarea`, `contenteditable`) | `DocumentSession` + Snapshot Cache | Bật tuỳ chọn Trợ năng để hiển thị thanh gợi ý theo con trỏ |
| **Electron** | VS Code, Slack và trình soạn thảo Chromium | Native IMK / Snapshot Cache | Mỗi cửa sổ Electron giữ nguồn nhập riêng (`⌃ Space` nếu đổi cửa sổ) |
| **Terminal** | Terminal, iTerm2, Warp, Ghostty, Alacritty, kitty | Tự tắt dấu tiếng Việt mặc định | Quản lý danh sách ngoại lệ trong **Cài đặt → Thói quen gõ** |
| **iOS / iPadOS** | Bàn phím `viTekKeyboard` & Magic Keyboard | `InputSession` thuần Swift | Hoạt động không cần Open Access; hỗ trợ Split & One-Handed |

---

## Quy trình kiểm thử thủ công trong ứng dụng thật

Mở trang thử cục bộ [Tests/macOSCompatibility/browser.html](../Tests/macOSCompatibility/browser.html) hoặc ô soạn thảo trong Safari, Chrome, VS Code, TextEdit. Chọn **viTek** trong chính cửa sổ đó và gõ từng phím thật (không dùng dán hay điền DOM):

| Ca kiểm thử | Thao tác | Kết quả mong đợi |
|---|---|---|
| **Từ đầu tiên** | Ô trống, gõ `vieetj ` | `việt `, không tách rời chữ đầu |
| **Tự nhận Telex & VNI** | Gõ `vieetj vie65t reset server ` | `việt việt reset server ` |
| **Đổi thanh, giữ độ dài** | Gõ `vieet`, rồi `j` (chưa bấm Space) | `viêt` đổi ngay thành `việt` |
| **Xoá khi đang soạn** | Gõ `vieetj`, Backspace, `t`, Space | `việ` → `việt ` |
| **Thay vùng chọn** | Chọn `cũ` trong `trước cũ sau`, gõ `vieetj`, Return | Chỉ vùng chọn được thay bằng `việt`; hai bên giữ nguyên |
| **Biên UTF-16 & Emoji** | Đặt con trỏ sau `👩🏽‍💻 `, gõ `vieetj ` | Emoji còn nguyên, tiếp theo là `việt ` |
| **Chuyển focus giữa từ** | Đang gõ dở, click sang ô khác rồi gõ tiếp | Không chèn lặp từ cũ hay thay chữ sang ô mới |
| **Di chuyển con trỏ** | Đang gõ dở, click vị trí khác rồi gõ | Không sửa nhầm vùng cũ theo vị trí mới |
| **Phím tắt ứng dụng** | `Tab`, `Shift-Tab`, mũi tên, `⌘A`, `⌘F`, `⌘Z` | Chốt từ đúng lúc, phím tắt tới ứng dụng ngay |
| **Cập nhật phiên bản** | Chạy cập nhật bộ gõ rồi chọn lại viTek | Kiểm tra kết nối phản hồi và gõ tiếp bình thường |
