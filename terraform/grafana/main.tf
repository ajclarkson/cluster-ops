terraform {
  required_version = ">= 1.9"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
  }

  backend "http" {
    address        = "https://gitlab.com/api/v4/projects/75240401/terraform/state/grafana"
    lock_address   = "https://gitlab.com/api/v4/projects/75240401/terraform/state/grafana/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/75240401/terraform/state/grafana/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_service_account_token
}
