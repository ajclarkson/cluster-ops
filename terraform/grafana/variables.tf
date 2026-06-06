variable "grafana_url" {
  type    = string
  default = "http://grafana.local.clarksons.me"
}

variable "grafana_service_account_token" {
  type      = string
  sensitive = true
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

variable "ntfy_token" {
  type      = string
  sensitive = true
}
