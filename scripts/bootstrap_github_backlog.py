#!/usr/bin/env python3
"""Create GitHub epics and stories from the markdown backlog."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path


EPIC_RE = re.compile(r"^## EPIC (\d+) - (.+)$")
STORY_RE = re.compile(r"^### \d+\.\s+([A-Z0-9-]+)\s+(.+)$")
GOAL_RE = re.compile(r"^Goal:\s*(.+)$")
ACCEPTANCE_RE = re.compile(r"^Acceptance:\s*(.+)$")


LABELS = {
    "epic": ("5319E7", "Top-level delivery slice"),
    "story": ("1D76DB", "User-facing implementation story"),
    "task": ("0E8A16", "Technical delivery task"),
    "bug": ("D73A49", "Something is not working"),
    "docs": ("0366D6", "Documentation work"),
    "security": ("B60205", "Security-related work"),
    "flutter": ("02569B", "Flutter mobile work"),
    "firebase": ("FFCA28", "Firebase or Cloud Functions work"),
    "genealogy": ("7F52FF", "Family tree and relationship domain"),
    "notifications": ("FB8C00", "Notifications and reminders"),
    "funds": ("2DA44E", "Fund and ledger features"),
    "scholarship": ("8B5CF6", "Scholarship program features"),
    "performance": ("C2410C", "Performance and observability"),
    "ai-agent": ("6F42C1", "AI-friendly workflow or issue"),
    "release": ("A371F7", "Release hardening work"),
}


PREFIX_LABELS = {
    "BOOT": ["docs", "ai-agent"],
    "AUTH": ["flutter", "firebase"],
    "CLAN": ["flutter"],
    "MEMBER": ["flutter"],
    "REL": ["genealogy"],
    "TREE": ["genealogy"],
    "TREEUI": ["genealogy", "flutter"],
    "EVENT": ["flutter", "notifications"],
    "NOTIF": ["notifications", "firebase"],
    "FUND": ["funds"],
    "SCH": ["scholarship"],
    "SEARCH": ["flutter"],
    "PROF": ["flutter"],
    "SEC": ["security", "firebase"],
    "CF": ["firebase"],
    "OPS": ["performance"],
    "REL-RELEASE": ["release"],
}


@dataclass
class Story:
    story_id: str
    title: str
    goal: str = ""
    acceptance: str = ""
    epic_number: int = 0
    epic_title: str = ""


@dataclass
class Epic:
    number: int
    title: str
    stories: list[Story] = field(default_factory=list)


def run(cmd: list[str], *, capture: bool = True) -> str:
    result = subprocess.run(
        cmd,
        check=True,
        text=True,
        capture_output=capture,
    )
    return result.stdout if capture else ""


def gh(cmd: list[str], *, capture: bool = True) -> str:
    return run(["gh", *cmd], capture=capture)


def parse_backlog(path: Path) -> list[Epic]:
    epics: list[Epic] = []
    current_epic: Epic | None = None
    current_story: Story | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        epic_match = EPIC_RE.match(line)
        if epic_match:
            current_epic = Epic(number=int(epic_match.group(1)), title=epic_match.group(2))
            epics.append(current_epic)
            current_story = None
            continue

        story_match = STORY_RE.match(line)
        if story_match and current_epic is not None:
            current_story = Story(
                story_id=story_match.group(1),
                title=story_match.group(2),
                epic_number=current_epic.number,
                epic_title=current_epic.title,
            )
            current_epic.stories.append(current_story)
            continue

        if current_story is None:
            continue

        goal_match = GOAL_RE.match(line)
        if goal_match:
            current_story.goal = goal_match.group(1)
            continue

        acceptance_match = ACCEPTANCE_RE.match(line)
        if acceptance_match:
            current_story.acceptance = acceptance_match.group(1)

    return epics


def default_repo() -> str:
    return gh(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]).strip()


def load_existing_issues(repo: str) -> dict[str, dict[str, str | int]]:
    payload = gh(
        [
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "all",
            "--limit",
            "500",
            "--json",
            "number,title,url",
        ]
    )
    issues = json.loads(payload)
    return {issue["title"]: issue for issue in issues}


def ensure_labels(repo: str, dry_run: bool) -> None:
    for name, (color, description) in LABELS.items():
        cmd = [
            "label",
            "create",
            name,
            "--repo",
            repo,
            "--color",
            color,
            "--description",
            description,
            "--force",
        ]
        if dry_run:
            print("DRY RUN:", " ".join(["gh", *cmd]))
            continue
        gh(cmd, capture=False)


def labels_for_story(story: Story) -> list[str]:
    labels = ["story"]
    for prefix, extra_labels in PREFIX_LABELS.items():
        if story.story_id.startswith(prefix):
            labels.extend(extra_labels)
            break
    return sorted(set(labels))


def labels_for_epic(epic: Epic) -> list[str]:
    labels = ["epic", "ai-agent"]
    if epic.stories:
        labels.extend(labels_for_story(epic.stories[0]))
    return sorted(set(label for label in labels if label != "story"))


def issue_body_for_epic(epic: Epic, story_refs: list[str] | None = None) -> str:
    story_lines = story_refs or ["- [ ] Stories will be linked after import"]
    lines = [
        "## Scope",
        "",
        f"Backlog epic generated from `docs/AI_AGENT_TASKS_150_ISSUES.md` for **{epic.title}**.",
        "",
        "## Success criteria",
        "",
        "- Stories in this epic are created, linked, and tracked in GitHub",
        "- Supporting documentation remains aligned with implementation",
        "- Pull requests reference the correct story or epic",
        "",
        "## Story checklist",
        "",
        *story_lines,
        "",
        "## Source",
        "",
        "- `docs/AI_AGENT_TASKS_150_ISSUES.md`",
        "- `docs/AI_BUILD_MASTER_DOC.md`",
        "- `docs/GITHUB_AUTOMATION_AI_PIPELINE.md`",
    ]
    return "\n".join(lines)


def issue_body_for_story(story: Story, epic_issue_number: int) -> str:
    goal = story.goal or "Complete the implementation slice described by the story title."
    acceptance = story.acceptance or "Use the story title and linked docs as the minimum acceptance baseline."
    lines = [
        "## Parent epic",
        "",
        f"#{epic_issue_number} - {story.epic_title}",
        "",
        "## Goal",
        "",
        goal,
        "",
        "## Acceptance summary",
        "",
        acceptance,
        "",
        "## Supporting docs",
        "",
        "- `docs/AI_AGENT_TASKS_150_ISSUES.md`",
        "- `docs/AI_BUILD_MASTER_DOC.md`",
        "",
        "## Delivery notes",
        "",
        "- Update documentation if schema, workflow, or behavior changes",
        "- Link the pull request back to this issue",
    ]
    return "\n".join(lines)


def create_issue(
    repo: str,
    title: str,
    body: str,
    labels: list[str],
    dry_run: bool,
) -> dict[str, str | int]:
    if dry_run:
        print(f"DRY RUN: create issue {title} labels={','.join(labels)}")
        return {"number": 0, "title": title, "url": ""}

    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as handle:
        handle.write(body)
        temp_path = handle.name

    try:
        cmd = ["issue", "create", "--repo", repo, "--title", title, "--body-file", temp_path]
        for label in labels:
            cmd.extend(["--label", label])
        output = gh(cmd).strip()
    finally:
        Path(temp_path).unlink(missing_ok=True)

    match = re.search(r"/issues/(\d+)$", output)
    if not match:
        raise RuntimeError(f"Could not parse issue number from output: {output}")
    return {"number": int(match.group(1)), "title": title, "url": output}


def update_issue_body(repo: str, issue_number: int, body: str, dry_run: bool) -> None:
    if dry_run:
        print(f"DRY RUN: update issue #{issue_number}")
        return

    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as handle:
        handle.write(body)
        temp_path = handle.name

    try:
        gh(["issue", "edit", str(issue_number), "--repo", repo, "--body-file", temp_path], capture=False)
    finally:
        Path(temp_path).unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        default=None,
        help="GitHub repository in OWNER/REPO format. Defaults to the current gh repo.",
    )
    parser.add_argument(
        "--source",
        default="docs/AI_AGENT_TASKS_150_ISSUES.md",
        help="Path to the markdown backlog source file.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Create only the first N stories for a trial import.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without creating or editing GitHub issues.",
    )
    args = parser.parse_args()

    repo = args.repo or default_repo()
    source_path = Path(args.source)
    if not source_path.exists():
        print(f"Backlog source not found: {source_path}", file=sys.stderr)
        return 1

    epics = parse_backlog(source_path)
    story_limit = args.limit
    if story_limit is not None:
        remaining = story_limit
        limited_epics: list[Epic] = []
        for epic in epics:
            if remaining <= 0:
                break
            stories = epic.stories[:remaining]
            remaining -= len(stories)
            limited_epics.append(Epic(number=epic.number, title=epic.title, stories=stories))
        epics = limited_epics

    print(f"Preparing GitHub backlog for {repo}")
    print(f"Epics: {len(epics)}")
    print(f"Stories: {sum(len(epic.stories) for epic in epics)}")

    ensure_labels(repo, args.dry_run)
    existing = load_existing_issues(repo) if not args.dry_run else {}

    epic_issue_numbers: dict[int, int] = {}
    story_refs_by_epic: dict[int, list[str]] = {epic.number: [] for epic in epics}

    for epic in epics:
        title = f"Epic: {epic.title}"
        issue = existing.get(title)
        if issue is None:
            print(f"Creating epic: {title}")
            issue = create_issue(repo, title, issue_body_for_epic(epic), labels_for_epic(epic), args.dry_run)
            existing[title] = issue
        else:
            print(f"Reusing epic: {title} #{issue['number']}")
        epic_issue_numbers[epic.number] = int(issue["number"])

    for epic in epics:
        epic_issue_number = epic_issue_numbers[epic.number]
        for story in epic.stories:
            title = f"[{story.story_id}] {story.title}"
            issue = existing.get(title)
            if issue is None:
                print(f"Creating story: {title}")
                issue = create_issue(
                    repo,
                    title,
                    issue_body_for_story(story, epic_issue_number),
                    labels_for_story(story),
                    args.dry_run,
                )
                existing[title] = issue
            else:
                print(f"Reusing story: {title} #{issue['number']}")
            story_refs_by_epic[epic.number].append(f"- [ ] #{issue['number']} - [{story.story_id}] {story.title}")

    for epic in epics:
        epic_number = epic_issue_numbers[epic.number]
        body = issue_body_for_epic(epic, story_refs_by_epic[epic.number])
        print(f"Updating epic checklist: #{epic_number}")
        update_issue_body(repo, epic_number, body, args.dry_run)

    print("Backlog sync complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
