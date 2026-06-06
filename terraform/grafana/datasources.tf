data "grafana_data_source" "mimir" {
  name = "prometheus"
}

data "grafana_data_source" "loki" {
  name = "Loki"
}
