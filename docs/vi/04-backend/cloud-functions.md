# Cloud Functions

_Cập nhật gần nhất: 17/03/2026_

Functions được triển khai tại `firebase/functions` bằng Firebase Functions v2 và
TypeScript.

## Cấu hình runtime

- Node.js: 20
- region: từ env `APP_REGION` (mặc định `asia-southeast1`)
- timezone scheduler: từ env `APP_TIMEZONE` (mặc định `Asia/Ho_Chi_Minh`)
- global options: `maxInstances = 10`
- getter env tập trung nằm ở `src/config/runtime.ts`
- deploy pipeline ghi env từ GitHub `production` vars/secrets
- runtime override billing không chứa secret lấy từ `runtimeConfig/global`
  qua `src/config/runtime-overrides.ts` (cache bộ nhớ 60 giây)

Thứ tự ưu tiên runtime config billing:

1. Firestore runtime override hợp lệ (`runtimeConfig/global`)
2. giá trị environment từ deploy/runtime
3. fallback mặc định trong code

## Danh sách function export

### Auth callables

- `resolveChildLoginContext`
- `claimMemberRecord`
- `registerDeviceToken`
- `createInvite` (đang scaffold, trả `unimplemented`)

### Genealogy callables và triggers

- `createParentChildRelationship`
- `createSpouseRelationship`
- `onRelationshipCreated`
- `onRelationshipDeleted`

### Events và notifications

- `onEventCreated`
- `sendEventReminder` (scheduler scaffold)

### Scholarship và funds

- `onSubmissionReviewed`
- `onTransactionCreated`

### Scheduled jobs

- `expireInvitesJob`

### Billing callables, webhooks, jobs

- `resolveBillingEntitlement`
- `loadBillingWorkspace`
- `updateBillingPreferences`
- `createSubscriptionCheckout`
- `completeCardCheckout` (nhánh tương thích)
- `simulateVnpaySettlement` (dev/testing)
- `cardPaymentCallback`
- `vnpayPaymentCallback`
- `billingSubscriptionReminderJob`
- `billingPendingTimeoutJob`

## Ghi chú cho billing

- signature secret được đọc qua runtime getter, không hard-code
- webhook idempotency theo `paymentWebhookEvents`
- timeout và limit cho pending checkout đọc từ env/runtime override
- flow người dùng mobile đi theo VNPay-first

## Hành vi signer cho auth

- debug token signer service account đọc từ
  `DEBUG_TOKEN_SIGNER_SERVICE_ACCOUNT`
- không còn hard-code theo project trong source

## Module hỗ trợ

- `notifications/push-delivery.ts`: fan-out tài liệu thông báo + gửi FCM
- module dùng chung:
  - `shared/logger.ts`
  - `shared/errors.ts`
  - `shared/firestore.ts`

## Lệnh build local

```bash
cd firebase/functions
npm ci
npm run build
```

Seed dữ liệu demo:

```bash
cd firebase/functions
npm run seed:demo
```
