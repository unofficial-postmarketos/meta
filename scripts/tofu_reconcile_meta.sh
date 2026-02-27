#!/usr/bin/env sh
set -eu

if ! command -v tofu >/dev/null 2>&1; then
    printf 'tofu CLI is required\n' >&2
    exit 1
fi

if [ -n "${TF_VAR_github_token:-}" ]; then
    :
elif [ -n "${GH_ADMIN_TOKEN:-}" ]; then
    export TF_VAR_github_token=$GH_ADMIN_TOKEN
else
    printf 'set TF_VAR_github_token or GH_ADMIN_TOKEN\n' >&2
    exit 1
fi

if [ -n "${TF_VAR_github_owner:-}" ]; then
    :
elif [ -n "${GITHUB_OWNER:-}" ]; then
    export TF_VAR_github_owner=$GITHUB_OWNER
else
    export TF_VAR_github_owner=unofficial-postmarketos
fi

if [ -n "${TF_VAR_meta_repository_name:-}" ]; then
    :
elif [ -n "${META_REPOSITORY_NAME:-}" ]; then
    export TF_VAR_meta_repository_name=$META_REPOSITORY_NAME
else
    export TF_VAR_meta_repository_name=meta
fi

repo_full_name=$TF_VAR_github_owner/$TF_VAR_meta_repository_name
github_api_url=${GITHUB_API_URL:-https://api.github.com}

tofu init -input=false

if ! tofu state show github_repository.meta >/dev/null 2>&1; then
    http_status=$(
        curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
            --header 'Accept: application/vnd.github+json' \
            --header "Authorization: Bearer $TF_VAR_github_token" \
            --header 'X-GitHub-Api-Version: 2022-11-28' \
            "$github_api_url/repos/$repo_full_name"
    )

    if [ "$http_status" = 200 ]; then
        tofu import -input=false github_repository.meta "$repo_full_name" >/dev/null
        printf 'imported existing repository %s\n' "$repo_full_name"
    elif [ "$http_status" = 404 ]; then
        printf 'repository %s does not exist yet; apply will create it\n' "$repo_full_name"
    else
        printf 'failed to query repository %s (HTTP %s)\n' "$repo_full_name" "$http_status" >&2
        exit 1
    fi
fi

tofu apply -input=false -auto-approve
