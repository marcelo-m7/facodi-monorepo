# FACODI Odoo Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a reproducible Odoo 19 Community runtime for FACODI with an installable addon skeleton and separate staging/production GitHub deployment paths.

**Architecture:** Run Odoo and PostgreSQL with Docker Compose on Google Compute Engine. Keep code in GitHub, keep PostgreSQL and filestore persistent, and deploy branches over SSH with an explicit module install/update step and health check.

**Tech Stack:** Odoo 19 Community, PostgreSQL 16, Docker Compose, Bash, GitHub Actions, Google Compute Engine.

**Spec:** `docs/architecture.md`

## Global Constraints

- Odoo version: 19.0 Community.
- Branch `staging` deploys only to staging.
- Branch `main` deploys only to production.
- PostgreSQL must not be published on a host port.
- Odoo HTTP/gevent ports bind only to loopback.
- Secrets must not be committed.

---

### Task 1: Runtime and installable addon skeleton

**Files:**
- Create: `addons/facodi_core/__init__.py`
- Create: `addons/facodi_core/__manifest__.py`
- Create: `infrastructure/docker-compose.yml`
- Create: `.env.example`
- Test: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: installable Odoo module named `facodi_core` and Compose services `db` and `odoo`.

- [x] Add the minimal `facodi_core` manifest with Odoo 19 version metadata.
- [x] Define PostgreSQL and Odoo services with persistent volumes and no public database port.
- [x] Add CI that validates Compose and installs `facodi_core` on a clean database.

### Task 2: Safe branch deployment

**Files:**
- Create: `scripts/deploy.sh`
- Create: `scripts/healthcheck.sh`
- Create: `.github/workflows/deploy-staging.yml`
- Create: `.github/workflows/deploy-production.yml`

**Interfaces:**
- Consumes: Compose services from Task 1.
- Produces: `bash scripts/deploy.sh <branch>` with module install/update detection and HTTP health verification.

- [x] Fetch and fast-forward the requested branch.
- [x] Pull container images and start PostgreSQL.
- [x] Detect whether `facodi_core` is installed and select `-i` or `-u`.
- [x] Run Odoo with `--stop-after-init`, restart the service, and run the health check.
- [x] Configure separate GitHub workflows and secret namespaces for staging and production.

### Task 3: Operations documentation

**Files:**
- Create: `docs/architecture.md`
- Create: `docs/deployment.md`
- Modify: `README.md`

**Interfaces:**
- Produces: operator instructions for VM bootstrap, DNS/firewall, GitHub secrets and branch flow.

- [x] Document the dual-stack VPC and exposure policy.
- [x] Document persistent data boundaries and backup requirements.
- [x] Document first deployment and GitHub Environment configuration.
