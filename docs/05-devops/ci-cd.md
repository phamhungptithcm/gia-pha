# CI/CD

The repository uses GitHub Actions to validate pull requests, promote approved weekly
releases, close delivered backlog items after production, and publish the MkDocs site
to GitHub Pages.

## Workflows

### `branch-ci.yml`

Runs on pull requests and pushes to `staging` and `main`.

Checks performed:

- install Python 3.12 and run `mkdocs build --strict`
- install Flutter and run `flutter analyze`
- run `flutter test`

The `ci-docs` and `ci-mobile` jobs are required status checks in the branch rulesets
for both protected branches.

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

## Future expansion

Future expansion:

- Firebase Functions linting and tests
- emulator-backed integration checks for critical paths

## Release notes automation

The repository now includes a helper script for friendly release notes:

```bash
RELEASE_TAG=v0.1.0 node scripts/generate_release_notes.mjs
```

Expected environment variables:

- `RELEASE_TAG` required, for example `v0.1.0`
- `RELEASE_VERSION` optional override for the displayed version
- `RELEASE_NOTES_PATH` optional output path, defaults to `dist/release-notes.md`
- `RELEASE_PRODUCT_NAME` optional product title override

This is intended for future release CI/CD flows that:

1. bump the app version
2. create a Git tag
3. generate release notes from commit history
4. attach those notes to the GitHub release and app store delivery step
