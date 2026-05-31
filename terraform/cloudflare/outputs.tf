output "tunnel_hostnames" {
  value = { for name, route in local.tunnel_routes : name => route.hostname }
}
