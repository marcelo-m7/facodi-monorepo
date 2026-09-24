# FACODI Program Operating Model — Design

**Date:** 2026-09-24
**Status:** Approved design
**Scope:** FACODI project/program governance and delivery architecture

## Intent

Make FACODI sustainable for a small team by separating product coordination from deploy/code ownership, reducing Marcelo's single-person bottleneck, and turning ideas into traceable increments with clear owners and acceptance criteria.

## Architecture

### Engineering control plane
`facodi-monorepo` is the program-level engineering control plane. It owns cross-repository product direction, program backlog, architectural decisions, specifications, implementation plans, dependency tracking, contributor onboarding, and cross-functional work.

It does not become a deployable monolith and does not duplicate addon source code.

### Deployment control plane
`facodi-deploy` remains the canonical composition/release boundary for production. It owns addon pins/composition, runtime/deployment configuration, release validation, Coolify-facing deployment mechanics, and production release evidence.

### Implementation repositories
- `facodi-learning`: educational domain, curriculum/Roadmap/UC/module/mapping and Odoo eLearning integration.
- `facodi-theme`: FACODI design system, Website/eLearning visual integration, accessibility and reusable frontend components.
- `facodi-ai`: optional intelligence layer for analysis/suggestions/review workflows; it must not become a second canonical educational domain.
- Other repositories remain bounded by their documented purpose and integrate through explicit contracts.

### Operational source of truth
Odoo is the FACODI operational core and canonical product/domain store for users, public educational catalogue, Roadmaps, UCs, modules, courses, contents, approved mappings, review/publication state and learning experience.

### Supabase boundary
Supabase is an auxiliary/experimental capability. No critical FACODI product flow may depend on Supabase until a specific increment:
1. defines the need and contract;
2. proves the benefit over an Odoo-first implementation;
3. defines security, observability, retries and ownership;
4. has automated tests;
5. is explicitly promoted to production architecture.

Suitable experiments include isolated asynchronous processing prototypes, telemetry or submission-processing spikes. Supabase must not silently become a second source of truth.

## Program workstreams

1. **Product & UX** — homepage, navigation, Roadmaps, UCs, modules, discovery, submissions and end-to-end student journeys.
2. **Content & Curation** — content ingestion, provenance, mappings, human review, publication quality and coverage gaps.
3. **Odoo Engineering** — standard-first domain implementation, ACLs, migrations, tests and upgrade safety.
4. **Theme, i18n & Accessibility** — `theme_facodi`, PT/EN and future languages, design tokens/components, WCAG-oriented implementation, responsive UX and SEO.
5. **AI & Automation** — analysis and suggestion workflows with human review; external providers are inference services, not canonical stores.
6. **Community & Marketing** — social media, campaigns, editorial calendar, outreach and measurable acquisition/engagement. Gustavo is the proposed owner of this workstream after account/role confirmation.
7. **Partnerships & Funding** — SEA-EU/UAlg, partnerships, sponsorship/donation mechanisms, funding documentation and financial sustainability.
8. **Operations & Release** — CI, backups, deploy, Coolify, observability, production validation and release hygiene.

## Immediate product outcomes

The first coordinated cycle optimizes for four outcomes:
1. Improve frontend copy, navigation and coherence from discovery to learning.
2. Make content submission useful, dynamic and understandable, learning from the Tube O2 interaction patterns without coupling the two products.
3. Increase the quantity and quality of published content and approved mappings.
4. Delegate a concrete marketing/funding-support surface so product engineering is not blocked on Marcelo doing every role.

## Work item routing

Every new idea starts in the program control plane and is classified by workstream, outcome, owner, priority and target repository. Implementation issues then live in the repository that owns the code or operational artifact. Cross-repository program issues link the implementation issues rather than duplicating them.

Use P0/P1/P2/P3 for urgency/impact and distinguish it from workflow state.

Every implementation issue should state:
- problem/user outcome;
- scope and non-goals;
- owning repository;
- dependencies;
- acceptance criteria;
- tests/validation;
- production validation when applicable.

## Product/domain principles

- Odoo standard-first: extend standard Odoo instead of recreating it.
- Course remains `slide.channel` where applicable; learning content remains `slide.slide`.
- FACODI domain structures add educational context without duplicating Odoo eLearning.
- Approved mappings may be published; pending suggestions remain private.
- Curriculum/coverage semantics must not imply institutional equivalence without evidence.
- Public taxonomy should make the learning hierarchy understandable and consistent.
- Prefer enriching existing FACODI components with real data and useful CTAs before creating more components.
- PT/EN are product requirements, not cleanup work.
- Accessibility, responsive behavior and SEO are part of Definition of Done.

## Content submission direction

Submission should become a guided, asynchronous-feeling experience with clear states and feedback. Reuse patterns learned from Tube O2 where useful, but FACODI/Odoo owns the FACODI submission record and final review/publication state.

A future Supabase experiment may process an isolated job, but the experiment must return a result to the Odoo-owned workflow and must be removable without breaking submission.

## Marketing and Gustavo

Create a bounded Community & Marketing backlog for Gustavo rather than assigning engineering work:
- channel/account inventory;
- editorial calendar;
- social content pipeline;
- campaign assets and reusable templates;
- outreach to student/community partners;
- campaign attribution/metrics;
- support to funding/sponsorship outreach.

Do not assign financial authority, spending authority or ownership/equity through project tooling. Those require separate explicit decisions.

## Funding

Track funding as a first-class program workstream. Separate confirmed funds, proposed expenses, approvals, commitments and paid expenses. Existing SEA-EU budget documentation is an input, not blanket authorization for new spending.

Initial sustainability work should investigate appropriate donation/sponsorship/payment mechanisms, legal/administrative ownership and institutional constraints before implementation.

## Security and secrets

No credentials, API keys, passwords or production secrets in GitHub issues, specs, code, XML, QWeb, JS or committed environment files.

Production changes should be versioned and idempotent where possible. Destructive migrations require explicit safeguards and backups.

Supabase security warnings must be resolved before exposing new production-facing capabilities.

## Definition of Done

A program increment is done only when its owning code/artifact is updated, tests pass, documentation/translation is updated as applicable, deployment composition is updated when needed, and production behavior is validated for relevant anonymous/authenticated, PT/EN and responsive paths.

## Governance rule

FACODI should optimize for fewer coherent, completed increments rather than accumulating disconnected features. New ideas remain valuable, but they enter the program backlog and do not automatically interrupt the current outcome unless they are P0/P1.
