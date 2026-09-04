#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_command gcloud

DEPLOY_SA="$(service_account_email "$GCP_DEPLOY_SERVICE_ACCOUNT")"
RUNTIME_SA="$(service_account_email "$GCP_RUNTIME_SERVICE_ACCOUNT")"
PROJECT_NUMBER="$(project_number)"
POOL_RESOURCE="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${GCP_WIF_POOL}"
REPOSITORY_PRINCIPAL="principalSet://iam.googleapis.com/${POOL_RESOURCE}/attribute.repository/${GITHUB_REPOSITORY}"

ensure_service_account() {
  local account_id="$1"
  local display_name="$2"
  local email
  email="$(service_account_email "$account_id")"

  if resource_exists gcloud iam service-accounts describe "$email" --project "$GCP_PROJECT_ID"; then
    log "service account already exists: $email"
    return 0
  fi

  log "creating service account: $email"
  gcloud iam service-accounts create "$account_id" \
    --project "$GCP_PROJECT_ID" \
    --display-name "$display_name" \
    --quiet
}

ensure_service_account "$GCP_DEPLOY_SERVICE_ACCOUNT" "FACODI GitHub deploy"
ensure_service_account "$GCP_RUNTIME_SERVICE_ACCOUNT" "FACODI runtime"

if resource_exists gcloud iam workload-identity-pools describe "$GCP_WIF_POOL" \
  --project "$GCP_PROJECT_ID" --location global; then
  log "Workload Identity Pool already exists: $GCP_WIF_POOL"
else
  log "creating Workload Identity Pool: $GCP_WIF_POOL"
  gcloud iam workload-identity-pools create "$GCP_WIF_POOL" \
    --project "$GCP_PROJECT_ID" \
    --location global \
    --display-name "GitHub Actions" \
    --description "GitHub Actions identities for FACODI" \
    --quiet
fi

if resource_exists gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
  --project "$GCP_PROJECT_ID" --location global --workload-identity-pool "$GCP_WIF_POOL"; then
  issuer="$(gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
    --project "$GCP_PROJECT_ID" --location global --workload-identity-pool "$GCP_WIF_POOL" \
    --format='value(oidc.issuerUri)')"
  condition="$(gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
    --project "$GCP_PROJECT_ID" --location global --workload-identity-pool "$GCP_WIF_POOL" \
    --format='value(attributeCondition)')"
  [[ "$issuer" == "https://token.actions.githubusercontent.com" ]] || die "existing WIF provider uses unexpected issuer: $issuer"
  [[ "$condition" == "assertion.repository == '${GITHUB_REPOSITORY}'" ]] || die "existing WIF provider has unexpected attribute condition: $condition"
  log "Workload Identity Provider already exists and matches repository restriction"
else
  log "creating Workload Identity Provider: $GCP_WIF_PROVIDER"
  gcloud iam workload-identity-pools providers create-oidc "$GCP_WIF_PROVIDER" \
    --project "$GCP_PROJECT_ID" \
    --location global \
    --workload-identity-pool "$GCP_WIF_POOL" \
    --display-name "FACODI monorepo" \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --attribute-mapping "google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition "assertion.repository == '${GITHUB_REPOSITORY}'" \
    --quiet
fi

existing_wif_binding="$(gcloud iam service-accounts get-iam-policy "$DEPLOY_SA" \
  --project "$GCP_PROJECT_ID" \
  --flatten='bindings[].members' \
  --filter="bindings.role=roles/iam.workloadIdentityUser AND bindings.members=$REPOSITORY_PRINCIPAL" \
  --format='value(bindings.role)' | head -n1)"

if [[ "$existing_wif_binding" != "roles/iam.workloadIdentityUser" ]]; then
  log "granting repository Workload Identity User access"
  gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA" \
    --project "$GCP_PROJECT_ID" \
    --role roles/iam.workloadIdentityUser \
    --member "$REPOSITORY_PRINCIPAL" \
    --quiet >/dev/null
else
  log "repository Workload Identity User binding already present"
fi

for role in \
  roles/artifactregistry.writer \
  roles/iap.tunnelResourceAccessor \
  roles/compute.osAdminLogin \
  roles/compute.viewer; do
  ensure_project_role "serviceAccount:$DEPLOY_SA" "$role"
done

ensure_project_role "serviceAccount:$RUNTIME_SA" roles/artifactregistry.reader

existing_act_as="$(gcloud iam service-accounts get-iam-policy "$RUNTIME_SA" \
  --project "$GCP_PROJECT_ID" \
  --flatten='bindings[].members' \
  --filter="bindings.role=roles/iam.serviceAccountUser AND bindings.members=serviceAccount:$DEPLOY_SA" \
  --format='value(bindings.role)' | head -n1)"

if [[ "$existing_act_as" != "roles/iam.serviceAccountUser" ]]; then
  log "granting deploy identity permission to use runtime service account"
  gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_SA" \
    --project "$GCP_PROJECT_ID" \
    --role roles/iam.serviceAccountUser \
    --member "serviceAccount:$DEPLOY_SA" \
    --quiet >/dev/null
else
  log "runtime service-account user binding already present"
fi

PROVIDER_RESOURCE="$(gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
  --project "$GCP_PROJECT_ID" \
  --location global \
  --workload-identity-pool "$GCP_WIF_POOL" \
  --format='value(name)')"

cat <<EOF
GCP_WORKLOAD_IDENTITY_PROVIDER=$PROVIDER_RESOURCE
GCP_GITHUB_SERVICE_ACCOUNT=$DEPLOY_SA
EOF
