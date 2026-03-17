# Cấu hình Production

_Cập nhật gần nhất: 17/03/2026_

Tài liệu này mô tả cách tách cấu hình local và production để tránh lệch môi
trường khi phát hành.

## Các lớp cấu hình runtime

1. GitHub Environment `production` (vars + secrets)
2. Firestore runtime overrides `runtimeConfig/global` (không chứa secret)
3. Flutter `--dart-define` cho cấu hình compile-time

## Khóa bắt buộc

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

## Checklist trước khi release production

- xác nhận đủ biến và secret bắt buộc
- xác nhận cấu hình VNPay là production, không phải sandbox
- xác nhận `VNPAY_RETURN_URL` hợp lệ
- giữ `BILLING_ALLOW_MANUAL_SETTLEMENT=false` nếu không có nhu cầu vận hành đặc biệt

## Checklist sau khi deploy

- kiểm tra log CI: tạo `.env.<projectId>` thành công
- kiểm tra log sync runtime config thành công
- smoke test luồng auth và billing trên máy thật
- xác nhận chỉ kích hoạt quyền gói khi thanh toán thành công
