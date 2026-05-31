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

### 1. Node prep

Flash Raspberry Pi OS Lite (64-bit) directly to NVMe via Raspberry Pi Imager. Set static IP leases on the router (`.51/.52/.53`).

On each node, apply the following before installing k3s:

```bash
# Enable cgroup memory (required for k3s)
sudo sed -i 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt

# Reduce GPU memory split (headless node)
echo 'gpu_mem=16' | sudo tee -a /boot/firmware/config.txt

# Install open-iscsi for Longhorn
sudo apt install -y open-iscsi
sudo systemctl enable iscsid

sudo reboot
```

### 2. Install k3s

First master:
```bash
k3sup install \
  --ip 10.0.0.51 \
  --tls-san 10.0.0.50 \
  --tls-san rackman.local.clarksons.me \
  --cluster \
  --k3s-channel latest \
  --no-extras \
  --local-path $HOME/.kube/config \
  --user ajclarkson \
  --merge
```

Additional masters:
```bash
k3sup join \
  --ip 10.0.0.52 \
  --server-ip 10.0.0.51 \
  --server \
  --k3s-channel latest \
  --user ajclarkson \
  --k3s-extra-args '--disable=traefik --disable=servicelb --disable-network-policy'
```

Repeat for `10.0.0.53`.

### 3. Bootstrap Flux

```bash
flux bootstrap gitlab \
  --owner=ajclarkson \
  --repository=cluster-ops \
  --branch=main \
  --path=clusters/rackman
```

Flux will reconcile the rest from this repo. Reconciliation order: `infra-crds` → `infra-controllers` → `infra-configs` → `apps` → `patches`.

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
