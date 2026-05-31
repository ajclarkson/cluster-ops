variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID for clarksons.me"
}

variable "tunnel_secret" {
  type        = string
  sensitive   = true
  description = "Tunnel secret — base64-encoded 32-byte random value. Generate with: openssl rand -base64 32"
}
