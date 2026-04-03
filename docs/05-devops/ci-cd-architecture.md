# CI/CD Architecture

_Last reviewed: April 2, 2026_

This page captures the current BeFam delivery architecture as implemented in
GitHub Actions.

Core model:

- `staging` is the integration lane and auto-deploys backend plus web.
- `main` is the release lane and produces immutable production artifacts.
- staging OTP uses Firebase.
- production OTP uses Twilio.

## Leadership View

![BeFam CI/CD leadership diagram](../assets/diagrams/ci-cd-leadership.svg)

Slide assets:

- [PNG](../assets/diagrams/ci-cd-leadership.png)
- [SVG](../assets/diagrams/ci-cd-leadership.svg)

## Executive Summary

The delivery system is a promotion pipeline rather than direct-to-production
deployment.

1. Pushes to `staging` and `main` run branch CI and mobile smoke E2E.
2. Pushes to `staging` wait for checks, then deploy to the staging Firebase
   project and staging web hosting.
3. A separate promotion workflow opens or refreshes the `staging -> main`
   release PR.
4. Merges to `main` run an explicit production release workflow that:
   - re-validates quality gates,
   - performs production preflight checks,
   - creates the release tag `vYYYY.MM.DD`,
   - builds signed Android and iOS artifacts,
   - builds the immutable web bundle,
   - publishes release assets and provenance.
5. Production backend deploy and production hosting deploy happen in downstream
   `workflow_run` workflows after the main release succeeds.

## Environment Model

| Environment | Source branch | Deploy mode | OTP provider | Main outputs |
| --- | --- | --- | --- | --- |
| Staging | `staging` | Auto deploy | Firebase | Functions, rules, indexes, storage, staging web |
| Production | `main` | Release then deploy | Twilio | Signed AAB, signed IPA, web bundle, GitHub Release, backend deploy, hosting deploy |

## Current Workflow Map

### Release-branch validation

- `branch-ci.yml`
  - docs validation and build
  - Functions install, build, dead-code gate, tests
  - Flutter analyze, tests, coverage, web smoke
- `mobile-e2e.yml`
  - Android smoke E2E
- `mobile-e2e-ios.yml`
  - iOS smoke E2E
- `mobile-e2e-deep.yml`
  - deeper full-suite mobile regression on `staging` and `main`

### Staging delivery

- `deploy-staging.yml`
  - waits for CI, security, Android E2E, and iOS E2E
  - deploys staging Firebase backend
  - deploys staging web hosting
  - enforces `BEFAM_OTP_PROVIDER=firebase`
- `promote-staging-to-main.yml`
  - creates or refreshes the release PR from `staging` to `main`

### Production release and deploy

- `release-main.yml`
  - waits for upstream checks
  - re-runs quality gates
  - validates production config and signing material
  - cuts release tag `vYYYY.MM.DD`
  - builds Android AAB, iOS IPA, and web release bundle
  - publishes GitHub Release, checksums, manifest, attestations, and GHCR images
- `deploy-firebase.yml`
  - triggered by successful `release-main.yml`
  - deploys production Firebase backend
  - enforces `OTP_PROVIDER=twilio`
- `deploy-web-hosting.yml`
  - triggered by successful production Firebase deploy
  - downloads immutable web bundle from GitHub Release
  - deploys production hosting

### Manual operations

- `release-staging.yml`
  - manual signed staging Android/iOS artifact build
- `rollback-production.yml`
  - manual rollback of production Firebase and/or Hosting to a selected tag
- `deploy-docs.yml`
  - deploys docs site from `main`

## High-Level Design

```mermaid
flowchart LR
  Dev["Developer"] --> StagePush["Push to staging"]
  StagePush --> Checks["CI + Security + Mobile E2E"]
  Checks --> Staging["Staging Deploy
  Firebase backend + Web
  OTP = Firebase"]
  Staging --> Promote["Open PR: staging -> main"]
  Promote --> MainMerge["Merge to main"]
  MainMerge --> Release["Release Build
  Tag: BeFam vYYYY.MM.DD
  Android + iOS + Web artifacts"]
  Release --> Prod["Production Deploy
  Backend then Hosting
  OTP = Twilio"]
  Prod --> Users["Production Users"]
```

## Engineer View

```mermaid
flowchart TD
  Dev["Developer"] --> Push["Git push to staging/main"]

  Push --> BranchCI["branch-ci.yml
  docs
  functions build/test
  mobile analyze/test/web smoke"]
  Push --> AndroidE2E["mobile-e2e.yml
  Android smoke E2E"]
  Push --> IosE2E["mobile-e2e-ios.yml
  iOS smoke E2E"]
  Push --> DeepE2E["mobile-e2e-deep.yml
  deep E2E on staging/main"]

  Push -->|"staging branch"| StageGate["deploy-staging.yml
  wait for CI + security + E2E"]
  StageGate --> StageFirebase["Deploy staging Firebase
  rules/indexes/storage/functions
  runtime OTP_PROVIDER=firebase"]
  StageFirebase --> StageWeb["Build + deploy staging web
  BEFAM_OTP_PROVIDER=firebase
  full BEFAM_FIREBASE_* config"]

  Push -->|"staging branch"| Promote["promote-staging-to-main.yml
  create/update PR to main"]

  Push -->|"main branch"| MainGate["release-main.yml
  wait for CI + security + E2E"]
  MainGate --> Quality["quality gates
  docs/functions/security/mobile/android e2e"]
  Quality --> Preflight["production preflight
  secrets vars signing catalog"]
  Preflight --> Prepare["prepare-release
  create tag + notes"]
  Prepare --> AndroidRel["signed Android AAB
  OTP=twilio"]
  Prepare --> IosRel["signed iOS IPA
  OTP=twilio"]
  Prepare --> WebRel["web release bundle
  OTP=twilio"]
  Prepare --> Images["publish GHCR images"]

  AndroidRel --> GHRelease["publish-github-release
  assets + checksums + provenance"]
  IosRel --> GHRelease
  WebRel --> GHRelease
  Images --> GHRelease

  GHRelease --> ProdFirebase["deploy-firebase.yml
  workflow_run from release-main
  deploy production backend
  OTP_PROVIDER=twilio"]
  ProdFirebase --> ProdHosting["deploy-web-hosting.yml
  workflow_run from deploy-firebase
  download immutable web bundle
  deploy Firebase Hosting"]

  Manual["Manual ops"] --> StageArtifacts["release-staging.yml
  signed staging Android/iOS artifacts"]
  Manual --> Rollback["rollback-production.yml
  redeploy backend and/or hosting by tag"]
```

## Sequence Diagram

```mermaid
sequenceDiagram
  autonumber
  participant Dev as Developer
  participant GH as GitHub
  participant CI as Branch CI
  participant AE2E as Android E2E
  participant IE2E as iOS E2E
  participant ST as Staging Deploy
  participant PR as Promote PR
  participant RM as Release Main
  participant REL as GitHub Release
  participant PF as Prod Firebase Deploy
  participant PH as Prod Hosting Deploy
  participant FB as Firebase/GCP

  Dev->>GH: Push commit to staging/main

  GH->>CI: Trigger branch-ci.yml
  GH->>AE2E: Trigger mobile-e2e.yml
  GH->>IE2E: Trigger mobile-e2e-ios.yml

  alt Branch is staging
    GH->>ST: Trigger deploy-staging.yml
    ST->>GH: Wait for CI + security + E2E checks
    CI-->>ST: success
    AE2E-->>ST: success
    IE2E-->>ST: success
    ST->>FB: Deploy staging backend
    ST->>FB: Deploy staging hosting
    Note over ST,FB: Staging OTP flow uses Firebase
    GH->>PR: Trigger promote-staging-to-main.yml
    PR-->>GH: Create or refresh PR to main
  else Branch is main
    GH->>RM: Trigger release-main.yml
    RM->>GH: Wait for CI + security + E2E checks
    CI-->>RM: success
    AE2E-->>RM: success
    IE2E-->>RM: success
    RM->>RM: Re-run quality gates and preflight
    RM->>REL: Create tag, release notes, artifacts
    Note over RM,REL: Release build enforces Twilio for production
    GH->>PF: Trigger deploy-firebase.yml via workflow_run
    PF->>FB: Deploy production backend
    Note over PF,FB: Production runtime OTP uses Twilio
    FB-->>PF: success
    GH->>PH: Trigger deploy-web-hosting.yml via workflow_run
    PH->>REL: Download immutable web bundle
    PH->>FB: Deploy production hosting
  end

  opt Manual staging artifact build
    Dev->>GH: Dispatch release-staging.yml
    GH->>ST: Build signed staging mobile artifacts
  end

  opt Manual rollback
    Dev->>GH: Dispatch rollback-production.yml
    GH->>FB: Roll back backend and/or hosting by release tag
  end
```

## Operational Notes

- Current mobile store submission is still outside the automated production
  path. The pipeline builds signed artifacts and publishes them to GitHub
  Release, but does not currently submit them to Play Store or App Store.
- Production hosting deploy is artifact-based. It downloads the immutable web
  bundle from the GitHub Release instead of rebuilding from source.
- Staging and production both now fail closed on bundled Firebase fallback in
  release/deploy paths.
- Mobile E2E automation still uses Firebase OTP test flows for CI stability,
  even when validating `main` commits before production release.

## Source Workflows

- `.github/workflows/branch-ci.yml`
- `.github/workflows/mobile-e2e.yml`
- `.github/workflows/mobile-e2e-ios.yml`
- `.github/workflows/mobile-e2e-deep.yml`
- `.github/workflows/deploy-staging.yml`
- `.github/workflows/promote-staging-to-main.yml`
- `.github/workflows/release-main.yml`
- `.github/workflows/deploy-firebase.yml`
- `.github/workflows/deploy-web-hosting.yml`
- `.github/workflows/release-staging.yml`
- `.github/workflows/rollback-production.yml`
