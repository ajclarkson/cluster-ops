# Alert rules managed here are created via the Terraform provider and therefore
# have no provenance lock — they can be freely edited without API workarounds.
#
# To migrate an existing rule: delete it in Grafana UI, then add it here and apply.


resource "grafana_folder" "infra" {
  title = "Alerts"
}

resource "grafana_rule_group" "infra_5m" {
  name             = "5m"
  folder_uid       = grafana_folder.infra.uid
  interval_seconds = 300

  rule {
    name      = "NodeMemoryPressure"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "(1 - node_memory_working_set_bytes{job=\"integrations/kubernetes/resources\"} / on(node) kube_node_status_capacity{resource=\"memory\"}) * 100"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [15], type = "lt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "5m"
    annotations = {
      description = "Node {{ or $labels.instance \"unknown\" }} has been below 15% free memory for 5 minutes. OOM kills likely if this continues."
      summary     = "Low memory on {{ or $labels.instance \"unknown\" }} — {{ printf \"%.1f\" $values.B.Value }}% available"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "LokiBackendRestarted"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "increase(kube_pod_container_status_restarts_total{namespace=\"loki\", pod=\"loki-backend-0\", container=\"loki\"}[10m])"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "max"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "0s"
    annotations = {
      description = "loki-backend-0 has restarted in the last 10 minutes. Possible OOMKill (memory limit: 1Gi)."
      summary     = "loki-backend-0 restarted — possible OOMKill (limit: 1Gi)"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "LonghornManagerRestarted"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 1800
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "increase(kube_pod_container_status_restarts_total{namespace=\"longhorn-system\", pod=~\"longhorn-manager-.*\"}[30m])"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "max"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "0s"
    annotations = {
      description = "{{ or $labels.pod \"unknown\" }} has restarted in the last 30 minutes. This was previously caused by node-level OOM from unbounded Alloy memory usage."
      summary     = "longhorn-manager restarted on {{ or $labels.pod \"unknown\" }} — memory pressure may be returning"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "FluxReconciliationFailed"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "range"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = data.grafana_data_source.loki.uid
      model = jsonencode({
        datasource    = { type = "loki", uid = "loki" }
        editorMode    = "code"
        expr          = "count_over_time({namespace=\"flux-system\", container=\"manager\"} |= \"Reconciliation failed\" | json | name != \"\" [10m])"
        intervalMs    = 1000
        maxDataPoints = 43200
        queryType     = "range"
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "15m"
    annotations = {
      description = "{{ $labels.controller }} {{ $labels.name }} has been failing reconciliation for at least 15 minutes. Check `flux get all -A` and recent git changes."
      summary     = "Flux {{ $labels.controller }} {{ $labels.name }} stuck failing for 15+ minutes"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "FluxHelmReleaseNotReady"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "gotk_helmrelease_info{ready!=\"True\"}"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "15m"
    annotations = {
      summary     = "HelmRelease {{ $labels.namespace }}/{{ $labels.name }} not ready for 15+ minutes"
      description = "HelmRelease {{ $labels.namespace }}/{{ $labels.name }} has ready={{ $labels.ready }}. Check `flux get helmrelease -n {{ $labels.namespace }} {{ $labels.name }}` and Longhorn/chart logs for details."
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "FluxKustomizationNotReady"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "gotk_kustomization_info{ready!=\"True\"}"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "10m"
    annotations = {
      summary     = "Kustomization {{ $labels.namespace }}/{{ $labels.name }} not ready for 10+ minutes"
      description = "Kustomization {{ $labels.namespace }}/{{ $labels.name }} has ready={{ $labels.ready }}. Check `flux get kustomization -n {{ $labels.namespace }} {{ $labels.name }}` and recent git changes."
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "AppPodRestarting"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 900
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "increase(kube_pod_container_status_restarts_total{namespace!~\"kube-system|longhorn-system|loki|flux-system\"}[15m])"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "max"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [2], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "0s"
    annotations = {
      description = "{{ $labels.namespace }}/{{ $labels.pod }} has restarted more than twice in the last 15 minutes."
      summary     = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash-looping"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "ZigbeeBridgeOffline"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "zigbee2mqtt_bridge_state"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
        intervalMs    = 1000
        maxDataPoints = 43200
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
          evaluator = { params = [1], type = "lt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        refId         = "C"
        type          = "threshold"
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    no_data_state  = "Alerting"
    exec_err_state = "Error"
    for            = "2m"
    annotations = {
      summary     = "Zigbee2MQTT bridge is offline"
      description = "The Zigbee coordinator has disconnected. All Zigbee automations are dead until it reconnects."
    }
    is_paused = false
    notification_settings { contact_point = "Clarksons Slack" }
  }

  rule {
    name      = "ZigbeeDeviceOffline"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "zigbee2mqtt_device_up == 0"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
        intervalMs    = 1000
        maxDataPoints = 43200
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
          evaluator = { params = [1], type = "lt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        refId         = "C"
        type          = "threshold"
        intervalMs    = 1000
        maxDataPoints = 43200
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "30m"
    annotations = {
      summary     = "Zigbee device {{ $labels.device }} offline"
      description = "{{ $labels.device }} has been offline for 30+ minutes. Check the Zigbee Health dashboard for link quality and battery status."
    }
    is_paused = false
    notification_settings {
      contact_point = "Clarksons Slack"
      group_by      = ["alertname"]
    }
  }

  rule {
    name      = "NodeNetworkDrops"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 900
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "sum by (instance) (rate(node_network_receive_drop_total{job=\"integrations/node_exporter\", device!~\"lo|veth.*|cni.*|flannel.*|tunl.*\"}[5m]) + rate(node_network_transmit_drop_total{job=\"integrations/node_exporter\", device!~\"lo|veth.*|cni.*|flannel.*|tunl.*\"}[5m]))"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "max"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [5], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "10m"
    annotations = {
      description = "Node {{ $labels.instance }} is dropping more than 5 packets/sec sustained for 10 minutes. May indicate NIC issues or network saturation."
      summary     = "Network packet drops on {{ $labels.instance }}"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "NodeRedErrorSpike"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "range"
      relative_time_range {
        from = 900
        to   = 0
      }
      datasource_uid = data.grafana_data_source.loki.uid
      model = jsonencode({
        datasource = { type = "loki", uid = "loki" }
        editorMode = "code"
        expr       = "sum(count_over_time({namespace=\"node-red\"} |= \"level=error\" [15m]))"
        queryType  = "range"
        refId      = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [5], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "0s"
    annotations = {
      description = "Node-RED has logged more than 5 errors in the last 15 minutes. Check for HA connection failures or broken flows."
      summary     = "Node-RED error spike — possible HA connection issue or broken flow"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "HomeAssistantErrorSpike"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "range"
      relative_time_range {
        from = 900
        to   = 0
      }
      datasource_uid = data.grafana_data_source.loki.uid
      model = jsonencode({
        datasource = { type = "loki", uid = "loki" }
        editorMode = "code"
        expr       = "sum(count_over_time({namespace=\"home-assistant\"} |= \"ERROR\" != \"async_upnp_client.ssdp\" [15m]))"
        queryType  = "range"
        refId      = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [5], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "0s"
    annotations = {
      description = "Home Assistant has logged more than 5 errors in the last 15 minutes (SSDP noise excluded). Check the HA stack health dashboard for details."
      summary     = "Home Assistant error spike"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }
}

resource "grafana_rule_group" "infra_1m" {
  name             = "1m"
  folder_uid       = grafana_folder.infra.uid
  interval_seconds = 60

  rule {
    name      = "NodeSystemOOM"
    condition = "C"

    data {
      ref_id     = "A"
      query_type = "range"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.loki.uid
      model = jsonencode({
        datasource    = { type = "loki", uid = "loki" }
        editorMode    = "code"
        expr          = "count_over_time({node!=\"\"} |= \"System OOM encountered\"\n| regexp \"victim process: (?P<process>[^,]+)\" [5m])"
        intervalMs    = 1000
        maxDataPoints = 43200
        queryType     = "range"
        refId         = "A"
      })
    }

    data {
      ref_id = "reducer"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [{
          evaluator = { params = [0, 0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = [] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource    = { name = "Expression", type = "__expr__", uid = "__expr__" }
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "reducer"
        type          = "reduce"
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
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource    = { type = "__expr__", uid = "__expr__" }
        expression    = "reducer"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state   = "OK"
    exec_err_state  = "Error"
    for             = "1m"
    keep_firing_for = "1m"
    annotations = {
      description = "Node-level OOM kill on {{ $labels.node }}. Process killed: {{ $labels.process }}. Check pod restarts on this node."
      summary     = "System OOM on {{ $labels.node }} — killed {{ $labels.process }}"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }

  rule {
    name      = "NodeNotReady"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = data.grafana_data_source.mimir.uid
      model = jsonencode({
        expr          = "kube_node_status_condition{condition=\"Ready\",status=\"true\"}"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression    = "A"
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "B"
        type          = "reduce"
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
          evaluator = { params = [1], type = "lt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        expression    = "B"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "C"
        type          = "threshold"
      })
    }

    no_data_state  = "OK"
    exec_err_state = "Error"
    for            = "2m"
    annotations = {
      description = "Node {{ $labels.node }} has not been Ready for 2 minutes. Check `kubectl get nodes` and recent cluster events."
      summary     = "Node {{ $labels.node }} is not Ready"
    }
    is_paused = false

    notification_settings {
      contact_point = "Clarksons Slack"
    }
  }
}
