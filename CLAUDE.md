# cluster-ops

GitOps management for a 4-node k3s homelab cluster. Flux CD reconciles everything from this repo.

## Core constraint

**kubectl is read-only.** All changes to cluster state go through git → Flux. Never use kubectl to mutate resources directly.

## Configuration schemas

**Never guess or invent config schemas.** If adding or modifying configuration for any application (Frigate, Helm chart values, Longhorn, etc.), fetch the official documentation or check the source before writing YAML. Schema errors cause pod restarts and config-version churn. When in doubt, use the WebFetch tool to read the relevant docs page first.

## Architecture

- **Nodes**: `blinky` (10.0.0.51), `inky` (10.0.0.52), `pinky` (10.0.0.53) — RPi 5, control-plane + etcd, all run workloads. `clyde` (10.0.0.54) — BOSGAME E4 (Ryzen 5 3550H, x86_64), worker-only, Frigate workloads
- **VIP**: kube-vip on `10.0.0.50` (`rackman.local.clarksons.me`), router points DNS to VIP
- **Storage**: Longhorn (RWO/RWX), 2 replicas, Retain policy. iSCSI loaded via `iscsid` service (no dm_crypt — encryption not in use)
- **Reconciliation order**: `infra-crds` → `infra-controllers` → `infra-configs` → `apps` → `patches`
- **Secrets**: 1Password Connect via External Secrets Operator
- **Observability**: alloy-metrics (Mimir) + alloy-logs (Loki) via k8s-monitoring Helm chart, dashboards in Grafana
- **SSO**: oauth2-proxy in front of UIs that lack auth, backed by Keycloak with Google IdP. Custom first-broker flow removes account auto-registration.

## Key patterns

### Patching Helm-rendered resources
Use `postRenderers` on a HelmRelease — the only way to modify fields not exposed as chart values:

```yaml
postRenderers:
  - kustomize:
      patches:
        - target:
            kind: Deployment
          patch: |-
            - op: add
              path: /spec/revisionHistoryLimit
              value: 1
```

### RWO PVC deployments
Any Deployment using a RWO PVC must use `strategy: type: Recreate` (or the chart equivalent, e.g. `deploymentUpdate: type: Recreate` for minio). RollingUpdate deadlocks — new pod can't attach the volume while the old pod holds it.

### SSA field ownership conflicts
If Flux owns a field that needs changing (e.g. `rollingUpdate` after switching to Recreate):
1. Add `force: true` to the Kustomization in `clusters/rackman/apps.yaml`
2. Reconcile: `flux reconcile source git flux-system && flux reconcile kustomization apps`
3. Confirm healthy, then remove `force: true` and push

### Cross-cutting Deployment settings
Apply via postRenderers rather than per-chart values. `revisionHistoryLimit: 1` is set this way on all HelmReleases — in a GitOps cluster, git is the rollback history.

## Memory pressure on 8GB RPi nodes

Node memory is shared across all workloads. Before raising any memory limit:
1. Check current node usage: `kubectl top nodes`
2. Confirm the target node has headroom (aim to stay under ~80% committed limits)
3. OOMKills during large upgrades (k3s rolling restart, many chart upgrades simultaneously) are transient — kube-vip and longhorn-manager are typical collateral victims and self-heal

## Monitoring stack notes

- **alloy-metrics** scrapes kube-state-metrics, node-exporter, cadvisor, kubelet → remote-writes to Mimir
- **node-exporter** runs as a DaemonSet (enabled via `telemetryServices.node-exporter.deploy: true` in k8s-monitoring values) — provides `node_filesystem_*`, `node_network_*`, node temp etc.
- kube-state-metrics series count is the main driver of alloy-metrics WAL memory usage
- High ReplicaSet count (dead 0-replica RSes from Helm upgrades) inflates series — controlled via `revisionHistoryLimit: 1`
- Loki backend runs the compactor; node-red has 400-day retention which creates a large backlog — backend needs more memory than other Loki components
- Home events structured log stream: `{service_name="loki.source.kubernetes.home_events"}` — JSON with event_type, subsystem, location, decision, reason, outputs_result fields promoted as labels

## Grafana Terraform management

Grafana resources are managed in `terraform/grafana/`. Provider: grafana v4. State backend: HCP Terraform Cloud (`ajclarkson` org, `grafana` workspace). Auth via `TF_TOKEN_app_terraform_io` env var.

### Structure
- `alerts.tf` — `grafana_folder.infra` ("Alerts"), `grafana_rule_group.infra_5m` and `infra_1m`
- `dashboards.tf` — three `grafana_dashboard` resources at root level (no folder)
- `notifications.tf` — `grafana_contact_point.clarksons_slack`, `grafana_message_template.rackman_slack`
- `datasources.tf` — data sources for Mimir and Loki (used by alert rules)
- `dashboards/` — JSON dashboard definitions

### Dashboards
- `cluster-health.json` — node memory/CPU %, PVC disk %, pod restarts table, OOM events log
- `ha-stack-health.json` — HA/z2m/node-red/mosquitto restart stats, container memory, error rates, recent errors
- `ha-behaviour.json` — home automation decision stats, subsystem activity, decision log, errors; filtered by `$location` and `$subsystem`

### Known gotchas
- **Loki alert data blocks** need `query_type = "range"` as a top-level HCL attribute (not just inside `model` jsonencode) — otherwise Terraform diffs on every apply
- **Dashboard datasource UIDs** are hardcoded: Mimir = `cf6z4wiex30u8e`, Loki = `"loki"` (stream label UID)
- **Dashboard state drift**: if a folder containing Terraform-managed dashboards is deleted in the UI, Grafana deletes the dashboards too. Fix: `terraform state rm grafana_dashboard.<name>` then `terraform apply` to recreate
- **Contact point provisioning lock**: API-provisioned contact points show "provisioned, cannot be deleted via UI" — delete via Grafana API if needed
- **Loki datasource name is case-sensitive**: `name = "Loki"` (capital L) in `data "grafana_data_source"` lookups

## GitHub CLI

`gh` is available for PR review and commenting. Token is managed via keyring (`gh auth status` to verify):

```bash
gh pr list
gh pr view <id>
gh pr diff <id>
gh pr review <id> --comment -b "comment"
```

## Renovate

Major version bumps are held for manual review — chart schema changes often break values. Before merging a major:
- Check the chart changelog for values renames or removed keys
- Check if the deployment mode or architecture changed (e.g. Loki SimpleScalable deprecation)
- Test in a branch if the values migration is non-trivial
