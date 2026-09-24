# FACODI Idea Intake and Routing

Every new FACODI idea enters through the program control plane before implementation.

## Intake template

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

## Routing rules

1. Pick one primary workstream.
2. Pick one primary implementation owner: repository, Odoo operational data, Supabase experiment, or non-code operational artifact.
3. Link existing implementation issues before creating new ones.
4. Keep priority separate from execution gate.
5. If the work changes production runtime, release flows through `facodi-deploy`.
6. If the work changes FACODI product/domain state, Odoo remains canonical.
7. If the work uses Supabase, classify it as experimental unless an approved architecture increment explicitly promotes it.

## Examples

| Idea | Primary workstream | Owner |
| --- | --- | --- |
| Improve homepage text/components | Product & UX | `facodi-theme` |
| Add/review UC mapping | Content & Curation | `facodi-learning` + Odoo review flow |
| Change Coolify deployment | Operations & Release | `facodi-deploy` |
| Create Instagram campaign | Community & Marketing | Program/Drive/Canva/social surface |
| Try async video analysis in Edge Functions | AI & Automation | Supabase experimental increment |
| Import more YouTube learning resources | Content & Curation | `facodi-learning` + Odoo editorial workflow |

## Priority

- **P0** — production/data/security blocker or severe user-impacting breakage.
- **P1** — high-impact broken journey, correctness or delivery blocker.
- **P2** — important improvement with clear user/project value.
- **P3** — polish, cleanup or lower-impact enhancement.

## Gates

- **AFK** — autonomous implementation within an already approved contract.
- **REVIEW** — independent review required before promotion.
- **HITL** — human editorial, operational, financial or production decision required.

## Source-of-truth check

Before opening an implementation issue, answer:

- Is this code? Put implementation in the owning repository.
- Is this operational/product data? Odoo is canonical unless an explicit contract says otherwise.
- Is this deployment/release? `facodi-deploy`.
- Is this an experiment? Keep it isolated and reversible.
- Is this marketing/funding/community work? Track it in the program without inventing a code owner.
