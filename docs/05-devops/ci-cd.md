# CI/CD

The repository uses GitHub Actions to validate documentation changes and publish the
MkDocs site to GitHub Pages.

## Workflows

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

When application code is added, extend CI with:

- Flutter formatting, analysis, and tests
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
