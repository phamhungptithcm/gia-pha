#!/usr/bin/env python3
"""Close released stories and epics after a production merge."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict


CLOSING_RE = re.compile(
    r"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+(?:issue\s+)?"
    r"(?:#|https://github\.com/[^/]+/[^/]+/issues/)(\d+)\b",
    re.IGNORECASE,
)
EPIC_RE = re.compile(r"^#(\d+)\s+-\s+.+$", re.MULTILINE)


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, check=True, text=True, capture_output=True)
    return result.stdout.strip()


def gh(args: list[str]) -> str:
    return run(["gh", *args])


def gh_json(args: list[str]) -> object:
    payload = gh(args)
    return json.loads(payload) if payload else None


def list_repo_issues(repo: str) -> dict[int, dict[str, object]]:
    pages = gh_json(
        [
            "api",
            "--paginate",
            "--slurp",
            f"repos/{repo}/issues?state=all&per_page=100",
        ]
    )
    issues: dict[int, dict[str, object]] = {}
    for page in pages or []:
        for issue in page:
            if "pull_request" in issue:
                continue
            issues[int(issue["number"])] = issue
    return issues


def extract_issue_numbers(text: str | None) -> set[int]:
    if not text:
        return set()
    return {int(match) for match in CLOSING_RE.findall(text)}


def parent_epic_number(story_body: str | None) -> int | None:
    if not story_body:
        return None
    match = EPIC_RE.search(story_body)
    if not match:
        return None
    return int(match.group(1))


def associated_pr_numbers(repo: str, release_pr_number: int) -> set[int]:
    numbers = {release_pr_number}
    commits = gh_json(["api", f"repos/{repo}/pulls/{release_pr_number}/commits?per_page=100"]) or []
    for commit in commits:
        commit_sha = commit["sha"]
        commit_prs = gh_json(["api", f"repos/{repo}/commits/{commit_sha}/pulls"]) or []
        for pull_request in commit_prs:
            numbers.add(int(pull_request["number"]))
    return numbers


def pr_details(repo: str, pr_number: int) -> dict[str, object]:
    return gh_json(["api", f"repos/{repo}/pulls/{pr_number}"]) or {}


def add_comment(repo: str, issue_number: int, body: str, dry_run: bool) -> None:
    if dry_run:
        print(f"DRY RUN: comment on issue #{issue_number}")
        return
    gh(
        [
            "api",
            "-X",
            "POST",
            f"repos/{repo}/issues/{issue_number}/comments",
            "-f",
            f"body={body}",
        ]
    )


def close_issue(repo: str, issue_number: int, dry_run: bool) -> None:
    if dry_run:
        print(f"DRY RUN: close issue #{issue_number}")
        return
    gh(
        [
            "api",
            "-X",
            "PATCH",
            f"repos/{repo}/issues/{issue_number}",
            "-f",
            "state=closed",
        ]
    )


def issue_labels(issue: dict[str, object]) -> set[str]:
    return {label["name"] for label in issue.get("labels", [])}


def release_comment(pr_number: int, pr_url: str) -> str:
    return (
        f"Released to production via PR #{pr_number} ({pr_url}). "
        "Closing this story as delivered."
    )


def epic_comment(pr_number: int, pr_url: str, story_numbers: list[int]) -> str:
    story_list = ", ".join(f"#{number}" for number in sorted(story_numbers))
    return (
        f"All linked stories in this epic are now released to production via PR "
        f"#{pr_number} ({pr_url}). Closed stories in this release: {story_list}. "
        "Closing the epic."
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, help="GitHub repository in OWNER/REPO format.")
    parser.add_argument("--release-pr", required=True, type=int, help="Merged production release PR number.")
    parser.add_argument("--dry-run", action="store_true", help="Print planned actions without editing issues.")
    args = parser.parse_args()

    issues = list_repo_issues(args.repo)
    release_pr = pr_details(args.repo, args.release_pr)
    if not release_pr:
        print(f"Release PR #{args.release_pr} was not found.", file=sys.stderr)
        return 1

    prs_to_scan = associated_pr_numbers(args.repo, args.release_pr)
    story_issue_numbers: set[int] = set()

    for pr_number in sorted(prs_to_scan):
        pull_request = pr_details(args.repo, pr_number)
        story_issue_numbers.update(extract_issue_numbers(pull_request.get("body")))

    commits = gh_json(["api", f"repos/{args.repo}/pulls/{args.release_pr}/commits?per_page=100"]) or []
    for commit in commits:
        story_issue_numbers.update(extract_issue_numbers(commit["commit"]["message"]))

    if not story_issue_numbers:
        print("No releasable story references found in the release PR or included pull requests.")
        return 0

    newly_closed_story_numbers: list[int] = []
    candidate_epics: dict[int, list[int]] = defaultdict(list)

    for issue_number in sorted(story_issue_numbers):
        issue = issues.get(issue_number)
        if issue is None:
            print(f"Skipping missing issue #{issue_number}")
            continue

        labels = issue_labels(issue)
        if "story" not in labels:
            print(f"Skipping non-story issue #{issue_number}")
            continue

        if issue.get("state") == "open":
            add_comment(
                args.repo,
                issue_number,
                release_comment(args.release_pr, str(release_pr["html_url"])),
                args.dry_run,
            )
            close_issue(args.repo, issue_number, args.dry_run)
            issue["state"] = "closed"
            newly_closed_story_numbers.append(issue_number)

        epic_number = parent_epic_number(issue.get("body"))
        if epic_number is not None:
            candidate_epics[epic_number].append(issue_number)

    if not newly_closed_story_numbers:
        print("No open story issues needed closing.")
        return 0

    for epic_number, released_story_numbers in sorted(candidate_epics.items()):
        epic = issues.get(epic_number)
        if epic is None:
            continue

        if "epic" not in issue_labels(epic) or epic.get("state") != "open":
            continue

        related_stories = [
            issue
            for issue in issues.values()
            if "story" in issue_labels(issue) and parent_epic_number(issue.get("body")) == epic_number
        ]
        if not related_stories:
            continue

        if any(issue.get("state") != "closed" for issue in related_stories):
            continue

        add_comment(
            args.repo,
            epic_number,
            epic_comment(args.release_pr, str(release_pr["html_url"]), released_story_numbers),
            args.dry_run,
        )
        close_issue(args.repo, epic_number, args.dry_run)
        epic["state"] = "closed"

    print(f"Closed story issues: {', '.join(f'#{number}' for number in newly_closed_story_numbers)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
