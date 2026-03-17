# Mô hình dữ liệu

_Cập nhật gần nhất: 17/03/2026_

## Thực thể cốt lõi

Các collection Firestore chính:

- `clans`
- `branches`
- `members`
- `relationships`
- `events`
- `funds`
- `transactions`
- `scholarshipPrograms`
- `awardLevels`
- `achievementSubmissions`
- `notifications`
- `invites`
- `auditLogs`
- `users` và collection con `users/{uid}/deviceTokens`

Các collection cho billing:

- `subscriptions`
- `subscriptionInvoices`
- `paymentTransactions`
- `paymentWebhookEvents`
- `billingSettings`
- `billingAuditLogs`

Các trường quan trọng của thuê bao gồm:
`planCode` (`FREE`, `BASE`, `PLUS`, `PRO`), `memberCount`, `amountVndYear`,
`expiresAt`, `paymentMode`, `autoRenew`, `nextPaymentDueAt` và cờ quyền lợi
quảng cáo (`showAds`, `adFree`).

## Mô hình quan hệ

- cạnh quan hệ chuẩn được lưu trong `relationships`
- các mảng phi chuẩn hóa trên `members` (`parentIds`, `childrenIds`,
  `spouseIds`) giúp đọc nhanh khi render cây và hồ sơ
- khi tạo quan hệ, phía server kiểm tra trùng quan hệ vợ/chồng và chặn vòng lặp
  cha mẹ - con cái

## Mô hình định danh và phiên

- `members.authUid` liên kết tài khoản Firebase Auth với hồ sơ thành viên
- `users/{uid}` lưu ngữ cảnh truy cập để fallback cho rules:
  - `memberId`
  - `clanId` và `clanIds`
  - `branchId`
  - `primaryRole`
  - `accessMode`
  - `linkedAuthUid`
- token FCM được lưu ở `users/{uid}/deviceTokens/{token}`

## Chiến lược truy vấn và index

Các index ưu tiên truy vấn theo phạm vi clan, tìm kiếm thành viên và dữ liệu theo
thời gian:

- members theo `clanId + normalizedFullName`
- relationships theo `clanId + personA/personB + type`
- events theo `clanId/branchId + startsAt`
- notifications theo `memberId + createdAt`

Bộ index cho billing:

- subscriptions theo `clanId + status + expiresAt`
- payment transactions theo `clanId + createdAt`
- invoices theo `clanId + periodStart/periodEnd`

## Tài liệu tham chiếu

- [Firestore Production Schema](../../FIRESTORE_PRODUCTION_SCHEMA.md)
- [Firestore Schema (Backend)](../04-backend/firestore-schema.md)
