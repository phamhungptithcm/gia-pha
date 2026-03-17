# Lộ trình phát triển

_Cập nhật gần nhất: 17/03/2026_

## Mô hình phát hành

- `staging`: nhánh tích hợp tính năng
- `main`: nhánh phát hành production
- hằng tuần tạo PR promote từ `staging` sang `main`

## Các mốc chính

### M1 - Nền tảng và pipeline phát hành (Hoàn thành)
- khởi tạo Flutter + Firebase
- pipeline tài liệu và kiểm tra chất lượng
- CI nhánh và tự động hóa release

### M2 - Nhận diện và lõi dòng họ (Hoàn thành)
- OTP số điện thoại + truy cập trẻ em
- claim hồ sơ thành viên và liên kết phiên
- clan/member/relationship/genealogy nền tảng

### M3 - Sự kiện và tương tác (Hoàn thành)
- lịch âm dương trong cùng workspace
- tạo/sửa/xóa sự kiện và nhắc lịch
- hộp thư thông báo nền tảng

### M4 - Quỹ và khuyến học (Hoàn thành nền tảng)
- quản lý quỹ, giao dịch, số dư
- luồng chương trình khuyến học và xét duyệt

### M5 - Gói dịch vụ và thanh toán (Hoàn thành nền tảng)
- gói bậc thang theo quy mô thành viên
- luồng thanh toán VNPay-first
- xử lý trạng thái thanh toán và nhắc gia hạn

### M6 - Hồ sơ và cài đặt (Hoàn thành nền tảng)
- màn hình hồ sơ, chỉnh sửa thông tin
- shell cài đặt và hành vi đăng xuất

### M7 - Nâng chất UX và độ ổn định phát hành (Đang chạy)
- tối ưu câu chữ sản phẩm
- giảm mơ hồ ở các luồng nhạy cảm (onboarding, payment)
- cải thiện khả năng tiếp cận và hiển thị chữ lớn

### M8 - Vận hành quy mô lớn (Kế hoạch)
- tăng chiều sâu phân tích và quan sát hệ thống
- mở rộng điều hướng đích của thông báo
- tối ưu hiệu năng cho dòng họ quy mô lớn
