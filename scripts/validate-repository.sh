#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "validation failed: $*" >&2
  exit 1
}

[[ -f docker/Dockerfile ]] || fail "docker/Dockerfile is missing"
grep -Eq '^FROM[[:space:]]+odoo:19\.0([[:space:]]|$)' docker/Dockerfile || fail "Dockerfile must use odoo:19.0"
grep -Fq 'COPY addons/ /mnt/extra-addons/' docker/Dockerfile || fail "addons must be baked into the image"

[[ -f addons/facodi-learning/README.md || -f .gitmodules ]] || fail "facodi-learning placeholder/submodule missing"
[[ -f addons/facodi-theme/README.md || -f .gitmodules ]] || fail "facodi-theme placeholder/submodule missing"

[[ -f scripts/deploy-image.sh ]] || fail "scripts/deploy-image.sh is missing"
if grep -Eq 'git[[:space:]]+(pull|fetch|checkout|clone)' scripts/deploy-image.sh; then
  fail "deploy-image.sh must not mutate source with git"
fi

[[ -f .github/workflows/build-image.yml ]] || fail "build-image workflow missing"
grep -Fq 'id-token: write' .github/workflows/build-image.yml || fail "build workflow lacks OIDC permission"
grep -Fq 'google-github-actions/auth@' .github/workflows/build-image.yml || fail "build workflow lacks Google WIF auth"

grep -Fq 'FACODI_IMAGE' infrastructure/docker-compose.yml || fail "Compose must reference FACODI_IMAGE"
if grep -Fq '../addons:/mnt/extra-addons' infrastructure/docker-compose.yml; then
  fail "Compose must not bind-mount addon source"
fi

if grep -R -nE --exclude='validate-repository.sh' 'service[_-]?account.*\.json|GOOGLE_APPLICATION_CREDENTIALS.*\.json' .github scripts infrastructure docker 2>/dev/null; then
  fail "long-lived Google JSON credentials are not allowed"
fi

echo "repository validation passed"
