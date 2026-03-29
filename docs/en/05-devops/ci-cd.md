# CI/CD

_Last reviewed: March 28, 2026_

BeFam uses a protected promotion model:

- `staging` for integration
- `main` for production releases

## Workflow Summary

### `branch-ci.yml` (`CI - Branch Quality Gates`)
Runs on:
- pull requests targeting `staging` or `main`
- pushes to all branches except `main` (including feature/dev branches and `staging`)

Checks:
- docs build and rules-doc validation
- Functions install/build/test
- Flutter analyze/test
- Android release build verification
- dependency review + Trivy + gitleaks + image vulnerability scanning

### `mobile-e2e.yml` (`CI - Mobile E2E (PR/Manual)`)
Runs Android + iOS E2E for mobile-focused pull requests and manual dispatch.

### `deploy-docs.yml` (`CD - Deploy Docs (GitHub Pages)`)
Builds and publishes MkDocs to GitHub Pages.

### `deploy-staging.yml` (`CD - Deploy Staging`)
Deploys Firebase resources and web hosting to the staging environment.
Branch guard: staging only.

### `release-staging.yml` (`CD - Release Staging (Manual)`)
Manual `workflow_dispatch` to build signed staging mobile artifacts for store testing:
- Android AAB
- iOS IPA

This workflow does not create a release tag and does not publish a GitHub Release.

### `release-main.yml` (`CD - Release Main`)
Builds release artifacts, signs mobile binaries, publishes immutable release assets, checksums, and release manifest.
Branch guard: main only.

### `deploy-firebase.yml` (`CD - Deploy Firebase (Production)`)
Builds/deploys Firestore rules, indexes, storage rules, and Functions.
Also writes runtime `.env.<projectId>` and syncs non-secret runtime overrides.
Branch guard: main only.

### `deploy-web-hosting.yml` (`CD - Deploy Web Hosting (Production)`)
Deploys production hosting from the immutable web bundle attached to the release.
Branch guard: main only.

### `rollback-production.yml` (`CD - Rollback Production`)
Restores production Firebase/Hosting to a selected release tag.

### `weekly-release-promotion.yml` (`Ops - Promote Staging to Main`)
Auto-prepares `staging -> main` release PR weekly.

### `release-issue-closure.yml` (`Ops - Close Released Issues`)
Closes linked delivered issues after release PR merge to `main`.

## Production Environment Keys

Required vars:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`

Required production secrets:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Staging migration fallback (optional, staging only):
- `FIREBASE_SERVICE_ACCOUNT`
- `CARD_WEBHOOK_SECRET`
