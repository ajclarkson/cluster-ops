#!/usr/bin/env bash
# Run from your local machine after all three nodes have been prepped and rebooted.
# Requires: k3sup, flux, kubectl
set -euo pipefail

USER=ajclarkson
FIRST_MASTER=10.0.0.51
EXTRA_MASTERS=(10.0.0.52 10.0.0.53)
VIP=10.0.0.50
VIP_DNS=rackman.local.clarksons.me
K3S_CHANNEL=latest
JOIN_ARGS="--disable=traefik --disable=servicelb --disable-network-policy"

for cmd in k3sup flux kubectl; do
  command -v "$cmd" >/dev/null || { echo "missing dependency: $cmd" >&2; exit 1; }
done

echo "==> Installing first master ($FIRST_MASTER)"
k3sup install \
  --ip "$FIRST_MASTER" \
  --tls-san "$VIP" \
  --tls-san "$VIP_DNS" \
  --cluster \
  --k3s-channel "$K3S_CHANNEL" \
  --no-extras \
  --local-path "$HOME/.kube/config" \
  --user "$USER" \
  --merge

echo "==> Waiting for first master to be ready"
kubectl wait node --all --for=condition=Ready --timeout=120s

for IP in "${EXTRA_MASTERS[@]}"; do
  echo "==> Joining master $IP"
  k3sup join \
    --ip "$IP" \
    --server-ip "$FIRST_MASTER" \
    --server \
    --k3s-channel "$K3S_CHANNEL" \
    --user "$USER" \
    --k3s-extra-args "$JOIN_ARGS"
done

echo "==> Waiting for all masters to be ready"
kubectl wait node --all --for=condition=Ready --timeout=180s

echo "==> Bootstrapping Flux"
flux bootstrap gitlab \
  --owner=ajclarkson \
  --repository=cluster-ops \
  --branch=main \
  --path=clusters/rackman

echo "==> Done. Flux will reconcile the rest."
