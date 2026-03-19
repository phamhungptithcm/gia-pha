# Cấu hình Production

_Cập nhật gần nhất: 18/03/2026_

Tài liệu này mô tả cách tách cấu hình local và production để tránh lệch môi
trường khi phát hành.

## Các lớp cấu hình runtime

1. GitHub Environment `production` (vars + secrets)
2. Firestore runtime overrides `runtimeConfig/global` (không chứa secret)
3. Flutter `--dart-define` cho cấu hình compile-time

## Phiên bản OS đang hỗ trợ

Mức hỗ trợ production hiện tại:
- iOS: `15.0+`
- Android: `API 24+` (Android 7.0+)

Nơi cấu hình được áp dụng:
- iOS deployment target: `mobile/befam/ios/Podfile`
- Android min SDK: `mobile/befam/android/app/build.gradle.kts` (qua `flutter.minSdkVersion`)

Ràng buộc kỹ thuật của stack hiện tại:
- Flutter `3.41.x` mặc định Android min SDK là `24`.
- Bộ plugin Firebase iOS đang dùng yêu cầu deployment target `15.0`.

Nếu muốn hạ mức hỗ trợ xuống thấp hơn:
- cần chạy audit tương thích dependency trước
- pin/hạ version các plugin bị chặn (nếu có bản tương thích)
- kiểm thử lại đầy đủ trên máy thật cho auth số điện thoại, messaging, billing và print/export

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
