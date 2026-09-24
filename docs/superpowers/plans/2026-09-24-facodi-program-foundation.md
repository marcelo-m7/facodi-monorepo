# FACODI Program Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the approved FACODI operating model into an actionable program-control foundation in GitHub and Supabase, without changing product behavior or production Odoo code.

**Architecture:** `facodi-monorepo` becomes the explicit cross-repository program/intake layer; implementation issues remain in their owning repositories and `facodi-deploy` remains the release boundary. Odoo stays canonical for product/domain data. Supabase remains auxiliary/experimental and receives only a bounded security hardening change in this plan.

**Tech Stack:** GitHub Issues + Markdown, FACODI multi-repository workspace, Supabase Postgres project `bhfywztfyidvrlarebmg`, Google Drive references for funding/collaboration evidence.

**Spec:** `docs/superpowers/specs/2026-09-24-facodi-program-operating-model-design.md`

## Global Constraints

- `facodi-monorepo` is the program-level engineering control plane and must not become a deployable monolith.
- `facodi-deploy` remains the canonical composition/release boundary for production.
- Odoo is the FACODI operational core and canonical product/domain store.
- Supabase is an auxiliary/experimental capability and must not silently become a second source of truth.
- Odoo standard-first: extend standard Odoo instead of recreating it.
- Course remains `slide.channel` where applicable; learning content remains `slide.slide`.
- Approved mappings may be published; pending suggestions remain private.
- PT/EN are product requirements, not cleanup work.
- Accessibility, responsive behavior and SEO are part of Definition of Done.
- No credentials, API keys, passwords or production secrets in GitHub issues, specs, code, XML, QWeb, JS or committed environment files.
- Gustavo is the proposed Community & Marketing owner only after account/role confirmation; no financial, spending, ownership or equity authority is implied.
- Existing SEA-EU budget documentation is evidence/input, not blanket authorization for new spending.

## Review Focus

1. **New ideas accidentally bypass the control-plane split:** a contributor should be able to determine whether work belongs in monorepo, addon repo, deploy repo, Odoo data or an experiment without reading historical discussions.
2. **Existing engineering issues become duplicated rather than linked:** program/workstream issues must reference existing component issues instead of recreating equivalent implementation work.
3. **Supabase security hardening changes intended application behavior:** the migration must only remove unnecessary invocation rights from `public.rls_auto_enable()` and leave its event-trigger behavior intact.
4. **Gustavo receives implied authority beyond marketing/outreach:** work items must say “proposed owner” until account confirmation and must not assign financial authority, purchases or equity.
5. **Funding backlog treats a €4,000 planning sheet as free/uncommitted balance:** issues must distinguish requested budget, approved budget, committed spend, paid spend and currently available balance.

---

### Task 1: Align the program-control documentation

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `ARCHITECTURE.md`
- Modify: `docs/product-restructure-program.md`
- Create: `docs/program/workstreams.md`
- Create: `docs/program/intake-and-routing.md`

**Interfaces:**
- Consumes: the approved operating-model spec and the existing Program #7/repository ownership contract.
- Produces: one discoverable program contract that contributors and agents can use to classify new work.

- [ ] **Step 1: Read the current files and preserve existing valid ownership/release rules**

Confirm before editing that:
- `facodi-monorepo` is already documented as engineering control plane;
- `facodi-deploy` is already documented as deployment control plane;
- component ownership remains `facodi-learning`, `facodi-theme`, `facodi-ai`;
- historical deploy material remains governed by the existing transition issue.

Expected: no ownership inversion is introduced.

- [ ] **Step 2: Update `README.md` with the expanded program scope**

Add a concise “Program operating model” section linking the approved spec and explaining the eight workstreams:
`Product & UX`, `Content & Curation`, `Odoo Engineering`, `Theme/i18n/Accessibility`, `AI & Automation`, `Community & Marketing`, `Partnerships & Funding`, `Operations & Release`.

Keep the existing Program #7 as the current engineering/product-restructure program rather than rewriting its historical purpose.

- [ ] **Step 3: Update `AGENTS.md` with the intake/routing rule**

Add rules that:
- every idea starts as a program work item;
- implementation lives only in the owning repository;
- cross-repo issues link child issues instead of duplicating them;
- P0/P1/P2/P3 describes impact, while AFK/REVIEW/HITL describes execution gate;
- marketing/funding work is valid program work even when it does not touch code.

- [ ] **Step 4: Update architecture/program docs without making Supabase canonical**

Document:
```text
Odoo = operational/data control plane
GitHub monorepo = program/engineering control plane
facodi-deploy = deployment control plane
Supabase = auxiliary/experimental capability
Google Drive = institutional/media/working-document evidence
```

Explicitly state that a Supabase experiment requires a separate approved increment before becoming a production dependency.

- [ ] **Step 5: Create `docs/program/workstreams.md`**

For each workstream record:
- purpose;
- owning/participating repositories;
- proposed human owner if known;
- inputs;
- outputs;
- definition of done;
- prohibited ownership.

For Community & Marketing, record “Gustavo — proposed owner; GitHub/Odoo account confirmation pending”.

- [ ] **Step 6: Create `docs/program/intake-and-routing.md`**

Define an idea intake template:
```markdown
## Outcome
## User/problem
## Workstream
## Priority (P0/P1/P2/P3)
## Owner / proposed owner
## Target repository or operational system
## Dependencies
## Evidence/source
## Acceptance criteria
## Gate (AFK/REVIEW/HITL)
```

Include routing examples:
- homepage component → Product & UX + `facodi-theme`;
- UC mapping → Content & Curation + `facodi-learning`/Odoo;
- Coolify release → Operations & Release + `facodi-deploy`;
- social campaign → Community & Marketing, no addon repository;
- experimental async processor → AI & Automation + Supabase experiment, not canonical until promoted.

- [ ] **Step 7: Verify documentation consistency**

Read back all six files and assert there is no statement that:
- deploys come from `facodi-monorepo`;
- Supabase is the canonical backend;
- `facodi-deploy` owns business logic;
- AI may auto-approve/publish academic mappings.

Expected: all four assertions are false.

- [ ] **Step 8: Commit**

Commit message:
`docs(program): establish FACODI operating model`

---

### Task 2: Create the cross-functional FACODI program backlog

**Files/Systems:**
- GitHub Issues in `marcelo-m7/facodi-monorepo`
- Existing Program #7 remains linked, not replaced.

**Interfaces:**
- Consumes: Task 1 workstream and intake contracts.
- Produces: one umbrella program issue and eight workstream epics that become the entry points for future ideas.

- [ ] **Step 1: Create an umbrella issue**

Title:
`[Program] FACODI Product, Community & Sustainability`

Body must:
- link the approved spec;
- link Program #7 as the active engineering/product-restructure stream;
- list the four immediate outcomes from the spec;
- list the eight workstreams;
- state Odoo core / Supabase auxiliary boundary;
- explain P0–P3 and AFK/REVIEW/HITL;
- include a checklist for the eight workstream issues.

- [ ] **Step 2: Create the eight workstream issues**

Create:
1. `[Workstream] Product & UX`
2. `[Workstream] Content & Curation`
3. `[Workstream] Odoo Engineering`
4. `[Workstream] Theme, i18n & Accessibility`
5. `[Workstream] AI & Automation`
6. `[Workstream] Community & Marketing`
7. `[Workstream] Partnerships & Funding`
8. `[Workstream] Operations & Release`

Each issue must use the intake contract and link back to the umbrella issue.

- [ ] **Step 3: Add current existing programs/issues as dependencies, not duplicates**

Cross-link:
- Program #7 and INC-01…INC-08;
- `facodi-deploy` integration Epic #20;
- current `facodi-learning`, `facodi-theme`, `facodi-ai`, and deploy component issues.

Do not create a second copy of any already-defined implementation task.

- [ ] **Step 4: Verify issue graph**

Read the umbrella and eight workstream issues back.

Expected:
- every workstream links to the umbrella;
- engineering workstreams link existing component issues;
- no implementation issue body was duplicated verbatim.

---

### Task 3: Establish the first four outcome epics

**Files/Systems:**
- GitHub Issues in `marcelo-m7/facodi-monorepo`

**Interfaces:**
- Consumes: Task 2 workstream issue URLs.
- Produces: four outcome-level epics that organize the next delivery cycle across repositories.

- [ ] **Step 1: Create Outcome 1 — discovery-to-learning UX**

Title:
`[Outcome] Discovery → Learning: frontend, copy and navigation coherence`

Scope:
- homepage/component utilization;
- taxonomy/navigation;
- Roadmap → UC → module → course/content continuity;
- PT/EN copy;
- responsive/accessibility/SEO;
- reuse/enrichment of existing components before adding new ones.

Link existing theme/learning/navigation issues instead of replacing them.

- [ ] **Step 2: Create Outcome 2 — submission experience**

Title:
`[Outcome] Make content submission guided, dynamic and reviewable`

Scope:
- inspect current Odoo submission flow first;
- use Tube O2 only as a UX/reference pattern;
- clear pending/processing/review/published/failed states where supported by FACODI domain;
- Odoo owns submission and final review/publication state;
- any Supabase prototype is isolated and removable.

No direct Tube O2 dependency is created.

- [ ] **Step 3: Create Outcome 3 — content and approved mappings**

Title:
`[Outcome] Expand published learning content and reviewed mappings`

Scope:
- reconcile/import real learning content;
- provenance/license/source review;
- approved mappings only on public surfaces;
- visible gaps rather than invented coverage;
- content quality and discovery.

Link current content workflow/catalog/coverage issues.

- [ ] **Step 4: Create Outcome 4 — delegation and sustainability**

Title:
`[Outcome] Delegate community growth and build a funding pipeline`

Scope:
- Gustavo marketing workstream;
- social/editorial cadence;
- partnerships/outreach;
- funding/sponsorship investigation;
- operating metrics;
- no financial authority implied.

- [ ] **Step 5: Verify each outcome has a measurable acceptance condition**

Examples:
- UX outcome: a new anonymous visitor can go homepage → Roadmap/UC → available course/content without losing context.
- Submission outcome: a contributor sees a clear persisted state and next action after submitting.
- Content outcome: selected real content is reviewed/published/mapped with provenance, with unresolved gaps explicit.
- Sustainability outcome: recurring marketing backlog has an owner/cadence and funding opportunities have status/evidence/next action.

---

### Task 4: Create Gustavo's bounded Community & Marketing backlog

**Files/Systems:**
- GitHub Issues in `facodi-monorepo`
- Google Drive evidence/materials are linked, not copied into GitHub.

**Interfaces:**
- Consumes: Community & Marketing workstream and existing FACODI communication assets.
- Produces: a practical non-engineering backlog that can be assigned after Gustavo's GitHub identity is confirmed.

- [ ] **Step 1: Create “channel and account inventory” issue**

Acceptance:
- list current social/community channels;
- identify owner/access status;
- identify missing account(s);
- do not paste passwords/tokens;
- recommend naming/bio/link consistency.

- [ ] **Step 2: Create “30-day editorial calendar” issue**

Acceptance:
- weekly cadence;
- content pillars: learning resources, Roadmaps/UCs, project progress, community/contribution, partnerships/events;
- PT/EN strategy stated;
- each post has objective, CTA, target channel and source asset.

- [ ] **Step 3: Create “social asset kit” issue**

Acceptance:
- reusable Canva/Drive templates;
- FACODI brand consistency;
- formats for Instagram/LinkedIn/stories as applicable;
- assets link to canonical Drive sources.

- [ ] **Step 4: Create “campaign metrics” issue**

Acceptance:
- minimum metrics: impressions/reach where available, site visits, signup/contribution clicks, campaign source;
- no vanity-only reporting;
- define a lightweight weekly report.

- [ ] **Step 5: Create “student/community outreach” issue**

Acceptance:
- shortlist real partner/student communities;
- outreach message template;
- contact/status/next action;
- no invented endorsements.

- [ ] **Step 6: Mark Gustavo only as proposed owner**

Do not set an assignee unless a confirmed GitHub username is known and assignable.

Expected issue text:
`Proposed owner: Gustavo — assignment pending confirmed GitHub account.`

---

### Task 5: Create Partnerships & Funding operating backlog from existing evidence

**Files/Systems:**
- GitHub Issues in `facodi-monorepo`
- Existing Drive documents:
  - FACODI financial plan (€4,000 requested/projected)
  - FACODI collaboration plan for Gustavo/Sofia
  - existing SEA-EU/UAlg documents

**Interfaces:**
- Consumes: documented funding inputs.
- Produces: a funding pipeline that separates evidence, decisions and actions.

- [ ] **Step 1: Create “reconcile confirmed budget and commitments” issue**

Acceptance:
- requested amount;
- amount formally approved/available;
- already committed expenses;
- already paid expenses;
- uncommitted balance;
- deadlines and purchasing/payment rules;
- evidence link for each value.

Do not equate the existing €4,000 planning sheet with unrestricted available cash.

- [ ] **Step 2: Create “donations/sponsorship/payment mechanism feasibility” issue**

Acceptance:
- identify who can legally/administratively receive funds;
- distinguish donation, sponsorship, reimbursement and service revenue;
- identify institutional/UAlg/SEA-EU restrictions;
- compare candidate payment mechanisms only after ownership is clear;
- no payment account is opened by this task.

- [ ] **Step 3: Create “FACODI sponsorship/partner pack” issue**

Acceptance:
- one-page project description;
- problem/impact;
- current state and evidence;
- concrete sponsorship/support options;
- transparent use-of-funds categories;
- contact/next step;
- no unsupported institutional claims.

- [ ] **Step 4: Create “international pilot follow-up” issue**

Link the existing collaboration plan. Track remote pilot as default and in-person mission only when host, budget and authorization are confirmed.

---

### Task 6: Harden the auxiliary Supabase project before any experiment

**Files/Systems:**
- Supabase project: `bhfywztfyidvrlarebmg` (`facodi`)
- GitHub documentation in `docs/program/workstreams.md` / AI & Automation workstream

**Interfaces:**
- Consumes: current Supabase project state: no public tables, no Edge Functions, no migrations; advisor findings 0028/0029 on `public.rls_auto_enable()`.
- Produces: no public execution path to the event-trigger helper and a documented clean baseline for future experiments.

- [ ] **Step 1: Re-read the current Supabase security advisor and function ACL immediately before changing it**

Expected function properties:
- schema: `public`;
- name: `rls_auto_enable`;
- no arguments;
- returns `event_trigger`;
- `SECURITY DEFINER`;
- currently executable by `PUBLIC`, `anon` and `authenticated`.

If the observed function differs, STOP this task and revise the migration.

- [ ] **Step 2: Apply one named migration that revokes direct public/client invocation**

Migration SQL:
```sql
revoke execute on function public.rls_auto_enable()
from public, anon, authenticated;
```

Do not change the function body, event trigger, search path or owner.

- [ ] **Step 3: Verify privileges**

Run a read query against `pg_proc`/`proacl`.

Expected:
- `anon` has no EXECUTE;
- `authenticated` has no EXECUTE;
- PUBLIC has no EXECUTE;
- function remains `SECURITY DEFINER`;
- function definition is otherwise unchanged.

- [ ] **Step 4: Re-run Supabase security advisors**

Expected:
- lint 0028 absent for `rls_auto_enable`;
- lint 0029 absent for `rls_auto_enable`;
- no new higher-severity finding introduced by this migration.

- [ ] **Step 5: Record the experiment boundary**

In the AI & Automation workstream issue, record:
- project ref `bhfywztfyidvrlarebmg`;
- current state after hardening;
- “no critical FACODI dependency” rule;
- promotion checklist from the spec.

No tables or Edge Functions are created in this foundation plan.

---

### Task 7: Create the first execution queue and routing checkpoint

**Files/Systems:**
- GitHub umbrella/workstream/outcome issues
- Existing repository issues

**Interfaces:**
- Consumes: Tasks 2–6.
- Produces: a small ordered queue so the project does not attempt every idea simultaneously.

- [ ] **Step 1: Select the first active queue**

Order:
1. Outcome 1 — Discovery → Learning UX.
2. Outcome 2 — content submission.
3. Outcome 3 — content/mappings expansion.
4. Outcome 4 — delegation/sustainability runs in parallel only for non-engineering tasks that do not block 1–3.

- [ ] **Step 2: Mark explicit dependencies**

For each active outcome, link the exact existing component issues that already implement part of it.

Do not create new component issues unless there is a real uncovered gap.

- [ ] **Step 3: Record current blockers**

Include:
- Odoo live MCP unavailable in this session for direct production inspection/change;
- Gustavo GitHub handle/account not yet confirmed;
- confirmed/uncommitted funding balance still requires evidence reconciliation.

These blockers must not stop documentation/backlog/Supabase hardening work.

- [ ] **Step 4: Verify intake with five sample ideas**

Route these examples:
1. “Improve homepage text/components” → Product & UX → `facodi-theme`.
2. “Import more YouTube learning resources” → Content & Curation → `facodi-learning` + Odoo editorial workflow.
3. “Try async video analysis in Edge Functions” → AI & Automation → experimental Supabase increment.
4. “Create Instagram campaign” → Community & Marketing → program issue/Drive/Canva, no addon issue unless site change is required.
5. “Change Coolify deployment” → Operations & Release → `facodi-deploy`.

Expected: each has one clear primary owner and no conflicting source of truth.

- [ ] **Step 5: Publish a concise status comment on the umbrella issue**

Include:
- foundation created;
- first active outcomes;
- known blockers;
- next implementation focus;
- links to spec and plan.

---

## Self-Review

### Spec coverage
This plan operationalizes control-plane ownership, all eight workstreams, the four immediate outcomes, Gustavo's marketing role, funding as a first-class stream, the Odoo/Supabase boundary, security constraints and the first execution queue.

Product feature implementation itself is intentionally split into later plans. No frontend, Odoo domain, content-import or deployment feature is implemented by this foundation plan.

### Placeholder scan
No TBD/TODO/“implement later” placeholders are required for execution. Unknown identities/financial facts are explicitly represented as blockers that require evidence rather than guessed values.

### Type/interface consistency
The hierarchy is consistent throughout:
`Program → Workstream → Outcome → owning repository issue → PR/operational artifact → integration/release`.

### Review Focus coverage
- Control-plane bypass is checked in Tasks 1 and 7.
- Duplicate engineering issues are checked in Tasks 2 and 3.
- Supabase behavior preservation is checked in Task 6.
- Gustavo authority is checked in Task 4.
- Funding amount semantics are checked in Task 5.
