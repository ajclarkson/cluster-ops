# Alert rules managed here are created via the Terraform provider and therefore
# have no provenance lock — they can be freely edited without API workarounds.
#
# To migrate an existing rule: delete it in Grafana UI, then add it here and apply.

resource "grafana_rule_group" "node_alerts" {
  name             = "node-alerts"
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  rule {
    name      = "Node Memory High"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr         = "instance:node_memory_utilisation:ratio{job=\"integrations/node_exporter\"} > 0"
        instant      = true
        intervalMs   = 1000
        maxDataPoints = 43200
        refId        = "A"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [{
          evaluator = { params = [0.9], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["A"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        refId      = "C"
        type       = "threshold"
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      summary = "Node {{ $labels.instance }} memory usage above 90%"
    }
    labels = {
      severity = "warning"
    }
    is_paused = false
  }
}

resource "grafana_folder" "alerts" {
  title = "Cluster Alerts"
}
