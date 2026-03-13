# GitHub Workflow

This repository follows a docs-first workflow that is ready to scale into app and
backend delivery.

## Delivery loop

1. start from `main`
2. create a short-lived branch
3. implement changes
4. run local verification
5. open a pull request
6. let GitHub Actions validate docs and code
7. merge to `main`
8. publish docs from `main`

## Pull request checklist

- explain scope clearly
- link the related issue or epic
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

## Backlog source of truth

Planning starts from:

- `AI_BUILD_MASTER_DOC.md`
- `AI_AGENT_TASKS_150_ISSUES.md`
- `GITHUB_AUTOMATION_AI_PIPELINE.md`

Use `scripts/bootstrap_github_backlog.py` to project those planning artifacts into
GitHub issues without losing the original markdown source.
