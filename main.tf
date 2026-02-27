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

output "meta_repository_full_name" {
  description = "Full name for the managed meta repository."
  value       = github_repository.meta.full_name
}
