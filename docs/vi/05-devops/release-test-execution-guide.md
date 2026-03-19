# Hướng dẫn dùng Test Execution Sheet (Google Sheets)

_Cập nhật gần nhất: 19/03/2026_

## 1) File dùng để import

- CSV template: [release-test-execution-template.csv](release-test-execution-template.csv)
- Excel template: [release-test-execution-template.xlsx](release-test-execution-template.xlsx)
- Dashboard formula CSV: [release-test-dashboard-template.csv](release-test-dashboard-template.csv)

Template đã prefill toàn bộ test cases từ test plan, gồm 106 dòng.

Nếu muốn dùng ngay không cần setup, ưu tiên file `.xlsx` vì đã có sẵn:

- freeze header
- auto filter
- dropdown cho cột `status`
- conditional formatting theo trạng thái
- sheet `Dashboard` có công thức tổng hợp

## 2) Import vào Google Sheets (5 phút)

1. Mở Google Sheets -> tạo file mới.
2. `File -> Import -> Upload`.
3. Chọn file `release-test-execution-template.csv`.
4. Chọn import mode: `Replace spreadsheet` (khuyên dùng cho run đầu).
5. Freeze hàng tiêu đề: `View -> Freeze -> 1 row`.

## 3) Cách dùng cột chính

- `run_id`: mã đợt test, ví dụ `RC-20260319-01`
- `status`: chỉ dùng 5 giá trị
  - `NOT_RUN`
  - `PASS`
  - `FAIL`
  - `BLOCKED`
  - `N/A`
- `actual_result`: mô tả ngắn kết quả thực tế
- `defect_id`: mã bug ticket (ví dụ `BUG-241`)
- `defect_link`: link issue/PR fix
- `evidence_link`: link ảnh/video/log

## 4) Thiết lập Data Validation cho cột Status

1. Chọn toàn bộ cột `status`.
2. `Data -> Data validation -> Dropdown`.
3. Thêm options: `NOT_RUN`, `PASS`, `FAIL`, `BLOCKED`, `N/A`.
4. Bật reject input khác danh sách.

## 5) Conditional Formatting khuyến nghị

- `PASS`: nền xanh nhạt
- `FAIL`: nền đỏ nhạt
- `BLOCKED`: nền cam nhạt
- `NOT_RUN`: nền xám nhạt
- `N/A`: nền xanh dương nhạt

## 6) Formula nhanh để tạo mini dashboard

Giả sử sheet tên `Execution`.

- Tổng case:
  - `=COUNTA(Execution!C:C)-1`
- PASS:
  - `=COUNTIF(Execution!H:H,"PASS")`
- FAIL:
  - `=COUNTIF(Execution!H:H,"FAIL")`
- BLOCKED:
  - `=COUNTIF(Execution!H:H,"BLOCKED")`
- NOT_RUN:
  - `=COUNTIF(Execution!H:H,"NOT_RUN")`
- Tỷ lệ pass:
  - `=IFERROR(COUNTIF(Execution!H:H,"PASS")/(COUNTA(Execution!C:C)-1),0)`

## 7) Quy ước vận hành để tránh rối

- Mỗi lần test regression lớn: copy sheet cũ -> đổi `run_id` mới.
- Không sửa `test_case_id`.
- Nếu thêm test mới, thêm dòng mới với ID theo module (ví dụ `AUTH-011`).
- Chỉ đóng release khi toàn bộ `P0` ở trạng thái `PASS`.
