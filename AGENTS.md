# AGENTS.md — FACODI multi-repository engineering contract

## Purpose

Use this repository to coordinate work across FACODI repositories and operational workstreams without duplicating source code, bypassing ownership boundaries, or turning planning artefacts into a second runtime.

## Ownership

| Repository / system | Owns |
| --- | --- |
| `facodi-learning` | curriculum, import/review, coverage, eLearning domain, functional controllers/QWeb |
| `facodi-theme` | Website identity, header/footer, responsive presentation, editorial templates |
| `facodi-ai` | optional AI/provider integration; never editorial authority |
| `monodoo` | generic Odoo Community backend UX capabilities |
| `monynha-odoo` | shared components only when explicitly adopted by FACODI |
| `facodi-deploy` | production composition, pins, migrations, Coolify, acceptance, backup/restore, rollback |
| `facodi-monorepo` | program backlog, specs, plans, ADRs, agent workflow, cross-repo contracts and integration tests |
| Odoo | operational/product/domain data, users, learning state, review/publication state |
| Supabase | auxiliary/experimental capabilities only; not canonical FACODI state |
| Google Drive | institutional evidence, media and working documents |

## Required workflow

1. Start from a Program/Workstream/Outcome item in `facodi-monorepo`.
2. Classify the work using `docs/program/intake-and-routing.md`.
3. Read the linked component issues and owning repository documentation.
4. Create a branch/worktree in the owning repository; do not implement addon code here.
5. Implement and test the component in isolation.
6. Open the component PR with acceptance evidence.
7. Run cross-repository integration from `workspace/` when the increment spans repositories.
8. Merge only after REVIEW/HITL gates required by the issue.
9. Update `facodi-deploy` pins only after component commits are accepted.
10. Run deploy acceptance before staging/production.

## Intake and routing rules

- Every new idea starts as a program work item before implementation.
- Assign exactly one primary workstream and one primary owner/repository/system.
- Cross-repository program issues link component issues; they do not duplicate implementation bodies.
- P0/P1/P2/P3 describes urgency/impact. AFK/REVIEW/HITL describes the execution gate. Do not mix the two.
- Marketing, community, partnerships and funding tasks are valid program work even if they never create a code PR.
- If an idea touches Supabase, treat it as an experiment unless an approved architecture increment has explicitly promoted it to production infrastructure.

## Hard boundaries

- Do not deploy from `facodi-monorepo`.
- Do not copy FACODI addon implementations into this repository.
- Do not place academic/business logic in `facodi-deploy`.
- Do not let AI approve/publish curriculum mappings or content.
- Do not infer official equivalence, ECTS recognition or institutional endorsement.
- Do not overwrite Website Builder content merely to make tests pass.
- Do not update production pins to unmerged local workspace commits.
- Do not invent provenance when legacy data lacks evidence.
- Do not make Supabase a second source of truth through convenience.
- Do not put credentials, API keys, passwords or production secrets in issues, specs, code, XML, QWeb, JS or committed environment files.

## Issue contract

Every implementation issue should identify:

- Program/workstream/outcome
- owning repository/system
- priority P0/P1/P2/P3
- AFK / REVIEW / HITL gate
- inputs and authoritative sources
- explicit non-ownership
- produced interface/contract
- acceptance tests
- migration impact
- rollback/recovery
- verification evidence

## Integration evidence

A completed increment should record:

- component PR URLs and merged SHAs;
- exact branch/commit set used for integration;
- test commands and outcomes;
- browser evidence when UX is involved;
- migration/upgrade evidence when schema changes;
- unresolved editorial/HITL decisions;
- the `facodi-deploy` pin update/acceptance PR when release-ready.
