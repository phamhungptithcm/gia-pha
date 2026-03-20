#!/usr/bin/env python3
"""Validate Firebase Rules documentation stays aligned with rules files."""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DOC_CANDIDATE_PATHS = [
    REPO_ROOT / "docs/en/06-security/firebase-rules.md",
    REPO_ROOT / "docs/06-security/firebase-rules.md",
]
FIRESTORE_RULES_PATH = REPO_ROOT / "firebase/firestore.rules"
STORAGE_RULES_PATH = REPO_ROOT / "firebase/storage.rules"

DOC_REQUIRED_SNIPPETS = [
    "`firebase/firestore.rules`",
    "`firebase/storage.rules`",
    "## Firestore rules highlights",
    "## Storage rules highlights",
    "`hasClanAccess(clanId)`",
    "`primaryRole()`",
    "`branchIdClaim()`",
    "`isClanSettingsAdmin()`",
    "`isBranchScopedMemberManager(...)`",
    "`safeProfileUpdate()`",
    "`clans/{clanId}/members/{memberId}/avatar/{fileName}`",
    "`submissions/{clanId}/{memberId}/{fileName}`",
]

DOCUMENTED_SERVER_ONLY_COLLECTIONS = {
    "transactions",
    "auditLogs",
    "memberSearchIndex",
}

REQUIRED_HELPER_FUNCTIONS = {
    "hasClanAccess",
    "primaryRole",
    "branchIdClaim",
    "isClanSettingsAdmin",
    "isBranchScopedMemberManager",
    "safeProfileUpdate",
}


def _read_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path}")
    return path.read_text(encoding="utf-8")


def _resolve_doc_path() -> Path:
    for candidate in DOC_CANDIDATE_PATHS:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(
        "Missing required file. Checked: "
        + ", ".join(str(path) for path in DOC_CANDIDATE_PATHS)
    )


def _extract_function_names(rules_text: str) -> set[str]:
    return set(re.findall(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", rules_text))


def _extract_server_only_collections(firestore_rules: str) -> set[str]:
    # Collect top-level match blocks whose writes are server-only (allow write: if false;).
    collections: set[str] = set()
    for match in re.finditer(
        r"match\s+/([A-Za-z0-9_]+)/\{[A-Za-z0-9_]+\}\s*\{(?P<body>.*?)\n\s*\}",
        firestore_rules,
        flags=re.DOTALL,
    ):
        body = match.group("body")
        if re.search(r"allow\s+write\s*:\s*if\s+false\s*;", body):
            collections.add(match.group(1))
    return collections


def _extract_storage_limit_for_match(
    storage_rules: str,
    match_path_pattern: str,
) -> int | None:
    block = re.search(
        rf"match\s+/{match_path_pattern}\s*\{{(?P<body>.*?)\n\s*\}}",
        storage_rules,
        flags=re.DOTALL,
    )
    if not block:
        return None

    body = block.group("body")
    direct = re.search(
        r"request\.resource\.size\s*<\s*(\d+)\s*\*\s*1024\s*\*\s*1024",
        body,
    )
    if direct:
        return int(direct.group(1))

    helper_call = re.search(
        r"isValidWritePayload\(\s*(\d+)\s*\*\s*1024\s*\*\s*1024\s*\)",
        body,
    )
    if helper_call:
        return int(helper_call.group(1))

    return None


def _extract_storage_limits_mb(storage_rules: str) -> tuple[int, int]:
    avatar_limit = _extract_storage_limit_for_match(
        storage_rules,
        r"clans/\{clanId\}/members/\{memberId\}/avatar/\{fileName\}",
    )
    submission_limit = _extract_storage_limit_for_match(
        storage_rules,
        r"submissions/\{clanId\}/\{memberId\}/\{fileName\}",
    )
    if avatar_limit is None or submission_limit is None:
        raise ValueError("Unable to parse storage upload limits from firebase/storage.rules.")

    return avatar_limit, submission_limit


def main() -> int:
    try:
        docs_text = _read_text(_resolve_doc_path())
        firestore_rules = _read_text(FIRESTORE_RULES_PATH)
        storage_rules = _read_text(STORAGE_RULES_PATH)
    except (FileNotFoundError, OSError) as exc:
        print(f"[rules-doc-validation] {exc}", file=sys.stderr)
        return 1

    failures: list[str] = []

    for snippet in DOC_REQUIRED_SNIPPETS:
        if snippet not in docs_text:
            failures.append(f"Documentation missing required snippet: {snippet}")

    helper_names = _extract_function_names(firestore_rules)
    missing_helpers = sorted(REQUIRED_HELPER_FUNCTIONS - helper_names)
    if missing_helpers:
        failures.append(
            "firebase/firestore.rules is missing required helper function(s): "
            + ", ".join(missing_helpers)
        )

    server_only_in_rules = _extract_server_only_collections(firestore_rules)
    for collection in sorted(DOCUMENTED_SERVER_ONLY_COLLECTIONS):
        if collection not in server_only_in_rules:
            failures.append(
                "firebase/firestore.rules no longer marks "
                f"`{collection}` as server-only (`allow write: if false;`)."
            )
        if f"`{collection}`" not in docs_text:
            failures.append(
                f"Documentation should mention server-only collection `{collection}`."
            )

    try:
        avatar_limit_mb, submission_limit_mb = _extract_storage_limits_mb(storage_rules)
    except ValueError as exc:
        failures.append(str(exc))
    else:
        if f"{avatar_limit_mb} MB max size" not in docs_text:
            failures.append(
                "Documentation missing avatar upload size limit text "
                f"({avatar_limit_mb} MB max size)."
            )
        if f"{submission_limit_mb} MB max size" not in docs_text:
            failures.append(
                "Documentation missing submission upload size limit text "
                f"({submission_limit_mb} MB max size)."
            )

    if failures:
        print("[rules-doc-validation] FAILED", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    print("[rules-doc-validation] PASS: rules documentation is aligned with rules files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
