# CI/CD

_Cập nhật gần nhất: 21/03/2026_

BeFam dùng mô hình phát hành có kiểm soát:

- `staging`: tích hợp và kiểm thử
- `main`: phát hành production

## Tóm tắt workflow

### `branch-ci.yml` (`CI - Branch Quality Gates`)
Chạy khi:
- có pull request vào `staging` hoặc `main`
- có push vào mọi nhánh trừ `main` (bao gồm sub-branch dev/task và `staging`)

Kiểm tra gồm:
- build docs và kiểm tra tài liệu rules
- cài/build/test Functions
- `flutter analyze`, `flutter test`
- kiểm tra build Android release
- dependency review + Trivy + gitleaks + scan image

### `mobile-e2e.yml` (`CI - Mobile E2E (PR/Manual)`)
Chạy E2E Android + iOS cho PR mobile và khi chạy tay.

### `deploy-docs.yml` (`CD - Deploy Docs (GitHub Pages)`)
Build và publish site tài liệu lên GitHub Pages.

### `deploy-staging.yml` (`CD - Deploy Staging`)
Deploy Firebase + web hosting cho môi trường staging.
Chặn nhánh: chỉ `staging`.

### `release-main.yml` (`CD - Release Main`)
Tạo version release, ký binary mobile, build artifact bất biến, checksum và manifest.
Chặn nhánh: chỉ `main`.

### `deploy-firebase.yml` (`CD - Deploy Firebase (Production)`)
Build/deploy Firestore rules, indexes, Storage rules, Functions.
Đồng thời tạo `.env.<projectId>` và sync runtime overrides không chứa secret.
Chặn nhánh: chỉ `main`.

### `deploy-web-hosting.yml` (`CD - Deploy Web Hosting (Production)`)
Deploy hosting production từ gói web bất biến đã gắn vào release.
Chặn nhánh: chỉ `main`.

### `rollback-production.yml` (`CD - Rollback Production`)
Rollback production về tag release đã chọn.

### `weekly-release-promotion.yml` (`Ops - Promote Staging to Main`)
Tạo/cập nhật PR promote `staging -> main` theo lịch tuần.

### `release-issue-closure.yml` (`Ops - Close Released Issues`)
Tự đóng issue liên quan sau khi PR phát hành vào `main`.

## Khóa cấu hình production bắt buộc

Biến bắt buộc:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`

Secret bắt buộc cho production:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Fallback cho staging (tùy chọn trong giai đoạn chuyển đổi):
- `FIREBASE_SERVICE_ACCOUNT`
- `CARD_WEBHOOK_SECRET`
