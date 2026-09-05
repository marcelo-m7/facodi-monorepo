# FACODI Google Cloud staging bootstrap

This document provisions the Google Cloud resources required by the `staging` GitHub Actions deployment without creating long-lived Google credentials.

## What the bootstrap creates

The bootstrap creates or validates:

- required Google Cloud APIs;
- Docker Artifact Registry repository `facodi`;
- GitHub Workload Identity Pool/provider restricted to `marcelo-m7/facodi-monorepo`;
- `facodi-github-deploy` service account for GitHub Actions;
- `facodi-runtime` service account for the VM;
- repository-scoped Artifact Registry writer/reader IAM;
- public IPv4/IPv6 HTTP/HTTPS firewall rules;
- IAP-only SSH firewall rule;
- a regional static external IPv4 address;
- dual-stack Compute Engine VM `facodi-app-01` on the existing FACODI subnet;
- Docker Engine, Docker Compose and Google Cloud CLI on the VM.

The bootstrap does **not** create DNS records, the VM `.env`, application passwords or production resources.

## Prerequisites

```bash
gcloud auth login
gcloud auth list
gcloud projects describe YOUR_PROJECT_ID
```

The target subnet must already be dual-stack with external IPv6 enabled. Current defaults:

```text
GCP_REGION=europe-southwest1
GCP_ZONE=europe-southwest1-b
GCP_NETWORK=facodi-vpc
GCP_SUBNET=facodi-madrid
```

Expected subnet properties include:

```text
stackType: IPV4_IPV6
ipv6AccessType: EXTERNAL
```

## One-time bootstrap and validation

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/bootstrap-staging.sh

GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/validate-staging.sh
```

The scripts are designed to be re-run. Existing compatible resources are reused; critical mismatches stop execution instead of replacing resources silently.

## GitHub variables

Repository Actions variables:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
DEPLOY_STAGING_ENABLED=false
```

GitHub environment `staging`:

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH
```

Default deploy path: `/opt/facodi`.

Do not create `GOOGLE_CREDENTIALS`, `GCP_KEY`, `service-account.json` or another long-lived Google key for this pipeline.

## Create the VM runtime `.env`

Connect through IAP:

```bash
gcloud compute ssh facodi-app-01 \
  --project YOUR_PROJECT_ID \
  --zone europe-southwest1-b \
  --tunnel-through-iap
```

Generate sensitive values inside the SSH session:

```bash
POSTGRES_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"
ODOO_ADMIN_PASSWD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"
```

Create a root-owned secret file:

```bash
sudo install -d -m 0755 /opt/facodi

sudo tee /opt/facodi/.env >/dev/null <<EOF
FACODI_MODULES=facodi_learning,theme_facodi
POSTGRES_USER=odoo
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
ODOO_DB=facodi_staging
ODOO_ADMIN_PASSWD=$ODOO_ADMIN_PASSWD
ODOO_PORT=8069
ODOO_GEVENT_PORT=8072
ODOO_WORKERS=2
ODOO_MAX_CRON_THREADS=1
ODOO_HEALTHCHECK_URL=http://127.0.0.1:8069/web/login
EOF

sudo chown root:root /opt/facodi/.env
sudo chmod 600 /opt/facodi/.env
unset POSTGRES_PASSWORD ODOO_ADMIN_PASSWD
```

If this VM already exists with `FACODI_MODULES=facodi_learning,website_facodi`, take a PostgreSQL + filestore backup before the first deployment of the native theme evolution. `deploy-image.sh` can normalize the old token for that deployment, but update the persisted file to `theme_facodi` afterward.

## Enable staging deployment

Only after infrastructure and runtime secrets are ready:

```text
DEPLOY_STAGING_ENABLED=true
```

Then push to `staging` or manually run `Deploy staging`.

The workflow will:

1. resolve `facodi-learning`, `facodi-theme` and the pinned `odoo/design-themes` submodules recursively;
2. build one immutable Odoo 19 image containing the FACODI modules plus only upstream `theme_common`;
3. authenticate to Google Cloud through WIF;
4. push the SHA-tagged image to Artifact Registry;
5. connect to `facodi-app-01` through IAP;
6. copy Compose and the deployment/theme-transition helpers;
7. run deployment under OS Login administrative `sudo` so the root-owned `.env` remains protected;
8. pull the exact image using the VM runtime identity;
9. stop Odoo and start PostgreSQL;
10. perform the guarded legacy `website_facodi` cleanup if required;
11. install/update `facodi_learning` and `theme_facodi`;
12. apply `theme_facodi` through Odoo's standard theme-selection API;
13. start Odoo and require the HTTP health check to pass.

## First theme-transition rollback boundary

The old `website_facodi` addon and the new native `theme_facodi` use different Odoo theme lifecycles. The migration helper removes only known legacy module/view metadata and refuses ambiguous states; it does not edit Website Builder pages.

If the first transition deployment must be rolled back, restore the **pre-deployment PostgreSQL database and matching filestore together with the previous image**. Do not manually recreate old module metadata.

## DNS and reverse proxy

The VM has IPv4 and IPv6, while Odoo remains bound to loopback ports `8069` and `8072`. Public firewall exposure is limited to TCP 80/443. Point DNS at the VM only after reverse proxy and TLS configuration are ready.

## Re-running safely

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID bash infrastructure/gcp/bootstrap-staging.sh
```

The bootstrap does not delete the VPC, subnet, VM disks, Docker volumes or application data.
