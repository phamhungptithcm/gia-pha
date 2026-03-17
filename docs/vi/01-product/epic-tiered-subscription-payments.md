# Epic gói dịch vụ và thanh toán

_Cập nhật gần nhất: 17/03/2026_

Issue theo dõi: [#213](https://github.com/phamhungptithcm/gia-pha/issues/213)

## Mục tiêu

Xây hệ thống gói năm theo quy mô thành viên, với hành vi quyền lợi rõ ràng và
xác nhận thanh toán an toàn phía máy chủ.

## Bảng giá (năm, đã gồm VAT)

- `<= 10` thành viên: Free
- `11 - 200`: Base, 49.000 VND/năm
- `201 - 700`: Plus, 89.000 VND/năm
- `701+`: Pro, 119.000 VND/năm

## Phạm vi

- engine tính gói theo số thành viên
- trạng thái thuê bao và vòng đời gói
- luồng checkout ưu tiên VNPay cho người dùng mobile
- xác thực callback/webhook và xử lý idempotent
- nhắc gia hạn, lịch sử thanh toán, audit log

## Hành vi sản phẩm hiện tại

- backend tạo order checkout trước
- app mở URL checkout do backend trả về
- gói mới chỉ hiệu lực sau khi xác nhận thanh toán thành công
- thanh toán chờ hoặc thất bại/hủy không cấp quyền gói mới
- trạng thái kết quả thể hiện rõ cho người dùng

## Story map

- BILL-001 engine giá theo số thành viên
- BILL-002 mô hình vòng đời thuê bao
- BILL-003 giao diện workspace thanh toán
- BILL-004 tích hợp checkout VNPay
- BILL-005 xác thực callback/webhook
- BILL-006 cài đặt gia hạn
- BILL-007 scheduler nhắc gia hạn
- BILL-008 ràng buộc quyền lợi theo gói
- BILL-009 lịch sử thanh toán và hóa đơn
- BILL-010 audit log thanh toán
- BILL-011 bộ test billing
