# Nhật ký Thay đổi (Changelog)

Mọi bản phát hành của **viTek** sử dụng quy tắc phiên bản **`YYYYMMDD.X.YYY`** (`macOS` / `GitHub Releases`) và dạng rút gọn bỏ số `0` đệm đầu (`YYYYMMDD.X.Y`) trên **iOS App Store Connect**.

---

## `20261126.1.003` *(iOS `20261126.1.3`)*

### Đồng bộ Giao diện Tối giản Toàn macOS & Tăng Độ Chính Xác Gõ Song Ngữ
- **Tối giản `QuickActionPanel` (`⌃⌥A`), `SuggestionPanel` & `ModeIndicatorPanel`:** Chuyển bảng công cụ chữ & AI nhanh (`⌃⌥A`) sang kiến trúc `@Observable` 1 cột gọn nhẹ (`348 pt`, 0 lần resize khi di chuyển `↑`/`↓` hay hover), rút gọn `ModeIndicatorPanel` sang kích thước cố định `0 ms` và bỏ qua cập nhật thừa ở `SuggestionPanel` khi từ gợi ý + con trỏ không đổi.
- **Tinh gọn dòng danh sách trong `ClipboardPage`:** Lược bỏ huy hiệu màu & thẻ phân loại trùng lặp để đồng nhất với popup Clipboard mới.
- **Bảo vệ từ ngắn lập trình hay xung đột Telex (`VitekEngine` & `vitek-eval`):** Bổ sung bảo vệ cho `docs`, `cors`, `diff`, `buff` (giữ nguyên hành vi undo chủ động của `off`), bổ sung `seen`/`boom` vào nhóm khử mơ hồ theo ngữ cảnh ANE, và mở rộng bộ đánh giá tự động `vitek-eval` lên 42 trường hợp đạt 100%.

---

## `20261126.1.002` *(iOS `20261126.1.2`)*

### Tinh gọn Giao diện Tối giản & Tối ưu Hiệu năng Runtime
- **Thiết kế lại Popup Clipboard (`⌃⌥V`) tối giản 1 cột (`396 × 364 pt`):** Loại bỏ hoàn toàn lỗi vỡ dòng / méo nút lọc khi danh sách rỗng, bỏ khung preview 2 cột cồng kềnh và các nhãn thừa; chuyển sang kiến trúc `@Observable` cố định kích thước giúp nhấn `↑`/`↓`, di chuột và lọc trực tiếp đạt **0 lần resize panel, 0 lần dựng lại view**.
- **Tự động bỏ qua khóa bí mật / API token (`ClipboardMonitor`):** Bộ lọc nhẹ không dùng regex bỏ qua các chuỗi dạng `*_SECRET`, `*_TOKEN`, `*_PASSWORD`, `SecretKey`, `sk-`, `ghp_`, `PRIVATE KEY` ngay cả khi ứng dụng nguồn không gắn cờ `ConcealedType`.
- **Tinh gọn Cửa sổ Cài đặt macOS (7 → 5 mục) & iOS:** Gộp *Kiểu gõ* và *Thói quen gõ* thành **Bộ gõ**, đưa tuỳ chọn nâng cao vào `DisclosureGroup` đóng mặc định, bỏ banner tiêu đề lặp lại và thay dải lọc glass trong `ClipboardPage` bằng segmented control chuẩn macOS; lược bỏ các thẻ dư thừa trên màn hình chính iOS.
- **Tối ưu luồng gõ phím (`SettingsStore`):** Chuyển tra cứu ứng dụng loại trừ sang `Set<String>` `O(1)` và gom (coalesce/debounce) các lần ghi `UserDefaults` cho thói quen gõ & tần suất từ cá nhân ra khỏi luồng gõ phím chính.

---

## `20261126.1.001` *(iOS `20261126.1.1`)*

### Chống Đảo Phím >100 WPM, Gõ Lướt Tiếng Việt, iPad Pro Layout & Đồng bộ Liquid Glass
- **Khôi phục đảo thứ tự phím khi gõ cực nhanh (`smartTypoRecovery` trong `VitekEngine`):** Tự động phục hồi tất định các cặp phụ âm cuối và vần trượt tay ở tốc độ >100 WPM (`tieegns` / `tiegnes` → `tiếng`, `dduowgnf` → `đường`, `mihnf` → `mình`, `thafhn` → `thành`, `bahcj` → `bạch`, `nguwiof` / `nguiowf` → `người`) chỉ khi từ mang dấu tiếng Việt hợp lệ, bảo toàn 100% từ tiếng Anh (`signs`, `designs`, `john`) và thao tác huỷ dấu lặp (`tesst` → `test`).
- **Gõ lướt nối chữ tiếng Việt (`GlideDecoder` + Vệt sáng Liquid Glass 120Hz):** Bộ giải mã đường lướt thuần Swift không dùng Foundation, kết hợp ngữ cảnh câu và tần suất cá nhân để lướt nhanh một tay kèm khả năng chạm 1 lần trên thanh gợi ý để đổi từ đồng âm.
- **Bố cục iPad Pro Chuyên biệt (iPadOS 26 Full Layout):** Bổ sung phím `⇥ Tab`, cặp dấu `; / :`, `, / !`, `. / ?` trực tiếp trên mặt chữ và phím ẩn bàn phím `⌨️▾`; tự động thu gọn thông minh khi chuyển sang **Floating Keyboard** (`< 660 pt`).
- **Đồng bộ 100% Liquid Glass trên macOS & Widget iOS 26:** Nâng cấp trang **Gõ tắt (`ShortcutsPage`)**, cửa sổ bộ cài **`Cài viTek.app` (`InstallerApp`)** và **Widget Màn hình chính / Màn hình khoá (`TypingWidget`)** (thêm lối tắt mở thẳng **Clipboard** & **AI Viết**).
- **Tự động hoá kiểm định chất lượng (`scripts/verify_appstore.sh` & `scripts/run_keyboard_lab.sh`):** Kiểm tra tiêu chuẩn xét duyệt App Store Connect (`RequestsOpenAccess=false`, `PrivacyInfo.xcprivacy`, icon 1024×1024 không alpha, dung lượng `viTekKeyboard.appex`) và tự động chạy bộ kiểm thử bàn phím phần mềm `KeyboardLab`.

---

## `20261125.1.005` *(iOS `20261125.1.5`)*

### Kiến trúc lại Bộ Render Bàn phím iOS 26 Liquid Glass & Tối ưu Tốc độ 120Hz
- **Render trực tiếp `< 0,5 ms` không dùng Auto Layout (`KeyboardViewController`):** Thay thế toàn bộ 5 tầng `UIStackView` và hơn 150 ràng buộc Auto Layout bằng bộ nhớ đệm phím tái sử dụng (`LiquidKeyCapButton` + `SymbolCache` + `shadowPath` tính sẵn), xoá bỏ hoàn toàn việc huỷ/tạo lại `UIButton` khi gõ gợi ý từ hoặc chuyển trang `ABC ↔ 123 ↔ #+=`.
- **Độ trễ chạm `0 ms` & Trượt chọn phím liền kề:** Xoá hiệu ứng mờ trễ `150 ms` của `UIButton.system`, bổ sung vùng nhận chạm mở rộng giữa khe phím (`hitSlop`) và theo dõi ngón tay trượt trực tiếp sang phím kế bên kèm bóng phóng đại **Liquid Glass (`UIGlassEffect`)** không bao giờ bị cắt ở hàng phím trên cùng.
- **Loại bỏ nghẽn luồng chính khi đang gõ:** Chuyển toàn bộ truy vấn `UIPasteboard` sang bộ nhớ đệm sự kiện và đưa suy luận miền `CoreML` ra luồng nền bất đồng bộ để luồng chính luôn đạt 120Hz mượt mà.
- **Bố cục chuẩn công thái học Apple iOS 26:** Đồng nhất tuyệt đối chiều rộng phím chữ trên cả 3 hàng (`Q–P`, `A–L`, `Z–M`), chuyển nút `VI/EN` và công cụ nhanh lên thanh viên nang Liquid Glass phía trên để trả lại phím **Dấu cách rộng chính giữa (~55% bề ngang)**.
- **Thiết kế lại ứng dụng iOS (`ViTekApp` & `WritingView`) chuẩn iOS 26 Liquid Glass:** Thanh Tab thu gọn thông minh (`tabBarMinimizeBehavior(.onScrollDown)`), thẻ Hero `.glassEffect`, dải điều khiển `GlassEffectContainer`, ô gõ thử trực tiếp và hệ thống huy hiệu màu chuẩn Cài đặt iOS.

---

## `20261125.1.004` *(iOS `20261125.1.4`)*

### Nhân gõ Tiếng Việt & Khử mơ hồ ngữ cảnh ANE
- **Chuyển đổi mượt nguyên âm ghép hai chiều (`uô ↔ ươ`):** Cho phép đổi trực tiếp `uô → ươ` bằng `w` (`tuoongw` → `tương`, `muooiwf` → `mười`) và `ươ → uô` bằng `o` (`tuowngo` → `tuông`, `muowifo` → `muồi`) mà không cần xoá gõ lại.
- **Mở rộng gõ nhanh `w` (`yw` / `uyw` → `yê` / `uyê`):** Đồng bộ với `viw → viê`, hỗ trợ `ywus` → `yếu`, `quywts` → `quyết`, `chuywnj` → `chuyện`, `nguywnx` → `nguyễn` (nhấn `ww` hoàn tác về phím thô).
- **Mô hình ANE Core ML mở rộng (`NeuralContextScorer`):** Huấn luyện lại `VitekLanguageContext.mlmodelc` và `VitekDomainClassifier.mlmodelc` trên **260 mẫu câu song ngữ MIT** (chỉ `20 KB` mỗi mô hình, suy luận bất đồng bộ ngoài luồng phím nóng trên Neural Engine) kết hợp `SemanticRanker` xếp hạng ngữ nghĩa dài hạn và bộ đo kiểm `vitek-eval`.

### Thanh tác vụ chữ & Apple Intelligence tại con trỏ (`⌃⌥A`) & Gợi ý Gõ tắt
- **Quick Action Palette (`⌃⌥A` trên macOS):** Bảng nổi Liquid Glass ngay tại con trỏ (`QuickActionPanel`), hỗ trợ thay thế trực tiếp văn bản đang bôi đen bằng 5 tác vụ **Apple Intelligence `@Generable` trên thiết bị** (*Khôi phục dấu tiếng Việt*, *Sửa chính tả đồng âm*, *Chuẩn hoá lịch sự công sở*, …) cùng công cụ sửa font Unicode NFC, bỏ dấu, đổi hoa/thường chỉ bằng phím `1–7`.
- **Tự động phát hiện gợi ý gõ tắt (`SuggestedShortcut`):** Khai phá các cụm 2–3 từ lặp lại trong `PersonalFrequency` thành chữ tắt an toàn không trùng âm tiết tiếng Việt hay từ tiếng Anh (`"cảm ơn bạn"` → `cob`, `"tài khoản"` → `tk`) để thêm chỉ với 1 cú nhấp trên macOS & iOS.

### Giao diện Clipboard Liquid Glass Swift 27 & Tư thế Bàn phím Gập (Duo)
- **Thiết kế lại Clipboard Swift 27 (`GlassCornerStyle.rounded(16)` & `GlassEffectContainer`):** Khắc phục triệt để lỗi bo tròn quá mức làm cắt góc chữ và mất dấu tiếng Việt chồng tầng; đồng bộ trang Cài đặt Clipboard sang `.settingsForm()` liền mạch kèm huy hiệu phân loại thông minh (URL, Email, SĐT, OTP, Mã màu, Code) và Smart Paste Chip.
- **Tối ưu tư thế màn hình gập (`KeyboardPosture`):** Bàn phím iOS/iPadOS tự thích ứng từ màn ngoài gọn sang màn mở rộng chia đôi kèm **Cầu nối trung tâm 3 chế độ** (Rê con trỏ 2D, Numpad `3×4`, Clipboard nhanh).

---

## `20261125.1.003` *(iOS `20261125.1.3`)*

### Quản lý Clipboard & Đồng bộ iCloud mở rộng
- **Clipboard Manager đa nền tảng (`ClipboardHistory`):** Lưu tới 25 mẫu ghim và 25 mục sao chép gần đây; tìm kiếm tiếng Việt không phân biệt dấu (`"viet nam"` → `"Việt Nam"`), tự động bỏ qua dữ liệu nhạy cảm từ trình quản lý mật khẩu trên macOS (`ConcealedType` / `TransientType`).
- **Dán nhanh mọi nơi:** Bảng nổi Liquid Glass **`⌃⌥V`** trên macOS (nhấn phím `1–9` hoặc click để dán, giữ nguyên `Esc` đóng), tab **Clipboard** trong ứng dụng iOS và nút **`📋`** ngay trên thanh gợi ý bàn phím iOS/iPadOS.
- **Đồng bộ iCloud mở rộng (`CloudSettingsSync`):** Tự động hợp nhất mẫu **Clipboard đã ghim**, tuỳ chọn **Clipboard gần đây** (mặc định tắt để giữ riêng tư) và **Từ vựng cá nhân đã học** giữa Mac, iPhone và iPad.

### Tối ưu Luồng Gõ & Tiên đoán thông minh hơn
- **Bộ nhớ ngữ cảnh 3 từ (Trigram) trong `PersonalFrequency`:** Xếp hạng gợi ý chính xác hơn dựa trên hai từ liền trước, đồng bộ top từ/cụm cá nhân qua iCloud.
- **Gợi ý mở rộng Gõ tắt trực tiếp (`Shortcuts`):** Khi đang gõ chữ tắt trên macOS/iOS, cụm mở rộng xuất hiện ngay đầu thanh gợi ý.
- **Chọn nhanh gợi ý bằng `⌥ Space` (macOS):** Bấm `⌥ Space` để chèn ngay từ gợi ý đầu tiên bên cạnh `⌥ 1–5`.

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
