#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_command gcloud

DEPLOY_SA="$(service_account_email "$GCP_DEPLOY_SERVICE_ACCOUNT")"
RUNTIME_SA="$(service_account_email "$GCP_RUNTIME_SERVICE_ACCOUNT")"
WIF_CONDITION="assertion.repository == '${GITHUB_REPOSITORY}' && (assertion.ref == 'refs/heads/main' || assertion.ref == 'refs/heads/staging')"

REQUIRED_APIS=(
  compute.googleapis.com
  artifactregistry.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  sts.googleapis.com
  iap.googleapis.com
  oslogin.googleapis.com
)

for api in "${REQUIRED_APIS[@]}"; do
  enabled="$(gcloud services list --enabled \
    --project "$GCP_PROJECT_ID" \
    --filter="config.name=$api" \
    --format='value(config.name)' | head -n1)"
  [[ "$enabled" == "$api" ]] || die "required API is not enabled: $api"
done

resource_exists gcloud artifacts repositories describe "$GCP_ARTIFACT_REPOSITORY" \
  --project "$GCP_PROJECT_ID" --location "$GCP_REGION" \
  || die "Artifact Registry repository missing: $GCP_ARTIFACT_REPOSITORY"
AR_FORMAT="$(gcloud artifacts repositories describe "$GCP_ARTIFACT_REPOSITORY" \
  --project "$GCP_PROJECT_ID" --location "$GCP_REGION" --format='value(format)')"
[[ "$AR_FORMAT" == "DOCKER" ]] \
  || die "Artifact Registry repository is not Docker: ${AR_FORMAT:-unset}"

for service_account in "$DEPLOY_SA" "$RUNTIME_SA"; do
  resource_exists gcloud iam service-accounts describe "$service_account" --project "$GCP_PROJECT_ID" \
    || die "service account missing: $service_account"
done

resource_exists gcloud iam workload-identity-pools describe "$GCP_WIF_POOL" \
  --project "$GCP_PROJECT_ID" --location global \
  || die "Workload Identity Pool missing: $GCP_WIF_POOL"

resource_exists gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
  --project "$GCP_PROJECT_ID" --location global --workload-identity-pool "$GCP_WIF_POOL" \
  || die "Workload Identity Provider missing: $GCP_WIF_PROVIDER"

PROVIDER_RESOURCE="$(gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
  --project "$GCP_PROJECT_ID" \
  --location global \
  --workload-identity-pool "$GCP_WIF_POOL" \
  --format='value(name)')"
PROVIDER_ISSUER="$(gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
  --project "$GCP_PROJECT_ID" \
  --location global \
  --workload-identity-pool "$GCP_WIF_POOL" \
  --format='value(oidc.issuerUri)')"
PROVIDER_CONDITION="$(gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" \
  --project "$GCP_PROJECT_ID" \
  --location global \
  --workload-identity-pool "$GCP_WIF_POOL" \
  --format='value(attributeCondition)')"
[[ "$PROVIDER_ISSUER" == "https://token.actions.githubusercontent.com" ]] \
  || die "unexpected Workload Identity issuer: $PROVIDER_ISSUER"
[[ "$PROVIDER_CONDITION" == "$WIF_CONDITION" ]] \
  || die "unexpected Workload Identity condition: $PROVIDER_CONDITION"

resource_exists gcloud compute networks describe "$GCP_NETWORK" --project "$GCP_PROJECT_ID" \
  || die "VPC network missing: $GCP_NETWORK"
resource_exists gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" \
  || die "subnet missing: $GCP_SUBNET"

SUBNET_NETWORK="$(gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(network)')"
SUBNET_STACK="$(gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(stackType)')"
SUBNET_IPV6_ACCESS="$(gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(ipv6AccessType)')"
[[ "$SUBNET_NETWORK" == */networks/"$GCP_NETWORK" ]] \
  || die "subnet is attached to unexpected VPC: $SUBNET_NETWORK"
[[ "$SUBNET_STACK" == "IPV4_IPV6" ]] \
  || die "subnet is not dual-stack IPV4_IPV6: ${SUBNET_STACK:-unset}"
[[ "$SUBNET_IPV6_ACCESS" == "EXTERNAL" ]] \
  || die "subnet does not use external IPv6: ${SUBNET_IPV6_ACCESS:-unset}"

for rule in facodi-allow-web-ipv4 facodi-allow-web-ipv6 facodi-allow-ssh-iap; do
  resource_exists gcloud compute firewall-rules describe "$rule" --project "$GCP_PROJECT_ID" \
    || die "firewall rule missing: $rule"
done

resource_exists gcloud compute addresses describe "$STAGING_IPV4_NAME" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" \
  || die "reserved staging IPv4 missing: $STAGING_IPV4_NAME"
RESERVED_IPV4="$(gcloud compute addresses describe "$STAGING_IPV4_NAME" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(address)')"

resource_exists gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  || die "staging VM missing: $STAGING_VM_NAME"

VM_SUBNET="$(gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  --format='value(networkInterfaces[0].subnetwork)')"
VM_STACK="$(gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  --format='value(networkInterfaces[0].stackType)')"
VM_INTERNAL_IPV4="$(gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  --format='value(networkInterfaces[0].networkIP)')"
VM_EXTERNAL_IPV4="$(gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
VM_EXTERNAL_IPV6="$(gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  --format='value(networkInterfaces[0].ipv6AccessConfigs[0].externalIpv6)')"
VM_SERVICE_ACCOUNT="$(gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE" \
  --format='value(serviceAccounts[0].email)')"

[[ "$VM_SUBNET" == */subnetworks/"$GCP_SUBNET" ]] \
  || die "VM is attached to unexpected subnet: $VM_SUBNET"
[[ "$VM_STACK" == "IPV4_IPV6" ]] \
  || die "VM is not dual-stack IPV4_IPV6: ${VM_STACK:-unset}"
[[ -n "$VM_INTERNAL_IPV4" ]] || die "VM internal IPv4 is missing"
[[ -n "$VM_EXTERNAL_IPV4" ]] || die "VM external IPv4 is missing"
[[ "$VM_EXTERNAL_IPV4" == "$RESERVED_IPV4" ]] \
  || die "VM external IPv4 does not match reserved address: VM=$VM_EXTERNAL_IPV4 reserved=$RESERVED_IPV4"
[[ -n "$VM_EXTERNAL_IPV6" ]] || die "VM external IPv6 is missing"
[[ "$VM_SERVICE_ACCOUNT" == "$RUNTIME_SA" ]] \
  || die "VM uses unexpected runtime service account: $VM_SERVICE_ACCOUNT"

cat <<EOF

FACODI staging validation passed.

GitHub repository variables:
GCP_PROJECT_ID=$GCP_PROJECT_ID
GCP_REGION=$GCP_REGION
GCP_ARTIFACT_REPOSITORY=$GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME=$FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER=$PROVIDER_RESOURCE
GCP_GITHUB_SERVICE_ACCOUNT=$DEPLOY_SA
DEPLOY_STAGING_ENABLED=false

GitHub environment 'staging' variables:
STAGING_VM_NAME=$STAGING_VM_NAME
STAGING_VM_ZONE=$GCP_ZONE
STAGING_DEPLOY_PATH=$STAGING_DEPLOY_PATH

DNS values for later configuration:
STAGING_EXTERNAL_IPV4=$VM_EXTERNAL_IPV4
STAGING_EXTERNAL_IPV6=$VM_EXTERNAL_IPV6
EOF
