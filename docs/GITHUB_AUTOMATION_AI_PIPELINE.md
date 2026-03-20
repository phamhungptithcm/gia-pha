# GITHUB AUTOMATION AI PIPELINE
## AI-driven PR, Build, Review, and Release Workflow

_Last reviewed: March 14, 2026_

This document describes the current automation model used in this repository.

## 1. Branch model

- `staging`: development integration branch
- `main`: production release branch
- feature branches: `codex/<slug>`, `feat/<id>-<slug>`, `fix/<id>-<slug>`,
  `docs/<id>-<slug>`

All delivery changes go through pull requests.

## 2. Protected branch policy

Both `staging` and `main` require:

- pull request merge only (no direct push)
- at least one reviewer approval
- required status checks from Branch CI:
  - `ci-docs`
  - `ci-functions`
  - `ci-mobile`

## 3. Workflow inventory

### `branch-ci.yml`

Runs on PR/push for `staging` and `main`:

- strict docs build
- functions install + build
- Flutter analyze + test + Android release build
- Docker image build checks for mobile and Firebase tooling

### `docs-ci.yml`

Runs on docs changes (PR and non-main pushes) and enforces
`mkdocs build --strict`.

### `deploy-docs.yml`

Publishes MkDocs site to GitHub Pages from `main`.

### `deploy-firebase.yml`

Deploys Firestore rules/indexes, Storage rules, and Functions from `main`
using credentials from the GitHub `production` environment.

### `release-main.yml`

On `main` pushes:

- computes next semver tag
- creates tag when needed
- generates friendly release notes
- builds Android release AAB
- builds signed iOS IPA artifact
- publishes GitHub release with artifacts
- builds/pushes GHCR images:
  - `befam-mobile-builder`
  - `befam-firebase-tools`

### `weekly-release-promotion.yml`

Every Monday at 14:00 UTC (and manual dispatch):

- compares `staging` to `main`
- creates/refreshes production promotion PR
- enables auto-merge once approval + CI are satisfied

### `release-issue-closure.yml`

When a PR is merged into `main`:

- closes released stories referenced by closing keywords
- closes parent epic when all linked stories are closed

## 4. Agent workflow expectations

1. read relevant docs and issue acceptance criteria
2. create a scoped branch from `staging`
3. implement code + tests + docs updates
4. open PR to `staging` with validation details
5. use closing keywords (for example `Closes #123`) only when scope is truly complete
6. merge after approval and green CI
7. allow automated `staging` -> `main` promotion/release flow to complete

## 5. Release note automation

Scripts:

- `scripts/next_release_version.mjs`
- `scripts/generate_release_notes.mjs`

Example:

```bash
RELEASE_TAG=v0.1.0 RELEASE_PRODUCT_NAME=BeFam node scripts/generate_release_notes.mjs
```

## 6. Backlog source of truth

Planning artifacts remain in markdown and are projected into GitHub issues:

- `docs/AI_BUILD_MASTER_DOC.md`
- `docs/AI_AGENT_TASKS_150_ISSUES.md`
- `docs/GITHUB_AUTOMATION_AI_PIPELINE.md`

Importer:

```bash
python3 scripts/bootstrap_github_backlog.py --repo phamhungptithcm/gia-pha
```
