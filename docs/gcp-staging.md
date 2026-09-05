# FACODI Google Cloud staging bootstrap

This document provisions the Google Cloud resources required by the existing `staging` GitHub Actions deployment without creating long-lived Google credentials.

## What the bootstrap creates

The bootstrap uses the current `gcloud` identity to create or validate:

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

The bootstrap does **not** create DNS records, the VM `.env`, application passwords, or production resources.

## Prerequisites

Install and authenticate Google Cloud CLI on the operator machine:

```bash
gcloud auth login
gcloud auth list
gcloud projects describe YOUR_PROJECT_ID
```

The target VPC/subnet must already exist and the subnet must be dual-stack with external IPv6 enabled.

Default network values used by the repository are:

```text
GCP_REGION=europe-southwest1
GCP_ZONE=europe-southwest1-b
GCP_NETWORK=facodi-vpc
GCP_SUBNET=facodi-madrid
```

Inspect the subnet before bootstrap:

```bash
gcloud compute networks subnets describe facodi-madrid \
  --project YOUR_PROJECT_ID \
  --region europe-southwest1 \
  --format='yaml(name,network,ipCidrRange,stackType,ipv6AccessType,externalIpv6Prefix)'
```

The expected values include:

```text
stackType: IPV4_IPV6
ipv6AccessType: EXTERNAL
```

## One-time bootstrap

Show the available configuration without credentials:

```bash
bash infrastructure/gcp/bootstrap-staging.sh --help
```

Run the bootstrap from an authenticated recursive clone of `facodi-monorepo`:

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/bootstrap-staging.sh
```

Optional values can be overridden without editing source code:

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID \
GCP_ZONE=europe-southwest1-b \
GCP_MACHINE_TYPE=e2-standard-2 \
GCP_BOOT_DISK_SIZE=30GB \
STAGING_VM_NAME=facodi-app-01 \
  bash infrastructure/gcp/bootstrap-staging.sh
```

The scripts are designed to be re-run. Existing compatible resources are reused. Critical mismatches such as an IPv4-only subnet or an existing firewall rule on another VPC cause the bootstrap to stop instead of silently replacing resources.

## Validate the cloud resources

Run:

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/validate-staging.sh
```

A successful run prints the repository variables expected by GitHub Actions, including the full Workload Identity Provider resource name. It also prints the public IPv4 and IPv6 values allocated to the staging VM for later DNS configuration.

## GitHub repository variables

Open:

`facodi-monorepo -> Settings -> Secrets and variables -> Actions -> Variables`

Add the values printed by `validate-staging.sh`:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
DEPLOY_STAGING_ENABLED=false
```

Do not create `GOOGLE_CREDENTIALS`, `GCP_KEY`, `service-account.json` or another long-lived Google key for this pipeline.

## GitHub staging environment variables

Create or edit the GitHub environment named `staging` and add:

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH
```

The default deploy path is `/opt/facodi`.

## Create the VM runtime `.env`

Connect through IAP rather than public SSH:

```bash
gcloud compute ssh facodi-app-01 \
  --project YOUR_PROJECT_ID \
  --zone europe-southwest1-b \
  --tunnel-through-iap
```

On the VM, wait for the startup script if necessary:

```bash
sudo journalctl -u google-startup-scripts.service --no-pager
sudo docker version
sudo docker compose version
gcloud --version
```

Generate the two sensitive values inside the SSH session so they never pass through GitHub:

```bash
POSTGRES_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"
ODOO_ADMIN_PASSWD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(36))')"
```

Create the runtime configuration as a **root-owned secret**. The GitHub OS Login identity does not need direct read access to `.env`; the final deployment script is executed with OS Login administrative `sudo` access.

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

Store the generated Odoo master password in the project's secure credential store if operators need it later. Do not commit the `.env` file.

This root-only ownership is intentional: a human operator and the GitHub service account use different OS Login Unix identities. Keeping `.env` owned by a human user with mode `600` would make automated deployment unable to read it.

## Enable the first staging deployment

Only after all previous validation succeeds, change the repository variable:

```text
DEPLOY_STAGING_ENABLED=true
```

Then either push a commit to `staging` or run the `Deploy staging` workflow manually.

The workflow will:

1. resolve both addon submodules recursively;
2. build one immutable Odoo image;
3. authenticate to Google Cloud through WIF;
4. push the SHA-tagged image to Artifact Registry;
5. connect to `facodi-app-01` through IAP;
6. copy only Compose and deployment scripts;
7. run the deployment script under OS Login administrative `sudo` so it can read root-owned runtime secrets;
8. authenticate Docker with the VM runtime identity's short-lived access token;
9. pull the exact image;
10. install/update `facodi_learning` and `theme_facodi`;
11. start Odoo and perform the HTTP health check.

## DNS and reverse proxy

The VM has IPv4 and IPv6, but Odoo remains bound to loopback ports `8069` and `8072`. The Google Cloud firewall exposes only TCP 80/443 publicly.

Do not point public DNS at the VM until a reverse proxy with TLS has been configured. DNS/reverse-proxy configuration is intentionally a separate deployment step.

The bootstrap reserves the external IPv4 address. The automatically assigned external IPv6 address is not treated as a separately reserved static IPv6 resource by this implementation.

## Re-running safely

The bootstrap may be executed again after partial completion:

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID bash infrastructure/gcp/bootstrap-staging.sh
```

It does not delete the VPC, subnet, VM disks, Docker volumes or application data.
