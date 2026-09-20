# FACODI Engineering Workspace

`facodi-monorepo` is the **engineering control plane** for FACODI. It exists to give human and agentic contributors one place to plan, coordinate, inspect and integration-test work that spans the independent FACODI repositories.

It is **not the production deployment source of truth**. Production composition, runtime pins, migrations, Coolify lifecycle, backup/restore and rollout belong to [`marcelo-m7/facodi-deploy`](https://github.com/marcelo-m7/facodi-deploy).

## Control-plane split

```text
facodi-monorepo
  engineering control plane
  specs · plans · ADRs · agent instructions · integration contracts
        |
        +----> facodi-learning   curriculum/eLearning/domain
        +----> facodi-theme      public Website/UI/UX
        +----> facodi-ai         optional AI/provider runtime
        +----> monodoo           reusable Odoo backend UX
        +----> monynha-odoo      shared components when explicitly consumed
        |
        +----> facodi-deploy
               deployment control plane
               pins · image · migrations · CI acceptance · Coolify · rollback
```

Odoo remains the operational/data control plane.

## Repository contract

- Business/domain code is changed in its owning repository and reviewed there.
- `facodi-monorepo` never becomes a second source of truth for addon code.
- A workspace checkout may combine branches from several repositories for integration testing.
- Only merged/approved component commits may be promoted into `facodi-deploy`.
- Deployment code must not be added here. Existing deployment-era files are legacy material pending an explicit parity/retirement issue.
- Agent work is organized as **Program → Increment → component issues → PRs → integration → deploy acceptance**.
- Work is classified as:
  - **AFK** — autonomous technical implementation;
  - **REVIEW** — independent code/integration review required;
  - **HITL** — a real editorial, operational or production decision requires a human.

See [AGENTS.md](AGENTS.md), [ARCHITECTURE.md](ARCHITECTURE.md) and [WORKSPACE.yaml](WORKSPACE.yaml).

## Bootstrap

The preferred workspace is clone-based, not deployment-pin-based:

```bash
git clone https://github.com/marcelo-m7/facodi-monorepo.git
cd facodi-monorepo
./scripts/bootstrap-workspace.sh
./scripts/workspace-status.sh
```

Component repositories are cloned under `workspace/`, which is ignored by this repository. Existing historical submodules remain temporarily for transition compatibility and must not be treated as the new workspace contract.

## Current program

The active product restructuring is tracked in this repository as a Program and vertical increments. The existing implementation Epic in `facodi-deploy` remains the integration/release tracker and continues to reference the component issues already created across `facodi-learning`, `facodi-theme`, `facodi-ai` and `facodi-deploy`.

The first product slice is:

```text
official UAlg curriculum
  -> draft import
  -> human review/version publication
  -> public curriculum
  -> curricular unit
  -> approved FACODI course coverage
  -> standard Odoo eLearning course/content
```

The source curriculum is institutional reference data. FACODI does not award ECTS, institutional equivalence or academic degrees.

## Legacy deployment material

This repository historically owned image build and GCP deployment. Those files are preserved during the transition so history and operational knowledge are not discarded before parity is checked. New deployment work belongs only in `facodi-deploy`; a dedicated transition issue governs removal/archival of the old Docker, infrastructure and deployment workflows.
