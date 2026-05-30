# cluster-ops

GitOps management for a 3-node Raspberry Pi 4 (8GB) k3s homelab cluster. Flux CD reconciles everything from this repo.

## Core constraint

**kubectl is read-only.** All changes to cluster state go through git → Flux. Never use kubectl to mutate resources directly.

## Architecture

- **Nodes**: `blinky`, `inky`, `pinky` — single control plane (blinky), all run workloads
- **VIP**: kube-vip on `10.0.0.20`, load balancer range `10.0.0.30–39`
- **Storage**: Longhorn (RWO/RWX), 2 replicas, Retain policy
- **Reconciliation order**: `infra-controllers` → `infra-configs` → `apps` → `patches`
- **Secrets**: 1Password Connect via External Secrets Operator
- **Observability**: alloy-metrics (Mimir) + alloy-logs (Loki) via k8s-monitoring Helm chart, dashboards in Grafana

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

- **alloy-metrics** scrapes kube-state-metrics, cadvisor, kubelet → remote-writes to Mimir
- kube-state-metrics series count is the main driver of alloy-metrics WAL memory usage
- High ReplicaSet count (dead 0-replica RSes from Helm upgrades) inflates series — controlled via `revisionHistoryLimit: 1`
- Loki backend runs the compactor; node-red has 400-day retention which creates a large backlog — backend needs more memory than other Loki components

## GitLab CLI

`glab` is available for MR review and commenting. The token is in `CLAUDE_GITLAB_TOKEN` but glab reads `GITLAB_TOKEN`, so prefix all commands:

```bash
GITLAB_TOKEN=$CLAUDE_GITLAB_TOKEN glab mr list
GITLAB_TOKEN=$CLAUDE_GITLAB_TOKEN glab mr view <id>
GITLAB_TOKEN=$CLAUDE_GITLAB_TOKEN glab mr diff <id>
GITLAB_TOKEN=$CLAUDE_GITLAB_TOKEN glab mr note <id> -m "comment"
```

## Renovate

Major version bumps are held for manual review — chart schema changes often break values. Before merging a major:
- Check the chart changelog for values renames or removed keys
- Check if the deployment mode or architecture changed (e.g. Loki SimpleScalable deprecation)
- Test in a branch if the values migration is non-trivial
