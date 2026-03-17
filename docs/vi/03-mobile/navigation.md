# Điều hướng

_Cập nhật gần nhất: 17/03/2026_

## Luồng vào ứng dụng

1. `main.dart` khởi tạo Firebase và trạng thái bootstrap.
2. `BeFamApp` mở `AuthExperience`.
3. Khi khôi phục phiên thành công hoặc xác minh OTP xong, app chuyển vào
   `AppShellPage`.

## Trạng thái điều hướng trong auth

- chọn phương thức đăng nhập
- nhập số điện thoại
- nhập mã trẻ em
- xác minh OTP với 6 ô nhập và auto-submit khi đủ số

## Điểm đến trong shell

Tab điều hướng hiện tại:

- Home
- Tree
- Events
- Profile

Tab Events chứa workspace lịch âm/dương. Hộp thư thông báo và trang đích thông
báo được mở từ deep-link hoặc profile/settings.

## Điều hướng theo thông báo

- push service lắng nghe FCM khi app foreground và khi mở từ notification
- payload `event`/`scholarship` chuyển tới tab phù hợp và mở trang đích
- payload được chuẩn hóa thành `NotificationDeepLink`

Mở rộng theo kế hoạch:

- deep-link từ nhắc gia hạn tới màn hình quản lý gói dịch vụ

## Mục tiêu UX cho điều hướng

- onboarding auth ít bước, ít rào cản
- cấu trúc rõ ràng, dễ đọc cho người lớn tuổi
- hành vi back nhất quán ở form và trang chi tiết
