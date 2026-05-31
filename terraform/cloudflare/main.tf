terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/75240401/terraform/state/cloudflare"
    lock_address   = "https://gitlab.com/api/v4/projects/75240401/terraform/state/cloudflare/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/75240401/terraform/state/cloudflare/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
