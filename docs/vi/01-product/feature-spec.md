# Đặc tả tính năng

_Cập nhật gần nhất: 17/03/2026_

## Ma trận trạng thái tính năng

| Nhóm tính năng | Trạng thái | Hành vi hiện tại |
| --- | --- | --- |
| Xác thực OTP số điện thoại | Đã chạy | Đăng nhập Firebase + khôi phục phiên |
| Truy cập trẻ em | Đã chạy | Mã trẻ em + xác minh số phụ huynh |
| Liên kết phiên thành viên | Đã chạy | Đồng bộ claim phiên vào Firestore |
| Không gian clan/branch | Đã chạy | Tạo/sửa có kiểm soát quyền |
| Quản lý thành viên | Đã chạy | CRUD, tìm kiếm, lọc, avatar |
| Quan hệ gia đình | Đã chạy | Thiết lập cha mẹ-con cái và vợ chồng có ràng buộc |
| Xem cây gia phả | Đã chạy | Hiển thị cây và chi tiết thành viên theo ngữ cảnh |
| Sự kiện âm/dương lịch | Đã chạy | Tạo/sửa/xóa, lặp lại, nhắc lịch |
| Quỹ dòng họ | Đã chạy | Danh sách/quỹ chi tiết/tạo quỹ/giao dịch/số dư chạy |
| Khuyến học | Đã chạy | Chương trình, bậc thưởng, nộp và duyệt |
| Khám phá gia phả | Đã chạy | Tìm kiếm công khai + gửi yêu cầu tham gia |
| Hồ sơ và cài đặt | Đã chạy nền tảng | Màn hình hồ sơ, sửa hồ sơ, placeholder tùy chọn |
| Hộp thư thông báo | Đã chạy nền tảng | Danh sách thông báo, trạng thái đã đọc |
| Gói dịch vụ | Đã chạy | Tính gói theo số thành viên |
| Luồng thanh toán | Đã chạy | 3 bước: Chọn gói -> Xác nhận -> Thanh toán VNPay |
| Trạng thái thanh toán | Đã chạy | Thành công / Chờ đối soát / Thất bại-hủy |
| Kích hoạt quyền gói | Đã chạy | Chỉ kích hoạt sau khi xác nhận thanh toán thành công |

## Quy tắc thanh toán hiện tại

### Hành vi người dùng
- Gói hiện tại còn hạn: được nâng cấp lên gói cao hơn.
- Gia hạn cùng gói: chỉ mở khi gần đến hạn.
- Hạ gói: bị chặn nếu số thành viên vượt giới hạn gói mục tiêu.

### Cam kết hệ thống
- Phiên checkout được tạo phía backend trước khi mở VNPay.
- Thanh toán đang chờ hoặc thất bại không kích hoạt gói mới.
- Thẻ gói đang dùng chỉ phản ánh gói thực sự đang hiệu lực.

### Kênh thanh toán
- Luồng người dùng trên mobile ưu tiên VNPay.
- Nhánh callback thẻ vẫn giữ cho tương thích backend.
