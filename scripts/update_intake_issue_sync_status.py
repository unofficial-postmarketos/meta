#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys


SYNC_BLOCK_START = "<!-- mirror-sync-status-start -->"
SYNC_BLOCK_END = "<!-- mirror-sync-status-end -->"


def run_gh(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        text=True,
    )


def issue_title(source_path: str, target_repo: str) -> str:
    return f"Mirror intake: {source_path} -> {target_repo}"


def build_sync_block(
    sync_status: str,
    synced_at: str,
    default_branch: str,
    source_head_sha: str,
    run_url: str,
) -> str:
    return "\n".join(
        [
            "## Mirror Sync Status",
            SYNC_BLOCK_START,
            f"- Last sync status: `{sync_status}`",
            f"- Last sync at (UTC): `{synced_at}`",
            f"- Last synced branch: `{default_branch}`",
            f"- Last synced upstream HEAD: `{source_head_sha}`",
            f"- Last sync run: {run_url}",
            SYNC_BLOCK_END,
        ]
    )


def upsert_sync_block(body: str, block: str) -> str:
    def dedupe_headings(text: str) -> str:
        duplicate_heading = "\n## Mirror Sync Status\n\n## Mirror Sync Status\n"
        while duplicate_heading in text:
            text = text.replace(duplicate_heading, "\n## Mirror Sync Status\n")
        return text

    existing = body or ""
    start = existing.find(SYNC_BLOCK_START)
    end = existing.find(SYNC_BLOCK_END)

    if start != -1 and end != -1 and end > start:
        replace_start = start
        section_heading = "## Mirror Sync Status"
        heading_index = existing.rfind(section_heading, 0, start)
        if heading_index != -1:
            between = existing[heading_index + len(section_heading) : start]
            if not between.strip():
                replace_start = heading_index

        end += len(SYNC_BLOCK_END)
        prefix = existing[:replace_start].rstrip()
        suffix = existing[end:].lstrip("\n")

        if prefix and suffix:
            updated = f"{prefix}\n\n{block}\n\n{suffix}".rstrip() + "\n"
            return dedupe_headings(updated)

        if prefix:
            updated = f"{prefix}\n\n{block}\n"
            return dedupe_headings(updated)

        if suffix:
            updated = f"{block}\n\n{suffix}".rstrip() + "\n"
            return dedupe_headings(updated)

        updated = f"{block}\n"
        return dedupe_headings(updated)

    if existing.strip():
        updated = existing.rstrip() + "\n\n" + block + "\n"
    else:
        updated = block + "\n"

    return dedupe_headings(updated)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update intake issue body with latest mirror sync metadata"
    )
    parser.add_argument("source_path")
    parser.add_argument("target_repo")
    parser.add_argument("sync_status", choices=["success", "failure"])
    parser.add_argument("synced_at")
    parser.add_argument("default_branch")
    parser.add_argument("source_head_sha")
    parser.add_argument("run_url")
    args = parser.parse_args()

    title = issue_title(args.source_path, args.target_repo)

    result = run_gh(
        "issue",
        "list",
        "--state",
        "all",
        "--limit",
        "20",
        "--search",
        f"{title} in:title",
        "--json",
        "number,title,body",
    )
    issues = json.loads(result.stdout)

    issue = next((item for item in issues if item.get("title") == title), None)
    if issue is None:
        print(f"no intake issue found for {title}; skipping", file=sys.stderr)
        return 0

    new_block = build_sync_block(
        sync_status=args.sync_status,
        synced_at=args.synced_at,
        default_branch=args.default_branch,
        source_head_sha=args.source_head_sha,
        run_url=args.run_url,
    )
    updated_body = upsert_sync_block(issue.get("body") or "", new_block)

    run_gh("issue", "edit", str(issue["number"]), "--body", updated_body)
    print(f"updated issue #{issue['number']} sync status")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
