#!/usr/bin/env sh
set -eu

manifest_path=${1:-config/repos.mirrored.csv}
github_owner=${GITHUB_OWNER:-unofficial-postmarketos}
meta_repository_name=${META_REPOSITORY_NAME:-meta}
github_api_url=${GITHUB_API_URL:-https://api.github.com}

if ! command -v tofu >/dev/null 2>&1; then
    printf 'tofu CLI is required\n' >&2
    exit 1
fi

if command -v python3 >/dev/null 2>&1; then
    python_bin=python3
elif command -v python >/dev/null 2>&1; then
    python_bin=python
else
    printf 'python3 or python is required\n' >&2
    exit 1
fi

if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_token=$GITHUB_TOKEN
elif [ -n "${GH_ADMIN_TOKEN:-}" ]; then
    auth_token=$GH_ADMIN_TOKEN
    export GITHUB_TOKEN=$GH_ADMIN_TOKEN
else
    printf 'set GITHUB_TOKEN or GH_ADMIN_TOKEN\n' >&2
    exit 1
fi

if [ -z "${TOFU_STATE_PASSPHRASE:-}" ]; then
    printf 'set TOFU_STATE_PASSPHRASE\n' >&2
    exit 1
fi

passphrase_length=$(printf '%s' "$TOFU_STATE_PASSPHRASE" | wc -c | tr -d '[:space:]')
if [ "$passphrase_length" -lt 16 ]; then
    printf 'TOFU_STATE_PASSPHRASE must be at least 16 characters\n' >&2
    exit 1
fi

tofu init -input=false

import_if_exists() {
    address=$1
    repo_name=$2

    if tofu state show "$address" >/dev/null 2>&1; then
        return 0
    fi

    repo_full_name=$github_owner/$repo_name
    http_status=$(
        curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
            --header 'Accept: application/vnd.github+json' \
            --header "Authorization: Bearer $auth_token" \
            --header 'X-GitHub-Api-Version: 2022-11-28' \
            "$github_api_url/repos/$repo_full_name"
    )

    if [ "$http_status" = 200 ]; then
        tofu import -input=false "$address" "$repo_name" >/dev/null
        printf 'imported existing repository %s\n' "$repo_full_name"
        return 0
    fi

    if [ "$http_status" = 404 ]; then
        printf 'repository %s does not exist yet; apply will create it\n' "$repo_full_name"
        return 0
    fi

    printf 'failed to query repository %s (HTTP %s)\n' "$repo_full_name" "$http_status" >&2
    exit 1
}

import_if_exists github_repository.meta "$meta_repository_name"

"$python_bin" - "$manifest_path" <<'PY' | while IFS= read -r target_repo; do
import csv
import sys

manifest = sys.argv[1]

with open(manifest, "r", encoding="utf-8", newline="") as handle:
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

        print(second)
PY
    if [ -z "$target_repo" ]; then
        continue
    fi
    import_if_exists "github_repository.mirror[\"$target_repo\"]" "$target_repo"
done

tofu apply -input=false -auto-approve
