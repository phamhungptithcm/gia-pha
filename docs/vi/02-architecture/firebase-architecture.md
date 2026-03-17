# Kiến trúc Firebase

_Cập nhật gần nhất: 17/03/2026_

## Project và vùng triển khai

- project id: `be-fam-3ab23`
- vùng Firestore mặc định: `asia-southeast1`
- vùng Cloud Functions: `asia-southeast1`
- múi giờ scheduler: `Asia/Ho_Chi_Minh`

## Dịch vụ Firebase đang sử dụng

- Firebase Auth (đăng nhập OTP số điện thoại)
- Cloud Firestore (kho dữ liệu nghiệp vụ chính)
- Firebase Storage (avatar và tệp đính kèm)
- Cloud Functions for Firebase v2 (callable, trigger, scheduler)
- Firebase Cloud Messaging (đăng ký token và gửi push)
- Firebase Analytics và Crashlytics trên mobile

Billing runtime đang hoạt động với:

- cổng thanh toán do Cloud Functions điều phối
- trạng thái thuê bao/hóa đơn lưu trong Firestore
- runtime override không chứa secret ở `runtimeConfig/global`

## Mô hình truy cập

- ngữ cảnh định danh được truyền qua custom claims (`clanIds`, `memberId`,
  `branchId`, `primaryRole`, `memberAccessMode`)
- tài liệu phiên mobile được mirror vào `users/{uid}`
- Firestore/Storage rules kiểm tra phạm vi clan và quyền ghi theo vai trò

## Bản đồ module backend hiện tại

```text
firebase/functions/src/
  auth/callables.ts
  billing/callables.ts
  billing/webhooks.ts
  billing/subscription-reminders.ts
  billing/store.ts
  config/runtime.ts
  config/runtime-overrides.ts
  genealogy/callables.ts
  genealogy/relationship-triggers.ts
  events/event-triggers.ts
  scholarship/submission-triggers.ts
  funds/transaction-triggers.ts
  notifications/push-delivery.ts
  scheduled/jobs.ts
```

## Kiến trúc phát hành

- `deploy-firebase.yml` build và deploy rules/indexes/storage/functions từ `main`
- workflow này cũng tạo `firebase/functions/.env.<projectId>` và sync runtime
  billing override không chứa secret lên `runtimeConfig/global`
- `release-main.yml` xử lý tag release, release notes, artifact mobile và publish
  image lên GHCR
- `branch-ci.yml` đảm bảo sức khỏe docs/functions/mobile trên nhánh bảo vệ
