# Phát triển local

_Cập nhật gần nhất: 17/03/2026_

Trang này mô tả thiết lập local cho ứng dụng mobile BeFam.

## Vị trí app

```text
mobile/befam/
```

## Toolchain đã dùng

- Flutter SDK
- Android SDK command-line tools
- Android platform packages và emulator
- CocoaPods
- Xcode (`/Applications/Xcode.app`)

## Biến môi trường

Shell cần có:

- `JAVA_HOME`
- `ANDROID_SDK_ROOT`
- `ANDROID_HOME`
- Flutter/Android SDK trong `PATH`

Sau khi thay đổi cấu hình, mở terminal mới hoặc chạy `source ~/.zshrc`.

## Kiểm tra môi trường

```bash
./scripts/flutter_doctor_local.sh
```

Kỳ vọng:

- Android toolchain pass
- Flutter SDK pass
- CocoaPods được nhận diện
- iOS simulator dùng được khi developer path trỏ đúng Xcode đầy đủ

## Mở Android emulator

```bash
./run_flutter_targets.sh android-emulator-start
```

Tên emulator:

```text
flutter_android_test
```

## Chạy app

```bash
./run_flutter_targets.sh
./run_flutter_targets.sh android-debug
./run_flutter_targets.sh android-usb
./run_flutter_targets.sh android-usb-release-ci
./run_flutter_targets.sh android-doctor
./run_flutter_targets.sh ios-sim
./run_flutter_targets.sh web-server 8080
```

Nếu máy Android cắm dây chưa hiện ra, chạy:

```bash
./run_flutter_targets.sh android-doctor
./run_flutter_targets.sh android-restart-adb
```

Hoặc chạy trực tiếp:

```bash
cd mobile/befam
flutter run -d emulator-5554
```

Chạy iOS simulator khi máy đang trỏ command-line tools:

```bash
cd mobile/befam
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter devices
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d ios
```

## Sinh lại model

```bash
cd mobile/befam
dart run build_runner build --delete-conflicting-outputs
```

## Kiểm tra trước PR

```bash
cd mobile/befam
flutter analyze
flutter test
```

## Auth runtime

Ứng dụng dùng Firebase auth/runtime services cho luồng local thông thường và bám sát production.

Các `--dart-define` hữu ích:

- override vùng Functions:
  `--dart-define=BEFAM_FIREBASE_FUNCTIONS_REGION=asia-southeast1`
- override timezone mặc định:
  `--dart-define=BEFAM_DEFAULT_TIMEZONE=Asia/Ho_Chi_Minh`
- override deny-list host checkout:
  `--dart-define=BEFAM_INVALID_CHECKOUT_HOSTS=example.com`

Compile-time env constants nằm tại:
`mobile/befam/lib/core/services/app_environment.dart`

## Firebase project

App hiện nối với project:

```text
be-fam-3ab23
```

File cấu hình sinh tự động:

- `mobile/befam/android/app/google-services.json`
- `mobile/befam/ios/Runner/GoogleService-Info.plist`
- `mobile/befam/lib/firebase_options.dart`

Repo-level Firebase config:

- `.firebaserc`
- `firebase.json`
- `firebase/firestore.rules`
- `firebase/firestore.indexes.json`
- `firebase/storage.rules`
- `firebase/functions/`

## Seed dữ liệu demo (tùy chọn)

```bash
cd firebase/functions
npm ci
npm run seed:demo
```

Nếu dùng service account file:

```bash
cd firebase/functions
FIREBASE_PROJECT_ID=be-fam-3ab23 \
FIREBASE_SERVICE_ACCOUNT_JSON=/absolute/path/to/service-account.json \
npm run seed:demo
```

Bộ seed hiện gồm:

- 1 demo clan, 4 branch
- 32 thành viên đa thế hệ
- quan hệ cha mẹ-con cái/vợ chồng đủ rộng để test cây
- invite cho luồng phone OTP và child OTP
- `debug_login_profiles` cho các kịch bản local bypass

Lưu ý khi test dữ liệu thật local:

- profile test chỉ hiển thị khi `isActive: true` và `isTestUser: true`
- bypass OTP test dùng `debugOtpCode` (trả về `autoOtpCode`)
- debug mode có thể bật `appVerificationDisabledForTesting`
- sau đăng nhập, dữ liệu feature lấy từ Firebase repositories giống production
