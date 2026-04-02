# CI/CD

_Cập nhật gần nhất: 02/04/2026_

BeFam dùng mô hình phát hành có kiểm soát:

- `staging`: tích hợp và kiểm thử
- `main`: phát hành production

## Tóm tắt workflow

### `branch-ci.yml` (`CI - Branch Quality Gates`)
Chạy khi:
- có push vào mọi nhánh, bao gồm `staging` và `main`

Kiểm tra gồm:
- build docs và kiểm tra tài liệu rules
- cài/build/test Functions
- `flutter analyze`, `flutter test`
- kiểm tra build Android release
- dependency review + Trivy + gitleaks + scan image

### `mobile-e2e.yml` + `mobile-e2e-ios.yml`
Chạy smoke E2E Android/iOS khi có push vào mọi nhánh và khi chạy tay.
Job sẽ tự bỏ qua khi push không đụng tới phần mobile hoặc file E2E liên quan.

### `mobile-e2e-deep.yml` (`CI - Mobile E2E Deep`)
Chạy deep regression đầy đủ cho mobile khi có push vào `staging` hoặc `main`, và khi chạy tay.

### `deploy-docs.yml` (`CD - Deploy Docs (GitHub Pages)`)
Build và publish site tài liệu lên GitHub Pages.

### `deploy-staging.yml` (`CD - Deploy Staging`)
Deploy Firebase + web hosting cho môi trường staging.
Chặn nhánh: chỉ `staging`.

### `release-staging.yml` (`CD - Release Staging (Manual)`)
Workflow chạy tay (`workflow_dispatch`) để build artifact mobile staging có ký số phục vụ test upload store:
- Android AAB
- iOS IPA

Workflow này không tạo release tag và không publish GitHub Release.

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

### `promote-staging-to-main.yml` (`Ops - Promote Staging to Main`)
Tạo hoặc cập nhật PR promote `staging -> main` mỗi khi có commit mới vào `staging`.

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
