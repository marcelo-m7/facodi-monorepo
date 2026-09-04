#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_files=(
  infrastructure/gcp/lib.sh
  infrastructure/gcp/bootstrap-staging.sh
  infrastructure/gcp/configure-wif.sh
  infrastructure/gcp/create-vm.sh
  infrastructure/gcp/vm-startup.sh
  infrastructure/gcp/validate-staging.sh
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing GCP bootstrap file: $file" >&2
    exit 1
  fi
done

grep -q 'IPV4_IPV6' infrastructure/gcp/create-vm.sh
grep -q '35.235.240.0/20' infrastructure/gcp/create-vm.sh
grep -q 'roles/iam.workloadIdentityUser' infrastructure/gcp/configure-wif.sh
grep -q 'attribute.repository' infrastructure/gcp/configure-wif.sh
grep -q -- '--tunnel-through-iap' .github/workflows/deploy-staging.yml

if grep -R -E 'BEGIN PRIVATE KEY|"private_key"[[:space:]]*:' infrastructure/gcp .github/workflows; then
  echo "long-lived private key material must not be committed" >&2
  exit 1
fi

for script in infrastructure/gcp/*.sh; do
  bash -n "$script"
done

echo "GCP bootstrap repository contract passed"
