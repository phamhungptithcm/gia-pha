# Cấu hình Production

_Cập nhật gần nhất: 20/03/2026_

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

Biến bắt buộc (runtime Functions):
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`
- `APP_RUNTIME_CONFIG_COLLECTION`
- `APP_RUNTIME_CONFIG_DOC_ID`
- `EXPIRE_INVITES_JOB_SCHEDULE`
- `EVENT_REMINDER_JOB_SCHEDULE`
- `EVENT_REMINDER_LOOKAHEAD_MINUTES`
- `EVENT_REMINDER_SCAN_LIMIT`
- `EVENT_REMINDER_GRACE_MINUTES`
- `BILLING_SUBSCRIPTION_REMINDER_JOB_SCHEDULE`
- `BILLING_PENDING_TIMEOUT_JOB_SCHEDULE`
- `BILLING_DELINQUENCY_JOB_SCHEDULE`
- `BILLING_CONTACT_NOTICE_JOB_SCHEDULE`
- `BILLING_PENDING_TIMEOUT_MINUTES`
- `BILLING_PENDING_TIMEOUT_LIMIT`
- `BILLING_DELINQUENCY_GRACE_DAYS`
- `BILLING_DELINQUENCY_LIMIT`
- `BILLING_DELINQUENCY_REMINDER_DAYS`
- `BILLING_CONTACT_NOTICE_BATCH_LIMIT`
- `BILLING_CONTACT_NOTICE_REQUIRE_ENDPOINTS`
- `BILLING_CONTACT_NOTICE_WEBHOOK_TIMEOUT_MS`
- `BILLING_CONTACT_NOTICE_WEBHOOK_MAX_RETRIES`
- `BILLING_CONTACT_NOTICE_WEBHOOK_BACKOFF_MS`
- `NOTIFICATION_PUSH_ENABLED`
- `NOTIFICATION_EMAIL_ENABLED`
- `NOTIFICATION_EMAIL_COLLECTION`
- `NOTIFICATION_DEFAULT_PUSH_ENABLED`
- `NOTIFICATION_DEFAULT_EMAIL_ENABLED`
- `NOTIFICATION_ALLOW_NON_OTP_SMS`
- `NOTIFICATION_EVENT_MAX_AUDIENCE`
- `BILLING_CONTACT_SMS_WEBHOOK_URL`
- `BILLING_CONTACT_EMAIL_WEBHOOK_URL`
- `CALLABLE_ENFORCE_APP_CHECK`
- `OTP_PROVIDER`
- `OTP_ALLOWED_DIAL_CODES`
- `OTP_TWILIO_VERIFY_SERVICE_SID`
- `OTP_TWILIO_TIMEOUT_MS`
- `OTP_TWILIO_MAX_RETRIES`
- `OTP_TWILIO_BACKOFF_MS`
- `GOOGLE_PLAY_PACKAGE_NAME`
- `BILLING_IAP_PRODUCT_IDS_BASE`
- `BILLING_IAP_PRODUCT_IDS_PLUS`
- `BILLING_IAP_PRODUCT_IDS_PRO`
- `BILLING_IAP_IOS_PRODUCT_IDS_BASE`
- `BILLING_IAP_IOS_PRODUCT_IDS_PLUS`
- `BILLING_IAP_IOS_PRODUCT_IDS_PRO`
- `BILLING_IAP_ANDROID_PRODUCT_IDS_BASE`
- `BILLING_IAP_ANDROID_PRODUCT_IDS_PLUS`
- `BILLING_IAP_ANDROID_PRODUCT_IDS_PRO`
- `BILLING_IAP_ALLOW_TEST_MOCK`
- `BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS`
- `BILLING_IAP_APPLE_VERIFY_MAX_RETRIES`
- `BILLING_IAP_APPLE_VERIFY_BACKOFF_MS`
- `GOOGLE_IAP_RTDN_AUDIENCE`
- `GOOGLE_IAP_RTDN_SERVICE_ACCOUNT_EMAIL`
- `BILLING_PRICING_CACHE_MS`

Secret bắt buộc:
- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `APPLE_SHARED_SECRET`

Bắt buộc khi `OTP_PROVIDER=twilio`:
- `OTP_TWILIO_ACCOUNT_SID`
- `OTP_TWILIO_AUTH_TOKEN`
- `OTP_TWILIO_VERIFY_SERVICE_SID`

Secret tùy chọn:
- `CARD_WEBHOOK_SECRET`
- `BILLING_CONTACT_NOTICE_WEBHOOK_TOKEN`
- `APPLE_IAP_WEBHOOK_BEARER_TOKEN`
- `GOOGLE_IAP_WEBHOOK_BEARER_TOKEN`

Biến build Mobile/Web (GitHub vars, tùy chọn):
- `BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS`
- `BEFAM_FIREBASE_*`
- `BEFAM_FIREBASE_FUNCTIONS_REGION`
- `BEFAM_DEFAULT_TIMEZONE`
- `BEFAM_INVALID_CHECKOUT_HOSTS`
- `BEFAM_ENABLE_APP_CHECK`
- `BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY`
- `BEFAM_ALLOW_FIREBASE_PHONE_FALLBACK` (bắt buộc `false` ở production)
- `BEFAM_BILLING_PENDING_TIMEOUT_MINUTES`

## Checklist trước khi release production

- xác nhận đủ biến và secret bắt buộc
- xác nhận product ID IAP khớp với gói đã publish trên App Store / Google Play
- xác nhận `BILLING_IAP_ALLOW_TEST_MOCK=false` ở production
- xác nhận `BILLING_ENABLE_LEGACY_CARD_FLOW=false` ở production
- xác nhận `CALLABLE_ENFORCE_APP_CHECK=true` ở production
- giữ `BILLING_ALLOW_MANUAL_SETTLEMENT=false` nếu không có nhu cầu vận hành đặc biệt

## Checklist sau khi deploy

- kiểm tra log CI: tạo `.env.<projectId>` thành công
- kiểm tra log sync runtime config thành công
- smoke test luồng auth và billing trên máy thật
- xác nhận chỉ kích hoạt quyền gói khi thanh toán thành công
