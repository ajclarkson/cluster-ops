#!/usr/bin/env bash
# Refreshes the vendored keycloak-operator CRDs from a jsdelivr mirror of
# keycloak/keycloak-k8s-resources (raw.githubusercontent.com rate-limits
# repeated fetches, jsdelivr doesn't). Also bumps the CRD_VERSION marker
# that the custom Renovate manager in renovate.json tracks.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version, e.g. 26.5.0>" >&2
  exit 1
fi

version="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
crds_dir="$repo_root/infrastructure/controllers/keycloak-operator/crds"
kustomization="$repo_root/infrastructure/controllers/keycloak-operator/kustomization.yaml"

files=(
  keycloaks.k8s.keycloak.org-v1.yml
  keycloakrealmimports.k8s.keycloak.org-v1.yml
  kubernetes.yml
)

for f in "${files[@]}"; do
  url="https://cdn.jsdelivr.net/gh/keycloak/keycloak-k8s-resources@${version}/kubernetes/${f}"
  echo "fetching ${f}..."
  curl -sfL --max-time 20 -o "${crds_dir}/${f}" "$url"
done

sed -i.bak -E "s/# CRD_VERSION: [0-9]+\.[0-9]+\.[0-9]+/# CRD_VERSION: ${version}/" "$kustomization"
rm -f "${kustomization}.bak"

echo "done. review the diff, then commit."
