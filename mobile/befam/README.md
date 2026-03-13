# BeFam Flutter App

This directory contains the BeFam mobile application for iOS and Android.

## Bootstrap status

The current app foundation includes:

- Firebase core initialization for Android and iOS
- Material 3 theme built from the BeFam palette
- A bottom-navigation shell with placeholder workspaces
- Freezed and JSON code generation for app models
- Structured local logging and release-ready Crashlytics wiring

## Firebase wiring

The app is configured for Firebase project `be-fam-3ab23` with generated client
configuration in:

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
flutter run
```

Validate the bootstrap foundation:

```bash
flutter analyze
flutter test
```

## Current scope

The app now opens into a bootstrap dashboard that confirms Firebase readiness,
surfaces the initial BeFam modules, and provides placeholder destinations for
tree, events, and profile flows while feature work expands.
