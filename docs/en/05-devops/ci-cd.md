# CI/CD

_Last reviewed: March 17, 2026_

BeFam uses a protected promotion model:

- `staging` for integration
- `main` for production releases

## Workflow Summary

### `branch-ci.yml`
Runs on PR/push for `staging` and `main`.

Checks:
- docs build and rules-doc validation
- Functions install/build/test
- Flutter analyze/test
- Android release build verification

### `docs-ci.yml`
Runs for docs/rules changes and ensures docs remain strict-build clean.

### `deploy-docs.yml`
Builds and publishes MkDocs to GitHub Pages.

### `deploy-firebase.yml`
Builds/deploys Firestore rules, indexes, storage rules, and Functions.
Also writes runtime `.env.<projectId>` and syncs non-secret runtime overrides.

### `release-main.yml`
Builds release artifacts and publishes semver-tagged release outputs.

### `weekly-release-promotion.yml`
Auto-prepares `staging -> main` release PR weekly.

### `release-issue-closure.yml`
Closes linked delivered issues after release PR merge to `main`.

## Production Environment Keys

Required vars:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`

Required secrets:
- `FIREBASE_SERVICE_ACCOUNT`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Optional secret:
- `CARD_WEBHOOK_SECRET`
