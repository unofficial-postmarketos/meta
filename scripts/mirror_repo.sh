#!/usr/bin/env sh
set -eu

if [ "$#" -ne 2 ]; then
    printf 'usage: mirror_repo.sh <source_path> <target_repo>\n' >&2
    exit 1
fi

source_path=$1
target_repo=$2

gitlab_base_url=${GITLAB_BASE_URL:-https://gitlab.postmarketos.org}
github_owner=${GITHUB_OWNER:-unofficial-postmarketos}

if [ -z "${TARGET_PUSH_TOKEN:-}" ]; then
    printf 'set TARGET_PUSH_TOKEN\n' >&2
    exit 1
fi

tmp_dir=$(mktemp -d)

cleanup() {
    rm -rf "$tmp_dir"
}

trap cleanup EXIT INT TERM

case "$gitlab_base_url" in
    */)
        gitlab_base_url=${gitlab_base_url%/}
        ;;
esac

source_repo_url=$gitlab_base_url/$source_path.git
if [ -n "${SOURCE_READ_TOKEN:-}" ]; then
    case "$source_repo_url" in
        https://*)
            source_repo_url=https://oauth2:${SOURCE_READ_TOKEN}@${source_repo_url#https://}
            ;;
        http://*)
            source_repo_url=http://oauth2:${SOURCE_READ_TOKEN}@${source_repo_url#http://}
            ;;
        *)
            printf 'unsupported source URL scheme for authenticated clone\n' >&2
            exit 1
            ;;
    esac
fi

target_repo_url=https://x-access-token:${TARGET_PUSH_TOKEN}@github.com/$github_owner/$target_repo.git

export GIT_TERMINAL_PROMPT=0

printf 'mirroring %s -> %s/%s\n' "$source_path" "$github_owner" "$target_repo"
git clone --mirror "$source_repo_url" "$tmp_dir/repo.git"
git -C "$tmp_dir/repo.git" push --mirror "$target_repo_url"
printf 'mirror completed for %s\n' "$target_repo"
