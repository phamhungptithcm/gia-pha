#!/usr/bin/env python3
"""Generate release execution/dashboard artifacts from Flutter --machine E2E output.

This script maps integration_test results into the release execution template:
docs/vi/05-devops/release-test-execution-template.csv
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List

CASE_ID_PATTERN = re.compile(r"\[([A-Z]+-\d{3})\]")

STATUS_PRIORITY = {
    "FAIL": 4,
    "BLOCKED": 3,
    "PASS": 2,
    "NOT_RUN": 1,
    "N/A": 0,
}


@dataclass(frozen=True)
class CaseExecutionRecord:
    case_id: str
    status: str
    test_name: str
    result: str
    message: str
    source: str


def _status_from_machine_result(result: str, skipped: bool) -> str:
    if skipped:
        return "BLOCKED"
    normalized = (result or "").strip().lower()
    if normalized == "success":
        return "PASS"
    if normalized in {"failure", "error"}:
        return "FAIL"
    if normalized == "skipped":
        return "BLOCKED"
    return "NOT_RUN"


def _clean_message(value: str) -> str:
    text = (value or "").strip().replace("\n", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _is_real_test_name(name: str) -> bool:
    normalized = (name or "").strip()
    if not normalized:
        return False
    if normalized.startswith("loading "):
        return False
    if normalized in {"(setUpAll)", "(tearDownAll)"}:
        return False
    return True


def parse_machine_file(path: Path) -> List[CaseExecutionRecord]:
    tests_by_id: Dict[int, dict] = {}
    errors_by_test_id: Dict[int, List[str]] = defaultdict(list)
    records: List[CaseExecutionRecord] = []

    with path.open("r", encoding="utf-8") as file:
        for raw_line in file:
            line = raw_line.strip()
            if not line:
                continue

            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(event, dict):
                continue

            event_type = event.get("type")
            if event_type == "testStart":
                test = event.get("test")
                if isinstance(test, dict):
                    test_id = test.get("id")
                    if isinstance(test_id, int):
                        tests_by_id[test_id] = test
                continue

            if event_type == "error":
                test_id = event.get("testID")
                if isinstance(test_id, int):
                    message = _clean_message(str(event.get("error", "")))
                    if message:
                        errors_by_test_id[test_id].append(message)
                continue

            if event_type != "testDone":
                continue

            test_id = event.get("testID")
            if not isinstance(test_id, int):
                continue
            test = tests_by_id.get(test_id) or {}
            test_name = str(test.get("name", "")).strip()
            if not _is_real_test_name(test_name):
                continue

            case_ids = CASE_ID_PATTERN.findall(test_name)
            if not case_ids:
                continue

            result = str(event.get("result", "")).strip()
            skipped = bool(event.get("skipped", False))
            status = _status_from_machine_result(result, skipped)
            messages = errors_by_test_id.get(test_id, [])
            message = messages[0] if messages else ""

            for case_id in case_ids:
                records.append(
                    CaseExecutionRecord(
                        case_id=case_id,
                        status=status,
                        test_name=test_name,
                        result=result or "unknown",
                        message=message,
                        source=path.name,
                    )
                )

    return records


def collapse_records(
    records: Iterable[CaseExecutionRecord],
) -> Dict[str, Dict[str, str]]:
    grouped: Dict[str, List[CaseExecutionRecord]] = defaultdict(list)
    for record in records:
        grouped[record.case_id].append(record)

    collapsed: Dict[str, Dict[str, str]] = {}
    for case_id, entries in grouped.items():
        chosen_status = "NOT_RUN"
        for entry in entries:
            if STATUS_PRIORITY.get(entry.status, 0) > STATUS_PRIORITY.get(
                chosen_status, 0
            ):
                chosen_status = entry.status

        details = []
        for entry in entries:
            line = f"{entry.status} via {entry.test_name}"
            if entry.message:
                line = f"{line} ({entry.message})"
            details.append(line)

        collapsed[case_id] = {
            "status": chosen_status,
            "actual_result": " | ".join(details)[:4000],
        }
    return collapsed


def read_csv_rows(path: Path) -> List[dict]:
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        return list(reader)


def write_csv_rows(path: Path, fieldnames: List[str], rows: List[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def detect_app_version(pubspec: Path) -> str:
    if not pubspec.exists():
        return ""
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("version:"):
            return line.split(":", 1)[1].strip()
    return ""


def detect_git_sha(repo_root: Path) -> str:
    try:
        output = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(repo_root),
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return output.strip()
    except Exception:
        return ""


def to_dashboard_rows(execution_rows: List[dict]) -> List[dict]:
    status_counts = defaultdict(int)
    priority_counts = defaultdict(int)
    priority_pass = defaultdict(int)
    priority_fail = defaultdict(int)
    priority_blocked = defaultdict(int)

    for row in execution_rows:
        status = (row.get("status") or "NOT_RUN").strip().upper() or "NOT_RUN"
        priority = (row.get("priority") or "").strip().upper()
        status_counts[status] += 1
        if priority:
            priority_counts[priority] += 1
            if status == "PASS":
                priority_pass[priority] += 1
            elif status == "FAIL":
                priority_fail[priority] += 1
            elif status == "BLOCKED":
                priority_blocked[priority] += 1

    total = len(execution_rows)
    pass_count = status_counts["PASS"]
    pass_rate = (pass_count / total) if total else 0.0

    return [
        {
            "metric": "Total Cases",
            "formula_or_value": str(total),
            "notes": "Total test case rows",
        },
        {
            "metric": "PASS",
            "formula_or_value": str(status_counts["PASS"]),
            "notes": "Passed test cases",
        },
        {
            "metric": "FAIL",
            "formula_or_value": str(status_counts["FAIL"]),
            "notes": "Failed test cases",
        },
        {
            "metric": "BLOCKED",
            "formula_or_value": str(status_counts["BLOCKED"]),
            "notes": "Blocked test cases",
        },
        {
            "metric": "NOT_RUN",
            "formula_or_value": str(status_counts["NOT_RUN"]),
            "notes": "Not executed yet",
        },
        {
            "metric": "N/A",
            "formula_or_value": str(status_counts["N/A"]),
            "notes": "Not applicable",
        },
        {
            "metric": "Pass Rate",
            "formula_or_value": f"{pass_rate:.2%}",
            "notes": "PASS / Total cases",
        },
        {
            "metric": "P0 Total",
            "formula_or_value": str(priority_counts["P0"]),
            "notes": "Total P0 cases",
        },
        {
            "metric": "P0 PASS",
            "formula_or_value": str(priority_pass["P0"]),
            "notes": "Passed P0 cases",
        },
        {
            "metric": "P0 FAIL",
            "formula_or_value": str(priority_fail["P0"]),
            "notes": "Failed P0 cases",
        },
        {
            "metric": "P0 BLOCKED",
            "formula_or_value": str(priority_blocked["P0"]),
            "notes": "Blocked P0 cases",
        },
        {
            "metric": "P1 Total",
            "formula_or_value": str(priority_counts["P1"]),
            "notes": "Total P1 cases",
        },
        {
            "metric": "P1 PASS",
            "formula_or_value": str(priority_pass["P1"]),
            "notes": "Passed P1 cases",
        },
    ]


def write_markdown_report(
    output_path: Path,
    *,
    run_id: str,
    environment: str,
    device: str,
    app_version: str,
    build_sha: str,
    machine_files: List[str],
    execution_rows: List[dict],
    case_results: Dict[str, Dict[str, str]],
) -> None:
    total = len(execution_rows)
    status_counts = defaultdict(int)
    for row in execution_rows:
        status_counts[(row.get("status") or "NOT_RUN").strip().upper()] += 1

    lines = [
        "# BeFam E2E Release Report",
        "",
        "## Metadata",
        f"- Run ID: `{run_id}`",
        f"- Environment: `{environment}`",
        f"- Device: `{device}`",
        f"- App version: `{app_version}`",
        f"- Build SHA: `{build_sha}`",
        f"- Generated at (UTC): `{dt.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')}`",
        "",
        "## Inputs",
    ]
    for machine_file in machine_files:
        lines.append(f"- `{machine_file}`")

    lines.extend(
        [
            "",
            "## Summary",
            f"- Total cases: **{total}**",
            f"- PASS: **{status_counts['PASS']}**",
            f"- FAIL: **{status_counts['FAIL']}**",
            f"- BLOCKED: **{status_counts['BLOCKED']}**",
            f"- NOT_RUN: **{status_counts['NOT_RUN']}**",
            "",
            "## Automated case results",
            "| Case ID | Status | Actual Result |",
            "|---|---|---|",
        ]
    )

    for case_id in sorted(case_results.keys()):
        status = case_results[case_id]["status"]
        actual = case_results[case_id]["actual_result"].replace("|", "\\|")
        lines.append(f"| {case_id} | {status} | {actual} |")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--machine-file",
        action="append",
        required=True,
        help="Path to flutter --machine output JSONL. Repeat for multiple inputs.",
    )
    parser.add_argument("--template-execution", required=True)
    parser.add_argument("--template-dashboard", required=True)
    parser.add_argument("--output-execution", required=True)
    parser.add_argument("--output-dashboard", required=True)
    parser.add_argument("--output-report-md", default="")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--environment", default="staging")
    parser.add_argument("--device", default="")
    parser.add_argument("--tester", default=os.environ.get("USER", ""))
    parser.add_argument("--test-date", default=dt.date.today().isoformat())
    parser.add_argument("--app-version", default="")
    parser.add_argument("--build-sha", default="")
    parser.add_argument("--evidence-link", default="")
    parser.add_argument("--repo-root", default="")
    parser.add_argument("--pubspec-path", default="")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve() if args.repo_root else Path.cwd()
    pubspec_path = (
        Path(args.pubspec_path).resolve()
        if args.pubspec_path
        else repo_root / "mobile/befam/pubspec.yaml"
    )

    app_version = args.app_version.strip() or detect_app_version(pubspec_path)
    build_sha = args.build_sha.strip() or detect_git_sha(repo_root)
    run_id = args.run_id.strip() or f"RC-{dt.date.today().strftime('%Y%m%d')}-01"

    machine_paths = [Path(item).resolve() for item in args.machine_file]
    parsed_records: List[CaseExecutionRecord] = []
    for path in machine_paths:
        if path.exists():
            parsed_records.extend(parse_machine_file(path))

    case_results = collapse_records(parsed_records)

    template_execution_path = Path(args.template_execution).resolve()
    execution_rows = read_csv_rows(template_execution_path)
    fieldnames = [
        "run_id",
        "suite",
        "test_case_id",
        "priority",
        "precondition",
        "steps",
        "expected_result",
        "status",
        "actual_result",
        "defect_id",
        "defect_link",
        "evidence_link",
        "tester",
        "test_date",
        "environment",
        "device",
        "app_version",
        "build_sha",
        "notes",
    ]

    for row in execution_rows:
        case_id = (row.get("test_case_id") or "").strip().upper()
        row["run_id"] = run_id
        row["tester"] = args.tester
        row["test_date"] = args.test_date
        row["environment"] = args.environment
        row["device"] = args.device
        row["app_version"] = app_version
        row["build_sha"] = build_sha

        record = case_results.get(case_id)
        if record is None:
            row["status"] = row.get("status") or "NOT_RUN"
            continue

        row["status"] = record["status"]
        row["actual_result"] = record["actual_result"]
        if args.evidence_link.strip():
            row["evidence_link"] = args.evidence_link.strip()
        note_prefix = row.get("notes", "").strip()
        auto_note = "auto-filled from integration_test machine output"
        row["notes"] = f"{note_prefix} | {auto_note}".strip(" |")

    output_execution_path = Path(args.output_execution).resolve()
    write_csv_rows(output_execution_path, fieldnames, execution_rows)

    dashboard_rows = to_dashboard_rows(execution_rows)
    output_dashboard_path = Path(args.output_dashboard).resolve()
    write_csv_rows(
        output_dashboard_path,
        fieldnames=["metric", "formula_or_value", "notes"],
        rows=dashboard_rows,
    )

    output_report_md = args.output_report_md.strip()
    if output_report_md:
        write_markdown_report(
            Path(output_report_md).resolve(),
            run_id=run_id,
            environment=args.environment,
            device=args.device,
            app_version=app_version,
            build_sha=build_sha,
            machine_files=[str(path) for path in machine_paths],
            execution_rows=execution_rows,
            case_results=case_results,
        )

    print(f"[e2e-report] execution={output_execution_path}")
    print(f"[e2e-report] dashboard={output_dashboard_path}")
    if output_report_md:
        print(f"[e2e-report] markdown={Path(output_report_md).resolve()}")


if __name__ == "__main__":
    main()
