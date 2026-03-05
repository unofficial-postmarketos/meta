#!/usr/bin/env python3

import csv
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def read_entries(path: Path) -> list[tuple[str, str]]:
    if not path.exists():
        return []

    entries: list[tuple[str, str]] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        for row in reader:
            if len(row) < 2:
                continue

            first = row[0].strip()
            second = row[1].strip()

            if not first:
                continue

            if first.startswith("#"):
                header_first = first.lstrip("#").strip()
                if header_first == "source_path" and second == "target_repo":
                    continue
                continue

            if first == "source_path" and second == "target_repo":
                continue

            entries.append((first, second))

    return entries


def write_entries(path: Path, entries: list[tuple[str, str]]) -> None:
    rows = ["source_path,target_repo"]
    rows.extend(f"{source_path},{target_repo}" for source_path, target_repo in entries)
    content = "\n".join(rows) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 5:
        fail(
            "usage: update_mirrored_manifest.py <mirrored_manifest> <source_path> "
            "<target_repo> <canonical_manifest>"
        )

    mirrored_manifest = Path(sys.argv[1])
    source_path = sys.argv[2].strip()
    target_repo = sys.argv[3].strip()
    canonical_manifest = Path(sys.argv[4])

    if not source_path or not target_repo:
        fail("source_path and target_repo must be non-empty")

    canonical_entries = set(read_entries(canonical_manifest))
    if (source_path, target_repo) not in canonical_entries:
        fail(
            "entry is not present in canonical manifest: "
            f"{source_path},{target_repo}"
        )

    current_entries = set(read_entries(mirrored_manifest))
    before_count = len(current_entries)
    current_entries.add((source_path, target_repo))

    sorted_entries = sorted(current_entries, key=lambda item: (item[0], item[1]))
    write_entries(mirrored_manifest, sorted_entries)

    changed = len(current_entries) != before_count
    print(f"changed={'true' if changed else 'false'}")
    print(f"entry={source_path},{target_repo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
