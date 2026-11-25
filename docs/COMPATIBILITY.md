# Kiểm tra tương thích gõ tiếng Việt trên macOS

## Trạng thái mới nhất — 2026-11-16

Bản cài cục bộ `37d264f8…` đã qua kiểm xoá rồi gõ lại ngay từ đầu trên Chrome và VS Code. Bộ kiểm Swift có 200 test đạt. [Ca gõ lại, gợi ý sai ngữ cảnh và gạch chân](QA-REWRITE-2026-11-16.md).

## Lượt trước — 2026-11-13

Bản cài ngày 13/11 hash `aaa0e03c…` có lõi từ điển/xếp hạng mới và sửa ca mất chữ `dd` khi host đổi hệ tọa độ con trỏ. **196 Swift tests**, **94 ca UI / 1197 assertion / 190 lần nhận gợi ý**, không retry shortcut trên VS Code/Chrome; macOS và iOS build đạt. Có kiểm dừng giữa từ 700 ms. Xem [QA từ điển và gợi ý](QA-PREDICTION-2026-11-13.md); các con số của đợt trước bên dưới không cộng vào lượt này.

Đợt AI trước đã cập nhật phần chuẩn bị session Apple Intelligence, hash `f7a70f4d…`. Đã kiểm UI AI trên macOS, 3 XCTest UI iOS và 1.019 assertion vòng đời cache; xem [QA Apple Silicon](QA-APPLE-SILICON-2026-11-13.md). Ma trận gõ 180 ca bên dưới thuộc bản Telex `bb5a6955…` trước cập nhật AI, không phải một lượt kiểm lại.

Bản Release `2026.0.003` đã sửa xung đột `view/views/swiss`, Backspace sau Telex rút gọn và ca callback chữ tiêu thụ nhầm lượt Command kế tiếp. Bản cuối đạt **180 ca UI, 1.990 assertion, 80 lần nhận gợi ý**, **30 lần mở Find bằng một Cmd+F**, không retry shortcut trên VS Code/Chrome; **178 Swift tests** và **20.017 assertion gate Command** đạt. Hash, bằng chứng đỏ/xanh và giới hạn tại [QA Telex và Apple 13/11](QA-TELEX-APPLE-2026-11-13.md).

Apple Intelligence đã sinh câu thật trên máy Mac; ba XCTest UI iOS đạt. Phạm vi App Intents, widget và phần chưa kiểm trên iPhone thật được ghi ở [Tích hợp Apple](APPLE-INTEGRATION.md).

## Lượt trước — 2026-11-12

Bản Release `2026.0.003` của lượt trước đã sửa Cmd+F nhả nhanh, bổ sung `viw` → `viê` và xử lý hai ca cache composition làm mất chữ. Bản cuối đạt 220 ca UI, 992 assertion, 80 lần nhận gợi ý và 90 lần mở Find bằng một Cmd+F trên VS Code/Chrome; 175 Swift tests đạt. Xem hash, giới hạn khi không có quyền theo dõi modifier và bằng chứng tại [QA Cmd+F nhanh và Telex 12/11](QA-FAST-CMDF-TELEX-2026-11-12.md). Báo cáo Cmd+F trước đó là lịch sử của bản sửa một phần.

Đợt sửa mất chữ trước đó đạt 240 ca stress và 169 Swift tests, ghi trong [QA stress 12/11](QA-STRESS-2026-11-12.md). Các số này thuộc đợt kiểm riêng, không cộng vào số đạt của bản Cmd+F mới.

Kiểm gợi ý đến muộn có độ trễ cưỡng bức và timeout kết nối bộ cài được ghi riêng trong [QA gợi ý muộn 12/11](QA-LATE-RESULTS-2026-11-12.md).

Các mục bên dưới là lịch sử theo từng bản kiểm; thông tin bản đang cài và số test của các ngày cũ không mô tả trạng thái hiện tại.

## Lịch sử bản 2026.0.003 — 2026-11-05

Đường macOS hiện dùng `DocumentSession` với `IMKDocumentClient`. Khi đọc được vùng sửa chính xác, mỗi phím chèn chữ đã chốt; không giữ marked text chỉ để chờ dấu cách. Khi không đọc được ngay từ đầu, dùng native composition làm đường tương thích. Mất readback giữa từ đã chèn trực tiếp giữ chữ hiện có và cho phần còn lại của token đi qua, không đoán vùng thay thế.

Các ca hồi quy dùng `NSTextView` thật và chính module host sử dụng: xoá sau khi chuyển con trỏ, chọn `iệ` trong `việt` rồi gõ `a`, chốt hai lần, client tự bỏ composition, callback cũ sau đổi client, emoji, text correction cùng độ dài, mất readback và vùng chọn còn được giữ sau một lần thay thế tuyệt đối. Các ca native fallback cũ cũng đã chuyển sang module mới.

`Tests/InstallerSmoke/Check.swift` kiểm cài/cập nhật trong thư mục tạm và handshake giữa hai tiến trình thật, gồm trường hợp đúng và từ chối phiên bản/đường dẫn sai. Không đăng ký hay chọn nguồn nhập của người dùng trong smoke test.

Trang thử có ô **Tìm kiếm tức thì**. Gõ `vieetj` và dừng trước Space: phải thấy `việt`, gợi ý, `composition=false`. Sau đó kiểm chọn hết/gõ lại, xoá giữa từ, thay vùng chọn, Tab, Enter, đổi ô và cập nhật server.

Người dùng gõ tay trên bản thử đầu và vẫn báo mất chữ, còn gạch chân; Chrome chưa được xác nhận đạt. Chẩn đoán tiếp theo phát hiện truy vấn con trỏ/văn bản của Chromium có thể còn thuộc frame cũ sau một lần `insertText` với vùng tuyệt đối. Một prototype ghép mark/chốt ngay trong cùng phím đã gây lặp tiền tố; prototype đó đã được bỏ. Bản hiện tại giữ snapshot giao dịch có giới hạn để nhận biết phản hồi chậm, gồm xoá/gõ lại và frame trung gian quay về giá trị cũ; không dùng native mark trên đường committed.

Kiểm tự động hiện tại: 135 test đạt (81 session, 52 engine, 2 repository), gồm ca renderer sửa lại anchor native ban đầu: trước sửa mất toàn bộ từ, sau sửa giữ `trước việt `. Ca qua Space từng trả `việt vie65t reset server `, sau sửa đạt `việt việt reset server `; ở cuối từ thứ hai đã hết marked text trước Space. Các ca dùng `NSTextView` thật nhưng độ trễ được tiêm qua adapter, chưa chứng minh tương thích Chrome/Electron thực tế. Cần kiểm bản Release hiện tại bằng phím thật trước khi đánh dấu đạt. Máy bị khóa ở lượt kiểm cuối nên chưa thể tiếp tục; bản cài đang dùng đã được khôi phục về 2026.0.002, còn 2026.0.003 là bản ứng viên.


Kiểm bản ứng viên cuối trong lượt này:

| Kiểm tra | Kết quả |
|---|---|
| Swift Package | 135 test đạt: 81 session, 52 engine, 2 repository |
| Release host + installer, warnings là lỗi | Build thành công |
| Installer smoke | Sao chép/cập nhật và handshake hai tiến trình đạt; không đổi nguồn nhập thật |
| Chữ ký ứng viên local | `codesign --verify --deep --strict` đạt |
| Phiên bản / khoảng trắng diff / cú pháp shell installer | Đạt |
| Chrome bằng phím thật trên ứng viên cuối | Chưa kiểm: máy khóa; không xem các lượt prototype là xác nhận |
| Bản đang cài | 2026.0.002, chữ ký hợp lệ; chẩn đoán đã trả về trạng thái tắt ban đầu |

Bản ứng viên local nằm ở `build/integration-review-20261105/viTekInstaller.app` (ký ad-hoc, chưa phải bản phát hành). Kiểm trực tiếp cần mở khóa máy, tạm ngừng nhập dữ liệu, cập nhật rồi dùng trang thử cục bộ. Không gõ thử trong biểu mẫu đang làm việc.

Tham khảo giao thức host: [Chromium RenderWidgetHostViewCocoa](https://raw.githubusercontent.com/chromium/chromium/main/content/app_shim_remote_cocoa/render_widget_host_view_cocoa.mm). Không sao chép mã hay dữ liệu của bộ gõ khác.

Các báo cáo bên dưới là lịch sử **2026.0.002**, không phải xác nhận cho kiến trúc mới.

---


Từ bản **2026.0.002**, mọi ứng dụng macOS dùng chung một đường native marked composition: `setMarkedText` giữ từ đang soạn; `insertText` chốt từ. Không có danh sách phân loại ứng dụng cho cơ chế gõ, và việc thêm dấu không phụ thuộc đọc lại văn bản sau mỗi phím. Tuỳ chọn gạch chân chỉ đổi cách hiển thị; ứng dụng có thể tự vẽ gạch chân.

## Sửa lỗi mất readback giữa từ

Đường cũ cập nhật chữ thường bằng vùng thay thế tuyệt đối, rồi đọc lại để xác nhận quyền sửa. Khi ứng dụng đột ngột trả nil giữa từ, host bỏ phiên soạn và bắt đầu từ mới. Không thể khôi phục an toàn chỉ từ vị trí con trỏ vì ứng dụng cũng có thể đã đổi văn bản hoặc đổi ô nhập.

Bản mới giữ quyền soạn bằng giao thức native từ chữ đầu tiên đến khi chốt. `NativeCompositionWriter` chỉ nhận callback mark/insert, không nhận API đọc văn bản. Đọc lại vẫn dùng cho tính năng phụ như sửa từ đã chốt và ngữ cảnh gợi ý; không quyết định sự tồn tại của từ đang gõ.

Đã trích các hàm routing của controller cũ vào harness dùng `NSTextView` thật và chủ động mất readback sau `vie`. Trước sửa, Telex trả `vieẹt `, VNI trả `vie65t `; thêm thanh cùng độ dài cũng hỏng (`viêtj`). Có 7 assertion thất bại. Giữ nguyên kết quả mong đợi, đổi harness sang writer được controller bản mới sử dụng: các ca đều đạt `việt `, gồm xóa chữ, thay vùng chọn và chốt hai lần không lặp chữ.

Đây là kiểm tích hợp transport với Cocoa, chưa phải mô phỏng mọi ứng dụng. Khi người dùng đổi ô nhập, viTek dựa vào callback commit/deactivate của IMK; cần kiểm riêng bằng phím và chuột thật.

`DirectEditor` và `DirectTypingProbe` vẫn được kiểm thử như tiện ích của package, nhưng không còn nằm trên đường gõ macOS. Bản sửa trước đó chỉ kiểm được ô không đọc văn bản ngay từ đầu; cơ chế mới giải quyết cả mất readback giữa từ.

## Kiểm thử tự động

Chạy `swift test` để kiểm lõi, phiên soạn, vùng UTF-16 và native composition. Các ca kiểm thử do dự án tự soạn.

Trên macOS, `NativeTextInputTests` còn chạy với `NSTextView` thật: hai cách cập nhật chữ, gõ hỗn hợp Telex/VNI/Anh, thay vùng chọn, emoji, Backspace và đổi thanh không đổi độ dài. Đây là kiểm tích hợp với AppKit trong tiến trình test, chưa đi qua sự kiện bàn phím, IMK server hay ứng dụng bên ngoài. Đọc đoạn rỗng từ `NSTextView` trong lần thử này trả nil; lựa chọn marked text là dự kiến.

Kết quả kiểm thử trước khi cài bản 2026.0.002, ngày 2026-11-04 trên Apple silicon, Xcode 27.2:

| Kiểm tra | Kết quả |
|---|---|
| Toàn bộ Swift Package | 111 test đạt: 57 session, 52 engine, 2 repository |
| Host và bộ cài macOS, compiler coi warning là lỗi | Bản trước thay đổi native composition: Debug thành công; xem báo cáo cài bản mới bên dưới |
| `Tests/InstallerSmoke/Check.swift` | Đạt với payload mới, sao chép/cập nhật trong thư mục tạm |
| `vitek-bench`, Release, 52.400 phím | p50 0,79 µs; p99 3,29 µs; ngân sách p99 < 50 µs |
| Trang thử HTML | JavaScript qua `node --check`; chưa kiểm UI |
| Phiên bản và khoảng trắng diff | `scripts/version.sh check`, `git diff --check` đạt |

Benchmark chỉ đo engine/session, không đo độ trễ IMK hay vẽ chữ của ứng dụng. Kết quả cài bản mới và kiểm trực tiếp được ghi riêng bên dưới.

Khi môi trường chỉ cho ghi trong thư mục dự án:

```sh
mkdir -p .build/task-module-cache .build/task-cache
CLANG_MODULE_CACHE_PATH="$PWD/.build/task-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/task-module-cache" \
swift test --disable-sandbox --cache-path "$PWD/.build/task-cache"
```

Biên dịch host và bộ cài:

```sh
xcodegen generate --spec Apps/macOS/project.yml
xcodebuild -project Apps/macOS/viTek.xcodeproj -scheme viTekInstaller \
  -configuration Debug -derivedDataPath build/Compatibility.noindex \
  CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

Build không ký chỉ phục vụ kiểm tra biên dịch; cài để dùng theo [INSTALL.md](INSTALL.md).

## Quy trình kiểm trong ứng dụng thật

Mở [trang thử trình duyệt](../Tests/macOSCompatibility/browser.html) trên máy. Trang có input, textarea, contenteditable và textarea đồng bộ giá trị bằng JavaScript. Chọn viTek trong chính cửa sổ đó và gõ từng phím. Không dùng paste, DOM fill hay sự kiện JavaScript làm bằng chứng bộ gõ macOS hoạt động.

Chạy mỗi ca cả khi bật và tắt **Gạch chân chữ đang gõ**. Tắt gợi ý khi kiểm Tab điều hướng; kiểm gợi ý thành ca riêng.

| Ca | Thao tác | Kết quả cần kiểm |
|---|---|---|
| Từ đầu tiên | Ô trống, gõ `vieetj ` | `việt `, không còn chữ đầu bị tách |
| Tự nhận | Gõ `vieetj vie65t reset server ` | `việt việt reset server ` |
| Đổi thanh, giữ độ dài | Gõ `vieet`, rồi `j` | `viêt` đổi ngay thành `việt`, không phải chờ Space |
| Xóa khi đang soạn | Gõ `vieetj`, Backspace, `t`, Space | `việt ` |
| Vùng chọn | Chọn `cũ` giữa `trước cũ sau`, gõ `vieetj`, Return | Chỉ vùng chọn được thay; hai bên còn nguyên |
| UTF-16 | Đặt con trỏ sau `👩🏽‍💻 `, gõ `vieetj ` | Emoji còn nguyên, tiếp theo là `việt ` |
| Chuyển focus | Đang gõ từ, bấm ô khác rồi gõ tiếp | Không chèn lặp từ cũ hay thay chữ trong ô mới |
| Di chuyển con trỏ | Đang gõ từ, bấm vị trí khác và gõ | Không sửa vùng cũ bằng vị trí mới |
| Phím ứng dụng | Tab, Shift-Tab, mũi tên, ⌘A, ⌘Z | Phím tới ứng dụng đúng lúc; ghi rõ kết quả Undo |
| Cập nhật viTek | Chọn lại nguồn nhập trong cửa sổ sau cập nhật | Xác nhận nhận phím; ghi riêng nếu cần mở lại ứng dụng |

## Cài bản 2026.0.002

Đã chạy `CONFIGURATION=Release scripts/install_dev.sh` thành công. Phiên bản trong bundle cài là `2026.0.002`; `codesign --verify --deep --strict` đạt. Bản cũ được sao lưu tại `/tmp/vitek-before-marked-composition/viTek.app` trước cập nhật.

SHA-256 của executable đã cài: `c3c1aa5e4200e33cfa42ded08bd6917e9f3292bd6413686e28febddcaa09089b`.

Nhật ký xác nhận Chrome kích hoạt bản có `nativeComposition=true` sau cập nhật. Đây chỉ chứng minh kết nối tới đường gõ mới, không thay cho kiểm kết quả chữ. Chẩn đoán được bật tạm rồi tắt lại sau kiểm tra; thiết lập ban đầu không có khóa này.

## Ma trận cần xác nhận trên bản sửa

| Nhóm | Ứng dụng / bề mặt | Trạng thái trong đợt này |
|---|---|---|
| Cocoa | TextEdit, Notes, Xcode | Chưa kiểm giao diện ứng dụng thật |
| WebKit | Safari: input, textarea, contenteditable | Chưa kiểm trực tiếp |
| Chromium | Chrome 156.0.8078.80: input trên biểu mẫu W3C | Bản 2026.0.002 đạt Telex/VNI xen tiếng Anh, đổi thanh cùng độ dài, Backspace và chuyển giữa hai ô nhập khi từ chưa chốt. Edge chưa kiểm |
| Gecko | Firefox: ba ô nhập chuẩn | Chưa kiểm trực tiếp |
| Electron | VS Code 1.143.1: editor Untitled | Bản 2026.0.002 đạt Telex/VNI xen tiếng Anh, đổi thanh trước dấu cách, Backspace và gõ tiếp; đã kiểm cả AX và ảnh cửa sổ |
| Electron | Claude 4.4212.0, cửa sổ New session | Đạt Telex/VNI/Anh, đổi thanh trước Space, Backspace và gõ tiếp; vào được ô nháp bằng File → New Session in New Window |
| Electron | DeepSeek Harness 0.2.1-rc.5, ô nháp mới | Đạt Telex/VNI/Anh, đổi thanh, Backspace và chốt từ |
| Electron | Antigravity 2.28.2, Message input | Đạt Telex/VNI/Anh, đổi thanh, Backspace và chốt từ |
| Electron | Grok Bot 0.78.1, Prompt | Đạt Telex/VNI/Anh, đổi thanh, Backspace và chốt từ; khôi phục nháp gốc |
| Electron | Cursor 3.25.9, Cursor Agents Prompt | Lần đầu chữ thô, chưa có activation viTek; mở lại rồi đạt toàn bộ chuỗi và sửa dấu. TIS và log xác nhận Cursor dùng viTek ở lượt đạt |
| Electron | Qoder 0.5.1, New Task | Đã tới được ô nhập sau khi đóng menu bằng Cancel. Lượt chữ thô chưa hợp lệ: foreground thực là UserNotificationCenter, không có phím Qoder tới IMK; chờ người dùng xử lý hộp thoại được bảo vệ |
| Electron | Slack | Chưa kiểm |
| Terminal | Terminal, iTerm2 | Chưa kiểm trực tiếp |
| JVM | JetBrains | Chưa kiểm trực tiếp |

### Phím thực tế trên bản cài 2026.0.002

Người dùng đã nhường bàn phím/chuột cho lượt kiểm. Dùng các lệnh `pressKey` riêng từng phím qua công cụ điều khiển ứng dụng macOS; không dùng paste, DOM fill hoặc JavaScript sinh input để tạo kết quả kiểm IME. Môi trường macOS 27.2 (26B123), Apple silicon.

| Ứng dụng | Chuỗi phím / thao tác | Kết quả quan sát |
|---|---|---|
| Chrome, ô First name trên W3C | `vieetj vie65t reset server ` | `việt việt reset server ` |
| Chrome | Chọn toàn bộ; gõ `vieet`, rồi `j`, chưa Space | `việt` ngay trong ô nhập |
| Chrome | Backspace khi đang soạn `việt` | `việ` |
| Chrome | Gõ lại `t`, bấm ô Search kế bên trước khi Space, gõ `nam ` | Ô cũ giữ `việt`; ô mới chỉ có `nam `, không ghép/lặp |
| VS Code, tài liệu mới | `vieetj vie65t reset server ` | `việt việt reset server `; AX và ảnh cửa sổ khớp |
| VS Code | Chọn toàn bộ; gõ `vieetj`, chưa Space | `việt` |
| VS Code | Backspace, rồi `t` và Space | Từng bước: `việ`, rồi `việt ` |

Đã xóa nội dung và đóng tài liệu Untitled thử trong VS Code; cửa sổ trở về Welcome. Chrome được kiểm trong cửa sổ W3C riêng, không dùng biểu mẫu mua hàng hay gửi biểu mẫu. Lệnh đóng cửa sổ thử Chrome bị timeout lúc đọc trạng thái, nên không xác nhận việc đóng. Lượt kiểm tiếp theo đã gõ vào nháp Claude; không gửi tin nhắn. Bộ gõ vẫn cài bản mới; chẩn đoán giữ trạng thái tắt.

### Lượt kiểm Electron mở rộng

Claude, DeepSeek Harness, Antigravity, Grok Bot và Cursor đều nhận chuỗi phím `vieetj vie65t reset server ` thành `việt việt reset server `. Sau khi chọn lại toàn bộ nội dung thử, gõ `vieetj` cho `việt` trước Space; Backspace cho `việ`; `t` rồi Space cho `việt `. DeepSeek Harness và Antigravity biểu diễn thêm ký tự zero-width trong AX khi đang có composition; sau chốt từ, giá trị AX là `việt `.

Đã xóa nháp thử của DeepSeek Harness và Cursor. Grok Bot có sẵn nháp `vieetj` trước kiểm, đã khôi phục đúng bằng paste sau khi kiểm; thao tác paste này chỉ phục hồi nháp, không được tính là kiểm IME. Nháp thử Claude còn `việt`; việc xóa nháp Antigravity chưa được xác nhận vì lượt xóa vẫn đọc lại `việt `. Không gửi tin nhắn hay tạo tác vụ chạy trong các ứng dụng.

Chuyển từ Claude sang DeepSeek, ô mới chỉ nhận `nam `; chưa xác nhận được ô Claude gốc ở cùng lượt vì công cụ chuyển sang một cửa sổ Claude khác. Không tính trường hợp này là kiểm đầy đủ chuyển ứng dụng giữa từ.

### Phân biệt lỗi nhập liệu với tiêu điểm kiểm thử

Lượt Cursor đầu cho chữ thô nhưng không có activation viTek trong log. Sau khi mở lại Cursor, API TIS ngoài sandbox xác nhận viTek enabled/selected; foreground là Cursor và log có activation, các lệnh mark rồi insert. Lượt kiểm UI khi đó đạt. Chưa xác định nguyên nhân chính xác của lượt đầu; không quy thành lỗi thuật toán.

Lượt Qoder cho chữ thô trong khi foreground thực là `com.apple.UserNotificationCenter`. Nhật ký không có phím Qoder mới. Công cụ từ chối điều khiển UserNotificationCenter vì lý do an toàn; cần người dùng tự xử lý hộp thoại rồi đưa Qoder ra trước. Không dùng đường vòng để điều khiển hộp thoại bị chặn và không tính lượt Qoder này là thất bại của engine.

`defaults AppleEnabledInputSources` không có viTek trong lần đọc, nhưng API TIS ngoài sandbox xác nhận viTek đã bật và được chọn, Launch Services và tiến trình đều trỏ đúng bản cài 2026.0.002. TIS trong sandbox báo lỗi kết nối hiservices và có thể trả trạng thái không đáng tin. Không sửa đăng ký nguồn nhập chỉ dựa trên dữ liệu defaults/sandbox này.

Các ca này xác nhận các bề mặt được nêu, không khẳng định mọi editor web hay mọi ứng dụng Electron đều đã qua. Mất readback chủ động được kiểm trong harness Cocoa; chưa tiêm lỗi readback vào tiến trình Chrome/Electron thật.

Các xác nhận lịch sử ở [ROADMAP.md](ROADMAP.md) không được tính là kiểm thử bản sửa này. Trang thử cục bộ từng bị chính sách công cụ chặn mở URL `file://`; kiểm trực tiếp tiếp theo dùng biểu mẫu công khai W3C, không truy cập tệp cục bộ qua trình duyệt. Không suy ra tương thích toàn bộ ứng dụng từ unit test hoặc build thành công. Đổi thanh cùng độ dài đã đạt trên input Chrome và editor VS Code trong lượt này; các editor khác và mọi tình huống nối lại nguồn nhập sau cập nhật vẫn cần kiểm riêng.

Ghi kết quả kèm phiên bản macOS, ứng dụng, nguồn nhập đang chọn, loại ô, trạng thái gạch chân, chuỗi phím và kết quả thực tế. Chỉ dùng nội dung thử. Nhật ký chẩn đoán có sẵn của viTek chỉ ghi loại lệnh, độ dài và vị trí, không ghi chữ người dùng.

Tham chiếu giao thức: [Apple — replacementRange](https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller/replacementrange()).
