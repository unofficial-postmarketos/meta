variable "github_owner" {
  description = "GitHub organization or user that owns managed repositories."
  type        = string
  default     = "unofficial-postmarketos"
}

variable "meta_repository_name" {
  description = "Repository name for the control-plane repository."
  type        = string
  default     = "meta"
}
