locals {
  # Internal cluster service base — nginx ingress
  cluster_ingress = "http://10.0.0.30"

  # Public routes exposed via tunnel (explicit whitelist — add deliberately)
  tunnel_routes = {
    "sso" = {
      hostname = "sso.clarksons.me"
      service  = "${local.cluster_ingress}"
      # Keycloak handles its own auth — no additional access policy needed
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cluster" {
  account_id = var.cloudflare_account_id
  tunnel_id  = var.tunnel_id

  config = {
    ingress = concat(
      [
        for name, route in local.tunnel_routes : {
          hostname = route.hostname
          service  = route.service
          origin_request = {
            http_host_header = route.hostname
          }
        }
      ],
      # Catch-all — must be last
      [{ service = "http_status:404" }]
    )
  }
}

resource "cloudflare_dns_record" "tunnel_routes" {
  for_each = local.tunnel_routes

  zone_id = var.cloudflare_zone_id
  name    = each.value.hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
