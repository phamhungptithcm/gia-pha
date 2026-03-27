# Cloud Functions

_Cập nhật gần nhất: 26/03/2026_

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
- `sendEventReminder` (scheduler theo cửa sổ nhắc việc):
  - truy vấn nhắc việc đến hạn bằng trường chỉ mục `nextReminderAt`
  - tự backfill các event cũ chưa có metadata cursor
  - cập nhật cursor sau mỗi lượt xử lý để giảm quét recurring toàn bộ

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

## Hành vi auth runtime

- không dùng debug signer trong callable production
- không còn hard-code theo project trong source

## Danh mục callable cần quyền quản trị

Danh sách dưới đây tổng hợp các callable có kiểm tra quyền nâng cao trong code
(`ensureAnyRole`, `ensureClanAccess`, claimed session).

| Callable | Module | Quyền tối thiểu | Ghi chú |
| --- | --- | --- | --- |
| `assignGovernanceRole` | `governance/callables.ts` | `SUPER_ADMIN` hoặc `CLAN_ADMIN` | Gán quyền quản trị theo clan, có audit log và tín hiệu refresh claims |
| `getTreasurerDashboard` | `governance/callables.ts` | `SUPER_ADMIN`, `CLAN_ADMIN`, `BRANCH_ADMIN`, `TREASURER` | Dashboard tài chính và lịch sử đóng góp |
| `recordFundTransaction` | `funds/callables.ts` | `SUPER_ADMIN`, `CLAN_ADMIN`, `TREASURER` | Ghi giao dịch thu/chi quỹ có kiểm tra số dư |
| `reviewScholarshipSubmission` | `scholarship/callables.ts` | `SCHOLARSHIP_COUNCIL_HEAD` đang active | Quy trình bỏ phiếu 2/3 cho khuyến học |
| `disburseScholarshipSubmissionFromFund` | `scholarship/callables.ts` | `SUPER_ADMIN`, `CLAN_ADMIN`, `TREASURER` | Chi trả hồ sơ đã duyệt từ quỹ |
| `reviewJoinRequest` | `genealogy/discovery-callables.ts` | Nhóm reviewer governance (`SUPER_ADMIN`, `CLAN_ADMIN`, `CLAN_LEADER`, `BRANCH_ADMIN`, `ADMIN_SUPPORT`, `VICE_LEADER`, `SUPPORTER_OF_LEADER`) | Duyệt yêu cầu gia nhập gia phả |
| `listJoinRequestsForReview` | `genealogy/discovery-callables.ts` | Cùng nhóm reviewer như `reviewJoinRequest` | API hàng đợi yêu cầu cần duyệt |
| `detectDuplicateGenealogy` | `genealogy/discovery-callables.ts` | `SUPER_ADMIN`, `CLAN_ADMIN`, `ADMIN_SUPPORT` | Kiểm tra trùng gia phả lúc setup |
| `createParentChildRelationship` | `genealogy/callables.ts` | `SUPER_ADMIN`, `CLAN_ADMIN`, hoặc `BRANCH_ADMIN` cùng chi | Sửa quan hệ nhạy cảm có kiểm tra cycle |
| `createSpouseRelationship` | `genealogy/callables.ts` | `SUPER_ADMIN`, `CLAN_ADMIN`, hoặc `BRANCH_ADMIN` cùng chi | Sửa quan hệ vợ/chồng nhạy cảm |
| `loadBillingWorkspace` | `billing/callables.ts` | Nhóm billing admin (`SUPER_ADMIN`, `CLAN_ADMIN`, `BRANCH_ADMIN`, `CLAN_OWNER`, `CLAN_LEADER`, `VICE_LEADER`, `SUPPORTER_OF_LEADER`) | Workspace quản lý gói theo scope |
| `updateBillingPreferences` | `billing/callables.ts` | Cùng nhóm billing admin | Cập nhật cài đặt billing |
| `verifyInAppPurchase` | `billing/callables.ts` | Cùng nhóm billing admin | Xác thực IAP và cập nhật entitlement |

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
