# Thông báo

_Cập nhật gần nhất: 17/03/2026_

Thông báo BeFam được phân phối qua Firestore + FCM, với mobile service hỗ trợ
cả trạng thái foreground và mở app từ notification.

## Luồng end-to-end

1. App đã đăng nhập khởi động push service trong `AppShellPage`.
2. Token thiết bị được đăng ký qua callable `registerDeviceToken`.
3. Có fallback ghi token trực tiếp vào `users/{uid}/deviceTokens`.
4. Trigger backend gọi `notifyMembers(...)`.
5. `notifyMembers` ghi document `notifications` và gửi FCM multicast.
6. Token FCM không hợp lệ được dọn khỏi Firestore.

## Nhóm target hỗ trợ

Mapping target push hiện tại:

- `event`
- `scholarship`
- `billing` (đang mở rộng)
- `generic` (nội bộ)

Mobile deep-link parser map `target` về:

- `NotificationTargetType.event`
- `NotificationTargetType.scholarship`
- `NotificationTargetType.billing` (đang mở rộng)
- `NotificationTargetType.unknown`

## Nguồn trigger đã nối

- tạo sự kiện (`onEventCreated`)
- thay đổi trạng thái duyệt khuyến học (`onSubmissionReviewed`)

Nguồn trigger mở rộng theo kế hoạch:

- nhắc hết hạn thuê bao
- nhắc đến hạn gia hạn thủ công
- cập nhật kết quả thanh toán

## Mô hình đọc/cập nhật

- người dùng đọc thông báo theo phạm vi member/clan
- thành viên chỉ được đánh dấu đã đọc thông báo của chính mình
- tạo/xóa thông báo là hành vi phía server

## Trạng thái hộp thư mobile

- màn hình inbox đã có trong shell
- đọc notifications theo member với phân trang tăng dần
- có thao tác mark-read
- event/scholarship mở trang đích tương ứng
- cài đặt notification vẫn ở mức placeholder cho profile-level

## Bước tiếp theo

- thay placeholder bằng trang chi tiết event/scholarship đầy đủ
- lưu cài đặt notification xuống backend
