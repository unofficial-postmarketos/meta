# Unofficial postmarketOS Meta Agents Guide

This repository (`unofficial-postmarketos/meta`) is the control plane for mirroring
and automation around `gitlab.postmarketos.org`.

## Mission

- Mirror repositories from GitLab to `github.com/unofficial-postmarketos` in near-realtime.
- Keep infrastructure behavior declarative, reviewable, and reproducible.
- Start with repositories, then expand toward broader infra mirroring as capacity allows.

## Compatibility Target (Important)

All CI/CD automation in this repo must stay within a conservative workflow subset
that works on both GitHub Actions and Forgejo Actions.

### Required workflow rules

- Prefer portable YAML primitives: `on`, `jobs`, `steps`, `env`, `if`, and basic matrix usage.
- Prefer `run` steps backed by POSIX `sh` scripts committed in `scripts/`.
- Keep `uses:` dependencies minimal (`actions/checkout` is the default baseline).
- Avoid platform-exclusive features unless guarded and documented.
- Assume `vars`/`secrets` can be missing; scripts must apply sane defaults or fail clearly.
- Do not rely on GitHub-only integration features (OIDC cloud federation,
  merge queue APIs, environment protection APIs, etc.) for core behavior.

## Repository layout

- `AGENTS.md`: this contract.
- `*.tf`: OpenTofu configuration for GitHub reconciliation.
- `config/repos.csv`: explicit source-to-target repo mapping.
- `scripts/*.sh`: portable automation scripts.
- `.github/workflows/*.yml`: workflow entry points.

## Commit message style

- Use Conventional Commits (`type(scope): subject`) for all commits.
- Keep subjects concise and imperative (for example: `feat(sync): add daily repo discovery`).

## Security and credentials

- `SOURCE_READ_TOKEN` (optional): read token for private GitLab projects.
- `TARGET_PUSH_TOKEN` (required for mirroring): push token for target forge.
- `GH_ADMIN_TOKEN` (required for OpenTofu reconciliation): GitHub token with
  repository administration permissions for the target org.
- `TOFU_STATE_PASSPHRASE` (recommended): passphrase for OpenTofu state/plan
  encryption. If omitted, automation falls back to `GH_ADMIN_TOKEN`.
- Never log tokens. Never commit credentials. Never enable shell tracing in CI.

## Mirroring contract

- Mirror input is `config/repos.csv` with records: `source_path,target_repo`.
- `source_path` is the full GitLab project path without `.git`.
- `target_repo` is the repository name under the target org/owner.
- Mirroring is performed with `git clone --mirror` then `git push --mirror`.

## Operating principles

- Idempotent and retry-safe execution.
- Explicit mappings over implicit name transforms.
- Fast failure for malformed config.
- Concise, deterministic logs.
