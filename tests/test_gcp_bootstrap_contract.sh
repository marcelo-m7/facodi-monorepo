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
grep -q 'attribute.ref=assertion.ref' infrastructure/gcp/configure-wif.sh
grep -q "assertion.ref == 'refs/heads/main'" infrastructure/gcp/configure-wif.sh
grep -q "assertion.ref == 'refs/heads/staging'" infrastructure/gcp/configure-wif.sh
grep -q 'ensure_artifact_repository_role' infrastructure/gcp/configure-wif.sh
grep -q 'roles/artifactregistry.writer' infrastructure/gcp/configure-wif.sh
grep -q 'roles/artifactregistry.reader' infrastructure/gcp/configure-wif.sh
grep -q -- '--tunnel-through-iap' .github/workflows/deploy-staging.yml
grep -q 'sudo -n bash scripts/deploy-image.sh' .github/workflows/deploy-staging.yml
grep -q 'gcloud auth print-access-token' scripts/deploy-image.sh

if grep -q 'ensure_project_role .*roles/artifactregistry' infrastructure/gcp/configure-wif.sh; then
  echo "Artifact Registry IAM must be scoped to the FACODI repository" >&2
  exit 1
fi

if grep -q 'roles/compute.viewer' infrastructure/gcp/configure-wif.sh; then
  echo "broad Compute Viewer role is not required for OS Login/IAP deployment" >&2
  exit 1
fi

if grep -R -E 'BEGIN PRIVATE KEY|"private_key"[[:space:]]*:' infrastructure/gcp .github/workflows; then
  echo "long-lived private key material must not be committed" >&2
  exit 1
fi

for script in infrastructure/gcp/*.sh scripts/deploy-image.sh; do
  bash -n "$script"
done

help_output="$(env -u GCP_PROJECT_ID bash infrastructure/gcp/bootstrap-staging.sh --help)"
grep -q 'GCP_PROJECT_ID' <<< "$help_output"
grep -q 'facodi-vpc' <<< "$help_output"
grep -q 'facodi-madrid' <<< "$help_output"

echo "GCP bootstrap repository contract passed"
