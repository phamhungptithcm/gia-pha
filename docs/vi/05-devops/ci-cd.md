# CI/CD

_Cập nhật gần nhất: 17/03/2026_

BeFam dùng mô hình phát hành có kiểm soát:

- `staging`: tích hợp và kiểm thử
- `main`: phát hành production

## Tóm tắt workflow

### `branch-ci.yml`
Chạy khi có PR/push vào `staging` hoặc `main`.

Kiểm tra gồm:
- build docs và kiểm tra tài liệu rules
- cài/build/test Functions
- `flutter analyze`, `flutter test`
- kiểm tra build Android release

### `docs-ci.yml`
Chạy cho thay đổi docs/rules để đảm bảo tài liệu luôn build strict thành công.

### `deploy-docs.yml`
Build và publish site tài liệu lên GitHub Pages.

### `deploy-firebase.yml`
Build/deploy Firestore rules, indexes, Storage rules, Functions.
Đồng thời tạo `.env.<projectId>` và sync runtime overrides không chứa secret.

### `release-main.yml`
Tạo phiên bản release, build artifact và publish release assets.

### `weekly-release-promotion.yml`
Tạo/cập nhật PR promote `staging -> main` theo lịch tuần.

### `release-issue-closure.yml`
Tự đóng issue liên quan sau khi PR phát hành vào `main`.

## Khóa cấu hình production bắt buộc

Biến bắt buộc:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`

Secret bắt buộc:
- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Secret tùy chọn:
- `CARD_WEBHOOK_SECRET`
