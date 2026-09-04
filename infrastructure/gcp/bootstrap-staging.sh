#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage:
  GCP_PROJECT_ID=PROJECT_ID bash infrastructure/gcp/bootstrap-staging.sh

Required environment:
  GCP_PROJECT_ID

Common optional overrides:
  GCP_REGION                 default: europe-southwest1
  GCP_ZONE                   default: ${GCP_REGION}-b
  GCP_NETWORK                default: facodi-vpc
  GCP_SUBNET                 default: facodi-madrid
  GCP_ARTIFACT_REPOSITORY    default: facodi
  FACODI_IMAGE_NAME          default: odoo
  STAGING_VM_NAME            default: facodi-app-01
  STAGING_DEPLOY_PATH        default: /opt/facodi
  GCP_MACHINE_TYPE           default: e2-standard-2
  GCP_BOOT_DISK_SIZE         default: 30GB

The script is designed to be re-run. It creates missing staging resources
and refuses destructive replacement of the existing VPC/subnet.
EOF
  exit 0
fi

if (( $# > 0 )); then
  echo "unexpected arguments; use --help" >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_command gcloud

ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)"
[[ -n "$ACTIVE_ACCOUNT" ]] || die "no active gcloud account; run: gcloud auth login"
log "using gcloud account: $ACTIVE_ACCOUNT"
log "target project: $GCP_PROJECT_ID"

REQUIRED_APIS=(
  compute.googleapis.com
  artifactregistry.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  sts.googleapis.com
  iap.googleapis.com
  oslogin.googleapis.com
)

log "enabling required Google Cloud APIs"
gcloud services enable "${REQUIRED_APIS[@]}" \
  --project "$GCP_PROJECT_ID" \
  --quiet

if resource_exists gcloud artifacts repositories describe "$GCP_ARTIFACT_REPOSITORY" \
  --project "$GCP_PROJECT_ID" --location "$GCP_REGION"; then
  REPOSITORY_FORMAT="$(gcloud artifacts repositories describe "$GCP_ARTIFACT_REPOSITORY" \
    --project "$GCP_PROJECT_ID" --location "$GCP_REGION" --format='value(format)')"
  [[ "$REPOSITORY_FORMAT" == "DOCKER" ]] \
    || die "Artifact Registry repository $GCP_ARTIFACT_REPOSITORY exists but is not Docker: $REPOSITORY_FORMAT"
  log "Artifact Registry repository already exists: $GCP_ARTIFACT_REPOSITORY"
else
  log "creating Docker Artifact Registry repository: $GCP_ARTIFACT_REPOSITORY"
  gcloud artifacts repositories create "$GCP_ARTIFACT_REPOSITORY" \
    --project "$GCP_PROJECT_ID" \
    --location "$GCP_REGION" \
    --repository-format docker \
    --description "FACODI immutable Odoo images" \
    --quiet
fi

bash "$SCRIPT_DIR/configure-wif.sh"
bash "$SCRIPT_DIR/create-vm.sh"
bash "$SCRIPT_DIR/validate-staging.sh"
