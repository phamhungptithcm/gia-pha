# GitHub Workflow

This repository follows a `staging` to `main` delivery model with GitHub-managed
reviews, CI, and release promotion.

## Delivery loop

1. start from `staging`
2. create a short-lived branch
3. implement changes
4. run local verification
5. open a pull request to `staging`
6. let GitHub Actions validate docs and code
7. merge to `staging` after approval
8. let the weekly release workflow open the `staging` to `main` production PR
9. approve the release PR and let auto-merge finish the production promotion
10. publish docs from `main`, deploy Firebase production changes, and close released stories and epics

## Pull request checklist

- explain scope clearly
- link the related story with a closing keyword such as `Closes #123`
- note testing performed
- call out schema or contract changes
- include screenshots when UI content changes

## Repository scaffolding

The GitHub setup includes:

- issue templates for epic, story, docs, bug, and technical task intake
- a pull request template
- CODEOWNERS for review routing
- labels for epics, stories, domains, and agent-driven work
- a backlog bootstrap script that creates GitHub issues from the source planning doc
- a production Firebase deployment workflow that reads credentials from the `production` environment

## Backlog source of truth

Planning starts from:

- `AI_BUILD_MASTER_DOC.md`
- `AI_AGENT_TASKS_150_ISSUES.md`
- `GITHUB_AUTOMATION_AI_PIPELINE.md`

Use `scripts/bootstrap_github_backlog.py` to project those planning artifacts into
GitHub issues without losing the original markdown source.
