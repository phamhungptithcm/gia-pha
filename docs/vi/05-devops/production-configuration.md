# Cấu hình Production

_Cập nhật gần nhất: 22/03/2026_

Tài liệu này mô tả cách tách cấu hình local và production để tránh lệch môi
trường khi phát hành.

## Các lớp cấu hình runtime

1. GitHub Environment `production` (vars + secrets)
2. Firestore runtime overrides `runtimeConfig/global` (không chứa secret)
3. Flutter `--dart-define` cho cấu hình compile-time

## Phạm vi deploy staging

Pipeline `staging` chỉ dùng môi trường sandbox và chỉ deploy:
- Tài nguyên Firebase của staging (`firestore:rules`, `firestore:indexes`, `storage`, `functions`)
- Web hosting
- Artifact Android AAB + iOS IPA đã ký
- Tùy chọn phát hành mobile thử nghiệm: Android track `internal/closed` và iOS `TestFlight`

`staging` **không được** publish lên kênh mobile production.
Dùng `STAGING_MOBILE_PUBLISH_ENABLED=true` để bật publish mobile staging.

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
- `FIRESTORE_DATABASE_ID` (`(default)` cho staging, `befam` cho production theo cấu hình hiện tại)
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
- `AI_ASSIST_ENABLED`
- `AI_ASSIST_MODEL`
- `OTP_PROVIDER`
- `OTP_ALLOWED_DIAL_CODES`
- `OTP_TWILIO_VERIFY_SERVICE_SID`
- `OTP_TWILIO_TIMEOUT_MS`
- `OTP_TWILIO_MAX_RETRIES`
- `OTP_TWILIO_BACKOFF_MS`
- `GOOGLE_PLAY_PACKAGE_NAME`
- `BILLING_IAP_ALLOW_TEST_MOCK`
- `BILLING_IAP_APPLE_VERIFY_TIMEOUT_MS`
- `BILLING_IAP_APPLE_VERIFY_MAX_RETRIES`
- `BILLING_IAP_APPLE_VERIFY_BACKOFF_MS`
- `GOOGLE_IAP_RTDN_AUDIENCE`
- `GOOGLE_IAP_RTDN_SERVICE_ACCOUNT_EMAIL`
- `BILLING_PRICING_CACHE_MS`

Product ID IAP được đọc từ Firestore collection `subscriptionPackages` (`storeProductIds.ios` và `storeProductIds.android`), không còn map qua biến môi trường.

Secret deploy bắt buộc (OIDC + billing):
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
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

Secret bắt buộc khi `AI_ASSIST_ENABLED=true`:
- `GOOGLE_GENAI_API_KEY`

Secret ký build release bắt buộc:
- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`
- `ANDROID_RELEASE_KEY_PASSWORD`
- `IOS_P12_BASE64`
- `IOS_P12_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`

Secret bắt buộc để publish mobile staging (nếu bật):
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (hoặc fallback `FIREBASE_SERVICE_ACCOUNT`)
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY`

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

## Thiết lập Gemini key qua GitHub Secrets

Nguồn tạo key:
- mở [Google AI Studio](https://aistudio.google.com/app/apikey)
- chọn đúng Google project dùng cho BeFam
- tạo API key cho Gemini Developer API
- copy key ngay sau khi tạo

Nơi lưu key:
- vào GitHub repository `Settings` -> `Environments` -> `production`
- thêm environment secret tên `GOOGLE_GENAI_API_KEY`
- nếu staging cũng bật AI, thêm cùng tên secret trong environment `staging`

Nơi lưu config không nhạy cảm:
- thêm GitHub environment var `AI_ASSIST_ENABLED=true`
- thêm GitHub environment var `AI_ASSIST_MODEL=gemini-2.5-flash-lite`

Luồng deploy production sau khi cấu hình:
1. workflow `CD - Deploy Firebase (Production)` lấy `GOOGLE_GENAI_API_KEY` từ GitHub Environment secret
2. workflow sync secret này vào Firebase Functions Secret Manager bằng `firebase functions:secrets:set`
3. Functions AI chỉ bind secret đó ở runtime, không ghi key vào repo hoặc `.env` production

Lệnh CLI tương đương để kiểm tra/thao tác tay:

```bash
cd firebase/functions
firebase functions:secrets:set GOOGLE_GENAI_API_KEY
firebase functions:secrets:access GOOGLE_GENAI_API_KEY
```

Khuyến nghị vận hành:
- dùng GitHub **environment secret**, không dùng repository secret chung cho production
- rotate key bằng cách update secret trên GitHub rồi chạy lại workflow deploy
- không đưa `GOOGLE_GENAI_API_KEY` vào `.env.<project>` production

## Checklist trước khi release production

- xác nhận đủ biến và secret bắt buộc
- xác nhận Firestore production đúng `FIRESTORE_DATABASE_ID` (giá trị production hiện tại: `befam`)
- xác nhận staging luôn dùng database `(default)` và project sandbox `be-fam-3ab23`
- xác nhận product ID IAP khớp với gói đã publish trên App Store / Google Play
- xác nhận `BILLING_IAP_ALLOW_TEST_MOCK=false` ở production
- xác nhận `BILLING_ENABLE_LEGACY_CARD_FLOW=false` ở production
- xác nhận `CALLABLE_ENFORCE_APP_CHECK=true` ở production
- nếu `AI_ASSIST_ENABLED=true`, xác nhận `GOOGLE_GENAI_API_KEY` đã có trong GitHub environment secret `production`
- xác nhận đã bật branch protection cho `staging` và `main` với required checks
- nếu secret từng bị lộ (đặc biệt `APPLE_SHARED_SECRET`) phải rotate ngay trước khi release
- giữ `BILLING_ALLOW_MANUAL_SETTLEMENT=false` nếu không có nhu cầu vận hành đặc biệt
- xác nhận `subscriptionPackages` có đủ plan active `FREE/BASE/PLUS/PRO` (preflight sẽ chặn release nếu thiếu)

## Checklist sau khi deploy

- kiểm tra log CI: tạo `.env.<projectId>` thành công
- kiểm tra log CI: bước sync `GOOGLE_GENAI_API_KEY` vào Firebase Secret Manager thành công
- kiểm tra log sync runtime config thành công
- kiểm tra log sync `subscriptionPackages` thành công
- smoke test luồng auth và billing trên máy thật
- xác nhận chỉ kích hoạt quyền gói khi thanh toán thành công

## Baseline Firestore quản lý bằng code

Deploy production/staging sẽ đồng bộ `subscriptionPackages` từ:

- `firebase/functions/config/subscription-packages.catalog.json`

Lệnh kiểm tra/đồng bộ:

```bash
cd firebase/functions
npm ci
FIREBASE_PROJECT_ID=<project-id> npm run config:subscription-packages:check
FIREBASE_PROJECT_ID=<project-id> npm run config:subscription-packages:sync
```
