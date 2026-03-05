#!/usr/bin/env python3

import csv
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) > 2:
        print("usage: build_mirror_matrix.py [manifest_path]", file=sys.stderr)
        return 1

    manifest = Path(sys.argv[1] if len(sys.argv) == 2 else "config/repos.mirrored.csv")
    if not manifest.exists():
        print(json.dumps({"include": []}))
        return 0

    with manifest.open("r", encoding="utf-8", newline="") as handle:
        lines = [line for line in handle if line.strip() and not line.startswith("#")]

    if not lines:
        print(json.dumps({"include": []}))
        return 0

    include: list[dict[str, str]] = []
    reader = csv.DictReader(lines)
    for row in reader:
        source_path = (row.get("source_path") or "").strip()
        target_repo = (row.get("target_repo") or "").strip()
        if source_path and target_repo:
            include.append({"source_path": source_path, "target_repo": target_repo})

    print(json.dumps({"include": include}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
