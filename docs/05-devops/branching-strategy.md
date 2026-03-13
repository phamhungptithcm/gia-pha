# Branching Strategy

The repository uses `main` as the default protected branch and favors short-lived
topic branches.

## Branch types

- `main`: stable branch and GitHub Pages deployment source
- `codex/<slug>`: Codex-created implementation branches
- `feat/<issue-id>-<slug>`: feature delivery
- `fix/<issue-id>-<slug>`: bug fixes
- `docs/<issue-id>-<slug>`: documentation-only changes

## Rules

- branch from the latest `main`
- keep changes scoped to one issue or one closely related set of issues
- open a pull request before merge
- avoid long-lived integration branches unless the team later adds `develop`

## Example

```text
codex/docs-pages-and-backlog
docs/BOOT-010-mkdocs-setup
feat/AUTH-001-login-method-selection
fix/SEC-003-branch-admin-guard
```
