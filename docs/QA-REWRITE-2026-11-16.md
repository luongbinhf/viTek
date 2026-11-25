# QA xoá và gõ lại, gợi ý theo câu, gạch chân

Bản Release cục bộ 2026.0.003, SHA-256 của executable sau cài `37d264f8f844e24b8e1d6cb93a9e10f2335852633c92e230fb4a476133ab6769`. Kiểm trên macOS 27.2, Chrome 157.0.8103.52 và VS Code 1.146.0. Chữ ký cục bộ qua kiểm tra strict. Bộ chạy gửi mã phím qua HID vào cửa sổ QA, đọc kết quả bằng Accessibility, kiểm nguồn nhập bằng Telex và VNI trước mỗi lượt.

| Ca kiểm | Chrome | VS Code |
|---|---:|---:|
| Xoá cả từ đang soạn, gõ ngay `Gawpj`, sửa ký tự cuối, xoá vùng chọn rồi gõ `vieetj` | 5/5 | 5/5 |
| Nhận `người`, `môi trường`, `lao động` và `JSON.parse` | 20/20 lần nhận | 20/20 lần nhận |
| Kiểm hai gợi ý lạc câu và nhận `liệu` sau `cơ sở dữ li` | 3/3 vòng | 3/3 vòng |
| Di chuyển con trỏ rồi xoá ở giữa `viêt`, còn `vêt` | 3/3 | 3/3 |

Mỗi ca phím nhanh chạy với khoảng nghỉ bổ sung 0, 1 hoặc 5 ms. Hai phép kiểm âm quan sát thanh ứng viên trong một giây sau Space. Bộ hồi quy Swift đạt 139 test session, 59 test engine và 2 test repository. [Nhật ký chạy trực tiếp](../reports/qa-rewrite-2026-11-16/system-qa.log).

## Mất chữ sau khi xoá

Trước bản sửa, ca mất quyền đọc văn bản cho kết quả `trước Gawpj sau`. Một lỗi khác xuất hiện khi xoá vùng chọn rồi gõ ngay. Chrome đã nhận từng phím và đang hiện `viê` thì viTek xử lý vị trí con trỏ cũ, làm từ mới thành `tj`. Ca hồi quy tái tạo thứ tự phản hồi này trong NSTextView. Backspace hiện cho phép bắt đầu lại Telex ngay tại ô đang gõ. Khi vùng đang soạn vẫn khớp và con trỏ đến muộn trùng đầu vùng chọn cũ, viTek tiếp tục cập nhật vùng do ứng dụng quản lý.

## Gợi ý và gạch chân

Trong hai câu `Con đang học ` và `Tôi vừa mua bao `, các ứng viên sai lần lượt là `máy` và `mật`. Cả hai đã biến mất trong lượt kiểm. Với `cơ sở dữ li`, trước sửa có cả `Linux` và `limit`. Test lõi hiện chỉ nhận `liệu`. Đây là các ví dụ hồi quy tự soạn. Chưa có phép đo chất lượng trên tập văn bản độc lập.

Đo vạch gạch chân trong ô Chrome cục bộ bằng cùng phông Arial 40 px, tắt spellcheck và ẩn con trỏ trên riêng ô kiểm. Với `Gặp` ở đầu ô, số pixel xanh giảm từ 592 xuống 296 trong lúc soạn, về 0 sau khi chốt bằng mũi tên phải. Ở bản vừa cài, `nam Gặp` có 298 pixel xanh lúc soạn, về 0 sau khi chốt. Chrome vẫn vẽ vạch ở cả hai vị trí. Phép đo hình ảnh chỉ thực hiện trên Chrome. [Ảnh lúc soạn](../reports/qa-rewrite-2026-11-16/chrome-composing.png) · [Ảnh sau khi chốt](../reports/qa-rewrite-2026-11-16/chrome-committed.png).
