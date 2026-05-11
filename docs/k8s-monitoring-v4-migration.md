# k8s-monitoring v3 → v4 Migration

Renovate MR !69 bumps `k8s-monitoring` from `3.8.7` to `4.1.1`. The values schema changed
completely in v4, so the MR cannot be merged as-is — the chart would deploy with defaults,
losing all custom configuration.

---

## Step 1 — Run the migration utility

Open: https://grafana.github.io/k8s-monitoring-helm-migrator/

Select migration mode: **v3 → v4**

Paste the following into the **values.yaml (v3)** text box:

```yaml
cluster:
  name: k8s-monitoring

destinations:
  - name: mimir
    type: prometheus
    url: http://mimir-nginx.mimir.svc/api/v1/push
  - name: loki
    type: loki
    url: http://loki-gateway.loki/loki/api/v1/push

clusterMetrics:
  enabled: true
  destinations:
    - mimir

prometheusOperatorObjects:
  enabled: true
  destinations:
    - mimir
  crds:
    deploy: true
  resources:
    requests:
      memory: 128Mi
      cpu: 100m
    limits:
      memory: 256Mi
      cpu: 500m

clusterEvents:
  enabled: true
  collector: alloy-logs

nodeLogs:
  enabled: true
  destinations:
    - loki

podLogs:
  enabled: true
  destinations:
    - loki

alloy-metrics:
  enabled: true
  alloy:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 500Mi
        cpu: 250m
  controller:
    nodeSelector:
      workload: observability

alloy-logs:
  enabled: true
  nodeSelector:
    logging: "true"
  alloy:
    resources:
      requests:
        memory: 128Mi
        cpu: 50m
      limits:
        memory: 256Mi
        cpu: 200m

prometheus:
  replicas: 1
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m
```

Copy the output from **values.yaml (v4)** and note any warnings in the **Notes** column.

---

## Step 2 — Re-add the custom home events pipeline

The migrator does not handle `extraConfig`. After applying the migrated values, manually
add the home events Alloy pipeline back under the alloy-logs collector's extra config in
the v4 structure. The original River config to port:

```river
// --- HOME EVENTS PIPELINE (ONLY mqtt-events-bridge pods) ---

discovery.kubernetes "home_events_pods" {
  role = "pod"
  selectors {
    role  = "pod"
    label = "app=mqtt-events-bridge"
  }
}

discovery.relabel "home_events_keep" {
  targets = discovery.kubernetes.home_events_pods.targets

  rule {
    action = "keep"
    source_labels = ["__meta_kubernetes_pod_label_app"]
    regex = "mqtt-events-bridge"
  }
}

loki.source.kubernetes "home_events" {
  targets    = discovery.relabel.home_events_keep.output
  forward_to = [loki.process.home_events.receiver]
}

loki.process "home_events" {
  stage.json {
    expressions = {
      subsystem      = "subsystem",
      location       = "location",
      event_type     = "event_type",
      outputs_result = "outputs.result",
      correlation    = "correlation_id",
      decision       = "decision",
      reason         = "reason",
    }
  }

  stage.labels {
    values = {
      stream         = "home_events",
      subsystem      = "subsystem",
      location       = "location",
      event_type     = "event_type",
      outputs_result = "outputs_result",
    }
  }

  forward_to = [loki.write.loki.receiver]
}
```

In v4 the key is likely `extraConfig` or `extraAlloyConfig` on the alloy-logs collector — check
the migrator notes and the v4 chart values schema.

---

## Step 3 — Verify nodeSelector labels still apply

The current cluster has:
- `alloy-metrics` pinned to nodes with label `workload: observability`
- `alloy-logs` DaemonSet filtered to nodes with label `logging: "true"`

Confirm the migrated v4 values carry these through. The path changed from
`controller.nodeSelector` to something under the collector definition — verify in the output.

---

## Step 4 — Apply and close Renovate MR !69

1. Replace the `values:` block in `apps/k8s-monitoring.yaml` with the migrated output
2. Bump `version:` to `4.1.1`
3. Push, let Flux reconcile, confirm metrics and logs still appear in Grafana/Mimir/Loki
4. Close Renovate MR !69 (superseded by this migration)

---

## Why this matters

- v4 bundles **Alloy 1.14.0** (up from 1.13.x) with upstream memory fixes
- v4 eliminates bulk pod label allocation — the root cause of the alloy-metrics memory leak
- Until migration is done, alloy-metrics will continue to OOMKill every ~5 days (500Mi cap, ~93Mi/day leak)
