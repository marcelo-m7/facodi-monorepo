# AGENTS.md — FACODI multi-repository engineering contract

## Purpose

Use this repository to coordinate work across FACODI repositories without duplicating their source code or bypassing their review boundaries.

## Ownership

| Repository | Owns |
| --- | --- |
| `facodi-learning` | curriculum, import/review, coverage, eLearning domain, functional controllers/QWeb |
| `facodi-theme` | Website identity, header/footer, responsive presentation, editorial templates |
| `facodi-ai` | optional AI/provider integration; never editorial authority |
| `monodoo` | generic Odoo Community backend UX capabilities |
| `monynha-odoo` | shared components only when explicitly adopted by FACODI |
| `facodi-deploy` | production composition, pins, migrations, Coolify, acceptance, backup/restore, rollback |
| `facodi-monorepo` | specs, plans, ADRs, agent workflow, cross-repo contracts and integration tests |

## Required workflow

1. Start from a Program/Increment issue in `facodi-monorepo`.
2. Read the linked component issues and owning repository documentation.
3. Create a branch/worktree in the owning repository; do not implement addon code here.
4. Implement and test the component in isolation.
5. Open the component PR with acceptance evidence.
6. Run cross-repository integration from `workspace/` when the increment spans repositories.
7. Merge only after REVIEW/HITL gates required by the issue.
8. Update `facodi-deploy` pins only after component commits are accepted.
9. Run deploy acceptance before staging/production.

## Hard boundaries

- Do not deploy from `facodi-monorepo`.
- Do not copy FACODI addon implementations into this repository.
- Do not place academic/business logic in `facodi-deploy`.
- Do not let AI approve/publish curriculum mappings or content.
- Do not infer official equivalence, ECTS recognition or institutional endorsement.
- Do not overwrite Website Builder content merely to make tests pass.
- Do not update production pins to unmerged local workspace commits.
- Do not invent provenance when legacy data lacks evidence.

## Issue contract

Every implementation issue should identify:

- Program increment
- owning repository
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
