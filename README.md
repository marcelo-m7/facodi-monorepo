# FACODI Odoo

Composition, build and deployment repository for **FACODI — Faculdade Comunitária Digital** on Odoo 19 Community.

This repository pins exact addon/upstream commits, builds one immutable Odoo image and deploys that image to Google Compute Engine. Feature implementation remains in the dedicated addon repositories.

## Runtime composition

```text
marcelo-m7/facodi-learning  -> facodi_learning
marcelo-m7/facodi-theme     -> theme_facodi
odoo/design-themes          -> theme_common only
             \                 |                 /
              +------ pinned Git submodules ----+
                              |
                              v
                    facodi-monorepo
                              |
                    immutable Docker image
                              |
                    Artifact Registry :SHA
                              |
                    Compute Engine + Compose
                       /                 \
                    Odoo 19          PostgreSQL 16
                    filestore         database
```

The theme dependency is pinned at `odoo/design-themes@a1818df4ade65406c0cacae8b1ea676e6f70095f`. The Docker image copies **only** `theme_common`; unrelated official themes are not baked into the runtime.

The currently verified FACODI theme pin is `marcelo-m7/facodi-theme@e10bebb051bd6c15c47915a986b7c2168c837265`.

GitHub authenticates to Google Cloud with **OIDC + Workload Identity Federation**. Long-lived service-account JSON keys are not part of the design. The running Odoo container never performs `git pull` or any other source checkout.

## Submodules

```text
addons/facodi-learning
addons/facodi-theme
vendor/odoo-design-themes
```

Clone with:

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
  facodi-learning/          pinned addon repository
  facodi-theme/             pinned addon repository
vendor/
  odoo-design-themes/       pinned upstream; image consumes theme_common only
docker/
  Dockerfile                immutable Odoo 19 image
infrastructure/
  docker-compose.yml        persistent Odoo/PostgreSQL runtime
  gcp/                      one-time GCP/WIF/VM bootstrap
scripts/
  build-image.sh
  deploy-image.sh
  migrate-theme-module-name.sh
  apply-facodi-theme.sh
  healthcheck.sh
  validate-repository.sh
.github/workflows/
  ci.yml
  build-image.yml
  deploy-staging.yml
  deploy-production.yml
docs/
  architecture.md
  ci-cd.md
  deployment.md
  gcp-staging.md
```

## Local build

```bash
cp .env.example .env
bash scripts/build-image.sh facodi-odoo:local
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d
```

The default technical modules are:

```text
FACODI_MODULES=facodi_learning,theme_facodi
```

Odoo is bound to `127.0.0.1:8069` by default. Public HTTP/HTTPS must terminate at a reverse proxy; PostgreSQL is never published publicly.

## Odoo theme lifecycle

`theme_facodi` is a native Odoo Website theme, not a parallel website application. Installing the module registers its theme templates. Deployment then selects it through Odoo's standard `ir.module.module.button_choose_theme()` lifecycle for each website.

The runtime therefore follows this order:

```text
pull exact image
  -> stop Odoo
  -> start PostgreSQL
  -> guarded legacy transition if required
  -> install/update facodi_learning + theme_facodi
  -> select theme_facodi through Odoo theme API
  -> start Odoo
  -> health check
```

### Transition from `website_facodi`

The previous `website_facodi` addon was a presentation-only normal addon containing one known inherited layout view. The new implementation intentionally does **not** rename its XML IDs into theme-template XML IDs.

`scripts/migrate-theme-module-name.sh` performs a guarded one-time cleanup before `theme_facodi` is installed. It aborts instead of guessing if:

- both old and new module records exist;
- the old addon owns XML IDs other than its known `website_layout` view; or
- another custom view inherits from that legacy view.

It does not modify `website_page` records or Website Builder page content. Existing VM `.env` files that still contain `website_facodi` are normalized in-memory by `deploy-image.sh`; operators should nevertheless update them permanently to `theme_facodi`.

Because this first transition changes module registry/view metadata, take a matching **PostgreSQL + filestore backup** before deploying it to an existing environment. Image rollback alone is not a complete rollback boundary for that first deployment.

## CI

Pull requests run repository contracts, GCP bootstrap/login contracts, Compose validation, immutable image build and clean Odoo module installation against the exact recursive submodule pins.

The FACODI theme repository separately runs its Odoo 19 theme tests, including asset compilation, homepage rendering, `/slides`, standard favicon ownership and theme-template loading.

## CD

Branch mapping:

```text
staging -> staging environment
main    -> production environment
```

When enabled, deployment builds and pushes an image tagged with the exact monorepo SHA, copies only the Compose/runtime scripts to the VM, pulls that exact image using the VM runtime identity, runs the guarded module/theme lifecycle and performs the HTTP health check. No application repository clone is required on the VM.

## Required GitHub variables

Repository Actions variables:

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

Environment variables:

```text
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH
PRODUCTION_VM_NAME
PRODUCTION_VM_ZONE
PRODUCTION_DEPLOY_PATH
```

Keep deployment flags disabled until the corresponding VM, WIF configuration, Artifact Registry and root-owned runtime `.env` are ready.

## Persistence and rollback

The application image is disposable; state is not. Backups and restores must keep PostgreSQL and the matching Odoo filestore together.

For normal code-only releases, rollback selects a previous immutable image. If a deployment changed database/module metadata, restore the matching pre-deployment database and filestore as well.

See `docs/architecture.md`, `docs/ci-cd.md`, `docs/deployment.md` and `docs/gcp-staging.md` for details.
