# CI/CD

_Last reviewed: April 2, 2026_

BeFam uses a protected promotion model:

- `staging` for integration
- `main` for production releases

## Workflow Summary

### `branch-ci.yml` (`CI - Branch Quality Gates`)
Runs on:
- pushes to every branch

Checks:
- docs build and rules-doc validation
- Functions install/build/test
- Flutter analyze/test
- Android release build verification
- dependency review + Trivy + gitleaks + image vulnerability scanning

### `mobile-e2e.yml` + `mobile-e2e-ios.yml`
Run Android/iOS smoke E2E on pushes to every branch, plus manual dispatch.
The jobs self-skip when the push does not touch mobile or E2E-related files.

### `mobile-e2e-deep.yml` (`CI - Mobile E2E Deep`)
Runs the full deep mobile regression suite on pushes to `staging` and `main`, plus manual dispatch.

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
Builds release-ready artifacts, signs mobile binaries, publishes immutable release assets, checksums, and the release manifest.
Branch guard: main only.

### `deploy-firebase.yml` (`CD - Deploy Firebase (Production)`)
Manual `workflow_dispatch` that promotes a selected `release-main` tag to production Firestore rules, indexes, Storage rules, and Functions.
Also writes runtime `.env.<projectId>` and syncs non-secret runtime overrides.
Input guard: `release_tag` must point to a GitHub Release produced from `main`.

### `deploy-web-hosting.yml` (`CD - Deploy Web Hosting (Production)`)
Manual `workflow_dispatch` that promotes the immutable web bundle attached to a selected `release-main` tag.
Input guard: `release_tag` must point to a GitHub Release produced from `main`.

### `rollback-production.yml` (`CD - Rollback Production`)
Restores production Firebase/Hosting to a selected release tag.

### `promote-staging-to-main.yml` (`Ops - Promote Staging to Main`)
Creates or refreshes the `staging -> main` promotion PR whenever new commits land on `staging`.

### `release-issue-closure.yml` (`Ops - Close Released Issues`)
Closes linked delivered issues after release PR merge to `main`.

## Production Environment Keys

Required vars:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_FUNCTIONS_REGION`
- `APP_TIMEZONE`
- `BEFAM_ADMOB_ANDROID_APP_ID`
- `BEFAM_ADMOB_IOS_APP_ID`
- `BEFAM_ADMOB_ANDROID_BANNER_UNIT_ID`
- `BEFAM_ADMOB_ANDROID_INTERSTITIAL_UNIT_ID`
- `BEFAM_ADMOB_ANDROID_REWARDED_UNIT_ID`
- `BEFAM_ADMOB_IOS_BANNER_UNIT_ID`
- `BEFAM_ADMOB_IOS_INTERSTITIAL_UNIT_ID`
- `BEFAM_ADMOB_IOS_REWARDED_UNIT_ID`

Required production secrets:
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT_EMAIL`
- `BILLING_WEBHOOK_SECRET`
- `VNPAY_TMNCODE`
- `VNPAY_HASH_SECRET`

Staging migration fallback (optional, staging only):
- `FIREBASE_SERVICE_ACCOUNT`
- `CARD_WEBHOOK_SECRET`
