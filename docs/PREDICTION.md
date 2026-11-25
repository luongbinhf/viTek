# Từ điển và gợi ý cục bộ

## Thành phần

- `VocabularyEntry`: từ hoặc cụm 1–8 token, lĩnh vực và ưu tiên biên tập 0–1.000. Không có tần suất giả định. Từ chối dòng mới, từ rỗng, ký tự ẩn/control, token quá dài và entry quá 1.024 byte UTF-8.
- `PredictionLexicon`: bất biến, `Sendable`, dựng một lần; chỉ mục tiền tố 1–3 ký tự và cạnh tiếp nối cụm. Chuỗi được bỏ dấu chỉ để tra nhóm; kết quả phải thỏa từng dấu/chữ đã gõ. Cho phép truyền bộ `entries` riêng mà không đổi thuật toán.
- `WordPrediction`: kiểm ranh giới, chọn văn bản/code, xếp hạng và bỏ trùng, trả tối đa 32 ứng viên (host dùng 5). Kết quả có `source`, `score`, `appendsSpace` và `insertion`.
- `CodeCompletion`: hoàn tất từ vựng có giới hạn, phân biệt chữ hoa và thường, nhận diện identifier ASCII gồm `_`, `$`, chữ số sau ký tự đầu. Không học hoặc lưu lịch sử.
- `WordCompletions` trên macOS: actor tra lõi cục bộ; chỉ gọi NSSpellChecker khi đang viết văn bản, tiền tố dài ít nhất hai ký tự, có dưới năm ứng viên cục bộ và chưa có cụm khớp.

## Xếp hạng

Khi có nhiều cụm khớp, thanh gợi ý chỉ hiện các tiếp nối của cụm khớp dài nhất. Trong nhóm đó, thứ tự phụ thuộc vào ưu tiên biên tập. Ví dụ, sau `cơ sở dữ li` chỉ hiện `liệu`. Từ độc lập có thể được tăng 500 điểm nếu trùng lĩnh vực được gọi rõ hoặc suy ra từ cụm khớp. Từ thông dụng có ưu tiên riêng để các âm tiết nằm trong thuật ngữ không lấn át mọi ngữ cảnh. Điểm không biểu diễn xác suất.

Một chữ chưa có ngữ cảnh không kích hoạt từ điển cục bộ vì quá mơ hồ. Sau Space, chỉ gợi ý tiếp nối cụm đã biết; không đưa ra danh sách từ ngẫu nhiên. Dấu câu và xuống dòng ngăn nối cụm. Nếu chỉ khớp một từ ngay trước Space, từ đã gõ phải khớp cả dấu. Trong câu có nhiều từ, một từ đơn lẻ chỉ kích hoạt cụm thông dụng hoặc cụm thuộc lĩnh vực đã chỉ định. Điều này giảm gợi ý `máy` sau `Con đang học ` và cũng có thể bỏ qua một tiếp nối chuyên ngành hợp lệ. Ngữ cảnh nhiều từ bỏ dấu có thể khớp (`co so du ` → `liệu`); dấu đã gõ phải khớp (`dá` không khớp `dữ`). Xóa/gõ lại cho cùng đầu vào phải trả cùng kết quả.

Mỗi lần gọi chỉ dùng tối đa 512 Character ngữ cảnh. Host IMK đọc tối đa 512 đơn vị UTF-16; chúng không tương đương với văn bản chứa emoji. Trước khi gọi dịch vụ nền tảng, hậu tố phải khớp **đúng UTF-16**, không chỉ tương đương Unicode. Callback đến muộn vẫn phải qua `SuggestionRequest` trước khi hiện/nhận.

## Code và ngữ cảnh hỗn hợp

Chế độ tự động nhận một số tín hiệu cú pháp (`let`, `const`, `func`, phép gán, receiver đã biết). Không mặc định mọi ô trong VS Code là code: Find và văn bản thường vẫn dùng đường văn bản. Có thể gọi `.code`/`.prose` rõ trong API.

Ví dụ:

| Đầu vào | Ứng viên | Cách chèn |
|---|---|---|
| `ngư` | `người` | `người ` |
| `bảo vệ môi ` | `trường` | `trường ` |
| `JSON.pa` | `parse` | `parse`, giữ `JSON.` |
| `const userName = value; return us` | `userName` | giữ nguyên hoa/thường, không Space |
| `unknown.pa` | không gợi ý member | không đoán kiểu receiver |
| `user_ng` với composition chỉ là `ng` | không gợi ý | không thay phần đuôi identifier |

Định danh lấy từ ngữ cảnh của **chính yêu cầu**, không từ ô trước hoặc lịch sử. String/comment bị bỏ khi thu định danh. Ở chế độ tự động, phần đang nằm trong comment/string có thể nhận gợi ý văn bản. Bộ quét chỉ là lexer nhỏ trong cửa sổ giới hạn; không xử lý đầy đủ mọi cú pháp, raw string, interpolation hay comment bắt đầu ngoài cửa sổ. Thành phần này không phải parser, LSP hoặc AI viết code.

## Phạm vi còn thiếu

Dữ liệu khởi đầu gồm từ/cụm và token, chưa có định nghĩa từ, từ loại, phân tích cú pháp, phân đoạn từ tiếng Việt đầy đủ, corpus tần suất hoặc mô hình ngôn ngữ học đã huấn luyện. Chất lượng được kiểm trên fixture tự soạn; chưa có số đo chất lượng ngoài mẫu trên corpus độc lập. Cần dữ liệu có giấy phép phù hợp và đánh giá riêng trước khi tuyên bố độ phủ lớn.

Lõi thuần Swift dùng chung macOS/iOS/Linux. Thanh gợi ý mới nối vào host macOS; bàn phím iOS hiện chưa có thanh nhận ứng viên này. Các phím Telex vẫn đi qua engine hiện tại, nên identifier có phím dấu mơ hồ có thể cần chuyển nguồn nhập hoặc nhận ứng viên trước phím đó. Tích hợp ngữ nghĩa code cần editor extension/LSP thay vì đoán từ tên ứng dụng. Apple Intelligence vẫn dùng cho yêu cầu viết rõ ràng; đường hoàn tất từng phím không gọi mô hình sinh.

Kiểm: `swift test`; đo: `swift run -c release vitek-prediction-bench`. [Báo cáo lần nâng cấp](QA-PREDICTION-2026-11-13.md).
