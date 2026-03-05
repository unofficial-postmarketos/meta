terraform {
  required_version = ">= 1.10.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  encryption {
    key_provider "external" "state" {
      command = ["python3", "${path.module}/scripts/tofu_state_key_provider.py"]
    }

    method "aes_gcm" "state" {
      keys = key_provider.external.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "github" {
  owner = var.github_owner
}
