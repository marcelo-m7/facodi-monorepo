# FACODI CI/CD

## Purpose

`facodi-monorepo` is the composition and deployment repository for the FACODI Odoo runtime. It does not own the implementation of the feature addons.

The active addon repositories are:

- `https://github.com/marcelo-m7/facodi-learning.git` -> technical Odoo module `facodi_learning`
- `https://github.com/marcelo-m7/facodi-theme.git` -> technical Odoo module `website_facodi`

They are consumed as pinned Git submodules under `addons/`.

## Build lifecycle

A deployment is always based on an immutable image:

```text
facodi-monorepo commit
  + facodi-learning pinned commit
  + facodi-theme pinned commit
                |
                v
         docker/Dockerfile
                |
                v
Artifact Registry image tagged with the monorepo Git SHA
```

The image path is:

```text
${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${GCP_ARTIFACT_REPOSITORY}/${FACODI_IMAGE_NAME}:${GITHUB_SHA}
```

The container never executes `git clone`, `git fetch`, `git checkout` or `git pull`.

The Docker build copies the checked-out addon repositories to a build-only source directory, discovers immediate Odoo module directories containing `__manifest__.py`, and copies those modules to `/mnt/extra-addons`. This allows each addon repository to keep repository-level documentation, workflows and other files outside the technical Odoo module directory.

## One-time Google Cloud bootstrap

The one-time infrastructure bootstrap is intentionally separate from recurring CI/CD.

```text
operator + gcloud
      |
      v
infrastructure/gcp/bootstrap-staging.sh
      |
      +--> required APIs
      +--> Artifact Registry
      +--> GitHub Workload Identity Federation
      +--> deploy/runtime service accounts
      +--> IAP + OS Login IAM
      +--> dual-stack Compute Engine VM
      +--> IPv4/IPv6 web firewall + IAP-only SSH
```

Run:

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/bootstrap-staging.sh
```

Then validate:

```bash
GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/validate-staging.sh
```

The validator prints the exact repository/environment variables needed by GitHub Actions. See [`gcp-staging.md`](gcp-staging.md) for the operator procedure.

The bootstrap does not create production resources, DNS records or application passwords.

## GitHub authentication to Google Cloud

GitHub Actions uses OpenID Connect and Google Workload Identity Federation. Do not create or upload a long-lived service-account JSON key.

Repository Actions variables expected by the workflows:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
DEPLOY_STAGING_ENABLED
DEPLOY_PRODUCTION_ENABLED
```

Recommended values for the current FACODI layout are conceptually:

```text
GCP_REGION=europe-southwest1
GCP_ARTIFACT_REPOSITORY=facodi
FACODI_IMAGE_NAME=odoo
DEPLOY_STAGING_ENABLED=false
DEPLOY_PRODUCTION_ENABLED=false
```

Use the actual Google Cloud project ID and Workload Identity resource names created for the project.

The bootstrap restricts the WIF provider to the exact GitHub repository `marcelo-m7/facodi-monorepo`. The deploy identity receives the permissions required to push Artifact Registry images and connect to the staging VM through IAP + OS Login. The VM has a separate runtime identity with Artifact Registry read access.

## Compute Engine runtime identity

The VM uses its own `facodi-runtime` Google Cloud service account and pulls the exact SHA-tagged Artifact Registry image with short-lived credentials from the instance metadata identity.

`deploy-image.sh` obtains an access token with:

```bash
gcloud auth print-access-token
```

and pipes that short-lived token to the Docker login command. This works whether Docker is directly available to the OS Login user or must be executed through passwordless sudo.

No Artifact Registry password or service-account JSON file is copied from GitHub to the VM.

## Administrative access

Staging SSH/SCP is forced through IAP TCP forwarding:

```text
GitHub Actions
     |
     | OIDC/WIF
     v
Google deploy service account
     |
     | IAP TCP tunnel
     v
VM internal IPv4 :22
```

The firewall allows TCP 22 only from Google's IAP TCP forwarding range `35.235.240.0/20` to instances tagged `facodi-admin`.

There is no `0.0.0.0/0 -> tcp:22` or `::/0 -> tcp:22` rule created by the FACODI bootstrap.

## Environment-specific GitHub variables

### Staging environment

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH
```

### Production environment

```text
PRODUCTION_VM_NAME
PRODUCTION_VM_ZONE
PRODUCTION_DEPLOY_PATH
```

Keep the repository variables `DEPLOY_STAGING_ENABLED` and `DEPLOY_PRODUCTION_ENABLED` set to `false` until the VMs, WIF provider, Artifact Registry repository and `.env` files are ready.

A typical deployment path is `/opt/facodi`.

## VM `.env`

The workflow deliberately does not overwrite `.env` on the server. Create it once on each VM and protect it with filesystem permissions.

Required runtime values include:

```text
POSTGRES_PASSWORD
ODOO_ADMIN_PASSWD
ODOO_DB
FACODI_MODULES=facodi_learning,website_facodi
```

`FACODI_IMAGE` is supplied by the deployment script for each release and does not need to be permanently pinned in `.env`.

For staging, follow the generated-secret procedure in [`gcp-staging.md`](gcp-staging.md) and keep `/opt/facodi/.env` readable only by the deployment user.

## Deployment sequence

For `staging` and `main`, when the respective deployment flag is enabled:

1. GitHub checks out the monorepo and all Git submodules recursively.
2. Repository architecture validation runs.
3. GitHub obtains a short-lived Google credential through Workload Identity Federation.
4. Docker discovers and bakes the technical Odoo modules from the pinned addon repositories into the image.
5. The image is pushed to Artifact Registry under `${GITHUB_SHA}`.
6. The deploy job authenticates to Google Cloud using WIF again.
7. For staging, GitHub opens IAP SSH/SCP tunnels and copies only `docker-compose.yml`, `deploy-image.sh` and `healthcheck.sh` to the VM.
8. The VM obtains a short-lived Google access token from its own runtime identity and authenticates Docker to Artifact Registry.
9. The VM pulls the exact SHA-tagged image.
10. PostgreSQL is started.
11. Missing FACODI modules are installed and already-installed FACODI modules are upgraded.
12. Odoo is started from the immutable image.
13. The HTTP health check must pass.

The VM does not need a clone of `facodi-monorepo` for application source code.

## Updating addon versions

The Gitlink entries in `facodi-monorepo` pin exact commits. To update an addon locally:

```bash
cd addons/facodi-learning
git fetch
git checkout <validated-commit>
cd ../..
git add addons/facodi-learning
git commit -m "chore: update facodi-learning"
```

Use the equivalent flow for `addons/facodi-theme`. Prefer commits whose addon repository CI has completed successfully.

The monorepo CI then installs the exact pinned modules together on a clean Odoo 19 database. This catches integration failures that may not appear when each addon is tested independently.

## Rollback

Rollback does not require source changes on the VM. Redeploy a previously known Artifact Registry image URI:

```bash
bash scripts/deploy-image.sh \
  europe-southwest1-docker.pkg.dev/<project>/facodi/odoo:<previous-monorepo-sha>
```

Database compatibility still matters: Odoo migrations performed by an addon may not always be reversible merely by downgrading the image. Database backups remain part of the production deployment policy.
