# cluster-ops

GitOps repo for a 3-node Raspberry Pi 5 k3s homelab cluster. Flux CD reconciles all cluster state from this repo — `kubectl` is read-only.

## Hardware

| Node | IP | Role |
|------|----|------|
| blinky | 10.0.0.51 | control-plane + worker |
| inky | 10.0.0.52 | control-plane + worker |
| pinky | 10.0.0.53 | control-plane + worker |

- 3-master HA with embedded etcd
- 256GB NVMe per node
- kube-vip control-plane VIP: `10.0.0.50` (`rackman.local.clarksons.me`)
- kube-vip load balancer pool: `10.0.0.30–39`

## Bootstrap

### 1. Flash nodes

Flash Raspberry Pi OS Lite (64-bit) directly to NVMe via Raspberry Pi Imager. In **OS Customisation**:

- Set username to `ajclarkson`
- Paste your SSH public key and enable SSH
- Set the hostname (`blinky` / `inky` / `pinky`)

Set static IP leases on the router (`.51/.52/.53`).

### 2. Node prep

From your local machine, once all three nodes are booted and reachable:

```bash
scripts/prep-all-nodes.sh
```

This SSHes into each node, enables cgroup memory, reduces GPU memory split, installs `open-iscsi`, and reboots. It waits for each node to come back before moving on.

### 3. Install k3s and bootstrap Flux

```bash
scripts/cluster-install.sh
```

Installs k3s on the first master via `k3sup`, joins the other two, then runs `flux bootstrap`. Requires `k3sup`, `flux`, and `kubectl` on your local machine.

Flux will reconcile the rest from this repo. Reconciliation order: `infra-crds` → `infra-controllers` → `infra-configs` → `apps` → `patches`.

> **Note:** kube-vip is deployed by Flux, so the control-plane VIP (`10.0.0.50`) won't exist until after bootstrap completes. This is fine — k3sup uses direct node IPs throughout, and the VIP is pre-added as a TLS SAN so it works as soon as kube-vip comes up. Once it does, update your kubeconfig server address from `10.0.0.51` to `10.0.0.50` to get HA control-plane access.

## Key services

| Service | URL |
|---------|-----|
| Grafana | grafana.local.clarksons.me |
| Longhorn | longhorn.local.clarksons.me |
| Keycloak | sso.local.clarksons.me |
| Home Assistant | homeassistant.local.clarksons.me |

SSO via oauth2-proxy (Keycloak + Google IdP) in front of services without native auth. Custom first-broker flow disables account auto-registration.

## Operational notes

See `CLAUDE.md` for key patterns, gotchas, and runbooks (RWO PVC deadlocks, SSA field ownership conflicts, Mimir ring surgery, etc.).
