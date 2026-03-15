# Local Development

This page documents the local Flutter setup for the BeFam mobile app.

_Last reviewed: March 14, 2026_

## App location

The local Flutter application scaffold lives at:

```text
mobile/befam/
```

## Installed toolchain

On this machine, the following components were installed:

- Flutter SDK
- Android SDK command-line tools
- Android platform packages and emulator
- CocoaPods
- Xcode application (`/Applications/Xcode.app`)

## Environment variables

The shell configuration exports:

- `JAVA_HOME`
- `ANDROID_SDK_ROOT`
- `ANDROID_HOME`
- Flutter and Android SDK paths in `PATH`

Open a new terminal or run `source ~/.zshrc` after setup changes.

## Verification

Run:

```bash
./scripts/flutter_doctor_local.sh
```

Expected result:

- Android toolchain passes
- Flutter SDK passes
- CocoaPods is detected
- iOS simulator support is available when full Xcode developer path is active

## Start Android emulator

Run:

```bash
./scripts/run_android_emulator.sh
```

The configured emulator name is:

```text
flutter_android_test
```

## Run the app

```bash
./scripts/run_befam_android.sh
```

Run directly with Flutter (recommended for day-to-day):

```bash
cd mobile/befam
flutter run -d emulator-5554
```

For iOS simulator on machines where `xcode-select` points to command-line
tools, force the developer path:

```bash
cd mobile/befam
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter devices
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run -d ios
```

## Regenerate app models

The Flutter app now uses Freezed and JSON code generation for bootstrap models.

Run after changing generated models:

```bash
cd mobile/befam
dart run build_runner build --delete-conflicting-outputs
```

## Mobile verification

Run before opening a pull request:

```bash
cd mobile/befam
flutter analyze
flutter test
```

## Auth and runtime mode

Debug builds now default to the live Firebase auth path.

- live path default: `BEFAM_USE_LIVE_AUTH=true`
- force mock backend for local sandbox/testing:

```bash
cd mobile/befam
flutter run -d emulator-5554 --dart-define=BEFAM_USE_LIVE_AUTH=false
```

Optional debug sandbox values:

- OTP: `123456`
- child identifiers: `BEFAM-CHILD-001`, `BEFAM-CHILD-002`

## Firebase project

The Flutter app is wired to Firebase project:

```text
be-fam-3ab23
```

Generated app configuration files:

- `mobile/befam/android/app/google-services.json`
- `mobile/befam/ios/Runner/GoogleService-Info.plist`
- `mobile/befam/lib/firebase_options.dart`

Bootstrap services now include:

- Firebase core initialization
- local logger output during development
- release-only Crashlytics collection when Firebase is available
- push token registration bootstrap on authenticated app shell

Repo-level Firebase configuration lives in:

- `.firebaserc`
- `firebase.json`
- `firebase/firestore.rules`
- `firebase/firestore.indexes.json`
- `firebase/storage.rules`
- `firebase/functions/`

## Optional Firebase demo seed for local UI validation

Seed baseline clan/member/invite data into Firebase:

```bash
cd firebase/functions
npm ci
npm run seed:demo
```

If you use a service account file:

```bash
cd firebase/functions
FIREBASE_PROJECT_ID=be-fam-3ab23 \
FIREBASE_SERVICE_ACCOUNT_JSON=/absolute/path/to/service-account.json \
npm run seed:demo
```

Seed output now includes:

- 1 demo clan with 4 branches
- 32 members (multi-generation graph, including both `active` and `deceased`)
- parent-child and spouse relationships for wide tree rendering tests
- invite records for phone and child OTP flows
- `debug_login_profiles` collection for local bypass role/security scenarios:
  - clan admin with existing clan
  - branch admin with existing clan
  - member with existing clan
  - unlinked user
  - branch admin role without clan linkage
  - clan admin context before clan creation
