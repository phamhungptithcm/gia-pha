# CI/CD Production Hardening

This document describes the production-safe CI/CD model used by BeFam.

## Release Branch Model

- `staging`: integration branch, used for pre-production validation.
- `main`: release-ready branch used to produce the candidate that can be promoted to production.
- Promotion path: `staging -> main` via pull request only.

## Required Protection Policies

For both `staging` and `main` rulesets:

- Pull request required (no direct pushes).
- At least 1 approval.
- Code owner review required.
- Last push approval required.
- Conversation resolution required.
- Required status checks:
  - `ci-docs`
  - `ci-functions`
  - `ci-mobile`
  - `security-dependency-review`
  - `security-trivy-fs`
  - `security-gitleaks`
  - `security-trivy-images`
- Commit signatures required.
- No bypass actors.

## Environment Protection

- `production` environment:
  - Branch policy: `main` only.
  - Required reviewer enabled.
  - Prevent self-review enabled.
  - Admin bypass disabled.
- `staging` environment:
  - Branch policy: `staging` only.
  - Admin bypass disabled.

## Workflow Order

### 1) PR/Branch Quality Gates

- `CI - Branch Quality Gates`: docs, functions, mobile checks,
  dependency review, Trivy (filesystem + images), and gitleaks.

### 2) Production Release

`CD - Release Main` workflow:

1. Quality gates run first.
2. Production preflight validates required secrets and Firestore billing config.
3. Release version/tag prepared.
4. Android, iOS, and Web release artifacts are built.
5. Manifest and checksum files are generated.
6. Build provenance attestations are generated.
7. GitHub Release is published with all assets.

### 3) Production Deployment

1. `CD - Release Main` publishes the immutable release tag and assets.
2. `CD - Deploy Firebase (Production)` is triggered manually with the selected `release_tag`.
3. `CD - Deploy Web Hosting (Production)` is triggered manually with the same `release_tag` after Firebase deploy is verified.

This keeps release creation and production promotion decoupled, reviewable, and rollback-friendly.

## Rollback

Use `CD - Rollback Production` workflow with:

- `release_tag`: target release tag.
- `deploy_target`: `all`, `firebase`, or `web`.

Rollback uses the selected immutable release (tag + web bundle asset).

## Identity & Secrets

### Production (enforced)

Production deploy and rollback are OIDC-only:

- `GCP_WORKLOAD_IDENTITY_PROVIDER` (secret)
- `GCP_SERVICE_ACCOUNT_EMAIL` (secret)

Legacy `FIREBASE_SERVICE_ACCOUNT` key fallback is removed from production workflows.

### Staging

`CD - Deploy Staging` still supports fallback JSON key mode during migration.

## Traceability & Reproducibility

Each release includes:

- versioned Android/iOS/Web artifacts,
- `release-manifest-<version>.json`,
- `checksums-<version>.txt`,
- provenance attestations.

This gives auditable and reproducible deployments per release.
