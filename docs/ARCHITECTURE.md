# viTek — Kiến trúc

viTek là bộ gõ tiếng Việt cho macOS (sau đó iOS).
Đọc kèm: [ENGINE.md](ENGINE.md) (đặc tả engine) · [UX.md](UX.md) (giao diện) · [ROADMAP.md](ROADMAP.md) · [SOURCES.md](../SOURCES.md).

---

## 1. Nguyên tắc

1. **Tự viết.** Không chép code, dữ liệu hay asset từ bộ gõ khác. Mọi hành vi được suy ra từ chính tả tiếng Việt và tài liệu công khai của Apple ([SOURCES.md](../SOURCES.md)).
2. **Engine là hàm thuần.** Engine không biết gì về macOS, iOS, sự kiện hay luồng. Nó nhận ký tự và trả lại chữ. Mọi quyết định "từ này là gì" nằm ở engine, nên kiểm thử được hoàn toàn bằng `swift test` mà không cần host.
3. **Host ngu.** Host chỉ dịch sự kiện gốc sang `HostEvent` rồi làm đúng các `HostCommand` nhận về. Hai host khác nhau thì hành xử giống hệt nhau.
4. **Sửa văn bản có xác minh.** `DocumentSession` chèn chữ đã chốt bằng `insertText` khi đọc lại được vùng chọn và chữ đang sở hữu. Mỗi phím kiểm lại con trỏ, vùng chọn và văn bản; các ô tìm kiếm vì thế nhận chữ trước Space, không phải chờ hết composition. Ứng dụng không đọc được từ đầu dùng marked text làm đường tương thích. Không Backspace giả hay phát lại phím. Đường nhập chữ không cần quyền Trợ năng. Khi quyền hệ thống hiện có cho phép, một CGEventTap chỉ nhận `flagsChanged`, trả nguyên sự kiện và đếm lần nhấn Command trên luồng riêng; IMK dùng định danh này một lần để chốt trước shortcut, kể cả khi đã nhả nhanh, đồng thời bỏ callback trùng đến muộn. Tap không nhận phím chữ và không gọi client; nếu không tạo được tap, dùng đường an toàn chỉ chốt khi Command còn giữ. Quyền Trợ năng còn hỗ trợ vị trí thanh gợi ý. Không đoán vùng thay thế khi mất readback giữa từ.
5. **Một ngôn ngữ, một toolchain.** Swift 6 với strict concurrency, Swift Package Manager, XcodeGen. macOS trước; host iOS sau này dùng lại nguyên engine và session.
6. **Kiểm thử trước khi tin.** Mỗi quy tắc chính tả có ca kiểm thử do chính dự án viết. Một hành vi chưa có test thì coi như chưa có.

## 2. Kiến trúc

```
 ┌──────────────────────── Ứng dụng đang gõ (TextEdit, Safari, Xcode…) ─────────────────────────┐
 │             setMarkedText (chữ đang soạn)            insertText (chữ đã chốt)                │
 └──────────────────────────────────────▲───────────────────────────────────────────────────────┘
                                        │ IMKTextInput
 ┌──────────────────────────────────────┴───────────────────────────────────────────────────────┐
 │ Apps/macOS — host InputMethodKit                                                             │
 │   VitekInputController   NSEvent → HostEvent (KeyMap), HostCommand → client                  │
 │   SettingsStore          UserDefaults ↔ EngineOptions, gõ tắt; đổi là áp dụng ngay           │
 │   menu()                 menu nguồn nhập: kiểu dấu, chính tả, gõ tắt              │
 │   SettingsWindow         cửa sổ cài đặt SwiftUI, thanh bên 6 mục (docs/UX.md)                │
 │   TypingHabits           điểm ưu tiên của ứng dụng, lưu bằng SettingsStore                       │
 └──────────────────────────────────────┬───────────────────────────────────────────────────────┘
                                        │ HostEvent ↓   ↑ SessionOutput { commands, passThrough }
 ┌──────────────────────────────────────┴───────────────────────────────────────────────────────┐
 │ Sources/VitekSession — giao thức soạn thảo, không phụ thuộc nền tảng                         │
 │   DocumentSession     xác minh vùng sửa, giữ quyền sở hữu, điều hướng và vòng đời giao dịch │
 │   InputSession        nối engine với host: khi nào mark, khi nào insert, khi nào cho phím qua│
 │   Shortcuts           gõ tắt khi hết từ, giữ kiểu hoa của người gõ                           │
 │   SimulatedTextField  host giả để test và CLI, đồng thời là tài liệu tham chiếu cho host     │
 └──────────────────────────────────────┬───────────────────────────────────────────────────────┘
                                        │ type(Character) / deleteBackward() / finish()
 ┌──────────────────────────────────────┴───────────────────────────────────────────────────────┐
 │ Sources/VitekEngine — chỉ dùng thư viện chuẩn Swift (không Foundation)                       │
 │   VitekEngine    API công khai: một engine cho mỗi ô nhập                                    │
 │   Composer       một từ: chữ + dấu phụ + một thanh, phím gốc, ba chế độ                      │
 │   Orthography    phụ âm đầu, bảng vần, kiểm tra chính tả, vị trí dấu thanh                   │
 │   Options        Telex/VNI, kiểu đặt dấu, các tuỳ chọn                                       │
 │   Glyphs         bảng ký tự dựng sẵn NFC và tra ngược                                        │
 │   EnglishWords   các từ tiếng Anh giữ nguyên khi gõ Telex (test, reset)                       │
 └──────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Quy tắc phụ thuộc

| Module | Được phụ thuộc vào | Cấm |
|---|---|---|
| `VitekEngine` | thư viện chuẩn Swift | Foundation, AppKit/UIKit, mọi module khác của viTek |
| `VitekSession` | `VitekEngine` | Foundation, framework nền tảng |
| `Apps/macOS` | `VitekSession`, `VitekEngine`, AppKit, SwiftUI, InputMethodKit | gọi thẳng vào chi tiết `Composer`/`Orthography` |
| `vitek-cli` | `VitekSession`, Foundation | — |

Engine và Session không dùng Foundation nên chạy được trong iOS keyboard extension (giới hạn bộ nhớ chặt) và trên Linux CI.

## 3. Một phím đi qua hệ thống

1. macOS gọi `VitekInputController.handle(_:client:)` với `NSEvent`.
2. `KeyMap` đổi sự kiện thành `HostEvent`:
   * `.character(c)`: ký tự do layout bàn phím sinh ra, không giữ ⌘/⌃/⌥.
   * `.backspace`.
   * `.boundary`: Return, Tab, Esc, phím mũi tên, phím tắt có ⌘/⌃/⌥.
3. `InputSession.handle` hỏi engine:
   * Engine nhận phím vào từ → `[.mark(chữ đang soạn)]`, nuốt phím.
   * Engine từ chối (dấu cách, dấu câu, chữ số không làm dấu) → `finish()` → gõ tắt → `[.insert(từ)]`, cho phím đi tiếp tới ứng dụng.
4. `DocumentSession` giữ giao dịch sửa chữ; host cung cấp `DocumentClient` (vùng chọn, marked range, đọc và ghi chữ). Khi đọc được vùng sửa chính xác, mỗi phím chèn chữ đã chốt, không giữ composition đến Space. Lần chèn đầu dùng vùng chọn mặc định; những lần sửa từ phía sau con trỏ dùng `insertText` với vùng UTF-16 đã xác minh. Chromium gửi lần thay vùng này đến renderer bất đồng bộ nhưng có thể vẫn trả snapshot cũ qua các truy vấn đồng bộ. Module giữ tối đa 32 snapshot giao dịch trước trong tối đa 500 ms, chỉ chấp nhận phản hồi khớp cả vùng, chữ và vùng chọn; phản hồi ngoài chuỗi đó làm mất quyền sửa. Xoá rồi gõ lại cùng giá trị không đủ chứng minh renderer đã xử lý hết các lần ghi. Không ghép `setMarkedText` rồi `insertText` trong cùng phím: Chromium có thể gộp hai lệnh khiến lặp chữ. Vùng và độ dài đều kiểm tra tràn UTF-16. Nếu từ trước kết thúc mà vẫn chưa được xác nhận, từ kế tiếp bắt đầu bằng native mark để host xác định vị trí. Ở lượt phím sau, khi đã đọc được đầy đủ mark và con trỏ, module chốt qua vùng composition hiện tại rồi tiếp tục đường committed; không mark/chốt trong cùng phím. Native fallback cũng đối chiếu các frame đã quan sát trong một khoảng chờ có giới hạn khi marked range hoặc vùng chọn chưa cập nhật, kể cả khi không đọc được chữ. Vị trí dự kiến tính từ lệnh đã gửi; chỉ nhận vị trí anchor được renderer sửa lại khi đọc được toàn bộ chữ đang sở hữu tại vị trí mới.
5. Phím điều hướng/phím tắt, mouse-down, commit và deactivate kết thúc giao dịch bằng chữ đang hiển thị, không chạy khôi phục phím hay gõ tắt. Đổi con trỏ hoặc văn bản ngoài dự kiến bỏ buffer mà không ghi lại từ cũ. Callback chốt tới sau khi client bỏ marked text không chèn lặp. Controller gắn giao dịch với đúng đối tượng client, cô lập trạng thái trên main actor và hoãn callback chốt tái nhập đến sau lần ghi hiện tại. Nếu readback mất giữa từ đã chèn trực tiếp, giữ nguyên chữ trên màn hình và cho các phím còn lại của token đi qua; bắt đầu nhận diện lại sau dấu phân cách. `DirectEditor`/`DirectTypingProbe` là tiện ích lịch sử, không điều khiển đường gõ mới.
6. Giữa hai từ, controller đọc lại `SettingsStore` nếu cài đặt đã đổi, nên đổi kiểu gõ không làm hỏng từ đang soạn.
7. Sửa từ vừa gõ: nếu phím là phím dấu, không có từ đang soạn và con trỏ đứng ngay sau một từ, controller đọc từ đó bằng `attributedSubstring`, rồi `DocumentSession.resume` nhận quyền sửa đúng vùng đã xác minh mà không tạo marked text. Phím được xử lý như bình thường trên từ vừa nạp lại. Ứng dụng trả văn bản không khớp thì bỏ qua.
8. Trước mỗi từ, host đọc điểm ưu tiên theo bundle ID. Engine nhận dấu chữ hoặc dấu số, dùng điểm ưu tiên để giải quyết cách đọc mơ hồ. Khi chốt từ có tín hiệu rõ, host cập nhật điểm trong UserDefaults. Hồ sơ chỉ chứa hai số nguyên giới hạn từ −3 đến 3.
9. Khi bật gợi ý và đang ở chế độ tiếng Việt, controller đọc tối đa 512 đơn vị UTF-16 trước con trỏ qua IMK sau khi xử lý phím (buffer dự phòng giới hạn 512 Character). `WordCompletions` chạy trên actor riêng. `WordPrediction` tra `PredictionLexicon` bất biến: chỉ mục tiền tố bỏ dấu để tìm nhóm, sau đó kiểm lại từng dấu đã gõ bằng `Spelling`; chỉ mục cụm ưu tiên ngữ cảnh dài hơn, rồi điểm biên tập và lĩnh vực. `BuiltinVocabulary` là dữ liệu khởi đầu tự soạn, không phải từ điển đầy đủ hay mô hình tần suất. Đường code chỉ dùng từ khóa/member đã khai báo và định danh trong ngữ cảnh hiện tại, bỏ string/comment, giữ nguyên hoa/thường và không thêm Space khi nhận. URL/email/đường dẫn hoặc phần đuôi token không thuộc composition bị loại. Dịch vụ macOS chỉ bổ sung khi văn bản có tiền tố và chưa đủ 5 kết quả cục bộ. `WordCandidate` giữ nguồn, điểm và cách chèn. `AccessibilityCaret` vẫn chạy riêng; `SuggestionRequest` vẫn xác minh revision/client/caret/context trước khi hiện và nhận. Tab luôn tới host; ⌥1–⌥5 mới nhận gợi ý. Xem [khung từ điển và QA](PREDICTION.md).

## 4. Bất biến

Khi native mark của Electron còn có anchor chưa xác nhận, một phím biến đổi không đổi độ dài (`d` → `đ`) có thể nhận caret tương đối sau caret document. `DocumentSession` chỉ giữ frame này trong lúc chờ nếu mark text khớp hoặc mark/caret đều từng quan sát; lưu tọa độ native tạm để qua khoảng dừng gõ. Không lấy tọa độ tạm làm vùng ghi tuyệt đối. Có regression dựng lại trace VS Code và kiểm dừng 550 ms trong `DocumentSessionTests`.

Gợi ý bất đồng bộ dùng `SuggestionRequest` để gắn kết quả với revision nhập liệu, client, con trỏ, tiền tố và ngữ cảnh đọc được. Bắt đầu yêu cầu mới, điều hướng, kích hoạt hoặc rời client đều vô hiệu hóa yêu cầu cũ. Host kiểm lại snapshot khi hiện thanh và khi nhận ⌥1–⌥5; chỉ khớp vị trí con trỏ chưa đủ. Phím boundary như Escape/Tab không lên lịch lại thanh vừa ẩn.

* Không có trạng thái toàn cục. Mỗi `IMKInputController` (mỗi ô nhập) có một `InputSession` riêng; `VitekEngine` là value type.
* Đầu ra luôn là NFC dựng sẵn: mỗi chữ Việt đúng một Unicode scalar. Test `GlyphsTests` kiểm tra bảng ký tự với phân rã chuẩn.
* Engine không bao giờ đổi ngôn ngữ toàn cục. Việt/Anh là nguồn nhập liệu của macOS (viTek ↔ ABC), người dùng đổi bằng 🌐/⌃Space.
* Phím không thuộc từ luôn tới được ứng dụng (`passThrough`), sau khi từ đang soạn đã được chốt.
* Backspace trong lúc soạn xoá ký tự trên màn hình, không phải phím gốc (`việt` ⌫ → `việ`).

## 5. Cấu trúc repo

```text
viTek/
├── Package.swift            # VitekEngine, VitekSession, vitek (CLI), test targets
├── VERSION                  # nguồn duy nhất của số phiên bản (YYYY.X.XXX)
├── Sources/
│   ├── VitekEngine/         # engine thuần Swift
│   ├── VitekSession/        # giao thức host-agnostic
│   ├── vitek-cli/           # `swift run vitek "vieetj nam"` → việt nam
│   ├── vitek-bench/         # đo thời gian mỗi phím (`swift run -c release vitek-bench`)
│   └── vitek-wordlist/      # sinh lại EnglishWordList.swift (công cụ, không phải sản phẩm)
├── Tests/
│   ├── VitekEngineTests/    # chính tả, Telex, VNI, khôi phục, chỉnh sửa, property test
│   ├── VitekSessionTests/   # lệnh host, gõ tắt
│   └── RepositoryTests/     # định dạng VERSION, khớp xcconfig
├── Apps/macOS/
│   ├── project.yml          # XcodeGen (không commit .xcodeproj)
│   ├── Config/Version.xcconfig
│   └── viTek/               # VitekInputController, KeyMap, SettingsStore, SettingsWindow, icon PDF
├── docs/                    # ARCHITECTURE, ENGINE, UX, ROADMAP
├── .github/, scripts/       # CI, cài đặt dev, phát hành
├── SOURCES.md
└── LICENSE
```

## 6. Build, chạy, cài

```sh
swift test                                   # toàn bộ test engine/session/repo
swift run vitek "Tooi yeeu tieengs Vieetj"   # → Tôi yêu tiếng Việt
swift run vitek --vni "Tie6ng1 Vie65t"       # → Tiếng Việt

xcodegen generate --spec Apps/macOS/project.yml
xcodebuild -project Apps/macOS/viTek.xcodeproj -scheme viTek -configuration Debug \
  -derivedDataPath build/DerivedData.noindex build

scripts/install_dev.sh            # build Debug, cài vào ~/Library/Input Methods, dừng tiến trình đang chạy
# Lần đầu: đăng xuất/đăng nhập lại, rồi System Settings → Keyboard → Input Sources → + → Vietnamese → viTek
scripts/version.sh bump build     # 20261125.1.001 → 20261125.1.002, ghi VERSION và Version.xcconfig
```

Cài đặt: menu nguồn nhập trên thanh menu → "Cài đặt viTek…". Thay đổi có hiệu lực từ từ tiếp theo, không cần chuyển nguồn nhập.
Icon nguồn nhập là PDF vector dạng template (giống icon nguồn nhập của chính macOS), vẽ bằng `swift scripts/make_input_icon.swift Apps/macOS/viTek/InputIconTemplate.pdf`. Không dùng ảnh bitmap: macOS co giãn icon theo từng chỗ hiển thị, bitmap sẽ nhoè.
Logo ứng dụng (`CFBundleIconFile = AppIcon`), iOS AppIcon (`viTek.png`), linh vật Cú Lạc (`BrandMascot.png`) và nền DMG Retina (`dmg-background.tiff`) được tạo bằng `swift scripts/make_brand_assets.swift <logo-source> <mascot-source>`.
Danh sách từ tiếng Anh sinh lại bằng `swift run vitek-wordlist /usr/share/dict/web2 > /tmp/list && mv /tmp/list Sources/VitekEngine/EnglishWordList.swift` (ghi ra tệp tạm trước, vì công cụ cần chính tệp đó để build).

## 7. Cổng chất lượng

| Cổng | Tiêu chí |
|---|---|
| Test | `swift test` xanh; mỗi PR thêm hành vi phải thêm test |
| Concurrency | Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`, không warning |
| Đầu ra | NFC dựng sẵn; property test 8.000 chuỗi ngẫu nhiên không crash, Backspace luôn về rỗng |
| Hiệu năng | < 50 µs/phím p99 qua `InputSession`, đo bằng `swift run -c release vitek-bench` (52.400 phím Telex, VNI và ngẫu nhiên) |
| Nguồn gốc | checklist trong [SOURCES.md](../SOURCES.md) cho mọi PR |
| Phiên bản | `VERSION` đúng `YYYYMMDD.X.YYY` và khớp `Version.xcconfig` + `Casks/vitek.rb` (`RepositoryTests`) |

## 8. Phiên bản

Mọi bản phát hành được đánh số theo chuẩn **`YYYYMMDD.X.YYY`**:

| Phần | Ý nghĩa |
|---|---|
| `YYYYMMDD` | ngày phát hành (năm, tháng, ngày) |
| `X` | dòng phát hành chính (`1`, `2`, …) |
| `YYY` | số thứ tự build trong ngày/đợt, từ `001`, về `001` khi sang ngày mới hoặc tăng `X` |

Ví dụ: `20261125.1.001` → `20261125.1.002` (sửa lỗi cùng ngày) → `20261201.1.001` (bản mới) → `20261201.2.001` (dòng mới).

* Nguồn duy nhất là tệp `VERSION`; `Apps/macOS/Config/Version.xcconfig` giữ nguyên `YYYYMMDD.X.YYY`, còn `Apps/iOS/Config/Version.xcconfig` tự động bỏ số `0` đệm đầu (`20261125.1.1`) để tuân thủ App Store Connect. Đổi bằng `scripts/version.sh`.
* Tag git là đúng chuỗi phiên bản `YYYYMMDD.X.YYY`, không tiền tố.

## 9. Chẩn đoán

`defaults write io.github.luongbinhf.inputmethod.viTek diagnostics -bool YES` bật nhật ký `~/Library/Logs/viTek/diagnostics.log`: ứng dụng nào kích hoạt viTek, có dùng marked text không, loại và độ dài lệnh gửi đi, vị trí con trỏ. Không ghi ký tự người dùng gõ. Tắt bằng `defaults delete io.github.luongbinhf.inputmethod.viTek diagnostics`.

Gợi ý cần ngữ cảnh: văn bản trước con trỏ khi ứng dụng đọc lại được, nếu không thì `typedContext`, những gì viTek đã gõ vào ô này kể từ lần con trỏ nhảy gần nhất. Vị trí con trỏ: `firstRect` ở con trỏ, rồi khung của ký tự ngay trước nó, chỉ nhận khung nằm trên màn hình. Chromium và Electron (nhận ra qua `chrome_crashpad_handler` trong framework, `AppCompatibility.isChromium`) chỉ báo vị trí khi có marked text; khi gõ trực tiếp, `firstRect` trả rác và khung dòng chỉ một chỗ bất kỳ (đã đo trong DeepSeek Harness: có lúc là chỗ bấm vào ô, có lúc là góc trên màn hình). Với các ứng dụng này viTek hỏi vị trí qua Trợ năng (`AccessibilityCaret`: bật `AXManualAccessibility`, đọc `AXSelectedTextMarkerRange` → `AXBoundsForTextMarkerRange`, hoặc `AXBoundsForRange` của ký tự trước con trỏ), chờ 0,12 giây sau phím cuối để cây trợ năng kịp cập nhật. Nếu ứng dụng trả `kAXErrorNoValue` khi hỏi ô đang nhập, viTek chờ thêm 0,12 giây rồi hỏi lại một lần. Phím mới hoặc việc rời ô nhập sẽ huỷ lượt hẹn cũ. Chưa có quyền Trợ năng thì không hiện thanh gợi ý.

Điều đã biết về Chromium/Electron (Claude, Slack, VS Code): mỗi cửa sổ giữ nguồn nhập riêng, nên phải chọn viTek **trong chính cửa sổ đó** (⌃ Space hoặc menu nguồn nhập); sau khi viTek khởi động lại, cửa sổ đó cần chọn lại viTek. Chữ đang soạn có lúc hiện chậm một nhịp khi độ dài không đổi (`viêt` → `việt`), chữ được chốt vẫn đúng.

## 10. Tệp gõ tắt

Nhập và xuất trong tab Gõ tắt của cửa sổ cài đặt (`ShortcutFile` trong `VitekSession`, có test riêng).

* Văn bản UTF-8, mỗi dòng một gõ tắt: chữ tắt, rồi Tab (hoặc một hay nhiều dấu cách), rồi cụm thay thế.
* Trong cụm thay thế, `\n`, `\r`, `\t`, `\\` là LF, CR, Tab và dấu `\`; CRLF xuất thành `\r\n` để giữ nguyên mẫu nhiều dòng.
* Dòng trống và dòng bắt đầu bằng `#` bị bỏ qua; dòng thiếu một trong hai phần được báo lại theo số dòng.
* Nhập là gộp: chữ tắt đã có thì cập nhật cụm thay thế, chữ tắt mới thì thêm vào cuối danh sách.

## 10. Cập nhật và kết nối nguồn nhập (2026.0.003)

Bộ cài GUI và `scripts/install_dev.sh` dùng chung `Installation.update`: kiểm payload trước, chuyển sang nguồn ASCII nếu cần, yêu cầu tiến trình cũ dừng bình thường, chờ dừng thành công rồi thay bundle nguyên tử. Không force-kill bộ gõ hoặc `TextInputMenuAgent`, không xóa bundle đang chạy trước khi bản mới sẵn sàng. Công cụ cài dòng lệnh báo lỗi với exit code, không để lỗi Swift thoát lên thành crash.

Đăng ký/bật/chọn nguồn nhập phải kiểm OSStatus. Sau chọn, `InputMethodConnection` dùng nonce mới, phiên bản và đường dẫn bundle để kiểm server đang trả lời, có giới hạn thời gian và hủy được. Phản hồi đi qua distributed notifications; công cụ CLI phải phục vụ run loop để nhận chúng. Đây là xác nhận tiến trình server, không thay thế kiểm phím trong từng ứng dụng. Ô mật khẩu/ô hạn chế nguồn nhập và client bên thứ ba giữ kết nối cũ vẫn cần kiểm riêng; không tuyên bố đã sửa mọi nguyên nhân viTek bị xám.
