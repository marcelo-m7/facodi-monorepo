# Docker Submodules CI/CD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `facodi-monorepo` into the immutable composition/build/deploy repository for Odoo 19 Community, with `facodi-learning` and `facodi-theme` maintained in separate repositories and attached as Git submodules.

**Architecture:** GitHub Actions resolves pinned submodule commits during checkout, builds one immutable Odoo image, authenticates to Google Cloud with GitHub OIDC/Workload Identity Federation, and pushes the image to Artifact Registry under the commit SHA. Compute Engine hosts only the runtime state and deployment files; deployment pulls the exact image tag and never performs `git pull` inside the Odoo container.

**Tech Stack:** Odoo 19 Community, Docker/Compose, PostgreSQL 16, Git submodules, GitHub Actions, Google Cloud Artifact Registry, Workload Identity Federation, Compute Engine.

**Spec:** approved conversation design: `marcelo-m7/facodi-learning` and `marcelo-m7/facodi-theme` are independent repositories, consumed by `marcelo-m7/facodi-monorepo` as submodules.

## Global Constraints

- Odoo base image remains `odoo:19.0`.
- PostgreSQL remains `postgres:16` with persistent volumes.
- Runtime containers never clone or pull source code.
- Docker images are addressed by immutable Git commit SHA.
- GitHub-to-Google authentication uses OIDC/Workload Identity Federation, not a long-lived service-account JSON key.
- `facodi-learning` maps to technical Odoo module `facodi_learning`.
- `facodi-theme` maps to technical Odoo module `facodi_theme`.
- Deploy workflows remain disabled until the required Google Cloud variables and environments are configured.

---

### Task 1: Repository contract and safety checks

**Files:**
- Create: `tests/test_repository_contract.sh`
- Create: `scripts/validate-repository.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: repository file layout.
- Produces: `scripts/validate-repository.sh`, a zero/non-zero validation command used by CI.

- [ ] Write a failing repository-contract test that requires the new Dockerfile, image-based Compose runtime, submodule placeholders or `.gitmodules`, WIF build workflow, and a deploy script that does not use `git pull`.
- [ ] Run the test in CI and verify that it fails because the new architecture is not yet implemented.
- [ ] Add `scripts/validate-repository.sh` and the required files until the contract passes.
- [ ] Keep Compose validation and an Odoo image build in CI.

### Task 2: Addon composition and immutable image

**Files:**
- Delete: `addons/facodi_core/__init__.py`
- Delete: `addons/facodi_core/__manifest__.py`
- Create: `addons/facodi-learning/README.md`
- Create: `addons/facodi-theme/README.md`
- Create: `scripts/attach-submodules.sh`
- Create: `docker/Dockerfile`
- Modify: `infrastructure/docker-compose.yml`
- Modify: `.env.example`

**Interfaces:**
- Consumes: source trees under `addons/facodi-learning` and `addons/facodi-theme`.
- Produces: Docker image containing both addon repositories under `/mnt/extra-addons`.

- [ ] Replace the embedded `facodi_core` addon with explicit future-submodule locations.
- [ ] Add a conversion script that removes placeholders and executes the two exact `git submodule add` commands once the repositories exist.
- [ ] Build from `odoo:19.0` and copy `addons/` into the image.
- [ ] Make Compose run `${FACODI_IMAGE}` rather than bind-mount addon source code.

### Task 3: Artifact Registry build through OIDC/WIF

**Files:**
- Create: `.github/workflows/build-image.yml`
- Create: `scripts/build-image.sh`

**Interfaces:**
- Consumes: repository checkout with recursive submodules and Google Cloud Actions variables.
- Produces: `${REGION}-docker.pkg.dev/${PROJECT}/${REPOSITORY}/${IMAGE}:${GITHUB_SHA}`.

- [ ] Create a reusable workflow with `id-token: write` and `contents: read`.
- [ ] Authenticate with `google-github-actions/auth` using Workload Identity Federation.
- [ ] Configure Artifact Registry Docker authentication.
- [ ] Build and push exactly one SHA-tagged FACODI Odoo image.

### Task 4: Image-only Compute Engine deployment

**Files:**
- Create: `scripts/deploy-image.sh`
- Modify: `.github/workflows/deploy-staging.yml`
- Modify: `.github/workflows/deploy-production.yml`
- Modify: `scripts/healthcheck.sh` if necessary.

**Interfaces:**
- Consumes: immutable Artifact Registry image URI, existing VM `.env`, Compute Engine metadata variables.
- Produces: running Odoo service using the requested image SHA.

- [ ] Use the reusable image-build workflow as a prerequisite to deployment.
- [ ] Authenticate the deploy job with the same GitHub OIDC/WIF model.
- [ ] Copy only Compose/deployment scripts to the VM with `gcloud compute scp`; never clone the application repository on the VM.
- [ ] Pull the immutable image, install/update `facodi_learning,facodi_theme`, restart Odoo and perform an HTTP health check.

### Task 5: Documentation and verification

**Files:**
- Modify: `README.md`
- Create: `docs/ci-cd.md`

**Interfaces:**
- Consumes: final workflows and runtime variables.
- Produces: setup instructions for Artifact Registry, WIF, VM service-account permissions, staging and production environments.

- [ ] Document repository responsibilities, submodule pinning, image lifecycle, required GitHub variables and required Google Cloud IAM roles.
- [ ] Verify repository contract, Compose parsing, Docker image build, and PR workflow status.
- [ ] Confirm the branch contains no long-lived Google credentials and no runtime `git pull`.
