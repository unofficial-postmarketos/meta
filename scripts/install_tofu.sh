#!/usr/bin/env sh
set -eu

tofu_version=${1:-1.10.7}
install_dir=${2:-$HOME/.local/bin}

if command -v python3 >/dev/null 2>&1; then
    python_bin=python3
elif command -v python >/dev/null 2>&1; then
    python_bin=python
else
    printf 'python3 or python is required\n' >&2
    exit 1
fi

if command -v tofu >/dev/null 2>&1; then
    installed_version_line=$(
        tofu version | {
            IFS= read -r line
            printf '%s' "$line"
        }
    )
    installed_version=$("$python_bin" - "$installed_version_line" <<'PY'
import re
import sys

line = sys.argv[1]
if not line:
    print("")
    raise SystemExit(0)

match = re.search(r"v([0-9]+\.[0-9]+\.[0-9]+)", line)
print(match.group(1) if match else "")
PY
)
    if [ "$installed_version" = "$tofu_version" ]; then
        printf 'tofu %s already available\n' "$tofu_version"
        exit 0
    fi
fi

case "$(uname -s)" in
    Linux)
        os=linux
        ;;
    Darwin)
        os=darwin
        ;;
    *)
        printf 'unsupported operating system: %s\n' "$(uname -s)" >&2
        exit 1
        ;;
esac

case "$(uname -m)" in
    x86_64|amd64)
        arch=amd64
        ;;
    aarch64|arm64)
        arch=arm64
        ;;
    *)
        printf 'unsupported architecture: %s\n' "$(uname -m)" >&2
        exit 1
        ;;
esac

tmp_dir=$(mktemp -d)

cleanup() {
    rm -rf "$tmp_dir"
}

trap cleanup EXIT INT TERM

archive_path=$tmp_dir/tofu.zip
download_url=https://github.com/opentofu/opentofu/releases/download/v$tofu_version/tofu_$tofu_version\_$os\_$arch.zip

curl --fail --silent --show-error --location \
    --output "$archive_path" \
    "$download_url"

"$python_bin" - "$archive_path" "$tmp_dir" <<'PY'
import os
import sys
import zipfile

archive = sys.argv[1]
output_dir = sys.argv[2]

with zipfile.ZipFile(archive, "r") as zf:
    members = [m for m in zf.namelist() if m.endswith("/tofu") or m == "tofu"]
    if not members:
        raise SystemExit("tofu binary not found in archive")
    member = members[0]
    zf.extract(member, output_dir)
    source_path = os.path.join(output_dir, member)
    target_path = os.path.join(output_dir, "tofu")
    if source_path != target_path:
        os.replace(source_path, target_path)
PY

mkdir -p "$install_dir"
install -m 0755 "$tmp_dir/tofu" "$install_dir/tofu"
printf 'installed tofu %s to %s/tofu\n' "$tofu_version" "$install_dir"
