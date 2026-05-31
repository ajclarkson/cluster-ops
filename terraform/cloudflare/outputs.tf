output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.cluster.id
}

output "tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.cluster.tunnel_token
  sensitive = true
}

output "tunnel_hostnames" {
  value = { for name, route in local.tunnel_routes : name => route.hostname }
}
