resource "grafana_data_source" "mimir" {
  name = "prometheus"
  type = "prometheus"
  uid  = "cf6z4wiex30u8e"
  url  = "http://mimir-gateway.mimir.svc/prometheus"

  json_data_encoded = jsonencode({
    httpMethod   = "POST"
    manageAlerts = false
  })
}
