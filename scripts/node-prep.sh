#!/usr/bin/env bash
# Run on each node before installing k3s. Reboots at the end.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo $0)" >&2
  exit 1
fi

CMDLINE=/boot/firmware/cmdline.txt
CONFIG=/boot/firmware/config.txt

# Enable cgroup memory — required for k3s
if ! grep -q 'cgroup_enable=memory' "$CMDLINE"; then
  sed -i 's/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' "$CMDLINE"
  echo "cgroup args added to $CMDLINE"
else
  echo "cgroup args already present, skipping"
fi

# Reduce GPU memory split for headless node
if ! grep -q 'gpu_mem=16' "$CONFIG"; then
  echo 'gpu_mem=16' >> "$CONFIG"
  echo "gpu_mem=16 added to $CONFIG"
else
  echo "gpu_mem already set, skipping"
fi

# Install open-iscsi for Longhorn
apt-get install -y open-iscsi
systemctl enable iscsid

echo "Node prep complete — rebooting in 5 seconds"
sleep 5
reboot
