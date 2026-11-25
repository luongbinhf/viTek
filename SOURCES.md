# Nguồn gốc và giấy phép

Mọi đóng góp đưa vào kho mã nguồn viTek phải có nguồn gốc và giấy phép rõ ràng.

## Không được dùng

* Mã nguồn hoặc dữ liệu của bất kỳ bộ gõ tiếng Việt nào khác (bất kể giấy phép), kể cả bảng mã, bộ test hay danh sách từ của chúng.
* Dữ liệu, asset hoặc thư viện mà giấy phép không cho phân phối theo giấy phép MIT mã nguồn mở và trên App Store.

## Được dùng

* Kiến thức chính tả tiếng Việt, sách giáo khoa, từ điển và tài liệu ngôn ngữ học công khai (để suy ra quy tắc, không chép bảng có bản quyền).
* Tài liệu công khai của Apple (InputMethodKit, Text Input Sources, Human Interface Guidelines), Swift Evolution, Unicode (UCD, CLDR) theo giấy phép của chúng.
* Dữ liệu có giấy phép cho phép phân phối theo giấy phép MIT mã nguồn mở và trên App Store (CC0, public domain, MIT, Apache-2.0, ODC-By kèm ghi công). **Không** dùng CC BY-SA, CC BY-NC hoặc "chỉ dùng cho nghiên cứu" trong sản phẩm.
* Thư viện bên thứ ba khai báo bằng Swift Package Manager, giấy phép permissive, ghi vào bảng bên dưới.

## Bảng nguồn

Mỗi dữ liệu, asset hoặc thư viện bên ngoài là một dòng. PR thiếu dòng thì không merge.

| Thành phần | Nguồn | Giấy phép | Ghi chú |
|---|---|---|---|
| Bảng vần, phụ âm đầu, quy tắc đặt dấu (`Orthography.swift`) | soạn trong dự án từ chính tả tiếng Việt | thuộc dự án | kiểm bằng `OrthographyTests` |
| Bảng ký tự dựng sẵn (`Glyphs.swift`) | Unicode Character Database | Unicode License v3 | kiểm bằng phân rã chuẩn trong `GlyphsTests` |
| Danh sách từ tiếng Anh (`EnglishWordList.swift`, `EnglishWords.swift`) | 143 từ do dự án chọn, kiểm bằng `/usr/share/dict/web2` (Webster's Second International, 1934) có sẵn trong macOS | web2: hết hạn bản quyền (public domain); danh sách chọn: thuộc dự án | 69 mục có cách đọc Telex mang dấu và 74 mục khôi phục chữ sau thao tác huỷ dấu |
| Bộ nhận diện thương hiệu, linh vật Cú Lạc & Logo (`AppIcon.icns`, `viTek.png`, `BrandMascot.png`, `assets/brand/*`) | tạo trong dự án và đóng gói qua `scripts/make_brand_assets.swift` | thuộc dự án (MIT) | sinh lại được từ nguồn gốc |
| Icon nguồn nhập (`InputIconTemplate.pdf`) | vẽ trong dự án bằng `scripts/make_input_icon.swift`: PDF vector, chữ là đường viền glyph của font hệ thống | thuộc dự án | sinh lại được từ script |
| Tín hiệu thói quen gõ (`TypingHabits.swift`) | Ví dụ từ mơ hồ và từ tiếng Anh do dự án chọn cho chế độ tự động | thuộc dự án | chỉ lưu điểm số theo ứng dụng |
| Gợi ý viết | Foundation Models của Apple, gọi `SystemLanguageModel.default` | thuộc hệ điều hành | mô hình trên thiết bị, không đóng gói trọng số |
| Gợi ý từ bổ sung | dịch vụ hoàn tất từ tiếng Việt của macOS, gọi qua `NSSpellChecker` | thuộc macOS | chỉ bổ sung sau kết quả cục bộ; không dùng cho code |
| Từ/cụm và thuật ngữ (`BuiltinVocabulary.swift`) | dữ liệu khởi đầu do dự án tự soạn, chia 6 lĩnh vực | thuộc dự án | ưu tiên biên tập, không phải tần suất đo từ corpus; không chép từ điển hay dữ liệu của bộ gõ khác |
| Từ khóa và member code (`CodeCompletion.swift`) | danh sách do dự án chọn; định danh khác chỉ lấy trong ngữ cảnh của lượt gợi ý | thuộc dự án | hoàn tất từ vựng, không suy luận kiểu hoặc chạy mã |
| `actions/checkout` (CI) | GitHub, [github.com/actions/checkout](https://github.com/actions/checkout) | MIT | chỉ dùng trong `.github/workflows`, không vào sản phẩm |
| XcodeGen (build) | [github.com/yonaskolb/XcodeGen](https://github.com/yonaskolb/XcodeGen), cài bằng Homebrew | MIT | công cụ sinh `.xcodeproj`, không vào sản phẩm |

Để ưu tiên các chữ lặp, dự án đối chiếu các lỗi trên `web2` với 5.000 mục có tần suất cao nhất trong bảng [Google Web 1T do Peter Norvig công bố](https://norvig.com/ngrams/). Với mỗi mục có chữ gõ tiếp sau `ss`, `ff` hoặc `rr` đã huỷ dấu, dự án chọn tiền tố ngắn nhất cũng là một mục từ `web2` có cùng lỗi và thuộc 10.000 hạng đầu. Cách chọn này thêm 71 mục tra cho 86 từ ưu tiên. Bảng tần suất chỉ dùng khi phân tích.

## Checklist cho mỗi PR

- [ ] Không chép code, dữ liệu hay test từ bộ gõ khác.
- [ ] Ca kiểm thử mới do tôi soạn.
- [ ] Dữ liệu, asset hoặc thư viện mới đã có dòng trong bảng nguồn.
