# unofficial-postmarketos Initial Bootstrap Plan

## Intent

Build `unofficial-postmarketos/meta` as the control plane for:

1. discovering public repositories under `https://gitlab.postmarketos.org/postmarketOS/`,
2. staging/approving which repositories should be mirrored,
3. creating and managing GitHub repositories via OpenTofu,
4. mirroring approved repositories in near-realtime.

This plan prioritizes portability across GitHub Actions and Forgejo Actions by keeping workflows simple and shell-driven.

## Scope (Initial)

- Repository discovery and mirroring.
- GitHub organization/repository management via OpenTofu.
- Approval gate before provisioning/mirroring each repository.

## Out of Scope (For Now)

- Full non-repo infra mirroring (issues, MRs, CI artifacts, package registries, etc.).
- Advanced GitHub-only features that reduce Forgejo workflow compatibility.

## Source-of-Truth Files

Use explicit CSV files with stable sorting and deterministic generation:

- `config/repos.discovered.csv`: auto-generated daily from GitLab API (`visibility=public`, `postmarketOS/*`).
- `config/repos.staged.csv`: approved repositories ready for provisioning.
- `config/repos.csv`: effective mirror manifest consumed by mirroring job (initially generated from staged list).
- `config/repo-intake.csv`: optional state map for issue tracking/idempotency (`source_path,target_repo,issue_number,status`).

Each generated file must be sorted with `LC_ALL=C sort` to prevent churn.

## High-Level Flow

1. Discovery job refreshes `repos.discovered.csv` daily.
2. Reconcile job compares discovered vs intake/staged and creates tracking issues for new repos.
3. Human approval (IssueOps label/comment) promotes repo into `repos.staged.csv`.
4. OpenTofu job ensures GitHub repo exists and matches baseline settings.
5. Mirror job pushes refs from GitLab to GitHub for entries in `config/repos.csv`.

## Workflow Plan

### 1) `sync-public-repos` (already started)

- Triggers: daily schedule + `workflow_dispatch`.
- Behavior:
  - query GitLab group projects for `postmarketOS` (including subgroups),
  - filter `visibility=public`,
  - generate stable `config/repos.discovered.csv`,
  - commit to `main` only on change.

### 2) `reconcile-intake`

- Triggers: on updates to `config/repos.discovered.csv` + `workflow_dispatch`.
- Behavior:
  - detect newly discovered repos not present in intake/staged,
  - create one issue per new repo in `meta`,
  - record issue metadata in `config/repo-intake.csv` (or derive from issue title/body if avoiding extra state file),
  - label issue with `discovered`.

### 3) `issueops-approve`

- Triggers: issue label/comment events + `workflow_dispatch`.
- Behavior:
  - detect approval signal (default: label `approved`),
  - append approved entry to `config/repos.staged.csv`,
  - regenerate `config/repos.csv` from staged list,
  - commit changes with deterministic ordering.

### 4) `tofu-plan` and `tofu-apply`

- Triggers:
  - `tofu-plan`: pull requests and `workflow_dispatch`,
  - `tofu-apply`: merges to `main` and `workflow_dispatch`.
- Behavior:
  - read staged/effective repo list,
  - manage GitHub repositories declaratively,
  - apply only in serialized mode (`concurrency` group enabled).

### 5) `mirror-repos`

- Triggers: frequent schedule + `workflow_dispatch`.
- Behavior:
  - validate manifest,
  - sync default branches for `config/repos.csv` entries (resolve upstream `HEAD`, then force-push that branch),
  - allow ad hoc single-repo runs for testing.

### 6) `validate-meta`

- Triggers: push, pull request, manual.
- Behavior:
  - CSV/schema/script validation,
  - shell syntax checks,
  - workflow sanity checks.

## OpenTofu Design

### Bootstrap assumption

- `github.com/unofficial-postmarketos` org creation is a one-time manual/bootstrap step.
- After org exists, OpenTofu manages org/repo settings and repository resources.

### State strategy

- Use git-tracked state with OpenTofu state encryption enabled.
- Default: encrypted state committed on `main` for simple auditability.
- Guardrail: one writer workflow at a time via `concurrency`.

### Provider/resource model

- Use GitHub provider resources for repositories driven by staged list.
- Add imports for pre-existing repositories to avoid destructive recreation.
- Keep baseline repo policy minimal at first (visibility, issues, default branch behavior) and expand gradually.

## IssueOps and Tracking Model

Each discovered repository gets a long-lived tracking issue in `meta`:

- Title example: `Mirror intake: postmarketOS/pmaports -> pmaports`.
- Suggested labels:
  - `discovered`
  - `approved`
  - `provisioned`
  - `mirroring`
- Suggested checklist in issue body:
  - [ ] approved for mirror
  - [ ] GitHub repo provisioned
  - [ ] mirror config active
  - [ ] first successful mirror observed

Issue remains open as an operational tracker and audit trail.

## Secrets and Auth

- `TARGET_PUSH_TOKEN`: required for mirror push operations.
- `GITLAB_API_TOKEN`: optional for public discovery (helpful for reliability/rate limits).
- `GITHUB_TOKEN`: default workflow token for repo-local commits.
- `GH_ADMIN_TOKEN` (name TBD): elevated token for OpenTofu org/repo management when `GITHUB_TOKEN` is insufficient.
- `TOFU_ENCRYPTION` or passphrase/KMS secret inputs for state encryption.

Never log token values and avoid shell tracing in CI.

## Determinism and Churn Control

- All generated manifests are fully regenerated, sorted, and deduplicated.
- Stable target-repo name encoding must be documented and reversible enough for operations.
- Commit only when file content actually changes.

## Rollout Phases

### Phase 0 (now)

- Land core scripts/workflows and baseline manifest behavior.

### Phase 1

- Split discovered/staged/effective manifests.
- Introduce intake issue generation workflow.

### Phase 2

- Add IssueOps approval flow that updates staged/effective manifests.

### Phase 3

- Add OpenTofu project for GitHub repo provisioning.
- Enable encrypted git-tracked state and serialized apply.

### Phase 4

- Tighten policy defaults, observability, and failure handling.
- Prepare extension into broader infra mirroring if capacity allows.

## Risks and Mitigations

- Missing instance-admin hooks on source GitLab:
  - mitigate with daily discovery + frequent mirroring schedule.
- Git-backed state race conditions:
  - mitigate with strict `concurrency` and single apply path.
- Token scope drift or expiration:
  - mitigate with explicit validation checks and clear failure messages.
- Mapping/name collisions:
  - mitigate with deterministic encoding and validation rules.

## Immediate Next Actions

1. Add `config/repos.discovered.csv` and `config/repos.staged.csv` split.
2. Implement `reconcile-intake` workflow + issue template.
3. Implement `issueops-approve` workflow to promote staged entries.
4. Scaffold OpenTofu configuration for GitHub repositories and encrypted state.
