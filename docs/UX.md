# Giao diện viTek

viTek là bộ gõ: phần lớn thời gian người dùng không nhìn thấy nó. Giao diện chỉ xuất hiện khi cần và không bao giờ lấy focus khỏi chỗ đang gõ.

## 1. Nguyên tắc

1. **Không cắt ngang việc gõ.** Không cửa sổ nào tự bật lên. Cửa sổ cài đặt chỉ mở khi người dùng chọn từ menu nguồn nhập.
2. **Theo chuẩn macOS.** Bố cục giống System Settings: thanh bên có icon màu, trang dạng Form nhóm. Dùng control hệ thống, SF Symbols, màu nhấn hệ thống. Tự hỗ trợ chế độ tối và Dynamic Type.
3. **Đổi là áp dụng ngay.** Thay đổi có hiệu lực từ từ tiếp theo, không làm hỏng từ đang gõ.
4. **Ví dụ thay cho định nghĩa.** Mỗi tuỳ chọn có ví dụ phím → kết quả (`tets` → `tét`), phím vẽ như phím thật.
5. **Tiếng Việt trước.** Mọi chữ trong giao diện là tiếng Việt có dấu; tên phím và ví dụ phím dùng font monospace.

## 2. Các bề mặt

| Bề mặt | Khi nào thấy | Nội dung |
|---|---|---|
| Nhãn thanh menu | khi viTek là nguồn nhập | macOS tự vẽ nhãn "VI" từ `TISIntendedLanguage = vi`, giống Telex của Apple |
| Icon nguồn nhập | danh sách Input Sources, menu nguồn nhập | `InputIconTemplate.pdf`: ô 22 × 16 pt chữ "Vi" khoét rỗng, PDF vector template như nhãn "A"/"VI" của hệ thống |
| Logo ứng dụng | Finder, trang Giới thiệu, các danh sách ứng dụng của System Settings | `AppIcon.icns`: biểu tượng squircle xanh ngọc & linh vật Cú Lạc viTek (`scripts/make_brand_assets.swift`) |
| Menu nguồn nhập | bấm icon | Chế độ gõ `VI/EN` · Đặt dấu kiểu mới · Kiểm tra chính tả · Gõ tắt · Gợi ý từ · Clipboard nhanh · Chuyển mã nhanh · Gợi ý viết… (macOS 26+) · Hướng dẫn nhanh… · Cài đặt viTek… |
| Thanh bên cài đặt | cửa sổ cài đặt | khối Liquid Glass bo góc, thụt vào trong cửa sổ (macOS 26+) |
| Chữ đang soạn | khi gõ | ưu tiên chữ đã chốt với vùng sửa đã xác minh; marked text chỉ là đường tương thích, một số ứng dụng vẫn tự vẽ gạch chân trên đường này |
| Thanh gợi ý | khi đang gõ dở hoặc ngay sau dấu cách | viên nang Liquid Glass, tối đa 5 từ, từ đầu tô nhạt màu nhấn, kèm phím chọn nhanh `⌥Space` (chọn đầu) và `⌥1–⌥5`. Ở cuối dòng, thanh nằm **cùng dòng, ngay sau con trỏ**, nơi không có chữ nào để che; giữa dòng thì xuống dưới dòng. Trong Chrome và ứng dụng Electron, vị trí con trỏ lấy qua Trợ năng: cần quyền Trợ năng (nút "Cấp quyền…" trong Kiểu gõ), chưa có thì không hiện thanh. Không nhận chuột, không lấy focus |
| Bảng dán nhanh Clipboard | bấm `⌃⌥V` | bảng nổi Liquid Glass (`ClipboardPanel`), hiển thị tối đa 9 mục (ghim ở trên, gần đây ở dưới), hỗ trợ bấm số `1–9` hoặc click để dán, `Esc` để đóng |
| Cửa sổ cài đặt | từ menu nguồn nhập | thanh bên 7 mục, xem §3 |

## 3. Cửa sổ cài đặt

Cửa sổ mở ở 780 × 560 pt và cho phép đổi kích thước. Bố cục dùng `NavigationSplitView` với thanh bên rộng 200 pt. Mỗi trang mở đầu bằng cùng một khối tiêu đề: logo viTek 44 pt, tên trang, một câu mô tả.

```text
┌──────────────┬───────────────────────────────────────────────┐
│ ● Bắt đầu    │  [icon]  Tên trang                            │
│ ● Kiểu gõ    │          Một câu nói trang này để làm gì.      │
│ ● Thói quen  │                                               │
│ ● Gõ tắt     │  ┌─ nhóm ──────────────────────────────────┐  │
│ ● Từ điển    │  │ Tuỳ chọn                         [ ◯ ]  │  │
│ ● Giới thiệu │  │ Tuỳ chọn                     [ Chọn ⌄ ] │  │
│              │  └─────────────────────────────────────────┘  │
│              │    Chú thích: ví dụ và hệ quả của nhóm trên.  │
└──────────────┴───────────────────────────────────────────────┘
```

| Mục | Icon, màu | Nội dung |
|---|---|---|
| Bắt đầu | `sparkles`, hồng | Ba bước chọn nguồn nhập, thử Telex/VNI và gõ xen tiếng Anh. Các hàng trong “Cài đặt hiện tại” mở thẳng trang tương ứng. |
| Kiểu gõ | `keyboard`, xanh dương | Bảng phím tham khảo Telex và VNI, kiểu đặt dấu, sửa từ vừa gõ (`viêt| + j` → việt), chính tả và trả lại phím, tuỳ chọn riêng của Telex. |
| Thói quen gõ | `globe`, xanh lá | Số ứng dụng đã học và nút xóa điểm ưu tiên. |
| Gõ tắt | `text.badge.plus`, cam | Sửa trực tiếp hai cột hoặc xóa ở cuối mỗi dòng. Chọn “Thêm gõ tắt”, nhập cả hai trường rồi lưu. Có thể quản lý và nhập/xuất danh sách cả khi tạm tắt gõ tắt. |
| Từ điển | `character.book.closed`, chàm | Bật/tắt giữ từ tiếng Anh và tra danh sách theo một phần của từ. Ô tìm kiếm vẫn dùng được khi tắt tùy chọn. |
| Clipboard | `doc.on.clipboard`, xanh cổ vịt | Quản lý lịch sử sao chép và mẫu ghim cố định, tìm kiếm tiếng Việt không dấu, chuyển mã nhanh và cấu hình đồng bộ iCloud. |
| Giới thiệu | `info`, xám | Phiên bản, kiểm tra & cập nhật 1 chạm SHA-256, nguồn nhập, bản quyền MIT. |

Menu "Hướng dẫn nhanh…" mở thẳng trang Bắt đầu; "Cài đặt viTek…" mở trang xem lần trước.

## 4. Quy ước bố cục

* Mọi bề mặt viTek đặt nổi trên ứng dụng khác (thanh gợi ý) là `GlassPanel`: panel không viền đặt nội dung SwiftUI trong `NSGlassEffectView` từ macOS 26 (modifier `glassEffect` của SwiftUI trong panel không viền chỉ cho ra nền mờ, không phải kính), nền vật liệu có viền mảnh trên macOS cũ hơn. Nút trong cửa sổ cài đặt dùng `glassButton()`. Sidebar `NavigationSplitView` tự nhận Liquid Glass khi build bằng SDK 26 trở lên.

* Tiêu đề và bảng gõ tắt cách lề ngang 28 pt.
* Trang dạng Form dùng `.settingsForm()` (Form nhóm trên nền cửa sổ) để khối tiêu đề và Form liền một mặt.
* Chú thích dưới nhóm dùng `Footnote` (callout, `secondary`). **Chỉ đặt `Footnote` trong Form.** Đặt thẳng trong `VStack` thì kích thước dọc cố định của nó khiến `NavigationSplitView` đo trang ở bề ngang 0 và đẩy cả cửa sổ ra ngoài khung.
* Phím vẽ bằng `KeyCap`; cặp phím → kết quả dùng `Example`.
* Thanh gợi ý đặt cách đáy khung dòng mà ứng dụng báo `max(8, 0,6 × chiều cao dòng) + 4` pt: Notes và TextEdit báo khung dòng hụt khoảng 8 pt so với chân chữ, đặt sát hơn sẽ đè lên chữ.
* Danh sách dài (gõ tắt) tự vẽ bằng `ScrollView` thay vì `Table`/`List`, để đặt được trong cột chi tiết của `NavigationSplitView`.

## 5. Kiểm tra giao diện

Trên macOS 27 và iOS 27, viTek dùng mức Liquid Glass đã chọn trong Cài đặt hệ thống. Khi kiểm tra giao diện, thử cả ba mốc trong hơn, mặc định và đậm hơn trên cùng một nền. Trên Mac, nhìn cả hai đầu bo của thanh khi số gợi ý đổi từ một lên năm rồi trở về một. Trên iOS, kiểm tra chữ trên các phím và thử gõ khi đổi mức kính.

Bàn phím iOS có [bộ kiểm thử trên Simulator](../Apps/iOS/KeyboardTests/README.md). Khi sửa cửa sổ cài đặt macOS, kiểm tra các thao tác sau.

* Chụp từng trang (một chương trình nhỏ dựng `SettingsView` với từng `SettingsPage` rồi chụp bằng `CGWindowListCreateImage`; `cacheDisplay` không vẽ đúng control AppKit) ở chế độ sáng và tối.
* Mở cài đặt từ menu nguồn nhập thật, kiểm cửa sổ hiện ra phía trước và gõ được vào ô gõ tắt.
* Thử gõ Telex, VNI và tiếng Anh trong cùng một câu, kiểm tra lại sau khi đổi ứng dụng.

### Quy tắc nhập liệu & gợi ý

Chữ được chèn ở trạng thái đã chốt khi ứng dụng cho xác minh vùng sửa, nên ô tìm kiếm có thể gợi ý trước Space. Gạch chân chỉ áp dụng khi phải dùng đường tương thích marked text, không đổi đường sửa chữ. Tab, Return, mũi tên và phím tắt luôn thuộc ứng dụng; `⌥Space` nhận nhanh từ đầu và `⌥1–⌥5` nhận theo vị trí trên thanh gợi ý viTek. Cấu hình mới mặc định tắt gợi ý; lựa chọn đã lưu của người dùng được giữ.

Khi click, đổi ô hoặc điều hướng, giữ nguyên cách viết đang thấy. Không mở rộng gõ tắt hoặc trả phím thô chỉ vì người dùng chuyển con trỏ. Khi mất readback giữa từ, giữ chữ đã có và cho các phím còn lại đi qua đến hết token; không đoán vùng để sửa lại.
