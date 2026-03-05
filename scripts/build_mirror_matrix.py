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

    include: list[dict[str, str]] = []
    with manifest.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        for row in reader:
            if len(row) < 2:
                continue

            source_path = row[0].strip()
            target_repo = row[1].strip()

            if not source_path:
                continue

            if source_path.startswith("#"):
                header_source = source_path.lstrip("#").strip()
                if header_source == "source_path" and target_repo == "target_repo":
                    continue
                continue

            if source_path == "source_path" and target_repo == "target_repo":
                continue

            include.append({"source_path": source_path, "target_repo": target_repo})

    print(json.dumps({"include": include}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
