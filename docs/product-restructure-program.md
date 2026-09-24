# FACODI Product Restructure — Program Map

Program tracker: https://github.com/marcelo-m7/facodi-monorepo/issues/7  
Integration/release tracker: https://github.com/marcelo-m7/facodi-deploy/issues/20

## Role inside the broader FACODI program

Program #7 remains the active engineering/product-restructure stream. It now sits inside the broader FACODI operating model defined in:

- `docs/superpowers/specs/2026-09-24-facodi-program-operating-model-design.md`
- `docs/program/workstreams.md`
- `docs/program/intake-and-routing.md`

This document keeps the original engineering increments intact and does not repurpose them for marketing, funding or other non-engineering work.

## Increment map

| Increment | Outcome | Tracker |
| --- | --- | --- |
| INC-01 | Architecture/repository baseline | https://github.com/marcelo-m7/facodi-monorepo/issues/10 |
| INC-02 | Official curriculum → public LESTI | https://github.com/marcelo-m7/facodi-monorepo/issues/11 |
| INC-03 | Curriculum coverage → FACODI courses | https://github.com/marcelo-m7/facodi-monorepo/issues/12 |
| INC-04 | Explore + information architecture + navigation | https://github.com/marcelo-m7/facodi-monorepo/issues/13 |
| INC-05 | Content provenance + editorial governance | https://github.com/marcelo-m7/facodi-monorepo/issues/14 |
| INC-06 | PT/EN/ES/FR + accessibility + SEO | https://github.com/marcelo-m7/facodi-monorepo/issues/15 |
| INC-07 | Optional AI-assisted curation | https://github.com/marcelo-m7/facodi-monorepo/issues/16 |
| INC-08 | Integration + recovery + release | https://github.com/marcelo-m7/facodi-monorepo/issues/17 |

## Promotion rule

```text
Program/Workstream/Outcome
  -> component issue
  -> component PR
  -> component tests
  -> cross-repo integration
  -> merged component SHA
  -> facodi-deploy pin update
  -> release acceptance
  -> staging
  -> HITL release decision
  -> production
```

The engineering workspace never promotes unmerged local commits directly to production.

## Gates and priority

- **P0/P1/P2/P3** describe impact/urgency.
- **AFK**: autonomous implementation may proceed within the issue contract.
- **REVIEW**: independent review is required before promotion.
- **HITL**: a person must decide an editorial, operational or production action.

## System boundaries

```text
Odoo = operational/data control plane
facodi-monorepo = program/engineering control plane
facodi-deploy = deployment control plane
Supabase = auxiliary/experimental capability
Google Drive = institutional/media/working-document evidence
```

A Supabase experiment requires a separate approved increment before it becomes a production dependency.

## Current deployment transition

Legacy deployment ownership still present in this repository is tracked in:
https://github.com/marcelo-m7/facodi-monorepo/issues/18

It must be removed or archived only after parity with `facodi-deploy` is verified.
