"""CocoIndex pipeline for BeFam repository inventory.

Run from the repository root:
    uv run --python 3.11 --with cocoindex cocoindex update scripts/cocoindex_repo_inventory.py
"""

from __future__ import annotations

import hashlib
import json
import pathlib
from collections.abc import Iterator

import cocoindex as coco
from cocoindex.connectors import localfs
from cocoindex.resources.file import FileLike, PatternFilePathMatcher


SOURCE_DIR = pathlib.Path(".")
OUTPUT_DIR = pathlib.Path("cocoindex-out/repo-inventory")
DB_PATH = pathlib.Path(".cocoindex/befam-repo-inventory.db")

INCLUDED_PATTERNS = [
    "*.md",
    "*.yml",
    "*.yaml",
    "*.json",
    "*.toml",
    "*.rules",
    "Dockerfile",
    "CODEOWNERS",
    "docs/**/*.md",
    "firebase/**/*.json",
    "firebase/**/*.rules",
    "firebase/functions/src/**/*.ts",
    "firebase/functions/test/**/*.ts",
    "mobile/befam/lib/**/*.dart",
    "mobile/befam/test/**/*.dart",
    "mobile/befam/integration_test/**/*.dart",
    "mobile/befam/pubspec.yaml",
    "scripts/**/*.py",
    "scripts/**/*.sh",
    ".github/workflows/**/*.yml",
]

EXCLUDED_PATTERNS = [
    ".git/**",
    ".gitnexus/**",
    ".venv/**",
    ".claude/worktrees/**",
    ".codex-artifacts/**",
    "artifacts/**",
    "site/**",
    "dist/**",
    "graphify-out/**",
    "cocoindex-out/**",
    "firebase/functions/node_modules/**",
    "firebase/functions/lib/**",
    "firebase/functions/package-lock.json",
    "mobile/befam/.dart_tool/**",
    "mobile/befam/build/**",
    "mobile/befam/artifacts/**",
    "mobile/befam/ios/Pods/**",
    "mobile/befam/ios/.symlinks/**",
    "mobile/befam/macos/Flutter/ephemeral/**",
    "mobile/befam/lib/l10n/generated/**",
    "scripts/package-lock.json",
    "**/*.g.dart",
    "**/*.freezed.dart",
    "**/__pycache__/**",
    "**/.pytest_cache/**",
]


@coco.lifespan
def coco_lifespan(builder: coco.EnvironmentBuilder) -> Iterator[None]:
    builder.settings.db_path = DB_PATH
    yield


def _category(path: str) -> str:
    if path.startswith("mobile/befam/"):
        return "mobile"
    if path.startswith("firebase/"):
        return "firebase"
    if path.startswith("docs/"):
        return "docs"
    if path.startswith(".github/"):
        return "ci"
    if path.startswith("scripts/"):
        return "scripts"
    return "repo"


@coco.fn(memo=True)
async def process_file(file: FileLike[pathlib.Path], outdir: pathlib.Path) -> None:
    rel_path = str(file.file_path.path).replace("\\", "/")
    text = await file.read_text(errors="replace")
    fingerprint = (await file.content_fingerprint()).hex()
    record = {
        "path": rel_path,
        "category": _category(rel_path),
        "suffix": pathlib.PurePosixPath(rel_path).suffix,
        "size_bytes": await file.size(),
        "line_count": text.count("\n") + (1 if text else 0),
        "word_count": len(text.split()),
        "sha256": hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest(),
        "content_fingerprint": fingerprint,
    }

    record_id = hashlib.sha256(rel_path.encode("utf-8")).hexdigest()[:24]
    localfs.declare_file(
        outdir / "files" / f"{record_id}.json",
        json.dumps(record, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        create_parent_dirs=True,
    )


@coco.fn
async def app_main(sourcedir: pathlib.Path, outdir: pathlib.Path) -> None:
    files = localfs.walk_dir(
        sourcedir,
        recursive=True,
        path_matcher=PatternFilePathMatcher(
            included_patterns=INCLUDED_PATTERNS,
            excluded_patterns=EXCLUDED_PATTERNS,
        ),
    )
    await coco.mount_each(process_file, files.items(), outdir)


app = coco.App(
    coco.AppConfig(name="BeFamRepoInventory"),
    app_main,
    sourcedir=SOURCE_DIR,
    outdir=OUTPUT_DIR,
)
