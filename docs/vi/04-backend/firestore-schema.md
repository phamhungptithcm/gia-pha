# Firestore Schema

_Cập nhật gần nhất: 17/03/2026_

Trang này tóm tắt mô hình Firestore đang dùng cho app mobile và Cloud Functions.

## Collection cốt lõi

- `clans`: hồ sơ dòng họ và metadata tổng hợp
- `branches`: cấu trúc chi và tham chiếu lãnh đạo chi
- `members`: hồ sơ thành viên, vai trò, mảng quan hệ phi chuẩn hóa
- `relationships`: cạnh quan hệ chuẩn
- `invites`: bản ghi mời theo phone và child-access
- `users`: ngữ cảnh phiên cho auth/rules fallback
- `notifications`: hộp thư thông báo theo thành viên
- `events`, `funds`, `transactions`, `scholarshipPrograms`, `awardLevels`,
  `achievementSubmissions`, `auditLogs`

Collection billing:

- `subscriptions`
- `subscriptionInvoices`
- `paymentTransactions`
- `paymentWebhookEvents`
- `billingSettings`
- `billingAuditLogs`

## Mẫu member + relationship

- nguồn chuẩn: cạnh trong `relationships`
- tối ưu đọc: `members.parentIds`, `members.childrenIds`, `members.spouseIds`
- callable quan hệ cập nhật mảng phi chuẩn hóa theo giao dịch

## Session và token thiết bị

- `users/{uid}` lưu ngữ cảnh truy cập:
  - `memberId`, `clanId`, `clanIds`, `branchId`, `primaryRole`, `accessMode`
- `users/{uid}/deviceTokens/{token}` lưu metadata route push

## Truy vấn và index

Index chính nằm tại `firebase/firestore.indexes.json`:

- members theo clan + name
- members theo clan + branch + name
- members theo clan + generation
- relationships theo clan + person + type
- events theo clan/branch + start time
- notifications theo member + created time/read state
- billing theo clan + trạng thái thuê bao/hạn dùng + thứ tự thời gian giao dịch

## Tham chiếu

- [Firestore Production Schema](../../FIRESTORE_PRODUCTION_SCHEMA.md)
