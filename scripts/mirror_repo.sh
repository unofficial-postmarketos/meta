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
github_api_url=${GITHUB_API_URL:-https://api.github.com}
mirror_output_file=${MIRROR_OUTPUT_FILE:-}

primary_push_token=${TARGET_PUSH_TOKEN:-}
fallback_push_token=${GH_ADMIN_TOKEN:-}

if [ -z "$primary_push_token" ] && [ -z "$fallback_push_token" ]; then
    printf 'set TARGET_PUSH_TOKEN or GH_ADMIN_TOKEN\n' >&2
    exit 1
fi

export GIT_TERMINAL_PROMPT=0

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

source_default_branch=$(
    git ls-remote --symref "$source_repo_url" HEAD | {
        IFS= read -r line || true
        printf '%s' "$line"
    }
)

case "$source_default_branch" in
    ref:\ refs/heads/*)
        source_default_branch=${source_default_branch#ref: refs/heads/}
        source_default_branch=${source_default_branch%%[[:space:]]*}
        ;;
    *)
        printf 'unable to resolve source default branch for %s\n' "$source_path" >&2
        exit 1
        ;;
esac

if [ -z "$source_default_branch" ]; then
    printf 'source default branch for %s is empty\n' "$source_path" >&2
    exit 1
fi

push_default_branch_with_token() {
    token=$1
    target_repo_url=https://x-access-token:${token}@github.com/$github_owner/$target_repo.git
    git -C "$tmp_dir/repo" push --force "$target_repo_url" \
        "refs/remotes/source/$source_default_branch:refs/heads/$source_default_branch"
}

set_target_default_branch() {
    token=$1
    http_status=$(
        curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
            --request PATCH \
            --header 'Accept: application/vnd.github+json' \
            --header "Authorization: Bearer $token" \
            --header 'X-GitHub-Api-Version: 2022-11-28' \
            --header "Content-Type: application/json" \
            --data "{\"default_branch\":\"$source_default_branch\"}" \
            "$github_api_url/repos/$github_owner/$target_repo"
    )

    if [ "$http_status" = 200 ]; then
        printf 'set target default branch to %s\n' "$source_default_branch"
        return 0
    fi

    printf 'warning: unable to set target default branch to %s (HTTP %s)\n' \
        "$source_default_branch" "$http_status" >&2
}

write_mirror_output() {
    key=$1
    value=$2

    if [ -z "$mirror_output_file" ]; then
        return 0
    fi

    printf '%s=%s\n' "$key" "$value" >> "$mirror_output_file"
}

printf 'syncing default branch %s for %s -> %s/%s\n' \
    "$source_default_branch" "$source_path" "$github_owner" "$target_repo"

git init "$tmp_dir/repo" >/dev/null
git -C "$tmp_dir/repo" remote add source "$source_repo_url"
git -C "$tmp_dir/repo" fetch --no-tags source \
    "refs/heads/$source_default_branch:refs/remotes/source/$source_default_branch"

source_head_sha=$(git -C "$tmp_dir/repo" rev-parse "refs/remotes/source/$source_default_branch")

write_mirror_output default_branch "$source_default_branch"
write_mirror_output source_head_sha "$source_head_sha"

push_token_used=
if [ -n "$primary_push_token" ]; then
    if push_default_branch_with_token "$primary_push_token"; then
        push_token_used=$primary_push_token
    else
        if [ -n "$fallback_push_token" ] && [ "$fallback_push_token" != "$primary_push_token" ]; then
            printf 'primary push token failed; retrying with GH_ADMIN_TOKEN\n' >&2
            push_default_branch_with_token "$fallback_push_token"
            push_token_used=$fallback_push_token
        else
            exit 1
        fi
    fi
else
    push_default_branch_with_token "$fallback_push_token"
    push_token_used=$fallback_push_token
fi

if [ -n "$push_token_used" ]; then
    set_target_default_branch "$push_token_used"
fi

printf 'default branch sync completed for %s\n' "$target_repo"
