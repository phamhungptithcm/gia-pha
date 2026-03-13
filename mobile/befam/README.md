# BeFam Flutter App

This directory contains the BeFam mobile application for iOS and Android.

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

## Run locally

```bash
flutter pub get
flutter run
```

## Current scope

The app currently boots into a Firebase readiness screen so the project
configuration can be validated before feature development expands across auth,
genealogy, events, funds, scholarship, and notifications.
