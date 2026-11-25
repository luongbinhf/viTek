# QA khung từ điển và gợi ý — 13/11/2026

## Điểm xuất phát và thay đổi

Đường cũ dựa vào NSSpellChecker cộng 19 cụm và 12 token kỹ thuật. Các fixture `ngư`, `chuy`, `WebS`, `TypeS`, `bảo vệ môi `, `hợp đồng lao `, `co so du `, `JSON.par` và định danh `userName` đều thiếu kết quả từ lõi cục bộ. Bộ kiểm ban đầu có **9 assertion lỗi** trong 4 test ([log đỏ](../reports/qa-prediction-2026-11-13/red.log)).

Đã thêm `PredictionLexicon`, `BuiltinVocabulary`, `WordPrediction`, `CodeCompletion` và metadata cho ứng viên. Xem [đặc tả và giới hạn](PREDICTION.md). `Terminology` trở thành API tương thích dùng cùng dữ liệu. macOS gọi pipeline mới, nhận code không thêm Space; kiểm revision/focus/caret khi nhận vẫn giữ nguyên.

Bộ seed có **617 từ/token khác nhau**, bao gồm các âm tiết thành phần của cụm và token kỹ thuật. Đây không phải 617 mục từ có định nghĩa. Có 6 lĩnh vực: thông dụng, công nghệ, kinh doanh, giáo dục, sức khỏe, khoa học. Không nhập corpus hoặc dữ liệu từ bộ gõ khác. Chưa có phép đo chất lượng ngoài mẫu trên corpus độc lập.

Một vòng kiểm tiếp theo phát hiện `ngư` xếp `ngữ` trên `người`. Đã tái hiện [ca đỏ về xếp hạng](../reports/qa-prediction-2026-11-13/ranking-red.log), bổ sung ưu tiên từ thông dụng và xác nhận `người` đứng đầu. Cụm khớp dài vẫn thắng ưu tiên unigram. Khi mở rộng dữ liệu, ca cũ `AP` có thêm `APPKIT`; kỳ vọng kiểm bỏ trùng đã cập nhật để giữ `API` đầu tiên và chỉ một `API`.

## Kiểm tự động và đo

**196 Swift tests đạt**: 135 session, 59 engine, 2 repository. Có 14 test mới cho từ điển/xếp hạng/code và 4 test native composition mới, gồm nhiều fixture, 50 vòng gõ/xóa, Unicode NFC/NFD, kiểm dấu đã gõ, dấu câu/xuống dòng, miền từ vựng, ngữ cảnh dài, URL/email/path, mid-identifier, dữ liệu không hợp lệ, nguồn system, không giữ định danh qua yêu cầu, không thêm Space cho code. [Log](../reports/qa-prediction-2026-11-13/tests.log).

Lưu ý: `xcơ sở dữ ` vẫn có thể gợi ý `liệu` từ cụm độc lập `dữ liệu thực nghiệm`; đây là suffix ngữ cảnh hợp lệ. Ca kiểm ranh giới dùng `xcơ sở ` để kiểm không khớp nhầm `cơ sở`. Không làm mất gợi ý hợp lệ chỉ để khớp một kỳ vọng test sai.

[Benchmark Release](../reports/qa-prediction-2026-11-13/benchmark.json), 12 ngữ cảnh × 1.000 lần, không NSSpellChecker/AI/host:

| Số đo | Kết quả |
|---|---:|
| Dựng chỉ mục lần đầu | 7,22 ms |
| p50 | 31,83 µs |
| p99 | 170,96 µs |
| Cao nhất | 7,51 ms |
| Tổng lượt tra | 12.000 |

Máy đang có các công việc build khác; đây là số đo của lượt chạy, không phải cam kết độ trễ end-to-end hoặc hiệu năng trên mọi chip. Chỉ mục chạy trên actor của gợi ý, không trong thao tác biến đổi từng phím của engine. Chưa đo mức dùng ANE; đường tra cứu này là Swift cục bộ.

## Mất chữ khi gõ nhanh và hệ tọa độ con trỏ

Stress trên VS Code phát hiện “hợp đồng lao” thành “hợp ngf lao” hoặc “hợp òng lao” trước khi nhận gợi ý. Không kết luận từ lượt đầu: engine thuần trả đúng; 10 vòng gõ riêng cụm từ và 10 vòng có log đều đạt, nhưng stress không log tái hiện ở vòng 27. Một lượt có log tiếp theo tái hiện ở vòng 2 ([UI đỏ](../reports/qa-prediction-2026-11-13/vscode-ui-red.log)).

[Trace vị trí/độ dài](../reports/qa-prediction-2026-11-13/vscode-callback-red.log) cho thấy các phím vẫn tới IMK. Sau Space và `dd`, host lần lượt trả caret 1 → 4 → 1 với marked range `{1,1}`. viTek coi frame cuối là di chuyển con trỏ, bỏ composition, nên chữ tiếp theo thay mất `đ`. Test native dựng đúng chuỗi này tái hiện **cùng kết quả “hợp òng lao”**, không dùng bộ phát phím ([test đỏ](../reports/qa-prediction-2026-11-13/caret-red.log)). Đây là lỗi xử lý trạng thái host trong viTek; không quy cho công cụ gửi phím.

Bản sửa chỉ nhận frame tương đối khi native anchor chưa xác nhận, còn native write đang chờ trong 500 ms, độ dài mark/caret phù hợp, và có text readback chính xác hoặc cả hai thành phần đã được quan sát. Giữ tọa độ đó làm **anchor tạm cho native composition**, không dùng để ghi vào vùng tuyệt đối. Việc chuyển sang committed replacement vẫn đòi text/range/caret xác minh như trước. Các test mất focus, di chuyển caret và chống kết quả muộn tiếp tục đạt.

Vòng sửa đầu đạt 50 lượt UI/200 lần nhận gợi ý ở hash `6fb9e5fa…`. Kiểm thêm dừng gõ 550 ms phát hiện chỉ giữ frame đến deadline là chưa đủ ([test đỏ khi dừng](../reports/qa-prediction-2026-11-13/caret-pause-red.log)); bản cuối lưu tọa độ native tạm đã quan sát để tiếp tục qua khoảng dừng. Không tăng timeout và không tự phát lại phím. Kết quả UI của bản cuối được ghi riêng bên dưới.

Có một lỗi kỳ vọng của runner: Backspace từ `JSON.parse` phải thành `JSON.pars`, không phải `JSON.par`. Đã sửa kỳ vọng; lượt này không được tính là lỗi sản phẩm ([log](../reports/qa-prediction-2026-11-13/vscode-harness-expectation.log)).

## Bản cài

macOS Release host + installer build thành công với compiler warnings là lỗi. Payload `/tmp/vitek-prediction-release-complete/viTek.app` cài bằng luồng cập nhật/handshake hiện có; chữ ký ad-hoc local với designated identifier ổn định. Executable SHA-256:

```text
aaa0e03cf54ff00bcea6c4951f7bec8e6b5da3f272eed7554ef595a81f3ca058
```

iOS app, keyboard extension và widget build thành công với XcodeBuildMCP; chỉ kiểm compile ở lượt này, không tính lại 3 XCTest UI của đợt AI trước. Bàn phím iOS chưa nối thanh gợi ý từ mới.

Không push/PR GitHub.

## UI trên bản cuối

Bộ phát phím dùng HID keycode, không paste/Unicode injection. Mỗi lượt xác nhận `vieetj vie65t ` → `việt việt `; đọc đúng PID/cửa sổ fixture và dừng nếu mất foreground. Không chạy vào cửa sổ cá nhân. Diagnostics tắt khi kiểm bản cuối, gợi ý bật.

| Lượt | Ca | Assertion | Nhận gợi ý | Retry shortcut |
|---|---:|---:|---:|---:|
| [vscode-prediction](../reports/qa-prediction-2026-11-13/vscode-prediction.log) | 20 | 262 | 80 | 0 |
| [vscode-pause](../reports/qa-prediction-2026-11-13/vscode-pause.log) | 3 | 14 | 3 | 0 |
| [vscode-matrix](../reports/qa-prediction-2026-11-13/vscode-matrix.log) | 24 | 236 | 12 | 0 |
| [chrome-prediction](../reports/qa-prediction-2026-11-13/chrome-prediction.log) | 20 | 343 | 80 | 0 |
| [chrome-pause](../reports/qa-prediction-2026-11-13/chrome-pause.log) | 3 | 18 | 3 | 0 |
| [chrome-matrix](../reports/qa-prediction-2026-11-13/chrome-matrix.log) | 24 | 324 | 12 | 0 |
| **Tổng** | **94** | **1197** | **190** | **0** |

Nhóm prediction kiểm `ngư` → `người`, `bảo vệ môi` → `trường`, `hợp đồng lao` → `động`, `JSON.pa` → `JSON.parse` rồi Backspace → `JSON.pars`, xác nhận không có Space thừa. Nhóm pause dừng 700 ms giữa `ddo` và phần còn lại. Matrix gồm burst 10 từ, Telex rút gọn, tiếng Anh/lặp/Backspace, thay vùng chọn, đổi ô, Cmd+F, chuỗi nhận gợi ý, chữ HOA và chỉnh caret. Khoảng nghỉ yêu cầu giữa phím luân phiên 0/1/5 ms; không phải phép đo tốc độ gõ vật lý vì còn chi phí đọc AX và vận chuyển sự kiện.

Một lượt của bản cuối bị ứng dụng khác giành foreground ở vòng 4; runner dừng đúng, không tính vào tổng ([log](../reports/qa-prediction-2026-11-13/final-vscode-interrupted.log)). Không cộng các lượt đạt của bản trung gian vào kết quả bản cuối. Số liệu xác nhận các fixture/môi trường trên, không chứng minh mọi host và mọi timing đều hết lỗi.

[Metrics máy đọc được](../reports/qa-prediction-2026-11-13/ui-metrics.json) · [Xác minh bản cài](../reports/qa-prediction-2026-11-13/validation.txt).
