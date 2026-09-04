# GCP Staging Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an idempotent `gcloud` bootstrap and validation layer that provisions the Google Cloud resources required by the existing FACODI staging image/deploy pipeline.

**Architecture:** Keep Google Cloud bootstrapping outside runtime containers. A local authenticated operator runs one orchestration script that creates/validates Artifact Registry, IAM/WIF, firewall rules and a dual-stack Compute Engine VM. Existing GitHub Actions then build and deploy immutable SHA-tagged Odoo images through WIF and IAP.

**Tech Stack:** Bash, Google Cloud CLI, GitHub Actions, Workload Identity Federation, Artifact Registry, Compute Engine, IAP TCP forwarding, OS Login, Docker/Compose, Odoo 19 Community, PostgreSQL 16.

**Spec:** `docs/superpowers/specs/2026-09-04-gcp-staging-bootstrap-design.md`

## Global Constraints

- Odoo remains `odoo:19.0`.
- PostgreSQL remains `postgres:16`.
- No long-lived Google service-account key is created or committed.
- Runtime containers never clone or pull source code.
- GitHub authentication uses OIDC/Workload Identity Federation.
- VM network stack is `IPV4_IPV6` on the configured existing dual-stack subnet.
- Public ingress is limited to HTTP/HTTPS; SSH is restricted to IAP TCP forwarding.
- Odoo 8069/8072 and PostgreSQL 5432 remain non-public.
- `GCP_PROJECT_ID` is mandatory; other resource names have documented environment-variable defaults.
- Bootstrap never deletes/recreates an existing VPC or subnet.
- Production is out of scope.

---

### Task 1: Define the GCP bootstrap repository contract

**Files:**
- Create: `tests/test_gcp_bootstrap_contract.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: repository file layout and shell source files.
- Produces: a zero/non-zero CI contract verifying the bootstrap surface exists, contains no service-account key material, uses dual-stack networking, and forces IAP SSH.

- [ ] **Step 1: Write the failing contract test**

Create a shell test that requires these files:

```text
infrastructure/gcp/lib.sh
infrastructure/gcp/bootstrap-staging.sh
infrastructure/gcp/configure-wif.sh
infrastructure/gcp/create-vm.sh
infrastructure/gcp/vm-startup.sh
infrastructure/gcp/validate-staging.sh
```

It must also assert:

```bash
grep -q 'IPV4_IPV6' infrastructure/gcp/create-vm.sh
grep -q '35.235.240.0/20' infrastructure/gcp/create-vm.sh
grep -q 'roles/iam.workloadIdentityUser' infrastructure/gcp/configure-wif.sh
grep -q 'attribute.repository' infrastructure/gcp/configure-wif.sh
grep -q -- '--tunnel-through-iap' .github/workflows/deploy-staging.yml
! grep -R -E 'BEGIN PRIVATE KEY|"private_key"[[:space:]]*:' infrastructure/gcp .github/workflows
```

Run `bash -n` for every `infrastructure/gcp/*.sh` file that exists.

- [ ] **Step 2: Add the contract to CI**

Add immediately after `Repository contract`:

```yaml
      - name: GCP bootstrap contract
        run: bash tests/test_gcp_bootstrap_contract.sh
```

- [ ] **Step 3: Open a draft PR and verify RED**

Expected: the PR CI fails because the required GCP bootstrap scripts do not exist yet.

- [ ] **Step 4: Commit**

```bash
git add tests/test_gcp_bootstrap_contract.sh .github/workflows/ci.yml
git commit -m "test: define GCP staging bootstrap contract"
```

### Task 2: Add shared configuration and Workload Identity Federation bootstrap

**Files:**
- Create: `infrastructure/gcp/lib.sh`
- Create: `infrastructure/gcp/configure-wif.sh`

**Interfaces:**
- Consumes: mandatory `GCP_PROJECT_ID` and optional environment overrides.
- Produces: normalized configuration variables plus `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_GITHUB_SERVICE_ACCOUNT` printed to stdout.

- [ ] **Step 1: Implement `lib.sh` configuration contract**

Define defaults exactly as follows:

```bash
: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
: "${GCP_REGION:=europe-southwest1}"
: "${GCP_ZONE:=${GCP_REGION}-b}"
: "${GCP_NETWORK:=facodi-vpc}"
: "${GCP_SUBNET:=facodi-madrid}"
: "${GCP_ARTIFACT_REPOSITORY:=facodi}"
: "${FACODI_IMAGE_NAME:=odoo}"
: "${STAGING_VM_NAME:=facodi-app-01}"
: "${STAGING_DEPLOY_PATH:=/opt/facodi}"
: "${GCP_MACHINE_TYPE:=e2-standard-2}"
: "${GCP_BOOT_DISK_SIZE:=30GB}"
: "${GITHUB_REPOSITORY:=marcelo-m7/facodi-monorepo}"
: "${GCP_WIF_POOL:=github}"
: "${GCP_WIF_PROVIDER:=facodi-monorepo}"
: "${GCP_DEPLOY_SERVICE_ACCOUNT:=facodi-github-deploy}"
: "${GCP_RUNTIME_SERVICE_ACCOUNT:=facodi-runtime}"
```

Add helper functions `require_command`, `resource_exists`, `ensure_project_role`, `service_account_email`, `project_number`, and `log`.

- [ ] **Step 2: Implement `configure-wif.sh` idempotently**

The script must:

```bash
gcloud iam service-accounts describe "$DEPLOY_SA" --project "$GCP_PROJECT_ID"
gcloud iam workload-identity-pools describe "$GCP_WIF_POOL" --location global --project "$GCP_PROJECT_ID"
gcloud iam workload-identity-pools providers describe "$GCP_WIF_PROVIDER" --workload-identity-pool "$GCP_WIF_POOL" --location global --project "$GCP_PROJECT_ID"
```

Create missing resources only. The provider must use:

```text
issuer=https://token.actions.githubusercontent.com
mapping=google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner
condition=assertion.repository == 'marcelo-m7/facodi-monorepo'
```

Grant the exact-repository principal set `roles/iam.workloadIdentityUser` on the deploy service account, using the numeric project number in the principal URI.

Grant the deploy service account:

```text
roles/artifactregistry.writer
roles/iap.tunnelResourceAccessor
roles/compute.osAdminLogin
roles/compute.viewer
```

Create the runtime service account if absent, grant it `roles/artifactregistry.reader`, and grant the deploy service account `roles/iam.serviceAccountUser` on the runtime service account.

- [ ] **Step 3: Verify shell syntax**

Run:

```bash
bash -n infrastructure/gcp/lib.sh
bash -n infrastructure/gcp/configure-wif.sh
```

Expected: both exit 0.

- [ ] **Step 4: Commit**

```bash
git add infrastructure/gcp/lib.sh infrastructure/gcp/configure-wif.sh
git commit -m "feat: bootstrap GitHub workload identity federation"
```

### Task 3: Add Artifact Registry, network firewall and dual-stack VM bootstrap

**Files:**
- Create: `infrastructure/gcp/vm-startup.sh`
- Create: `infrastructure/gcp/create-vm.sh`
- Create: `infrastructure/gcp/bootstrap-staging.sh`

**Interfaces:**
- Consumes: configuration from `lib.sh`, runtime service account created by Task 2, existing `facodi-vpc`/`facodi-madrid` dual-stack subnet.
- Produces: Artifact Registry repository, firewall rules, reserved external IPv4 address, and `facodi-app-01` dual-stack VM.

- [ ] **Step 1: Implement the VM startup script**

Use Debian package setup to install Docker Engine and the Compose plugin only when `docker` is absent. Always:

```bash
systemctl enable --now docker
install -d -m 0755 /opt/facodi /opt/facodi/infrastructure /opt/facodi/scripts
```

Do not create `/opt/facodi/.env` and do not clone Git repositories.

- [ ] **Step 2: Implement `create-vm.sh` network validation**

Before any VM mutation, require:

```bash
gcloud compute networks describe "$GCP_NETWORK" --project "$GCP_PROJECT_ID"
gcloud compute networks subnets describe "$GCP_SUBNET" --region "$GCP_REGION" --project "$GCP_PROJECT_ID"
```

Validate the subnet's network URL ends with `/networks/$GCP_NETWORK` and its stack type is `IPV4_IPV6`. Fail with a clear error otherwise.

- [ ] **Step 3: Create idempotent firewall rules**

Ensure exactly these rule contracts targeting tags:

```text
facodi-allow-web-ipv4: tcp:80,tcp:443 from 0.0.0.0/0 -> facodi-web
facodi-allow-web-ipv6: tcp:80,tcp:443 from ::/0 -> facodi-web
facodi-allow-ssh-iap: tcp:22 from 35.235.240.0/20 -> facodi-admin
```

Do not create any rule exposing 8069, 8072 or 5432.

- [ ] **Step 4: Reserve staging IPv4 and create the VM**

Reserve a regional external IPv4 resource `facodi-staging-ipv4` if absent. Resolve its actual address, then create the VM if absent with equivalent flags:

```bash
gcloud compute instances create "$STAGING_VM_NAME" \
  --project "$GCP_PROJECT_ID" \
  --zone "$GCP_ZONE" \
  --machine-type "$GCP_MACHINE_TYPE" \
  --subnet "$GCP_SUBNET" \
  --stack-type IPV4_IPV6 \
  --address "$STAGING_IPV4" \
  --network-tier PREMIUM \
  --ipv6-network-tier PREMIUM \
  --service-account "$RUNTIME_SA" \
  --scopes cloud-platform \
  --tags facodi-web,facodi-admin \
  --metadata enable-oslogin=TRUE \
  --metadata-from-file startup-script=infrastructure/gcp/vm-startup.sh \
  --image-family debian-12 \
  --image-project debian-cloud \
  --boot-disk-size "$GCP_BOOT_DISK_SIZE"
```

- [ ] **Step 5: Implement `bootstrap-staging.sh` orchestration**

It must:

1. require authenticated `gcloud`;
2. enable `compute.googleapis.com`, `artifactregistry.googleapis.com`, `iam.googleapis.com`, `iamcredentials.googleapis.com`, `sts.googleapis.com`, `iap.googleapis.com` and `oslogin.googleapis.com`;
3. create the Docker Artifact Registry repository when absent;
4. call `configure-wif.sh`;
5. call `create-vm.sh`;
6. call `validate-staging.sh` when that script exists.

- [ ] **Step 6: Verify syntax**

Run:

```bash
bash -n infrastructure/gcp/vm-startup.sh
bash -n infrastructure/gcp/create-vm.sh
bash -n infrastructure/gcp/bootstrap-staging.sh
```

Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add infrastructure/gcp/vm-startup.sh infrastructure/gcp/create-vm.sh infrastructure/gcp/bootstrap-staging.sh
git commit -m "feat: bootstrap dual-stack FACODI staging VM"
```

### Task 4: Make runtime deployment compatible with IAP and privileged Docker

**Files:**
- Modify: `.github/workflows/deploy-staging.yml`
- Modify: `scripts/deploy-image.sh`

**Interfaces:**
- Consumes: WIF deploy service account and IAP/OS Login created by earlier tasks.
- Produces: deployment that transfers runtime files and executes Docker without public SSH or Docker-group assumptions.

- [ ] **Step 1: Force IAP for SSH and SCP**

Add `--tunnel-through-iap` to every staging `gcloud compute ssh` and `gcloud compute scp` command.

Change the preparation command to use sudo and grant only the authenticated OS Login user ownership of runtime directories:

```bash
sudo mkdir -p "$DEPLOY_PATH/infrastructure" "$DEPLOY_PATH/scripts"
sudo chown -R "$(id -un):$(id -gn)" "$DEPLOY_PATH/infrastructure" "$DEPLOY_PATH/scripts"
```

- [ ] **Step 2: Make `deploy-image.sh` work with sudo Docker**

Select the Docker command at runtime:

```bash
if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo -n docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  echo "docker is unavailable to the deployment user" >&2
  exit 69
fi
```

Build Compose as:

```bash
COMPOSE=("${DOCKER[@]}" compose --env-file "$ROOT_DIR/.env" -f infrastructure/docker-compose.yml)
```

For Artifact Registry authentication use the VM identity's short-lived token with the same Docker privilege context:

```bash
gcloud auth print-access-token | "${DOCKER[@]}" login -u oauth2accesstoken --password-stdin "https://$registry"
```

Do not create a long-lived Docker credential file requirement.

- [ ] **Step 3: Verify syntax and contract**

Run:

```bash
bash -n scripts/deploy-image.sh
bash tests/test_gcp_bootstrap_contract.sh
```

Expected: exit 0 after Task 5 completes all required files.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/deploy-staging.yml scripts/deploy-image.sh
git commit -m "fix: deploy staging through IAP with runtime identity"
```

### Task 5: Add cloud validation and operator documentation

**Files:**
- Create: `infrastructure/gcp/validate-staging.sh`
- Create: `docs/gcp-staging.md`
- Modify: `README.md`
- Modify: `docs/ci-cd.md`

**Interfaces:**
- Consumes: real Google Cloud project resources after bootstrap.
- Produces: validation status and exact GitHub repository/environment variable values.

- [ ] **Step 1: Implement `validate-staging.sh`**

Check with `gcloud ... describe` that all expected resources exist. Resolve the VM network interface as JSON and assert:

```text
networkIP is non-empty
stackType == IPV4_IPV6
ipv6AccessConfigs exists
serviceAccounts contains facodi-runtime@PROJECT_ID.iam.gserviceaccount.com
```

Print a final configuration block containing:

```text
GCP_PROJECT_ID
GCP_REGION
GCP_ARTIFACT_REPOSITORY
FACODI_IMAGE_NAME
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_GITHUB_SERVICE_ACCOUNT
STAGING_VM_NAME
STAGING_VM_ZONE
STAGING_DEPLOY_PATH
DEPLOY_STAGING_ENABLED=false
```

Also print the VM external IPv4 and IPv6 values for later DNS configuration.

- [ ] **Step 2: Document the one-time bootstrap**

Document:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
GCP_PROJECT_ID=YOUR_PROJECT_ID bash infrastructure/gcp/bootstrap-staging.sh
```

Explain that the operator then creates `/opt/facodi/.env` manually through IAP SSH before setting `DEPLOY_STAGING_ENABLED=true`.

- [ ] **Step 3: Update CI/CD documentation**

Document the split between:

```text
one-time local gcloud bootstrap -> WIF/Artifact Registry/VM
ongoing GitHub Actions -> build immutable image -> IAP deploy
```

- [ ] **Step 4: Run complete repository verification**

Run in CI:

```bash
bash tests/test_repository_contract.sh
bash tests/test_gcp_bootstrap_contract.sh
docker compose --env-file .env.example -f infrastructure/docker-compose.yml config --quiet
docker build -f docker/Dockerfile -t facodi-odoo:ci .
```

Expected: all pass without Google Cloud credentials.

- [ ] **Step 5: Commit**

```bash
git add infrastructure/gcp/validate-staging.sh docs/gcp-staging.md README.md docs/ci-cd.md
git commit -m "docs: add reproducible GCP staging bootstrap"
```

### Task 6: PR verification and handoff

**Files:**
- No new files required.

**Interfaces:**
- Consumes: completed implementation branch.
- Produces: reviewable PR and explicit cloud-side next action.

- [ ] **Step 1: Verify PR CI is green**

Expected CI steps:

```text
Repository contract              success
GCP bootstrap contract           success
Validate Compose configuration   success
Build immutable Odoo image       success
Start PostgreSQL                 success
Install FACODI modules            success
```

- [ ] **Step 2: Verify no credential material**

Search the diff and repository additions for:

```text
BEGIN PRIVATE KEY
private_key
credentials_json
service-account.json
```

Expected: no secret/key material.

- [ ] **Step 3: Leave deployment disabled**

Do not set `DEPLOY_STAGING_ENABLED=true` in code. The next operator action after merge is to execute the documented bootstrap against the real Google Cloud project, validate it, create `/opt/facodi/.env`, add the printed GitHub variables, and only then enable staging deployment.
