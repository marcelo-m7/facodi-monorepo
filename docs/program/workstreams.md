# FACODI Program Workstreams

This document defines the eight operational workstreams used to classify FACODI work. A workstream is a coordination boundary, not a second code owner.

## 1. Product & UX
**Purpose:** Make the public and authenticated product understandable from discovery to learning.
**Repositories/systems:** `facodi-theme`, `facodi-learning`, Odoo Website/eLearning.
**Owner:** Marcelo / product coordination.
**Inputs:** audits, user journeys, production observations, content availability.
**Outputs:** coherent navigation, copy, journeys, components and acceptance criteria.
**Done when:** user-facing behavior is implemented in the owning repo, tested and validated in production where applicable.
**Does not own:** deploy composition, infrastructure or academic approval.

## 2. Content & Curation
**Purpose:** Grow useful learning content with provenance, review and clear curricular context.
**Repositories/systems:** `facodi-learning`, Odoo content/editorial records, Drive evidence.
**Owner:** editorial/product team.
**Inputs:** external learning sources, institutional curricula, submissions.
**Outputs:** reviewed content, mappings, provenance, explicit gaps.
**Done when:** content/mappings have evidence, review state and correct public/private visibility.
**Does not own:** final institutional equivalence claims or deployment runtime.

## 3. Odoo Engineering
**Purpose:** Maintain standard-first Odoo domain behavior, ACLs, migrations and tests.
**Repositories/systems:** `facodi-learning`, selected shared modules.
**Owner:** engineering.
**Inputs:** approved product/domain contracts.
**Outputs:** tested addons, migrations and integration contracts.
**Done when:** component tests and upgrade paths pass and integration requirements are documented.
**Does not own:** theme-only presentation or release composition.

## 4. Theme, i18n & Accessibility
**Purpose:** Make FACODI visually coherent, multilingual, responsive and accessible.
**Repositories/systems:** `facodi-theme`, Odoo Website/eLearning templates/assets.
**Owner:** frontend/theme engineering.
**Inputs:** product copy, design tokens, accessibility and SEO requirements.
**Outputs:** reusable components, PT/EN translations, responsive/a11y/SEO improvements.
**Done when:** affected surfaces are validated across language, viewport and access states.
**Does not own:** educational domain rules.

## 5. AI & Automation
**Purpose:** Assist discovery, analysis and review without becoming editorial authority.
**Repositories/systems:** `facodi-ai`, Odoo review workflows; Supabase only for approved experiments.
**Owner:** engineering/product.
**Inputs:** explicit use case, provider/configuration contract, reviewed source data.
**Outputs:** suggestions, analyses, jobs and audit evidence.
**Done when:** failures preserve the manual/Odoo flow and no auto-approval/publication bypass exists.
**Does not own:** canonical educational state or final review decisions.

### Supabase experiment boundary
Project ref: `bhfywztfyidvrlarebmg`.

Supabase remains auxiliary/experimental. Promotion to a required production dependency needs an explicit increment covering rationale, contracts, security/RLS, retries/idempotency, observability, tests, ownership and rollback.

## 6. Community & Marketing
**Purpose:** Build awareness, contribution and community participation.
**Systems:** GitHub program backlog, Google Drive, Canva/social platforms as applicable.
**Proposed owner:** Gustavo — assignment pending confirmed GitHub/Odoo account.
**Inputs:** product releases, learning resources, project milestones, events/partnerships.
**Outputs:** editorial calendar, campaign assets, outreach, attribution and weekly metrics.
**Done when:** activities have owner, cadence, CTA, source asset and measurable result.
**Does not own:** engineering implementation, spending authority, financial accounts or equity.

## 7. Partnerships & Funding
**Purpose:** Build sustainable institutional and financial support with evidence and clear approvals.
**Systems:** GitHub program backlog, Drive evidence, institutional processes.
**Owner:** Marcelo / designated project coordination.
**Inputs:** SEA-EU/UAlg documents, partner conversations, budgets, proposals.
**Outputs:** verified funding status, partner pipeline, sponsorship pack and approval-aware next actions.
**Done when:** every opportunity has evidence, status, next action and owner.
**Does not own:** automatic authority to spend, open accounts, promise equity or claim institutional endorsement.

## 8. Operations & Release
**Purpose:** Keep deployment reproducible, observable and recoverable.
**Repositories/systems:** `facodi-deploy`, Coolify, backups, CI/release acceptance.
**Owner:** release/operations engineering.
**Inputs:** merged component SHAs and tested migration requirements.
**Outputs:** pin updates, deploy evidence, rollback/recovery readiness.
**Done when:** acceptance passes and the intended commit set is verified in the target environment.
**Does not own:** business/domain logic or unreviewed addon work.
