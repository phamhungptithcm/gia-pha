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
cd mobile/befam
flutter run
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

The mobile apps are registered in Firebase, but the Google Cloud project still
has Cloud Firestore disabled. Enable Cloud Firestore for project `be-fam-3ab23`
before attempting to deploy Firestore rules, indexes, or Cloud Functions.
