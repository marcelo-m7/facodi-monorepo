# FACODI Engineering Workspace

`facodi-monorepo` is the **engineering control plane** for FACODI. It exists to give human and agentic contributors one place to plan, coordinate, inspect and integration-test work that spans the independent FACODI repositories.

It is **not the production deployment source of truth**. Production composition, runtime pins, migrations, Coolify lifecycle, backup/restore and rollout belong to [`marcelo-m7/facodi-deploy`](https://github.com/marcelo-m7/facodi-deploy).

## Control-plane split

```text
facodi-monorepo
  program + engineering control plane
  specs · plans · ADRs · backlog · agent instructions · integration contracts
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

Odoo remains the **operational/data control plane** and canonical source for FACODI product/domain records. Supabase is an **auxiliary/experimental capability** only; it is not a second source of truth and cannot become a production dependency without an explicit increment, security/observability contract and tests.

## Repository contract

- Business/domain code is changed in its owning repository and reviewed there.
- `facodi-monorepo` never becomes a second source of truth for addon code.
- A workspace checkout may combine branches from several repositories for integration testing.
- Only merged/approved component commits may be promoted into `facodi-deploy`.
- Deployment code must not be added here. Existing deployment-era files are legacy material pending an explicit parity/retirement issue.
- Agent work is organized as **Program → Workstream/Outcome → component issues → PRs → integration → deploy acceptance**.
- Priority uses **P0/P1/P2/P3**; execution gates use:
  - **AFK** — autonomous technical implementation;
  - **REVIEW** — independent code/integration review required;
  - **HITL** — a real editorial, operational or production decision requires a human.
- Marketing, community, partnerships and funding work are first-class program work even when they do not touch code.

See [AGENTS.md](AGENTS.md), [ARCHITECTURE.md](ARCHITECTURE.md), [WORKSPACE.yaml](WORKSPACE.yaml), the [program workstreams](docs/program/workstreams.md), and [intake/routing rules](docs/program/intake-and-routing.md).

## Program operating model

Program tracker: https://github.com/marcelo-m7/facodi-monorepo/issues/20  
GitHub Project board setup: https://github.com/marcelo-m7/facodi-monorepo/issues/44

The approved operating model is documented in [`docs/superpowers/specs/2026-09-24-facodi-program-operating-model-design.md`](docs/superpowers/specs/2026-09-24-facodi-program-operating-model-design.md).

FACODI is coordinated through eight workstreams:

1. Product & UX
2. Content & Curation
3. Odoo Engineering
4. Theme, i18n & Accessibility
5. AI & Automation
6. Community & Marketing
7. Partnerships & Funding
8. Operations & Release

New ideas enter through the program control plane, receive a workstream, outcome, priority, owner/proposed owner and target repository/system, then move to the repository or operational surface that actually owns the implementation.

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

The active product restructuring is tracked by [Program #7](https://github.com/marcelo-m7/facodi-monorepo/issues/7) and its vertical increments. The existing [integration/release Epic in `facodi-deploy`](https://github.com/marcelo-m7/facodi-deploy/issues/20) continues to reference the component issues already created across `facodi-learning`, `facodi-theme`, `facodi-ai` and `facodi-deploy`.

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
