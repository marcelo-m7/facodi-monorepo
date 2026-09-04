#!/usr/bin/env bash
set -euo pipefail

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

if [[ -f "$SCRIPT_DIR/validate-staging.sh" ]]; then
  bash "$SCRIPT_DIR/validate-staging.sh"
fi
