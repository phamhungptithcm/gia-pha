# Local Development

This page documents the local Flutter setup for the Family Clan App repository.

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
- iOS remains blocked until full Xcode is installed

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

## Local auth sandbox

Debug builds default to a local authentication sandbox so the UI can be tested
without waiting on real SMS delivery.

Use:

- OTP: `123456`
- child identifiers: `BEFAM-CHILD-001`, `BEFAM-CHILD-002`

To force the live Firebase auth path in debug:

```bash
cd mobile/befam
flutter run -d emulator-5554 --dart-define=BEFAM_USE_LIVE_AUTH=true
```

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
- local `logger` output during development
- release-only Crashlytics collection when Firebase is available

Repo-level Firebase configuration lives in:

- `.firebaserc`
- `firebase.json`
- `firebase/firestore.rules`
- `firebase/firestore.indexes.json`
- `firebase/storage.rules`
- `firebase/functions/`

## iOS requirement

iOS simulator and device builds require the full Xcode application.

After installing Xcode:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
cd mobile/befam
flutter run -d ios
```

## Remaining cloud provisioning step

The mobile apps are registered in Firebase and the default Firestore database is
now live in `asia-southeast1`.

Current remaining blocker:

- Firestore rules and indexes can deploy from the repository
- Cloud Functions v2 deployment still needs a billing account linked to `be-fam-3ab23`
- billing is required before Google can enable Cloud Build, Cloud Run, Artifact Registry, Secret Manager, and Cloud Scheduler for the project
