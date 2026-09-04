#!/usr/bin/env bash
set -euo pipefail

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
: "${GCP_REGION:=europe-southwest1}"
: "${GCP_ZONE:=${GCP_REGION}-b}"
: "${GCP_NETWORK:=facodi-vpc}"
: "${GCP_SUBNET:=facodi-madrid}"
: "${GCP_ARTIFACT_REPOSITORY:=facodi}"
: "${FACODI_IMAGE_NAME:=odoo}"
: "${STAGING_VM_NAME:=facodi-app-01}"
: "${STAGING_DEPLOY_PATH:=/opt/facodi}"
: "${GCP_MACHINE_TYPE:=e2-standard-2}"
: "${GCP_BOOT_DISK_SIZE:=30GB}"
: "${GITHUB_REPOSITORY:=marcelo-m7/facodi-monorepo}"
: "${GCP_WIF_POOL:=github}"
: "${GCP_WIF_PROVIDER:=facodi-monorepo}"
: "${GCP_DEPLOY_SERVICE_ACCOUNT:=facodi-github-deploy}"
: "${GCP_RUNTIME_SERVICE_ACCOUNT:=facodi-runtime}"
: "${STAGING_IPV4_NAME:=facodi-staging-ipv4}"

export GCP_PROJECT_ID GCP_REGION GCP_ZONE GCP_NETWORK GCP_SUBNET
export GCP_ARTIFACT_REPOSITORY FACODI_IMAGE_NAME STAGING_VM_NAME STAGING_DEPLOY_PATH
export GCP_MACHINE_TYPE GCP_BOOT_DISK_SIZE GITHUB_REPOSITORY GCP_WIF_POOL GCP_WIF_PROVIDER
export GCP_DEPLOY_SERVICE_ACCOUNT GCP_RUNTIME_SERVICE_ACCOUNT STAGING_IPV4_NAME

log() {
  printf '[facodi-gcp] %s\n' "$*"
}

die() {
  printf '[facodi-gcp] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || die "required command not found: $command_name"
}

resource_exists() {
  "$@" >/dev/null 2>&1
}

service_account_email() {
  local account_id="$1"
  printf '%s@%s.iam.gserviceaccount.com\n' "$account_id" "$GCP_PROJECT_ID"
}

project_number() {
  gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)'
}

ensure_project_role() {
  local member="$1"
  local role="$2"
  local existing

  existing="$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" \
    --flatten='bindings[].members' \
    --filter="bindings.role=$role AND bindings.members=$member" \
    --format='value(bindings.role)' | head -n1)"

  if [[ "$existing" == "$role" ]]; then
    log "IAM binding already present: $member -> $role"
    return 0
  fi

  log "granting project role: $member -> $role"
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="$member" \
    --role="$role" \
    --quiet >/dev/null
}

ensure_artifact_repository_role() {
  local member="$1"
  local role="$2"
  local existing

  existing="$(gcloud artifacts repositories get-iam-policy "$GCP_ARTIFACT_REPOSITORY" \
    --project "$GCP_PROJECT_ID" \
    --location "$GCP_REGION" \
    --flatten='bindings[].members' \
    --filter="bindings.role=$role AND bindings.members=$member" \
    --format='value(bindings.role)' | head -n1)"

  if [[ "$existing" == "$role" ]]; then
    log "Artifact Registry binding already present: $member -> $role"
    return 0
  fi

  log "granting Artifact Registry role: $member -> $role"
  gcloud artifacts repositories add-iam-policy-binding "$GCP_ARTIFACT_REPOSITORY" \
    --project "$GCP_PROJECT_ID" \
    --location "$GCP_REGION" \
    --member "$member" \
    --role "$role" \
    --quiet >/dev/null
}
