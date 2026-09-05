# FACODI Odoo

Composition, build and deployment repository for **FACODI — Faculdade Comunitária Digital** on Odoo 19 Community.

This repository does **not** own the feature addons. It pins their exact Git commits, builds one immutable Odoo image and deploys that image to Google Compute Engine.

## Architecture

```text
marcelo-m7/facodi-learning     marcelo-m7/facodi-theme
          |                              |
          +---------- Git submodules ----+
                         |
                         v
              marcelo-m7/facodi-monorepo
                         |
                  GitHub Actions
                         |
          checkout submodules recursively
                         |
                 docker/Dockerfile
                         |
                         v
              Google Artifact Registry
          odoo:<facodi-monorepo-commit-sha>
                         |
                         v
               Google Compute Engine
                 Docker Compose
                /              \
        Odoo 19 image       PostgreSQL 16
        persistent filestore persistent DB
```

GitHub authenticates to Google Cloud with **OIDC + Workload Identity Federation**. Long-lived Google service-account JSON keys are not part of the design.

The running Odoo container never performs `git pull`. Every deployed image contains the exact addon versions pinned by the monorepo commit.

## Addon repositories

The active submodules are:

- `marcelo-m7/facodi-learning` -> Odoo technical module `facodi_learning`
- `marcelo-m7/facodi-theme` -> Odoo technical module `theme_facodi`

The repository names and Odoo technical module names are intentionally independent. The Git submodule stores a repository commit; the Docker image discovers the Odoo module directories inside each checked-out repository and copies them into `/mnt/extra-addons`.

Current submodule paths:

```text
addons/facodi-learning
addons/facodi-theme
```

Clone locally with:

```bash
git clone --recurse-submodules https://github.com/marcelo-m7/facodi-monorepo.git
```

For an existing clone:

```bash
git submodule update --init --recursive
```

## Repository structure

```text
addons/
  facodi-learning/          Git submodule
  facodi-theme/             Git submodule
docker/
  Dockerfile                Odoo 19 image with discovered modules baked in
infrastructure/
  docker-compose.yml        persistent Odoo/PostgreSQL runtime
  gcp/
    bootstrap-staging.sh    one-time GCP staging orchestration
    configure-wif.sh        GitHub OIDC/WIF + service-account IAM
    create-vm.sh            dual-stack VM, firewall and static IPv4
    validate-staging.sh     cloud validation + GitHub variable output
    vm-startup.sh           Docker/gcloud VM preparation
scripts/
  gcp-login.sh              interactive gcloud install/login + local dotenv setup
  build-image.sh            build/push one immutable image
  deploy-image.sh           deploy a supplied image URI on a VM
  healthcheck.sh            HTTP readiness verification
  validate-repository.sh    architecture safety checks
.github/workflows/
  ci.yml                    contract, GCP bootstrap contract, Compose, image build and clean install
  build-image.yml           reusable WIF + Artifact Registry build
  deploy-staging.yml        staging image build + IAP/Compute Engine deploy
  deploy-production.yml     production image build + Compute Engine deploy
docs/
  ci-cd.md                  GitHub and image delivery model
  gcp-staging.md            one-time staging provisioning/operator guide
  architecture.md
  deployment.md
```

## Local image build

Copy the runtime configuration:

```bash
cp .env.example .env
```

Build the same image structure used by CI:

```bash
bash scripts/build-image.sh facodi-odoo:local
```

Start the runtime:

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d
```

Odoo is bound to `127.0.0.1:8069` by default. Put a reverse proxy in front of it for public HTTP/HTTPS access.

## Bootstrap Google Cloud staging

The repository includes an idempotent `gcloud` bootstrap for the first staging environment. It expects the FACODI VPC/subnet to exist already and validates that the subnet is dual-stack with external IPv6.

For an operator workstation, the helper below checks whether Google Cloud CLI is installed. If it is missing on Debian, Ubuntu or the Debian Linux environment used by ChromeOS, it asks before installing it from Google's official APT repository. It then performs interactive login, lists the accessible projects, validates the selected FACODI project and upserts the non-sensitive GCP/FACODI configuration into the existing `.env` without deleting unrelated entries:

```bash
bash scripts/gcp-login.sh
```

The helper never writes Google OAuth access/refresh tokens or service-account private keys to `.env`; those credentials remain managed by `gcloud`. The `.env` file remains ignored by Git and is set to mode `0600`.

After login, load the values and run the bootstrap:

```bash
set -a
source .env
set +a

bash infrastructure/gcp/bootstrap-staging.sh
```

Then validate and obtain the exact GitHub variable values:

```bash
bash infrastructure/gcp/validate-staging.sh
```

You can still use the explicit form if preferred:

```bash
gcloud auth login
GCP_PROJECT_ID=YOUR_PROJECT_ID \
  bash infrastructure/gcp/bootstrap-staging.sh
```

The bootstrap creates no service-account JSON key and no Odoo/PostgreSQL password. Keep `DEPLOY_STAGING_ENABLED=false` until `/opt/facodi/.env` exists on the VM and validation succeeds.

See [`docs/gcp-staging.md`](docs/gcp-staging.md) for the complete staging setup.

## CI

Pull requests run:

```text
checkout recursive submodules
       -> repository contract
       -> GCP bootstrap contract
       -> GCP login helper contract
       -> Compose validation
       -> immutable Docker build
       -> PostgreSQL startup
       -> clean installation of discovered Odoo modules
```

The integration test therefore validates the exact addon commits pinned by the monorepo, not placeholders or mocks. The GCP bootstrap and login-helper contracts run without cloud credentials.

## CD

The intended branch mapping is:

```text
staging -> staging FACODI environment
main    -> production FACODI environment
```

When deployment is enabled, the corresponding workflow:

1. checks out the monorepo plus recursive submodules;
2. authenticates to Google Cloud using GitHub OIDC/WIF;
3. builds the Odoo image;
4. pushes it to Artifact Registry tagged with the exact Git SHA;
5. connects to staging through IAP and copies only the runtime Compose/deployment scripts;
6. tells the VM to pull that exact image using the VM runtime identity;
7. installs missing FACODI modules or upgrades already-installed ones;
8. starts Odoo and runs a health check.

No application repository clone is required on the VM.

## Required GitHub Actions variables

Repository-level variables:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
DEPLOY_STAGING_ENABLED=false
DEPLOY_PRODUCTION_ENABLED=false
```

Staging environment variables:

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH
```

Production environment variables:

```text
PRODUCTION_VM_NAME
PRODUCTION_VM_ZONE
PRODUCTION_DEPLOY_PATH
```

Keep both deploy enable flags `false` until Artifact Registry, Workload Identity Federation, the Compute Engine VM and its `.env` file are configured.

See [`docs/ci-cd.md`](docs/ci-cd.md) for the image delivery model and [`docs/gcp-staging.md`](docs/gcp-staging.md) for the staging infrastructure bootstrap.

## Runtime persistence

The image is disposable; state is not.

Persistent resources are kept separately:

- PostgreSQL database -> Docker volume / persistent disk strategy
- Odoo filestore -> Docker volume / persistent disk strategy
- runtime secrets -> VM `.env`, never Git

This separation means the Odoo application image can be rebuilt or rolled back without treating GitHub as a data store.
