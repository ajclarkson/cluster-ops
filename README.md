# cluster-ops

GitOps repo for a k3s homelab cluster. Flux CD reconciles all cluster state from this repo — `kubectl` is read-only.

## Hardware

| Node | IP | Arch | Role |
|------|----|------|------|
| blinky | 10.0.0.51 | arm64 | control-plane + worker |
| inky | 10.0.0.52 | arm64 | control-plane + worker |
| pinky | 10.0.0.53 | arm64 | control-plane + worker |
| clyde | 10.0.0.54 | amd64 | worker (heavy/amd64 workloads) |

- 3-master HA with embedded etcd (blinky/inky/pinky)
- 256GB NVMe per RPi node
- clyde (BOSGAME E4 Mini PC) — AMD Ryzen 5 3550H, 16GB RAM, 512GB SSD (amd64 workloads, Frigate)
- kube-vip control-plane VIP: `10.0.0.50` (`rackman.local.clarksons.me`)
- kube-vip load balancer pool: `10.0.0.30–39`

> **Mixed-arch cluster:** RPi nodes are linux/arm64, BOSGAME is linux/amd64. Workloads targeting the BOSGAME must use `nodeAffinity` for `role=frigate`. Do not use multi-arch images that assume a single architecture.

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

### Adding a worker node (x86, e.g. BOSGAME)

Different process from the RPi nodes — Debian minimal install, no RPi-specific prep needed.

**1. Install Debian**

Flash a USB with Debian 13 netinstall. During install: set hostname, create user `ajclarkson`, enable SSH server, no desktop. Set a static DHCP lease on the router.

**2. Post-install setup (SSH in as ajclarkson, use root password when prompted)**

```bash
ssh ajclarkson@10.0.0.54

# Install fundamentals (run as root via su)
su -c 'apt-get install -y sudo passwd curl wget apt-transport-https'

# Add user to sudo (no password required — needed for k3sup)
su -c 'echo "ajclarkson ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ajclarkson'

# Log out and back in for sudo to take effect
exit
ssh ajclarkson@10.0.0.54

# Install open-iscsi for Longhorn
sudo apt-get install -y open-iscsi
sudo systemctl enable iscsid && sudo systemctl start iscsid

# Copy SSH key from local machine then disable password auth
# (run ssh-copy-id from your Mac first, then:)
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
exit
```

**3. Join the cluster (from local machine)**

```bash
k3sup join \
  --ip 10.0.0.54 \
  --server-ip 10.0.0.50 \
  --user ajclarkson \
  --k3s-channel latest
```

> Point at the VIP (`10.0.0.50`) not a specific control-plane node. No `--disable` flags needed — those are control-plane only. k3sup requires passwordless sudo on the remote node (handled above).

**4. Label for workload scheduling**

```bash
# No custom label needed — kubernetes.io/arch=amd64 is set automatically.
# Workloads target clyde via nodeAffinity on that standard label.
```

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
