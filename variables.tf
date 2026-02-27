variable "github_owner" {
  description = "GitHub organization or user that owns managed repositories."
  type        = string
  default     = "unofficial-postmarketos"
}

variable "github_token" {
  description = "Token used by the GitHub provider."
  type        = string
  sensitive   = true
}

variable "meta_repository_name" {
  description = "Repository name for the control-plane repository."
  type        = string
  default     = "meta"
}
