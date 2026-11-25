# Đặc tả engine viTek

Engine biến chuỗi phím thành chữ Việt. Tài liệu này là đặc tả. Code trong `Sources/VitekEngine` phải khớp với nó, và mọi thay đổi hành vi phải cập nhật cả hai cùng với test.

---

Khi dùng nguồn nhập macOS hoặc CLI mặc định, viTek thử Telex với chữ cái và đọc lại từ theo VNI khi xuất hiện phím số có thể đặt dấu. Một số chuỗi có cả cách đọc tiếng Anh và tiếng Việt, ví dụ `has` hay `too`. Với các chuỗi này, điểm Telex dương ưu tiên chữ Việt. Mã dạng `A1` được giữ nguyên trừ khi điểm VNI dương. Chỉ từ đã chốt có tín hiệu rõ mới cập nhật hai điểm. Các quy tắc Telex và VNI cố định dưới đây cũng có thể thử riêng bằng CLI với `--telex` hoặc `--vni`.

Khi bật giữ từ tiếng Anh, engine xét từ vừa chốt trước dấu cách. Một từ tiếng Anh đã nhận ra hoặc một chuỗi chữ cái được giữ nguyên mà engine không đọc được thành âm tiết Việt (như `read`, `need`, `over`) ưu tiên cách đọc tiếng Anh của từ mơ hồ kế tiếp. Một từ có chữ Việt mang dấu hoặc từ gợi ngữ cảnh như `sinh`, `trong` ưu tiên Telex. Ví dụ, `over there` giữ nguyên và `cos there` thành `có thể`, kể cả khi thói quen của ứng dụng thiên về ngôn ngữ kia. Tín hiệu chỉ dùng trong ô nhập hiện tại và hết hiệu lực khi gặp dấu câu hoặc khi rời ô.

Ở đầu phiên tự nhận, `this`, `more`, `there` ưu tiên tiếng Anh nếu điểm Telex chưa dương. Năm chuỗi ngắn `car`, `her`, `if`, `sex`, `was` cần tín hiệu tiếng Anh ngay trước đó mới được giữ nguyên. Telex cố định vẫn cho cách đọc tiếng Việt khi gõ từng từ riêng. Các từ mơ hồ không làm thay đổi hai điểm thói quen.

## 1. Thuật ngữ

| Từ | Nghĩa | Trong code |
|---|---|---|
| Chữ gốc | chữ cái ASCII thường `a`…`z` | `Form.base` |
| Dấu phụ | mũ (â ê ô), trăng (ă), móc (ơ ư), gạch (đ) | `Mark` |
| Thanh | ngang, huyền, sắc, hỏi, ngã, nặng | `Tone` (`level`, `grave`, `acute`, `hook`, `tilde`, `dot`) |
| Dạng chữ | chữ gốc + dấu phụ, không hoa/thường, không thanh | `Form` |
| Chữ | dạng chữ + hoa/thường | `Letter` |
| Phụ âm đầu | phần trước nguyên âm đầu tiên (`ngh`, `qu`, `gi`) | `Orthography.onsets` |
| Chuỗi nguyên âm | các nguyên âm liền nhau sau phụ âm đầu | `Segments.vowels` |
| Vần | chuỗi nguyên âm + phụ âm cuối | `Orthography.rhymes` |

Một từ đang gõ là **danh sách chữ + một thanh cho cả âm tiết**. Thanh không gắn vào chữ nào. Chữ hiển thị được dựng lại sau mỗi phím, nên dấu gõ ở đâu cũng về đúng chỗ.

## 2. Chính tả

### 2.1 Phụ âm đầu

`b c ch d đ g gh gi h k kh l m n ng ngh nh p ph qu r s t th tr v x` hoặc rỗng.

* **qu**: `u` sau `q` là âm đệm, thuộc phụ âm đầu. Vần còn lại là vần có âm đệm bỏ chữ đệm: `qua` ~ `oa`, `quê` ~ `uê`, `quốc` ~ `uôc`, `quyên` ~ `uyên`, và cách viết cũ `quít` ~ `uyt`.
* **gi**: trước một nguyên âm khác, `gi` là phụ âm đầu (`gia`, `giữa`; `giêng` là gi + iêng). Đứng riêng hoặc trước phụ âm cuối thì là `g` + `i` (`gì`, `gìn`).

Sau `qu` còn có vần `au` như trong `quạu`. Telex nhận cả `quauj` và `quaju`, VNI nhận `quau5`.

### 2.2 Vần

Danh sách đóng trong `Orthography.rhymes` (khoảng 150 vần, gồm vần vay mượn `oong`, `ooc` và vần địa phương `ưm`, `ưn`). Danh sách này chính là đặc tả; khi sửa phải kiểm lại bằng từ điển.

Ràng buộc theo phụ âm đầu:

* không có phụ âm đầu: `iê…` viết thành `yê…` (`yêu`, `yên`);
* có phụ âm đầu: `yê…` viết thành `iê…` (`tiên`);
* `k`, `gh`, `ngh` chỉ đứng trước `e ê i y`; `c`, `g`, `ng` thì ngược lại (ngoại lệ `gì`).

### 2.3 Thanh và phụ âm cuối tắc

Âm tiết kết thúc bằng `c`, `ch`, `p`, `t` chỉ mang thanh sắc hoặc nặng. Khi đang gõ, còn được phép chưa có thanh (vì người dùng có thể gõ thanh sau). Khi hết từ thì bắt buộc phải có (`viêt` không phải một từ, `việt` thì phải).

### 2.4 Vị trí dấu thanh (`Orthography.toneIndex`)

1. Một nguyên âm → nguyên âm đó.
2. Có nguyên âm mang dấu phụ (â ă ê ô ơ ư) → nguyên âm mang dấu phụ cuối cùng (`ươ` → `ơ`).
3. Có phụ âm cuối → nguyên âm cuối (`hoàn`, `huỳnh`, `toán`).
4. Ba nguyên âm → nguyên âm giữa (`hoài`, `khuỷu`, `ngoẻo`).
5. Hai nguyên âm: `oa`, `oe`, `uy` theo kiểu đặt dấu (`modern`: `hoà khoẻ thuý`; `traditional`: `hòa khỏe thúy`); các cặp khác → nguyên âm đầu (`mái`, `múa`, `mía`).

### 2.5 `ươ` không có âm cuối

`ươ` cần âm cuối (`ương`, `mươi`). Không có âm cuối thì viết `uơ` (`thuở`, `huơ`). Telex `uow` luôn đặt móc cả hai, nên việc chọn được hoãn tới khi hết từ.

## 3. Composer

### 3.1 Ba chế độ

| Chế độ | Hiển thị | Phím tiếp theo | Vào khi |
|---|---|---|---|
| `vietnamese` | chữ + thanh dựng lại | phím dấu tiếp tục đặt dấu | đầu từ |
| `literal` | văn bản như đang thấy | thêm nguyên phím | người dùng gõ lặp phím dấu để huỷ; hoặc từ hết là tiếng Việt khi viTek chưa đổi gì |
| `restored` | phím gốc nguyên văn | thêm nguyên phím | viTek đã đổi từ, rồi từ hết là tiếng Việt (`sẻv` → `serv`) |

### 3.2 Bảng phím

| Ý nghĩa | Telex | VNI |
|---|---|---|
| sắc huyền hỏi ngã nặng | `s f r x j` | `1 2 3 4 5` |
| xoá thanh | `z` | `0` |
| mũ (â ê ô) | `aa ee oo` (đúng nguyên âm đó) | `6` (a, e hoặc o) |
| móc (ơ ư; `uo` → `ươ`) | `w` | `7` |
| trăng (ă) | `w` | `8` |
| gạch (đ) | `dd` | `9` |
| iê rút gọn của viTek | `iw` hoặc `iew` (tuỳ chọn `quickTelexW`, mặc định bật) | — |
| ư đứng riêng | `w` (tuỳ chọn `standaloneW`) | — |
| ơ, ư một phím | `[ ]`, hoa `{ }` (tuỳ chọn `bracketVowels`) | — |

Telex chuẩn vẫn dùng `vieetj` → `việt`. Tuỳ chọn gõ nhanh của viTek thêm `viw` → `viê`, `viwtj` → `việt`, `viwts` → `viết`, và `vietwj` → `việt`. `s` vẫn là dấu sắc; có thể đặt trước/sau `w`. Nhấn `w` lần nữa trả ký tự gốc (`viww` → `viw`, `vieww` → `view`); Backspace xoá ký tự đang hiển thị (`viê` → `vi`). Chữ hoa theo nguyên âm đã gõ, không theo phím modifier. Từ chưa hoàn chỉnh như `viê` vẫn theo quy tắc khôi phục chính tả khi kết thúc từ. Có thể tắt riêng trong Cài đặt → Telex.

Khi bật giữ từ tiếng Anh, `view` ưu tiên tiếng Anh ngay lúc đang soạn, kể cả khi ngữ cảnh trước đó thiên về tiếng Việt. Gõ tiếp `s`, `er`, `ing` giữ tiền tố đang thấy (`views`, `viewer`, `viewing`). Backspace từ `view` cho `vie`, từ `views` cho `view`; gõ lại chữ vừa xóa không mất ký tự. `vieww` vẫn là thao tác hủy `w` cho `view`. Do ưu tiên này, dùng `viwtj` hoặc `vietwj` để gõ `việt`; `viewtj` chỉ đọc thành `việt` khi tắt giữ từ tiếng Anh. `swiss` giữ đủ hai chữ `s` cuối, cùng quy tắc bảo vệ các từ tiếng Anh chứa phím thanh lặp.

### 3.3 Đặt dấu phụ

Phím dấu tìm **ứng viên** trong chuỗi nguyên âm, từ phải sang trái, và nhận ứng viên đầu tiên mà kết quả vẫn **có thể thành âm tiết** (`Orthography.isPlausiblePrefix`):

* `w`/`7`: thử cặp `uo` trước (→ `ươ`), sau đó từng a/o/u (`mua` + w: `muă` không hợp lệ → `mưa`; `hoa` + w → `hoă`).
* mũ: nguyên âm cùng chữ gốc (Telex) hoặc bất kỳ a/e/o (VNI); đổi được `ă`→`â`, `ơ`→`ô`.
* gạch: chỉ áp lên `d` ở đầu từ, ở bất kỳ thời điểm nào (`dod` → `đo`).
* thanh: cần ít nhất một nguyên âm; thanh mới thay thanh cũ.

Không có ứng viên: phím Telex được gõ như một chữ cái; chữ số VNI kết thúc từ và đi thẳng tới ứng dụng (`var1`, `win10`).

Khi tắt `spellCheck`, mọi ứng viên đều được nhận và không bao giờ khôi phục.

### 3.4 Huỷ bằng phím lặp

Gõ lại phím dấu khi dấu đó đã có thì huỷ dấu, gõ nguyên phím, và chuyển sang `literal`: `ass` → `as`, `aaa` → `aa`, `ddd` → `dd`, `ww` → `w`, `a11` → `a1`.

Khi bật giữ từ tiếng Anh, nếu các phím đã gõ khớp với một mục trong `EnglishWords.repeatedToneKeyWords` như `office`, `current` hay `password`, viTek khôi phục chữ lặp ngay trong từ đang soạn và giữ kiểu hoa. Các chữ gõ tiếp nối vào từ đang thấy, ví dụ `offering`. Backspace xoá một chữ đang hiển thị, nên `boss⌫` còn `bos`.

### 3.5 Kiểm tra chính tả khi gõ

Sau mỗi chữ cái, nếu từ không còn có thể là âm tiết:

* viTek đã đổi gì đó và từ có nguyên âm → `restored` (hiện phím gốc);
* ngược lại → `literal` (giữ như đang thấy). Riêng từ chỉ có phụ âm thì giữ `đ` cho kiểu viết tắt khi chat (`đc`, `đt`).

### 3.6 Backspace

* `vietnamese`: xoá chữ cuối. Nếu chữ đó đang mang thanh thì bỏ thanh (`việt` ⌫⌫ → `vi`). Phím gốc được thay bằng chữ đang hiển thị.
* `literal`: xoá ký tự cuối.
* `restored`: phát lại toàn bộ phím trừ phím cuối, vì chính phím cuối có thể là thứ làm hỏng từ (`đườngg` ⌫ → `đường`).

### 3.7 Kết thúc từ (`finish`)

Sau khi áp §2.5, engine trả `FinishedWord { text, keys, vietnamese }`:

* `restored` → phím gốc; `literal` → văn bản đang thấy;
* `vietnamese` → chữ dựng lại, **trừ khi** `restoreInvalidWords` đang bật, viTek đã đổi từ, từ có nguyên âm và không phải âm tiết hoàn chỉnh. Khi đó trả phím gốc (`user` → `user`, `data` → `data`, `vieet` → `vieet`).

Cuối cùng là từ tiếng Anh (`keepEnglishWords`, chỉ với Telex): nếu viTek đã đổi từ, phím cuối là chữ cái thường (không phải phím dấu) và phím gốc viết thường nằm trong danh sách `EnglishWords`, thì trả phím gốc (`test` → `test`, `Reset` → `Reset`). Gõ dấu thanh ở cuối vẫn ra chữ Việt (`tets` → `tét`).

Ngoài nhóm có phím lặp ở §3.4, danh sách còn 69 từ tiếng Anh thông dụng do dự án chọn. Mỗi từ trong nhóm 69 từ được `swift run vitek-wordlist /usr/share/dict/web2` kiểm lại là có xung đột thật, tức cách đọc tiếng Việt mang dấu thanh. Từ chỉ thêm dấu mũ/móc (`teen` → `tên`, `own` → `ơn`) không bao giờ vào danh sách: người gõ Telex thêm các dấu đó ngay khi gõ nguyên âm, nên đó là chữ Việt.

Session áp gõ tắt lên `text`, rồi lên `keys` nếu `text` không khớp.

### 3.8 Sửa từ đã chốt (`resume`)

`resume(word)` nạp lại một từ đã có trong văn bản để phím tiếp theo sửa nó (`viêt` + `j` → `việt`). Engine nạp từng ký tự như khi gõ chữ có dấu trực tiếp (§3.9), phím gốc là chính các ký tự đó, và chỉ nhận khi mọi ký tự là chữ cái và từ dựng lại **đúng y** như đưa vào. Vì thế từ tiếng Anh (`test`), từ đặt dấu khác kiểu đang chọn (`hòa` khi dùng kiểu mới) và từ đang gõ dở đều bị từ chối, không có gì thay đổi.

Host chỉ gọi `resume` khi phím sắp gõ là phím dấu (`EngineOptions.isMarkKey`), không có từ đang soạn, con trỏ đứng ngay sau từ và sau con trỏ không phải chữ cái.

### 3.9 Ký tự Việt dựng sẵn

Layout bàn phím gõ thẳng `ư`, `ệ`… được nhận như chữ kèm dấu phụ và thanh, nên `trương` + `f` → `trường`.

## 4. Giới hạn đã biết

* Từ tiếng Anh ngoài danh sách vẫn có thể thành chữ Việt (`seem` → `sêm`, `wow` → `uơ`), và người quen gõ dấu thanh giữa từ phải gõ dấu ở cuối với 69 từ trong danh sách (`lits` → `lít`). Các ca này được ghim trong `RestoreTests.knownAmbiguities` và `EnglishWordsTests` để thay đổi nào cũng phải có chủ đích.
* `â`, `ă` đứng một mình không phải âm tiết nên hết từ sẽ về phím gốc (`aa` → `aa`).
* Sửa từ đã chốt dựa vào việc ứng dụng trả đúng văn bản quanh con trỏ (`attributedSubstring`). Ứng dụng tự sửa chính tả (TextEdit với "Correct spelling automatically") có thể đã đổi từ trước khi viTek đọc lại, và Backspace ngay sau một lần tự sửa sẽ hoàn tác lần sửa đó.
* Chưa có gợi ý từ.

## 5. Kiểm thử

* `GlyphsTests`: mọi ký tự trong bảng là một scalar NFC và phân rã đúng thành chữ gốc + dấu.
* `OrthographyTests`: phụ âm đầu, vần, quy tắc c/k/g/ng, thanh với âm cuối tắc, vị trí dấu theo hai kiểu.
* `TelexTests`, `VNITests`, `RestoreTests`, `EditingTests`: hành vi gõ, thứ tự dấu tự do, huỷ, khôi phục, Backspace, câu hoàn chỉnh.
* `EnglishWordsTests`: từ trong danh sách giữ nguyên, kết thúc bằng phím dấu vẫn ra chữ Việt, mọi từ trong danh sách đều xung đột thật.
* `ResumeTests`: sửa từ đã chốt, từ chối từ không dựng lại được, theo đúng kiểu đặt dấu.
* `randomKeysNeverBreakTheEngine`: 4 cấu hình × 2.000 chuỗi ngẫu nhiên có seed cố định.

Ca kiểm thử mới phải **do người viết soạn** từ quy tắc ở đây hoặc từ từ điển công khai, không chép từ bộ test của dự án khác ([SOURCES.md](../SOURCES.md)).
