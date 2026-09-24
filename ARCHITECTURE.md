# FACODI repository architecture

## Control planes

FACODI uses explicit control planes with a strict source-of-truth split.

### Program / engineering control plane — `facodi-monorepo`

Coordinates product outcomes, workstreams, architecture, agent work and cross-repository integration. It may check out multiple repositories under `workspace/`, but those checkouts are disposable and never become production artefacts.

### Source-of-truth codebases

- `facodi-learning` — Odoo eLearning/domain extensions.
- `facodi-theme` — Website theme and public presentation.
- `facodi-ai` — optional AI integration.
- `monodoo` — reusable backend identity/usability.
- `monynha-odoo` — shared modules when explicitly consumed.

Each repository keeps its own tests, history, PRs and releases.

### Deployment control plane — `facodi-deploy`

Owns the reproducible Odoo 19 Community runtime: exact component revisions, image composition, migration gate, Coolify lifecycle, CI/release acceptance, backup/restore and rollback.

### Operational/data control plane — Odoo

Odoo owns the database and canonical FACODI product/domain state: Website/eLearning records, users/permissions, Roadmaps/UCs/modules as implemented by FACODI, courses, contents, approved mappings, editorial state, learning progress and runtime operations.

### Auxiliary/experimental plane — Supabase

Supabase may host bounded experiments such as asynchronous processing prototypes, telemetry or isolated worker concepts. It is not canonical FACODI state and must not become a required production dependency without a dedicated approved increment that defines:

- why Odoo-first is insufficient for that capability;
- contracts and ownership;
- authentication/authorization and RLS;
- retries/idempotency;
- observability and failure handling;
- automated tests;
- promotion/rollback criteria.

### Evidence / working-document plane — Google Drive

Google Drive holds institutional evidence, finance/supporting documents, media and working documents. It does not replace GitHub for code/contracts or Odoo for operational product state.

## Promotion flow

```text
Program / Workstream / Outcome
    |
    v
component issues
    |
    v
component branches + PRs
    |
    v
component tests
    |
    v
cross-repo integration workspace
    |
    v
merged component SHAs
    |
    v
facodi-deploy pin update
    |
    v
deploy acceptance
    |
    +--> staging
    |
    +--> HITL release gate
    |
    v
production
```

## Product rule

The curriculum/product restructuring keeps standard Odoo authoritative:

- `slide.channel` is the canonical learner-facing course;
- `slide.slide` is canonical learner-facing content;
- FACODI curriculum reference/unit/coverage models store external curriculum facts and reviewed evidence;
- official curriculum facts come from institutional sources and are versioned;
- public pages expose only published references and approved coverage, filtered by native Website/access visibility;
- AI may propose relationships, but approval/publication remains governed by FACODI/Odoo review rules.

## Legacy transition

Before this split, `facodi-monorepo` also contained deployment and infrastructure code. That history remains useful, but it is no longer the ownership contract. Removal or archival must happen only after a parity check confirms that `facodi-deploy` contains every still-required operational procedure.
