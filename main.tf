resource "github_repository" "meta" {
  name        = var.meta_repository_name
  description = "Control plane for unofficial postmarketOS mirroring automation"
  visibility  = "public"

  has_issues             = true
  has_wiki               = false
  has_projects           = false
  delete_branch_on_merge = true

  allow_merge_commit = true
  allow_rebase_merge = true
  allow_squash_merge = true

  auto_init          = false
  archive_on_destroy = false

  topics = ["mirroring", "postmarketos", "meta"]
}

locals {
  mirrored_repo_manifest_raw = trimspace(file("${path.module}/config/repos.mirrored.csv"))

  mirrored_repo_rows = length(local.mirrored_repo_manifest_raw) == 0 ? [] : csvdecode(local.mirrored_repo_manifest_raw)

  mirrored_repo_map = {
    for row in local.mirrored_repo_rows : row.target_repo => {
      source_path = row.source_path
      target_repo = row.target_repo
    }
  }
}

resource "github_repository" "mirror" {
  for_each = local.mirrored_repo_map

  name        = each.value.target_repo
  description = "Mirror of ${each.value.source_path} from gitlab.postmarketos.org"
  visibility  = "public"

  has_issues             = false
  has_wiki               = false
  has_projects           = false
  delete_branch_on_merge = false

  allow_merge_commit = true
  allow_rebase_merge = false
  allow_squash_merge = false

  auto_init          = false
  archive_on_destroy = false
}

output "meta_repository_full_name" {
  description = "Full name for the managed meta repository."
  value       = github_repository.meta.full_name
}

output "mirrored_repository_count" {
  description = "Number of mirror repositories currently managed by OpenTofu."
  value       = length(github_repository.mirror)
}
