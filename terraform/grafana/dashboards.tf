resource "grafana_folder" "dashboards" {
  title = "Dashboards"
}

resource "grafana_dashboard" "cluster_health" {
  folder      = grafana_folder.dashboards.uid
  config_json = file("${path.module}/dashboards/cluster-health.json")
}
