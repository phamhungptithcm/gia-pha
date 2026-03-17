# Firebase Rules

_Cập nhật gần nhất: 17/03/2026_

## Điểm chính của Firestore rules

Rules nằm ở `firebase/firestore.rules` và đang đảm bảo:

- chỉ cho truy cập khi đã xác thực
- đọc theo phạm vi clan bằng claims hoặc fallback `users/{uid}`
- ghi theo vai trò cho `clans`, `branches`, `members`, `relationships`
- bảo vệ cập nhật hồ sơ cá nhân qua kiểm tra diff trường cho phép
- collection nhạy cảm chỉ cho server ghi (`transactions`, `auditLogs`, ...)

Mô hình rule cho billing:

- `subscriptions`, `paymentTransactions`, `subscriptionInvoices`,
  `paymentWebhookEvents` chỉ server được ghi
- dữ liệu billing chỉ owner/admin cùng `clanId` mới được đọc
- webhook-event không cho client thường đọc
- `billingAuditLogs` chỉ cho vai trò billing admin đọc, server-only write

### Helper chính

- `hasClanAccess(clanId)`
- `primaryRole()`
- `branchIdClaim()`
- `isClanSettingsAdmin()`
- `isBranchScopedMemberManager(...)`
- `safeProfileUpdate()`

## Điểm chính của Storage rules

Rules nằm ở `firebase/storage.rules` và đảm bảo:

- đọc theo phạm vi clan
- đường dẫn avatar:
  - `clans/{clanId}/members/{memberId}/avatar/{fileName}`
  - chỉ clan admin hoặc chủ hồ sơ mới được ghi
  - chỉ nhận file ảnh, giới hạn 10 MB
- đường dẫn tệp submission:
  - `submissions/{clanId}/{memberId}/{fileName}`
  - thành viên sở hữu được ghi, giới hạn 20 MB

## Hướng dẫn vận hành

- version hóa rules/indexes cùng thay đổi tính năng
- deploy rules/indexes qua CI từ nhánh bảo vệ
- khi thêm role field mới, cập nhật cả claims và `users/{uid}` fallback
- giữ tài liệu rules đồng bộ qua script validate trong CI
- thêm billing collections vào ma trận test rules/emulator trước rollout
