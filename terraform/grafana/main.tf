terraform {
  required_version = ">= 1.9"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
  }

  cloud {
    organization = "ajclarkson"
    workspaces {
      name = "grafana"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_service_account_token
}
