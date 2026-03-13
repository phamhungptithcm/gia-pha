# Gia Pha

Planning and delivery repository for the Family Clan App documentation set.

## Local docs preview

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-docs.txt
mkdocs serve
```

## GitHub Pages

The repository publishes the MkDocs site through GitHub Actions using the workflow in
`.github/workflows/deploy-docs.yml`.

## GitHub backlog bootstrap

```bash
python3 scripts/bootstrap_github_backlog.py --repo phamhungptithcm/gia-pha
```

The script reads `AI_AGENT_TASKS_150_ISSUES.md` and creates epics plus story issues in
GitHub with consistent labels.
