# GITHUB AUTOMATION AI PIPELINE
## AI-driven PR, Build, Review, and Deploy Workflow

This document defines how the repository should support AI agents working with GitHub.

## 1. Goals

- allow AI agents to work from issues and docs
- enforce safe automation boundaries
- provide repeatable CI/CD
- keep human reviewer in control of merge and production deploy

## 2. Repository Automation Components

Recommended GitHub setup:
- GitHub Actions
- issue templates
- pull request template
- CODEOWNERS
- branch protection
- labels
- project board
- optional release workflow

## 3. Branch Strategy

Branches:
- `main` for protected production-ready code
- `develop` optional if team wants integration branch, but simpler setup can use only `main`
- feature branches:
  - `feat/<issue-id>-<slug>`
  - `fix/<issue-id>-<slug>`
  - `docs/<issue-id>-<slug>`

Recommendation:
- use trunk-based with short-lived branches
- require PR for all changes

## 4. AI Agent Workflow

### Step 1 - Intake
AI agent reads:
- `docs/AI_BUILD_MASTER_DOC.md`
- linked design docs
- issue acceptance criteria

### Step 2 - Branch creation
Agent creates branch from latest protected base.

### Step 3 - Implementation
Agent:
- writes code
- updates tests
- updates relevant docs if contract changes

### Step 4 - PR creation
PR must contain:
- scope summary
- issue link
- acceptance checklist
- testing notes
- screenshots if UI changed

### Step 5 - CI
GitHub Actions runs:
- Flutter format or lint checks
- `flutter analyze`
- `flutter test`
- optional emulator/integration tests
- docs build
- Firebase functions tests

### Step 6 - Human review
Reviewer checks:
- correctness
- security
- architecture fit
- user experience

### Step 7 - Merge and deploy
After approval and green CI:
- merge to protected branch
- deploy staging automatically
- deploy production by manual approval

## 5. Suggested GitHub Issue Templates

Templates:
- feature
- bug
- technical task
- documentation
- security review

Feature issue fields:
- problem
- user story
- scope
- acceptance criteria
- technical notes
- out of scope

## 6. Suggested Pull Request Template

PR sections:
- Summary
- Linked issue
- What changed
- Why
- Screenshots / demo
- Test plan
- Risks
- Rollback notes
- Checklist

## 7. CODEOWNERS Strategy

Use CODEOWNERS to route review.

Example:
```text
/docs/ @product-owner
/mobile/flutter_app/lib/features/auth/ @mobile-owner
/mobile/flutter_app/lib/features/genealogy/ @mobile-owner
/firebase/functions/ @backend-owner
```

## 8. Branch Protection Rules

Protect `main`:
- no direct pushes
- require PR
- require status checks
- require at least 1 approval
- dismiss stale approvals on new commits
- require conversation resolution

## 9. Labels

Recommended labels:
- epic
- story
- task
- bug
- docs
- security
- flutter
- firebase
- genealogy
- notifications
- funds
- scholarship
- performance
- ai-agent

## 10. GitHub Actions Workflows

### 10.1 mobile-ci.yml
Runs on PRs affecting Flutter code.

Steps:
- checkout
- setup Flutter
- get dependencies
- format check
- analyze
- unit tests
- build apk or ios-no-codesign where feasible

### 10.2 functions-ci.yml
Runs on PRs affecting Cloud Functions.

Steps:
- setup node
- install deps
- lint
- unit tests
- emulator tests optional

### 10.3 docs-ci.yml
Runs on docs changes.

Steps:
- install Python + MkDocs Material
- build docs
- fail on broken nav / invalid markdown if lint added

### 10.4 deploy-docs.yml
Runs on merge to main.
Steps:
- build MkDocs
- deploy GitHub Pages

### 10.5 deploy-staging.yml
Optional on main or release branch.
Steps:
- build app artifacts
- deploy Firebase staging functions/rules

### 10.6 deploy-production.yml
Manual workflow dispatch with approval.
Steps:
- confirm tag or commit
- deploy prod functions/rules
- create release notes

## 11. AI-Specific Guardrails

AI agents should:
- never merge without human approval
- never alter secrets
- never deploy to prod automatically without protected approval
- never bypass failing tests
- always update docs when schema/contracts change

## 12. Suggested Project Board Columns

- Backlog
- Ready
- In Progress
- In Review
- Needs Revision
- Done

Automation:
- issue opened -> Backlog
- PR opened -> In Review
- merged PR -> Done

## 13. Commit Message Convention

Use conventional commits:
- `feat(auth): implement phone otp verification`
- `fix(tree): prevent duplicate spouse edges`
- `docs(schema): add scholarship collections`

## 14. Release Strategy

- semantic versioning recommended
- internal beta first
- use tags for release candidates
- maintain changelog

## 15. Example Automation Policy for AI Agent

An AI agent may:
- pick a Ready issue
- create feature branch
- implement scoped changes
- open PR
- request review

An AI agent may not:
- self-approve
- merge protected branch
- deploy production without explicit human approval

## 16. Required Repository Files

Suggested:
```text
.github/
  ISSUE_TEMPLATE/
    feature.yml
    bug.yml
    docs.yml
  workflows/
    mobile-ci.yml
    functions-ci.yml
    docs-ci.yml
    deploy-docs.yml
  pull_request_template.md
  CODEOWNERS
```

## 17. Human Reviewer Checklist

- issue scope respected
- access control unchanged or improved
- tests are meaningful
- docs updated
- no hidden schema changes
- no hardcoded secrets
