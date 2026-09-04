#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_command gcloud

RUNTIME_SA="$(service_account_email "$GCP_RUNTIME_SERVICE_ACCOUNT")"

resource_exists gcloud compute networks describe "$GCP_NETWORK" --project "$GCP_PROJECT_ID" \
  || die "VPC network not found: $GCP_NETWORK"

resource_exists gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" \
  || die "subnet not found: $GCP_SUBNET in $GCP_REGION"

SUBNET_NETWORK="$(gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(network)')"
SUBNET_STACK="$(gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(stackType)')"
SUBNET_IPV6_ACCESS="$(gcloud compute networks subnets describe "$GCP_SUBNET" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(ipv6AccessType)')"

[[ "$SUBNET_NETWORK" == */networks/"$GCP_NETWORK" ]] \
  || die "subnet $GCP_SUBNET is attached to a different VPC: $SUBNET_NETWORK"
[[ "$SUBNET_STACK" == "IPV4_IPV6" ]] \
  || die "subnet $GCP_SUBNET must be dual-stack IPV4_IPV6; found: ${SUBNET_STACK:-unset}"
[[ "$SUBNET_IPV6_ACCESS" == "EXTERNAL" ]] \
  || die "subnet $GCP_SUBNET must use external IPv6 access; found: ${SUBNET_IPV6_ACCESS:-unset}"

ensure_firewall_rule() {
  local name="$1"
  local source_range="$2"
  local rules="$3"
  local target_tag="$4"

  if resource_exists gcloud compute firewall-rules describe "$name" --project "$GCP_PROJECT_ID"; then
    local rule_network
    rule_network="$(gcloud compute firewall-rules describe "$name" \
      --project "$GCP_PROJECT_ID" --format='value(network)')"
    [[ "$rule_network" == */networks/"$GCP_NETWORK" ]] \
      || die "firewall rule $name exists on a different VPC: $rule_network"
    log "firewall rule already exists: $name"
    return 0
  fi

  log "creating firewall rule: $name"
  gcloud compute firewall-rules create "$name" \
    --project "$GCP_PROJECT_ID" \
    --network "$GCP_NETWORK" \
    --direction INGRESS \
    --action ALLOW \
    --rules "$rules" \
    --source-ranges "$source_range" \
    --target-tags "$target_tag" \
    --quiet
}

ensure_firewall_rule facodi-allow-web-ipv4 '0.0.0.0/0' 'tcp:80,tcp:443' facodi-web
ensure_firewall_rule facodi-allow-web-ipv6 '::/0' 'tcp:80,tcp:443' facodi-web
ensure_firewall_rule facodi-allow-ssh-iap '35.235.240.0/20' 'tcp:22' facodi-admin

if resource_exists gcloud compute addresses describe "$STAGING_IPV4_NAME" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION"; then
  log "static external IPv4 already exists: $STAGING_IPV4_NAME"
else
  log "reserving static external IPv4: $STAGING_IPV4_NAME"
  gcloud compute addresses create "$STAGING_IPV4_NAME" \
    --project "$GCP_PROJECT_ID" \
    --region "$GCP_REGION" \
    --network-tier PREMIUM \
    --quiet
fi

STAGING_IPV4="$(gcloud compute addresses describe "$STAGING_IPV4_NAME" \
  --project "$GCP_PROJECT_ID" --region "$GCP_REGION" --format='value(address)')"
[[ -n "$STAGING_IPV4" ]] || die "failed to resolve static external IPv4: $STAGING_IPV4_NAME"

if resource_exists gcloud compute instances describe "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" --zone "$GCP_ZONE"; then
  log "VM already exists: $STAGING_VM_NAME"
else
  log "creating dual-stack staging VM: $STAGING_VM_NAME"
  gcloud compute instances create "$STAGING_VM_NAME" \
    --project "$GCP_PROJECT_ID" \
    --zone "$GCP_ZONE" \
    --machine-type "$GCP_MACHINE_TYPE" \
    --subnet "$GCP_SUBNET" \
    --stack-type IPV4_IPV6 \
    --address "$STAGING_IPV4" \
    --network-tier PREMIUM \
    --ipv6-network-tier PREMIUM \
    --service-account "$RUNTIME_SA" \
    --scopes cloud-platform \
    --tags facodi-web,facodi-admin \
    --metadata enable-oslogin=TRUE \
    --metadata-from-file startup-script="$SCRIPT_DIR/vm-startup.sh" \
    --image-family debian-12 \
    --image-project debian-cloud \
    --boot-disk-size "$GCP_BOOT_DISK_SIZE" \
    --quiet
fi

cat <<EOF
STAGING_VM_NAME=$STAGING_VM_NAME
STAGING_VM_ZONE=$GCP_ZONE
STAGING_IPV4=$STAGING_IPV4
EOF
