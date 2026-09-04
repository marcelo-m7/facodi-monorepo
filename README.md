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
- `marcelo-m7/facodi-theme` -> Odoo technical module `website_facodi`

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
scripts/
  build-image.sh            build/push one immutable image
  deploy-image.sh           deploy a supplied image URI on a VM
  healthcheck.sh            HTTP readiness verification
  validate-repository.sh    architecture safety checks
.github/workflows/
  ci.yml                    contract, Compose, image build and clean install
  build-image.yml           reusable WIF + Artifact Registry build
  deploy-staging.yml        staging image build + Compute Engine deploy
  deploy-production.yml     production image build + Compute Engine deploy
docs/
  ci-cd.md                  Google Cloud and GitHub setup
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

## CI

Pull requests run:

```text
checkout recursive submodules
       -> repository contract
       -> Compose validation
       -> immutable Docker build
       -> PostgreSQL startup
       -> clean installation of discovered Odoo modules
```

The integration test therefore validates the exact addon commits pinned by the monorepo, not placeholders or mocks.

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
5. copies only the runtime Compose/deployment scripts to Compute Engine;
6. tells the VM to pull that exact image;
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

See [`docs/ci-cd.md`](docs/ci-cd.md) for the full Google Cloud setup and operational model.

## Runtime persistence

The image is disposable; state is not.

Persistent resources are kept separately:

- PostgreSQL database -> Docker volume / persistent disk strategy
- Odoo filestore -> Docker volume / persistent disk strategy
- runtime secrets -> VM `.env`, never Git

This separation means the Odoo application image can be rebuilt or rolled back without treating GitHub as a data store.
