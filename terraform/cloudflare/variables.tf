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

variable "tunnel_id" {
  type        = string
  description = "Cloudflare Tunnel ID (from the Cloudflare dashboard)"
}

variable "tunnel_secret" {
  type      = string
  sensitive = true
  description = "Cloudflare Tunnel secret (base64 encoded)"
}
