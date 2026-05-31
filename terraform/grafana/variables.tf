variable "grafana_url" {
  type    = string
  default = "http://grafana.local.clarksons.me"
}

variable "grafana_service_account_token" {
  type      = string
  sensitive = true
}
