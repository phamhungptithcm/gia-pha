# BeFam Flutter App

This directory contains the BeFam mobile application for iOS and Android.

## Bootstrap status

The current app foundation includes:

- Firebase core initialization for Android and iOS
- Material 3 theme built from the BeFam palette
- A bottom-navigation shell with placeholder workspaces
- Authentication entry with phone sign-in, child access, OTP verification, resend cooldown, and logout
- Freezed and JSON code generation for app models
- Structured local logging and release-ready Crashlytics wiring

## Firebase wiring

The app supports two Firebase bootstrap modes:

1. Environment-driven (recommended for shared repo / fork):
   - Pass `BEFAM_FIREBASE_*` values via `--dart-define` to avoid coupling to one project.
2. Bundled fallback (convenience for local and CI):
   - Enable with `--dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true`.

Generated bundled client configuration currently lives in:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

Enabled Flutter SDK packages:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_messaging`
- `firebase_crashlytics`

## Platform support

Current baseline in this repository:

- iOS `15.0+`
- Android `API 24+` (Android 7.0+)

Notes:

- iOS minimum is aligned with current Firebase iOS plugin requirements.
- Android minimum follows the current Flutter toolchain default and plugin constraints.

## Local workflow

Install packages:

```bash
flutter pub get
```

Regenerate code after model changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the app:

```bash
../../run_flutter_targets.sh
../../run_flutter_targets.sh android-debug
../../run_flutter_targets.sh android-usb
../../run_flutter_targets.sh android-usb-staging-release
../../run_flutter_targets.sh android-usb-release-ci
../../run_flutter_targets.sh android-doctor
../../run_flutter_targets.sh ios-sim
../../run_flutter_targets.sh web-chrome
```

If a wired Android phone does not appear, run:

```bash
../../run_flutter_targets.sh android-doctor
../../run_flutter_targets.sh android-restart-adb
```

Build signed local release artifacts (Android AAB + iOS IPA):

```bash
../../scripts/build_mobile_release_local.sh
```

By default the script opens a selection menu and auto-fills build metadata
using release logic (no manual typing required).

Optional examples:

```bash
../../scripts/build_mobile_release_local.sh --build-name 1.2.0 --build-number 120
../../scripts/build_mobile_release_local.sh --skip-ios
../../scripts/build_mobile_release_local.sh --skip-android
```

`run_flutter_targets.sh` auto-injects
`--dart-define=BEFAM_ALLOW_BUNDLED_FIREBASE_OPTIONS=true` for local runs and
forwards any exported `BEFAM_FIREBASE_*` env variables as dart-defines.

Validate the bootstrap foundation:

```bash
flutter analyze
flutter test
./../../scripts/run_mobile_e2e.sh smoke
```

E2E release-case mapping lives in `integration_test/README.md` and links to
the release execution/dashboard templates in `/docs/vi/05-devops/`.

Refresh the production brand asset pack:

```bash
python3 ../../scripts/generate_brand_assets.py
```

## Current scope

The app now opens into an authentication-first BeFam flow:

- login method selection
- phone sign-in with OTP
- child identifier flow with linked parent OTP
- silent session restore and logout
- dashboard shell after sign-in

For local UI testing in debug builds:

- OTP: `123456`
- child IDs: `BEFAM-CHILD-001`, `BEFAM-CHILD-002`
- live Firebase auth can be forced with `--dart-define=BEFAM_USE_LIVE_AUTH=true`
- functions region can be overridden with
  `--dart-define=BEFAM_FIREBASE_FUNCTIONS_REGION=asia-southeast1`
- default app timezone can be overridden with
  `--dart-define=BEFAM_DEFAULT_TIMEZONE=Asia/Ho_Chi_Minh`
- checkout host guard list can be overridden with
  `--dart-define=BEFAM_INVALID_CHECKOUT_HOSTS=example.com`
- iOS App Store footer link can be set with
  `--dart-define=BEFAM_IOS_APP_STORE_URL=https://apps.apple.com/app/id<your-app-id>`
- Android Google Play footer link can be set with
  `--dart-define=BEFAM_ANDROID_PLAY_STORE_URL=https://play.google.com/store/apps/details?id=<your-package>`

## Branding assets

Production-ready brand exports live in `assets/branding/` and are also synced into:

- `android/app/src/main/res` for launcher, adaptive, splash, and notification icons
- `ios/Runner/Assets.xcassets` for app icons and launch images

The current pack includes:

- main logo
- light background logo
- dark background logo
- app icon
- splash logo
- Android notification icon
- Android adaptive icon assets
- Google Play feature graphic
