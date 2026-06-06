locals {
  # Public routes exposed via tunnel (explicit whitelist — add deliberately)
  # Route directly to cluster services, bypassing nginx ingress
  tunnel_routes = {
    "sso" = {
      hostname = "sso.clarksons.me"
      service  = "http://keycloak-service.keycloak.svc:8080"
    }
    "home" = {
      hostname = "home.clarksons.me"
      service  = "http://home-assistant.home-assistant.svc:8123"
    }
    "ntfy" = {
      hostname = "ntfy.clarksons.me"
      service  = "http://ntfy.ntfy.svc:80"
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "cluster" {
  account_id = var.cloudflare_account_id
  name       = "rackman"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cluster" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cluster.id

  config = {
    ingress = concat(
      [
        for name, route in local.tunnel_routes : {
          hostname = route.hostname
          service  = route.service
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
  content = "${cloudflare_zero_trust_tunnel_cloudflared.cluster.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
