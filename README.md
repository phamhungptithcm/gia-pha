# Gia Pha

Gia Pha is the planning and technical documentation repository for the Family Clan App,
a mobile-first genealogy platform for managing family trees, clan operations, events,
funds, and scholarship programs.

## Overview

This repository is designed to serve as the project source of truth for:

- product direction and feature planning
- system architecture and data modeling
- Firebase and Cloud Functions design
- Flutter implementation planning
- GitHub workflow and delivery operations

## Repository Structure

- `docs/`: MkDocs content published to GitHub Pages
- `mobile/befam/`: Flutter application scaffold for local iOS and Android development
- `firebase/`: Firestore rules, indexes, Storage rules, and Cloud Functions scaffold
- `.github/`: GitHub Actions workflows, issue templates, and pull request template
- `scripts/`: repository automation utilities, including backlog bootstrap tooling
- `mkdocs.yml`: documentation site configuration

## Documentation

- Live site: [phamhungptithcm.github.io/gia-pha](https://phamhungptithcm.github.io/gia-pha/)
- Main source: `docs/`
- Key planning documents:
  - `docs/AI_BUILD_MASTER_DOC.md`
  - `docs/AI_AGENT_TASKS_150_ISSUES.md`
  - `docs/FIRESTORE_PRODUCTION_SCHEMA.md`
  - `docs/FLUTTER_IMPLEMENTATION_PLAN.md`

## Local Development

Preview the documentation site locally:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

Build the site in strict mode:

```bash
mkdocs build --strict
```

Build the BeFam mobile release-builder image locally:

```bash
docker build \
  --platform linux/amd64 \
  --build-arg RELEASE_VERSION=local \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t befam-mobile-builder:local .
```

On Apple Silicon, the BeFam mobile builder intentionally targets `linux/amd64`
because the Flutter Linux SDK used for Android release builds is x86_64-based.

Build the Firebase tooling image locally:

```bash
docker build \
  --file docker/firebase-tools.Dockerfile \
  --build-arg RELEASE_VERSION=local \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t befam-firebase-tools:local .
```

## Flutter Development

The repository includes a local Flutter app at `mobile/befam`.

Current bootstrap foundation:

- Firebase core initialization for Android and iOS
- Material 3 theme based on the project palette
- Home shell with module placeholders for tree, members, events, and profile
- Authentication entry flow with phone login, child access, OTP verify, and session restore
- Freezed and JSON code generation for app models
- Structured logging with release-only Crashlytics enablement

Installed local tooling on this machine:

- Flutter SDK via Homebrew
- Android SDK command-line tools
- Android platform packages and emulator image
- CocoaPods

Run an environment check:

```bash
./scripts/flutter_doctor_local.sh
```

Start the Android emulator:

```bash
./scripts/run_android_emulator.sh
```

Run the Flutter app on Android:

```bash
./scripts/run_befam_android.sh
```

Regenerate model code after changing Freezed or JSON models:

```bash
cd mobile/befam
dart run build_runner build --delete-conflicting-outputs
```

Recommended local verification:

```bash
cd mobile/befam
flutter analyze
flutter test
```

Local auth sandbox notes:

- default debug OTP: `123456`
- demo child identifiers: `BEFAM-CHILD-001`, `BEFAM-CHILD-002`
- force the live Firebase auth path in debug with `--dart-define=BEFAM_USE_LIVE_AUTH=true`

## Firebase Setup

This repository is now linked to Firebase project `be-fam-3ab23`.

Configured mobile app artifacts:

- `mobile/befam/android/app/google-services.json`
- `mobile/befam/ios/Runner/GoogleService-Info.plist`
- `mobile/befam/lib/firebase_options.dart`

Configured backend artifacts:

- `firebase.json`
- `firebase/firestore.rules`
- `firebase/firestore.indexes.json`
- `firebase/storage.rules`
- `firebase/functions/`
- `.firebaserc`

One-time cloud provisioning status:

- Android app registered: `com.familyclanapp.befam`
- iOS app registered: `com.familyclanapp.befam`
- Cloud Firestore API enabled for `be-fam-3ab23`
- Default Firestore database created in `asia-southeast1`
- Firestore rules and indexes deployed from the repository

Prepared production CI/CD artifacts:

- `.github/workflows/deploy-firebase.yml`
- `firebase/functions/.env.example`
- GitHub environment: `production`
- GitHub environment variable: `FIREBASE_PROJECT_ID=be-fam-3ab23`
- GitHub environment variable: `FIREBASE_FUNCTIONS_REGION=asia-southeast1`
- GitHub environment variable: `APP_TIMEZONE=Asia/Ho_Chi_Minh`
- optional GitHub environment variables for billing runtime:
  `BILLING_PENDING_TIMEOUT_MINUTES`,
  `BILLING_PENDING_TIMEOUT_LIMIT`,
  `BILLING_CARD_CHECKOUT_URL_BASE`,
  `BILLING_VNPAY_FALLBACK_URL`,
  `BILLING_VNPAY_GATEWAY_BASE_URL`,
  `VNPAY_RETURN_URL`,
  `BILLING_VNPAY_IP_ADDRESS`,
  `BILLING_VNPAY_LOCALE`
- GitHub environment secret: `FIREBASE_SERVICE_ACCOUNT`
- GitHub environment secrets: `BILLING_WEBHOOK_SECRET`, `CARD_WEBHOOK_SECRET`,
  `VNPAY_TMNCODE`, `VNPAY_HASH_SECRET`
- deploy workflow also syncs non-secret runtime overrides to Firestore at
  `runtimeConfig/global` so values can be updated per deploy without code edits
- setup helper script: `scripts/setup_github_production_config.sh`
- full runbook: `docs/05-devops/production-configuration.md`

Current production blocker:

- Cloud Functions v2 deployment still requires a billing account linked to `be-fam-3ab23`
- Google APIs such as Cloud Build, Cloud Run, Artifact Registry, and Cloud Scheduler cannot be enabled until billing is attached

### iOS note

iOS builds still require the full Xcode app, not just Command Line Tools. After Xcode is
installed, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
cd mobile/befam
flutter run -d ios
```

Production release automation on `main` now also prepares an unsigned iOS
`xcarchive` asset for GitHub Releases. A signed `.ipa` will still require Apple
signing certificates, provisioning profiles, and export options in CI.

## GitHub Automation

The repository includes:

- docs validation on pull requests
- required branch CI for `staging` and `main`
- Firebase Functions TypeScript build validation in branch CI
- Firebase tooling image validation in branch CI
- Android release APK validation in branch CI
- mobile release-builder image validation in branch CI
- GitHub Pages deployment from `main`
- production Firebase deploy workflow for Firestore, Storage, and Functions
- automatic semver tagging and GitHub release publishing on `main`
- friendly release note generation from conventional commits
- Android release APK and unsigned iOS XCArchive upload to GitHub Releases
- BeFam mobile builder image publishing to GHCR at `ghcr.io/phamhungptithcm/befam-mobile-builder`
- Firebase tooling image publishing to GHCR at `ghcr.io/phamhungptithcm/befam-firebase-tools`
- weekly release promotion pull requests from `staging` to `main`
- post-release story and epic closure after production merges
- issue and pull request templates
- CODEOWNERS support for review routing
- backlog import automation from the source planning docs
- release version resolution for tag-based production delivery

Create or sync the GitHub epic/story backlog with:

```bash
python3 scripts/bootstrap_github_backlog.py --repo phamhungptithcm/gia-pha
```

Generate friendly release notes for a tagged release:

```bash
RELEASE_TAG=v0.1.0 node scripts/generate_release_notes.mjs
```

Preview the next semver release that would be cut on `main`:

```bash
node scripts/next_release_version.mjs
```

## Workflow

1. Create a short-lived branch from `staging`.
2. Make the required documentation or implementation changes.
3. Run local verification where applicable.
4. Open a pull request to `staging`.
5. Merge to `staging` after review and successful checks.
6. Use `Closes #123` keywords for completed stories so production release automation can close them later.
7. Review and approve the weekly `staging` to `main` release pull request for production.
8. After the merge lands on `main`, let release automation create the semver tag, friendly notes, the Android APK asset, the unsigned iOS XCArchive asset, and the GHCR mobile plus Firebase images.
