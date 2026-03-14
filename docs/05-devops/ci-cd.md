# CI/CD

The repository uses GitHub Actions to validate pull requests, promote approved weekly
releases, close delivered backlog items after production, and publish the MkDocs site
to GitHub Pages.

## Workflows

### `branch-ci.yml`

Runs on pull requests and pushes to `staging` and `main`.

Checks performed:

- install Python 3.12 and run `mkdocs build --strict`
- install Node.js 20 and run `npm ci && npm run build` in `firebase/functions`
- build the Firebase tooling image from `docker/firebase-tools.Dockerfile`
- install Flutter and run `flutter analyze`
- run `flutter test`
- build the Android release APK path with `flutter build apk --release`
- build the BeFam mobile release-builder image from the repository root

The `ci-docs`, `ci-functions`, and `ci-mobile` jobs are required status checks in
the branch rulesets for both protected branches.

### `docs-ci.yml`

Runs on pull requests and non-`main` pushes when any of the following change:

- `docs/**`
- `mkdocs.yml`
- `requirements-docs.txt`
- `.github/workflows/docs-ci.yml`
- `.github/workflows/deploy-docs.yml`

Checks performed:

- install Python 3.12
- install `mkdocs-material==9.*`
- run `mkdocs build --strict`

### `deploy-docs.yml`

Runs on:

- pushes to `main`
- manual `workflow_dispatch`

Deploy flow:

1. checkout repository
2. configure GitHub Pages
3. install docs dependencies
4. build the static site with `mkdocs build --strict`
5. upload the `site/` artifact
6. publish via `actions/deploy-pages`

### `deploy-firebase.yml`

Runs on:

- pushes to `main` when Firebase files change
- manual `workflow_dispatch`

Deploy flow:

1. checkout repository
2. install Node.js 20 and build `firebase/functions`
3. install `firebase-tools`
4. load the production Firebase service account from the GitHub `production` environment
5. deploy Firestore rules, Firestore indexes, Storage rules, and Cloud Functions

### `release-main.yml`

Runs on:

- pushes to `main`
- manual `workflow_dispatch`

Release flow:

1. fetch full Git history and tags
2. resolve the next semver tag from commit history, or reuse the tag already on `HEAD`
3. create the Git tag if this is a fresh production merge
4. generate friendly release notes with `scripts/generate_release_notes.mjs`
5. build the Android release APK with the computed release version
6. build and push the BeFam mobile builder image to `ghcr.io/phamhungptithcm/befam-mobile-builder`
7. build and push the Firebase tooling image to `ghcr.io/phamhungptithcm/befam-firebase-tools`
8. create or update the GitHub release and attach the APK asset

### `weekly-release-promotion.yml`

Runs on:

- weekly schedule every Monday at `14:00 UTC`
- manual `workflow_dispatch`

Release flow:

1. compare `staging` against `main`
2. create or refresh the release PR if there is anything to promote
3. enable auto-merge using a merge commit
4. wait for required approval and Branch CI checks

### `release-issue-closure.yml`

Runs after a merged pull request lands on `main`.

Post-release flow:

1. scan the release PR and included pull requests for `Closes #123` style issue links
2. comment on released story issues and close them
3. close the parent epic once all of its linked stories are closed

## Local preview

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

## GitHub requirements

- GitHub Actions must be enabled for the repository
- GitHub Pages must use GitHub Actions as its publishing source
- if the repository stays private, GitHub Pages availability depends on the account plan
- the `production` environment must define:
  - secret `FIREBASE_SERVICE_ACCOUNT`
  - variable `FIREBASE_PROJECT_ID`
  - variable `FIREBASE_FUNCTIONS_REGION`

## Firebase provisioning status

Current production Firebase project:

- project id: `be-fam-3ab23`
- default Firestore database: `(default)`
- Firestore location: `asia-southeast1`

Completed from the repository on March 13, 2026:

- enabled the Cloud Firestore API
- created the default Firestore database
- deployed Firestore rules and indexes
- prepared GitHub-based production deployment for Functions and rules

Remaining blocker:

- Cloud Functions v2 still requires project billing before the deploy workflow can enable Cloud Build, Cloud Run, Artifact Registry, Secret Manager, and Cloud Scheduler

## Future expansion

Future expansion:

- Firebase Functions linting and tests
- emulator-backed integration checks for critical paths

## Release notes automation

The repository now includes helpers for both release versioning and friendly notes:

```bash
node scripts/next_release_version.mjs
RELEASE_TAG=v0.1.0 node scripts/generate_release_notes.mjs
```

Expected environment variables:

- `RELEASE_TAG` required, for example `v0.1.0`
- `RELEASE_VERSION` optional override for the displayed version
- `RELEASE_NOTES_PATH` optional output path, defaults to `dist/release-notes.md`
- `RELEASE_PRODUCT_NAME` optional product title override

Current production automation on `main` now:

1. resolves the next semver tag
2. creates the Git tag
3. generates release notes from commit history
4. publishes a GitHub release
5. uploads the Android release APK
6. pushes the BeFam mobile builder image to GHCR
7. pushes the Firebase tooling image to GHCR
