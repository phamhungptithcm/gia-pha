# Thông báo

_Cập nhật gần nhất: 19/03/2026_

Thông báo BeFam được phân phối qua Firestore + FCM (kênh chính), và có thể mở
rộng thêm email thông qua Firebase Extension `firestore-send-email`.

## Luồng end-to-end

1. App đã đăng nhập khởi động push service trong `AppShellPage`.
2. Token thiết bị được đăng ký qua callable `registerDeviceToken`.
3. Có fallback ghi token trực tiếp vào `users/{uid}/deviceTokens`.
4. Trigger backend gọi `notifyMembers(...)`.
5. `notifyMembers` luôn ghi document `notifications` cho inbox trong app.
6. Push được gửi theo channel toggle + category toggle của user.
7. Email (nếu bật) được queue vào collection mail để extension xử lý.
8. Token FCM không hợp lệ được dọn khỏi Firestore.

## Chính sách kênh gửi

- Push: kênh chính (free).
- Email: kênh bổ sung (gần như free, qua SMTP/extension).
- SMS: chỉ dùng cho OTP đăng nhập. SMS non-OTP bị tắt mặc định.

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

## Mô hình cài đặt

- Lưu tại `users/{uid}/preferences/notifications`.
- Backend áp dụng:
  - channel toggle (`pushEnabled`, `emailEnabled`)
  - category toggle (`eventReminders`, `scholarshipUpdates`,
    `fundTransactions`, `systemNotices`)
- Việc tạo notification doc vẫn server-side để đảm bảo lịch sử trong app.

## Trạng thái hộp thư mobile

- inbox đã có trong shell
- đọc notifications theo member + pagination
- có thao tác mark-read
- event/scholarship deep-link mở đúng trang đích
