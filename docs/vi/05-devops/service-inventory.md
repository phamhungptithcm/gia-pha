# Inventory Dịch Vụ Dự Án BeFam

_Cập nhật quét: 26/03/2026_

## Phạm vi quét

- Runtime app Flutter (`mobile/befam/pubspec.yaml`, `mobile/befam/lib/**`)
- Firebase Functions + runtime config (`firebase/functions/src/**`)
- CI/CD workflows (`.github/workflows/**`)
- Mẫu env vận hành (`scripts/github-staging.env.example`, `scripts/github-production.env.example`)

## Bảng dịch vụ

| Tên | Của cái gì | Mục đích sử dụng | Chi phí |
|---|---|---|---|
| Firebase Authentication (Phone/Auth) | Google Firebase | Đăng nhập, xác thực user, phiên làm việc | Free tier + có thể phát sinh phí theo mức dùng (đặc biệt OTP/SMS) |
| Cloud Firestore | Google Firebase | CSDL chính cho nghiệp vụ clan/member/billing/notification | Free tier + tính phí theo đọc/ghi/lưu trữ |
| Cloud Functions for Firebase (Gen2) | Google Firebase / Google Cloud | Backend API callable, scheduled jobs, webhook IAP | Free tier + tính phí theo invocations/CPU/network |
| Firebase Cloud Messaging (FCM) | Google Firebase | Gửi push notification | Thường miễn phí |
| Firebase Storage | Google Firebase | Lưu file/ảnh/tài nguyên upload | Free tier + tính phí theo lưu trữ/băng thông |
| Firebase Hosting | Google Firebase | Host web build của app | Free tier + tính phí theo băng thông/request (vượt quota) |
| Firebase App Check | Google Firebase | Chống abuse cho app/web (web dùng reCAPTCHA v3, mobile dùng Play Integrity + App Attest/DeviceCheck) | Thường miễn phí |
| Firebase Analytics | Google Firebase | Theo dõi event hành vi người dùng | Thường miễn phí |
| Firebase Crashlytics | Google Firebase | Thu thập crash report production | Thường miễn phí |
| Firebase Emulator Suite | Google Firebase | Chạy Auth/Firestore/Functions/Storage local cho dev/test | Miễn phí (local tooling) |
| Google Play Billing (Android IAP) | Google Play Console | Thanh toán in-app trên Android | Cần tài khoản Play Developer + phí chia sẻ doanh thu giao dịch |
| App Store In-App Purchase + App Store Server Notifications | Apple App Store Connect | Thanh toán in-app trên iOS + webhook vòng đời subscription | Cần Apple Developer Program + phí chia sẻ doanh thu giao dịch |
| Google Play Developer API (Android Publisher) | Google APIs | Server verify giao dịch Android subscription | Không có phí API riêng rõ ràng, chủ yếu phụ thuộc hạ tầng gọi API |
| Google Cloud Pub/Sub (RTDN) | Google Cloud | Nhận Real-time Developer Notifications từ Google Play vào webhook | Free tier + tính phí theo message (vượt quota) |
| Twilio Verify API | Twilio | Gửi và verify OTP SMS khi bật `OTP_PROVIDER=twilio` | Tính phí theo OTP/SMS (usage-based) |
| Google Mobile Ads (AdMob) | Google AdMob | Hiển thị banner/interstitial ads trong app | Không trả phí tích hợp; nền tảng chia sẻ doanh thu quảng cáo |
| GitHub Actions | GitHub | CI/CD: test, build, deploy, release automation | Có quota phút miễn phí theo plan, vượt quota tính phí |
| GitHub Releases | GitHub | Lưu/trả artifact release (AAB/IPA/Web bundle/checksum) | Theo quota storage/bandwidth của GitHub |
| GitHub Pages + MkDocs | GitHub Pages | Deploy site tài liệu docs | Miễn phí cho public repo (có giới hạn sử dụng) |
| Slack Incoming Webhook | Slack | Gửi thông báo CI/CD fail/success | Có thể dùng gói miễn phí hoặc trả phí tùy workspace |
| Google Cloud IAM (Workload Identity Federation + Service Account) | Google Cloud IAM | Xác thực OIDC từ GitHub Actions để deploy Firebase | Thường không có phí trực tiếp, tính phí nằm ở tài nguyên deploy |
| Trivy (filesystem/image scan) | Aqua Security (qua GitHub Action) | Security scan mã nguồn + container trong CI | Tool miễn phí, tốn phút runner CI |
| Gitleaks | Gitleaks (qua GitHub Action) | Quét lộ secret trong code | Tool miễn phí, tốn phút runner CI |
| GitHub Dependency Review Action | GitHub | Chặn dependency rủi ro trên PR | Tính trong chi phí GitHub Actions |
| Docker (build image trong CI) | Docker ecosystem | Build image tooling để test/scan/deploy flow | Tool miễn phí; chi phí chủ yếu là runner compute |

## Checklist Staging vs Production

Legend:
- `Bắt buộc`: nên có trước khi chạy deploy/release
- `Khuyên dùng`: nên bật để vận hành ổn định/an toàn hơn
- `Tùy chọn`: chỉ cần khi dùng tính năng tương ứng
- `N/A`: không áp dụng cho môi trường đó

| Dịch vụ / Nhóm | Staging | Production | Keys/Secrets chính | Checklist Staging | Checklist Production |
|---|---|---|---|---|---|
| Firebase project nền tảng (Auth + Firestore + Functions + Storage) | Bắt buộc | Bắt buộc | `FIREBASE_PROJECT_ID`, `FIREBASE_FUNCTIONS_REGION`, `FIRESTORE_DATABASE_ID` | [ ] | [ ] |
| Firebase Hosting (web) | Bắt buộc (deploy web staging) | Bắt buộc (deploy web prod) | `FIREBASE_HOSTING_TARGET` (optional) | [ ] | [ ] |
| Deploy auth GitHub -> GCP (OIDC hoặc key) | Bắt buộc | Bắt buộc | `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT_EMAIL` hoặc `FIREBASE_SERVICE_ACCOUNT` | [ ] | [ ] |
| Firebase App Check | Khuyên dùng | Bắt buộc | `BEFAM_ENABLE_APP_CHECK`, `BEFAM_APP_CHECK_WEB_RECAPTCHA_SITE_KEY`, `CALLABLE_ENFORCE_APP_CHECK` | [ ] | [ ] |
| Google Play IAP verify (Android) | Khuyên dùng (nếu test IAP) | Bắt buộc | `GOOGLE_PLAY_PACKAGE_NAME`, `BILLING_IAP_ALLOW_TEST_MOCK` | [ ] | [ ] |
| Apple IAP verify (iOS) | Khuyên dùng (nếu test IAP) | Bắt buộc | `APPLE_SHARED_SECRET`, `BILLING_IAP_APPLE_VERIFY_*` | [ ] | [ ] |
| Google RTDN qua Pub/Sub (Android subscription webhook) | Khuyên dùng | Bắt buộc | `GOOGLE_IAP_RTDN_AUDIENCE`, `GOOGLE_IAP_RTDN_SERVICE_ACCOUNT_EMAIL` | [ ] | [ ] |
| Webhook auth token cho IAP | Tùy chọn (fallback qua secret chung) | Khuyên dùng | `APPLE_IAP_WEBHOOK_BEARER_TOKEN`, `GOOGLE_IAP_WEBHOOK_BEARER_TOKEN`, fallback `BILLING_WEBHOOK_SECRET` | [ ] | [ ] |
| URL store hiển thị trên web/app | Tùy chọn | Khuyên dùng | `BEFAM_IOS_APP_STORE_URL`, `BEFAM_ANDROID_PLAY_STORE_URL` | [ ] | [ ] |
| Twilio Verify (OTP nhà mạng) | Tùy chọn | Tùy chọn (bắt buộc nếu `OTP_PROVIDER=twilio`) | `OTP_PROVIDER`, `OTP_TWILIO_VERIFY_SERVICE_SID`, `OTP_TWILIO_ACCOUNT_SID`, `OTP_TWILIO_AUTH_TOKEN` | [ ] | [ ] |
| FCM Push notification | Khuyên dùng | Khuyên dùng | `NOTIFICATION_PUSH_ENABLED` + cấu hình Firebase Messaging của app | [ ] | [ ] |
| Email queue notification | Tùy chọn | Tùy chọn | `NOTIFICATION_EMAIL_ENABLED`, `NOTIFICATION_EMAIL_COLLECTION` | [ ] | [ ] |
| Slack CI/CD notifications | Tùy chọn | Tùy chọn | `SLACK_WEBHOOK_URL` | [ ] | [ ] |
| Release signing mobile artifact | N/A | Bắt buộc (nếu release Android/iOS) | `ANDROID_RELEASE_*`, `IOS_*` secrets | [ ] | [ ] |
| GitHub Actions CI pipeline | Bắt buộc | Bắt buộc | Repo/workflow permissions + runner quota | [ ] | [ ] |
| GitHub Releases artifact publish | N/A (không dùng cho staging) | Khuyên dùng | Quyền `contents: write` + workflow release | [ ] | [ ] |
| GitHub Pages docs | N/A (không tách staging) | Bắt buộc (nhánh `main`) | Workflow docs + Pages permissions | [ ] | [ ] |
| Google Mobile Ads (AdMob) | Tùy chọn | Tùy chọn/Khuyên dùng (nếu monetization) | Hiện tại code dùng test ad unit ID mặc định | [ ] | [ ] |

## Baseline giá trị môi trường (khuyến nghị hiện tại)

| Key | Staging khuyến nghị | Production khuyến nghị |
|---|---|---|
| `FIREBASE_PROJECT_ID` | `be-fam-3ab23` | project production riêng (không phải `be-fam-3ab23`) |
| `FIRESTORE_DATABASE_ID` | `(default)` | `befam` |
| `FIREBASE_FUNCTIONS_REGION` | `asia-southeast1` | `asia-southeast1` |
| `BILLING_IAP_ALLOW_TEST_MOCK` | `false` (như template hiện tại) | `false` |
| `CALLABLE_ENFORCE_APP_CHECK` | tùy môi trường test | `true` |
| `OTP_PROVIDER` | `firebase` hoặc `twilio` tùy setup | `twilio` hoặc `firebase` theo mô hình vận hành |

## Baseline chi phí production (ước tính hiện tại)

_Rà soát ngày: 04/04/2026_

### Giả định tính toán

- Domain production là `befam.co`.
- Giá domain do chủ dự án cung cấp:
  - năm đầu: `$17.99`
  - từ năm thứ 2 trở đi: `$53.39/năm`
- Apple phát hành app qua Apple Developer Program: `$99/năm`.
- Google Play cần phí đăng ký developer: `$25` một lần, không phải phí lặp lại hàng năm.
- Code hiện tại có 6 scheduled jobs dùng `onSchedule`, tương ứng 6 Cloud Scheduler jobs:
  - 5 jobs trong [`firebase/functions/src/scheduled/jobs.ts`](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/firebase/functions/src/scheduled/jobs.ts)
  - 1 job trong [`firebase/functions/src/events/event-triggers.ts`](/Users/hunpeo97/Desktop/Workspace/Coder/gia-pha/firebase/functions/src/events/event-triggers.ts)
- Cloud Scheduler tính `$0.10/job/tháng`, miễn phí 3 jobs đầu mỗi billing account.
- Baseline dưới đây giả định billing account chưa dùng mất free tier 3 jobs ở project khác, nên chỉ còn 3 jobs phải trả phí cho BeFam.

### Chi phí cố định / gần-cố định

| Khoản | Cách tính | Năm 1 | Từ năm 2 |
|---|---|---:|---:|
| Domain `befam.co` | Giá user cung cấp | $17.99 | $53.39 |
| Apple Developer Program | Hàng năm | $99.00 | $99.00 |
| Google Play developer account | Một lần | $25.00 | $0.00 |
| Cloud Scheduler cho 6 scheduled jobs | `(6 - 3 free) x $0.10 x 12 tháng` | $3.60 | $3.60 |
| **Tổng fixed baseline** |  | **$145.59** | **$155.99** |

### Ghi chú về tổng fixed baseline

- Nếu team đã có sẵn tài khoản Google Play developer từ trước, có thể bỏ dòng `$25.00` one-time ở năm 1.
- Nếu 3 free Cloud Scheduler jobs đã bị dùng bởi project khác trong cùng billing account, chi phí Cloud Scheduler của BeFam có thể tăng tối đa lên:
  - `6 x $0.10 x 12 = $7.20/năm`
- Khi đó tổng fixed baseline sẽ là:
  - năm 1: `$149.19`
  - từ năm 2: `$159.59`

### Chi phí biến đổi theo usage

Các khoản dưới đây đã được codebase xác nhận là có thể phát sinh, nhưng không thể chốt số USD/năm nếu chưa có traffic production thật:

| Nhóm | Dịch vụ | Cách phát sinh chi phí |
|---|---|---|
| Auth/OTP | Firebase Authentication Phone Auth | tăng theo số lượt xác thực, đặc biệt OTP/SMS |
| OTP ngoài Firebase | Twilio Verify API | tăng theo số OTP/SMS gửi thật |
| Database | Cloud Firestore | tăng theo đọc/ghi/lưu trữ |
| Backend | Cloud Functions for Firebase Gen2 | tăng theo invocations/CPU/network |
| Storage | Firebase Storage | tăng theo lưu trữ và băng thông |
| Web | Firebase Hosting | tăng theo request và băng thông vượt quota |
| Billing webhook | Google Cloud Pub/Sub (RTDN) | tăng theo số message vượt free tier |
| CI/CD | GitHub Actions | tăng nếu vượt quota runner phút của plan |
| Artifact | GitHub Releases | tăng nếu artifact/storage/bandwidth vượt quota |
| Store revenue share | Apple / Google Play | phát sinh theo doanh thu IAP thực tế, không phải phí vận hành cố định |

### Khoản thường miễn phí hoặc chưa cần cộng vào baseline

- Firebase Cloud Messaging (FCM)
- Firebase App Check
- Firebase Analytics
- Firebase Crashlytics
- Firebase Emulator Suite
- GitHub Pages + MkDocs
- Slack Incoming Webhook nếu đang dùng free workspace
- Trivy, Gitleaks, Dependency Review, Docker tooling nếu vẫn nằm trong quota CI hiện có

### Nguồn giá tham chiếu

- Apple Developer Program: [developer.apple.com/support/compare-memberships](https://developer.apple.com/support/compare-memberships/)
- Apple membership fee details: [developer.apple.com/help/account/membership/program-enrollment](https://developer.apple.com/help/account/membership/program-enrollment)
- Cloud Scheduler pricing: [cloud.google.com/scheduler/pricing](https://cloud.google.com/scheduler/pricing)
- Firebase scheduled functions: [firebase.google.com/docs/functions/schedule-functions](https://firebase.google.com/docs/functions/schedule-functions)
- Android developer verification / registration fee reference: [developer.android.com/developer-verification/guides/early-access](https://developer.android.com/developer-verification/guides/early-access)

## Ghi chú quan trọng

- Tài liệu sản phẩm cũ còn nhắc `VNPay/Card`, nhưng code runtime hiện tại đang ưu tiên Store IAP (Apple/Google) cho payment flow.
- Một số dịch vụ là `tùy chọn theo env` (đặc biệt Twilio, email/sms webhook ngoài hệ thống).
- Chi phí ở bảng là mức phân loại vận hành; con số thực tế phụ thuộc plan account và mức traffic giao dịch thật.
