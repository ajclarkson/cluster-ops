resource "grafana_dashboard" "cluster_health" {
  config_json = file("${path.module}/dashboards/cluster-health.json")
}

resource "grafana_dashboard" "ha_stack_health" {
  config_json = file("${path.module}/dashboards/ha-stack-health.json")
}

resource "grafana_dashboard" "ha_behaviour" {
  config_json = file("${path.module}/dashboards/ha-behaviour.json")
}

resource "grafana_dashboard" "zigbee_health" {
  config_json = file("${path.module}/dashboards/zigbee-health.json")
}

resource "grafana_dashboard" "flux_status" {
  config_json = file("${path.module}/dashboards/flux-status.json")
}

resource "grafana_dashboard" "status_page" {
  config_json = file("${path.module}/dashboards/status-page.json")
}
