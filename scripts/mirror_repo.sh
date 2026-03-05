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

primary_push_token=${TARGET_PUSH_TOKEN:-}
fallback_push_token=${GH_ADMIN_TOKEN:-}

if [ -z "$primary_push_token" ] && [ -z "$fallback_push_token" ]; then
    printf 'set TARGET_PUSH_TOKEN or GH_ADMIN_TOKEN\n' >&2
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

push_with_token() {
    token=$1
    target_repo_url=https://x-access-token:${token}@github.com/$github_owner/$target_repo.git
    git -C "$tmp_dir/repo.git" push --mirror "$target_repo_url"
}

export GIT_TERMINAL_PROMPT=0

printf 'mirroring %s -> %s/%s\n' "$source_path" "$github_owner" "$target_repo"
git clone --mirror "$source_repo_url" "$tmp_dir/repo.git"

if [ -n "$primary_push_token" ]; then
    if ! push_with_token "$primary_push_token"; then
        if [ -n "$fallback_push_token" ] && [ "$fallback_push_token" != "$primary_push_token" ]; then
            printf 'primary push token failed; retrying with GH_ADMIN_TOKEN\n' >&2
            push_with_token "$fallback_push_token"
        else
            exit 1
        fi
    fi
else
    push_with_token "$fallback_push_token"
fi

printf 'mirror completed for %s\n' "$target_repo"
