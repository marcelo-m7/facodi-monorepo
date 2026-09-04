# GCP Staging Bootstrap Design

## Purpose

Provision the first reproducible Google Cloud staging environment for FACODI without storing long-lived Google credentials in GitHub and without cloning application source code on the runtime VM.

The immutable-image delivery model remains unchanged: GitHub Actions resolves the pinned addon submodules, builds one Odoo 19 image, pushes it to Artifact Registry, and deploys that exact SHA-tagged image to Compute Engine.

## Scope

This design adds an idempotent `gcloud` bootstrap layer for the resources that the existing staging deployment workflow expects.

It covers:

- Google APIs required by the deployment path;
- Artifact Registry Docker repository;
- GitHub Workload Identity Federation and a dedicated deploy service account;
- a separate VM runtime service account;
- a dual-stack Compute Engine VM attached to the existing FACODI VPC/subnet;
- public HTTP/HTTPS firewall rules for IPv4 and IPv6;
- SSH restricted to IAP TCP forwarding;
- OS Login for administrative SSH;
- VM startup preparation for Docker, Docker Compose, Google Cloud CLI and `/opt/facodi`;
- validation and output of the GitHub Actions variables required by the existing workflows.

It does not create DNS records, production infrastructure, Odoo/PostgreSQL passwords, or GitHub repository variables automatically.

## Existing assumptions

The project already uses:

- Odoo 19 Community;
- PostgreSQL 16;
- `facodi-learning` and `facodi-theme` as pinned Git submodules;
- immutable images in Artifact Registry;
- GitHub Actions OIDC/Workload Identity Federation;
- Compute Engine for runtime;
- `staging` as the staging delivery branch.

The bootstrap defaults to:

- region: `europe-southwest1`;
- VPC: `facodi-vpc`;
- subnet: `facodi-madrid`;
- VM: `facodi-app-01`;
- deploy path: `/opt/facodi`;
- Artifact Registry repository: `facodi`;
- image name: `odoo`;
- GitHub repository: `marcelo-m7/facodi-monorepo`;
- WIF pool: `github`;
- WIF provider: `facodi-monorepo`;
- deploy service account: `facodi-github-deploy`;
- runtime service account: `facodi-runtime`.

All defaults are overridable by environment variables. `GCP_PROJECT_ID` is mandatory for actual provisioning and is never inferred from a secret file.

## Network model

The bootstrap expects an existing dual-stack subnet. It validates that the subnet exists, belongs to the configured VPC, has `IPV4_IPV6` stack type, and uses external IPv6 before creating the VM.

The VM NIC is created with `IPV4_IPV6`. The VM receives:

- one reserved regional external IPv4 address, used to keep the staging A record stable later;
- one external IPv6 address allocated by Compute Engine from the subnet.

The first implementation does not reserve a custom static external IPv6 `/96`; DNS cutover remains a separate operation after cloud validation.

Ingress policy:

- TCP 80 and 443 from `0.0.0.0/0` to instances tagged `facodi-web`;
- TCP 80 and 443 from `::/0` to instances tagged `facodi-web`;
- TCP 22 only from the IAP TCP forwarding range `35.235.240.0/20` to instances tagged `facodi-admin`.

Odoo ports 8069/8072 and PostgreSQL 5432 are never opened in the Google Cloud firewall. Odoo remains bound to loopback by Docker Compose and is intended to sit behind a reverse proxy in a later step.

## Identity model

### GitHub deployment identity

`facodi-github-deploy@PROJECT_ID.iam.gserviceaccount.com` is impersonated through Workload Identity Federation.

The provider maps GitHub OIDC claims including `assertion.repository` and restricts authentication to the exact repository `marcelo-m7/facodi-monorepo`.

The WIF principal set receives `roles/iam.workloadIdentityUser` on the deploy service account.

The deploy service account receives:

- `roles/artifactregistry.writer` **on the FACODI Artifact Registry repository only**;
- `roles/iap.tunnelResourceAccessor` on the project for IAP TCP forwarding;
- `roles/compute.osAdminLogin` on the project for OS Login administrative access.

`roles/compute.osAdminLogin` already contains the Compute instance/project read permissions required for `gcloud compute ssh/scp`, so a broad `roles/compute.viewer` grant is intentionally avoided.

Because the target VM has a runtime service account, the deploy identity receives `roles/iam.serviceAccountUser` on that runtime service account, as required for OS Login access to a VM with an attached service account.

### VM runtime identity

`facodi-runtime@PROJECT_ID.iam.gserviceaccount.com` is attached to the Compute Engine VM and receives:

- `roles/artifactregistry.reader` **on the FACODI Artifact Registry repository only** so the VM can pull the immutable image.

No long-lived service-account key is created.

## VM bootstrap

The Compute Engine VM uses Debian 12 and enables OS Login through instance metadata.

The startup script:

1. installs Docker Engine and Docker Compose when absent;
2. installs Google Cloud CLI when absent;
3. enables and starts Docker;
4. creates `/opt/facodi/infrastructure` and `/opt/facodi/scripts`;
5. leaves `/opt/facodi/.env` absent so secrets must be created explicitly before enabling deployment.

The deploy workflow logs in through OS Login with administrative access and uses passwordless `sudo` for Docker when direct Docker access is unavailable. It does not create or depend on a permanent local deployment account or Docker group membership.

The startup script never clones Git repositories and never embeds Odoo/PostgreSQL credentials.

## Bootstrap command contract

The primary entrypoint is:

```bash
GCP_PROJECT_ID=my-project bash infrastructure/gcp/bootstrap-staging.sh
```

Help is available without Google credentials or a project ID:

```bash
bash infrastructure/gcp/bootstrap-staging.sh --help
```

Optional overrides use environment variables such as `GCP_REGION`, `GCP_ZONE`, `GCP_NETWORK`, `GCP_SUBNET`, `STAGING_VM_NAME`, `GCP_MACHINE_TYPE`, `GCP_BOOT_DISK_SIZE`, `GITHUB_REPOSITORY`, `GCP_ARTIFACT_REPOSITORY`, and `FACODI_IMAGE_NAME`.

The bootstrap is idempotent by construction: it describes each resource before attempting creation and treats an existing compatible resource as success. It fails rather than intentionally replacing existing network resources.

## Validation contract

`infrastructure/gcp/validate-staging.sh` verifies:

- required Google APIs are enabled;
- Artifact Registry repository exists in the expected region;
- both service accounts exist;
- WIF pool and provider exist;
- provider resource name can be resolved;
- configured VPC and subnet exist;
- VM exists in the expected zone and uses the configured subnet;
- VM stack type is dual-stack;
- VM has external IPv4 and IPv6;
- runtime service account is attached;
- IAP SSH firewall rule and HTTP/HTTPS rules exist.

On success it prints the values required in GitHub Actions:

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
```

`DEPLOY_STAGING_ENABLED` remains `false` until the operator creates `/opt/facodi/.env` and explicitly enables deployment.

## Runtime image authentication

The VM authenticates to Artifact Registry with its attached runtime service account. `scripts/deploy-image.sh` obtains a short-lived access token using `gcloud auth print-access-token` and passes it to `docker login` through stdin.

No Artifact Registry password or Docker credential is stored in GitHub.

## Safety constraints

- no service-account JSON keys;
- no passwords or API tokens in repository files;
- no `git pull` on the VM;
- no public SSH rule;
- no public Odoo or PostgreSQL ports;
- no automatic production changes;
- no automatic deletion or recreation of existing VPC/subnet resources;
- bootstrap exits on critical incompatible network configuration instead of mutating it destructively;
- Artifact Registry read/write roles are repository-scoped rather than project-wide.

## Success criteria

The implementation is complete when:

1. repository tests validate the bootstrap contract and shell syntax;
2. the primary bootstrap supports `--help` and environment-driven configuration;
3. the staging deploy workflow uses IAP for SSH/SCP;
4. documentation explains the one-time local `gcloud` bootstrap and the remaining manual secret step;
5. GitHub CI passes without requiring Google Cloud credentials;
6. no actual cloud deployment is claimed until `validate-staging.sh` is run successfully against a real project.
