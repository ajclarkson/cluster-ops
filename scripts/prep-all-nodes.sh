#!/usr/bin/env bash
# Run from your local machine after flashing and booting all three nodes.
# Assumes: SSH key auth already works (set up via Raspberry Pi Imager).
# Copies node-prep.sh to each node, runs it, and waits for the node to reboot.
set -euo pipefail

NODES=(10.0.0.51 10.0.0.52 10.0.0.53)
USER=ajclarkson
SCRIPT="$(dirname "$0")/node-prep.sh"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

wait_for_ssh() {
  local ip=$1
  echo "  waiting for $ip to come back up..."
  for i in $(seq 1 30); do
    if ssh $SSH_OPTS "$USER@$ip" true 2>/dev/null; then
      echo "  $ip is up"
      return 0
    fi
    sleep 10
  done
  echo "  timed out waiting for $ip" >&2
  return 1
}

for IP in "${NODES[@]}"; do
  echo "==> Prepping $IP"
  scp $SSH_OPTS "$SCRIPT" "$USER@$IP:/tmp/node-prep.sh"
  ssh $SSH_OPTS "$USER@$IP" "sudo bash /tmp/node-prep.sh" || true
  # node reboots — wait for it to return before moving on
  sleep 15
  wait_for_ssh "$IP"
done

echo "==> All nodes prepped. Run cluster-install.sh next."
