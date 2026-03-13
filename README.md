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
- `mobile/flutter_app/`: Flutter application scaffold for local iOS and Android development
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

## Flutter Development

The repository includes a local Flutter app scaffold at `mobile/flutter_app`.

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
cd mobile/flutter_app
flutter run
```

### iOS note

iOS builds still require the full Xcode app, not just Command Line Tools. After Xcode is
installed, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
cd mobile/flutter_app
pod install --project-directory=ios
flutter run -d ios
```

## GitHub Automation

The repository includes:

- docs validation on pull requests
- GitHub Pages deployment from `main`
- issue and pull request templates
- CODEOWNERS support for review routing
- backlog import automation from the source planning docs
- a release notes generator for future tag-based release automation

Create or sync the GitHub epic/story backlog with:

```bash
python3 scripts/bootstrap_github_backlog.py --repo phamhungptithcm/gia-pha
```

Generate friendly release notes for a tagged release:

```bash
RELEASE_TAG=v0.1.0 node scripts/generate_release_notes.mjs
```

## Workflow

1. Create a short-lived branch from `main`.
2. Make the required documentation or implementation changes.
3. Run local verification where applicable.
4. Open a pull request.
5. Merge to `main` after review and successful checks.
