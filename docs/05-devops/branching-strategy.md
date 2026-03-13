# Branching Strategy

The repository uses `staging` for day-to-day development and `main` for production
releases.

## Branch types

- `staging`: default development branch and integration branch
- `main`: protected production branch and GitHub Pages deployment source
- `codex/<slug>`: Codex-created implementation branches
- `feat/<issue-id>-<slug>`: feature delivery
- `fix/<issue-id>-<slug>`: bug fixes
- `docs/<issue-id>-<slug>`: documentation-only changes

## Rules

- branch from the latest `staging`
- keep changes scoped to one issue or one closely related set of issues
- open a pull request to `staging` before merge
- require one approval and passing Branch CI before merge to `staging` or `main`
- promote `staging` to `main` through the weekly release PR
- use merge commits for the `staging` to `main` promotion so release history stays aligned

## Example

```text
codex/docs-pages-and-backlog
docs/BOOT-010-mkdocs-setup
feat/AUTH-001-login-method-selection
fix/SEC-003-branch-admin-guard
```
