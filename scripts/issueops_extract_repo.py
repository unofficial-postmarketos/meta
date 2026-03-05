#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path


SOURCE_RE = re.compile(r"<!--\s*mirror-source-path:\s*(.+?)\s*-->", re.IGNORECASE)
TARGET_RE = re.compile(r"<!--\s*mirror-target-repo:\s*(.+?)\s*-->", re.IGNORECASE)
TITLE_RE = re.compile(r"^Mirror intake: (.+) -> (.+)$")


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: issueops_extract_repo.py <event_payload_path>")

    event_path = Path(sys.argv[1])
    payload = json.loads(event_path.read_text(encoding="utf-8"))
    issue = payload.get("issue") or {}

    body = issue.get("body") or ""
    title = issue.get("title") or ""

    source_match = SOURCE_RE.search(body)
    target_match = TARGET_RE.search(body)

    if source_match and target_match:
        source_path = source_match.group(1).strip()
        target_repo = target_match.group(1).strip()
    else:
        title_match = TITLE_RE.match(title)
        if not title_match:
            fail("unable to parse source_path and target_repo from issue")
        source_path = title_match.group(1).strip()
        target_repo = title_match.group(2).strip()

    if not source_path or not target_repo:
        fail("source_path and target_repo must both be present")

    print(f"source_path={source_path}")
    print(f"target_repo={target_repo}")


if __name__ == "__main__":
    main()
