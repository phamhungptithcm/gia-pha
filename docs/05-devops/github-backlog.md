# GitHub Backlog

This repository keeps planning in markdown and mirrors delivery work into GitHub
issues.

## Source documents

- `AI_BUILD_MASTER_DOC.md`
- `AI_AGENT_TASKS_150_ISSUES.md`
- `GITHUB_AUTOMATION_AI_PIPELINE.md`

## Backlog structure

- epics become GitHub issues labeled `epic`
- stories become GitHub issues labeled `story`
- epic issues are updated with checklists that link to their child stories
- domain labels such as `flutter`, `firebase`, `genealogy`, and `funds` help filter work

## Bootstrap command

Run the importer after cloning the repository and authenticating with GitHub CLI:

```bash
python3 scripts/bootstrap_github_backlog.py --repo phamhungptithcm/gia-pha
```

Useful flags:

- `--dry-run` prints the actions without creating issues
- `--limit 10` creates only the first 10 stories for testing

## Current epic groups

- Project Bootstrap
- Authentication
- Clan Management
- Member Profiles
- Relationship Management
- Genealogy Read Model
- Genealogy UI
- Events
- Notifications
- Funds
- Scholarship Programs
- Search and Discovery
- Profile and Settings
- Permissions and Security
- Cloud Functions Integration
- Observability and Analytics
- Release Hardening
