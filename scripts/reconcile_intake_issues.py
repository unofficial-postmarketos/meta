#!/usr/bin/env python3

import csv
import json
import subprocess
import sys
from pathlib import Path


def run_gh(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        text=True,
    )


def read_manifest(manifest_path: Path) -> list[tuple[str, str]]:
    with manifest_path.open("r", encoding="utf-8", newline="") as handle:
        lines = [line for line in handle if line.strip() and not line.startswith("#")]

    if not lines:
        return []

    entries: list[tuple[str, str]] = []
    reader = csv.DictReader(lines)
    for row in reader:
        source_path = (row.get("source_path") or "").strip()
        target_repo = (row.get("target_repo") or "").strip()
        if source_path and target_repo:
            entries.append((source_path, target_repo))
    return entries


def issue_title(source_path: str, target_repo: str) -> str:
    return f"Mirror intake: {source_path} -> {target_repo}"


def issue_body(source_path: str, target_repo: str) -> str:
    return "\n".join(
        [
            "Mirror candidate discovered from the canonical GitLab public repository list.",
            "",
            f"<!-- mirror-source-path: {source_path} -->",
            f"<!-- mirror-target-repo: {target_repo} -->",
            "",
            f"- Source path: `{source_path}`",
            f"- Target repository: `{target_repo}`",
            "- Activation mode: append-only (`mirrored` label adds this entry to `config/repos.mirrored.csv`)",
            "",
            "Checklist:",
            "- [ ] labeled `mirrored`",
            "- [ ] downstream repository provisioned",
            "- [ ] first mirror run completed",
        ]
    )


def ensure_labels() -> None:
    wanted = {
        "discovered": ("0e8a16", "Discovered in canonical upstream repository list"),
        "mirrored": ("1d76db", "Approved for append-only mirror activation"),
    }

    result = run_gh("label", "list", "--limit", "200", "--json", "name")
    existing = {item["name"] for item in json.loads(result.stdout)}

    for name, (color, description) in wanted.items():
        if name in existing:
            continue
        run_gh("label", "create", name, "--color", color, "--description", description)


def main() -> int:
    if len(sys.argv) > 2:
        print("usage: reconcile_intake_issues.py [manifest_path]", file=sys.stderr)
        return 1

    manifest = Path(sys.argv[1] if len(sys.argv) == 2 else "config/repos.csv")
    if not manifest.exists():
        print(f"manifest not found: {manifest}", file=sys.stderr)
        return 1

    entries = read_manifest(manifest)
    ensure_labels()

    existing_result = run_gh("issue", "list", "--state", "all", "--limit", "1000", "--json", "title")
    existing_titles = {item["title"] for item in json.loads(existing_result.stdout)}

    created = 0
    for source_path, target_repo in entries:
        title = issue_title(source_path, target_repo)
        if title in existing_titles:
            continue
        run_gh(
            "issue",
            "create",
            "--title",
            title,
            "--label",
            "discovered",
            "--body",
            issue_body(source_path, target_repo),
        )
        created += 1
        print(f"created issue: {title}")

    print(f"intake reconciliation complete: {len(entries)} entries, {created} issue(s) created")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
