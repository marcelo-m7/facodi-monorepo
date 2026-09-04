#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "repository contract failed: $*" >&2
  exit 1
}

[[ -f docker/Dockerfile ]] || fail "docker/Dockerfile is required"
grep -Eq '^FROM[[:space:]]+odoo:19\.0([[:space:]]|$)' docker/Dockerfile || fail "Dockerfile must derive from odoo:19.0"
grep -Fq 'COPY addons/ /mnt/extra-addons/' docker/Dockerfile || fail "Dockerfile must bake addons into /mnt/extra-addons"

[[ -f addons/facodi-learning/README.md || -f .gitmodules ]] || fail "facodi-learning placeholder or submodule is required"
[[ -f addons/facodi-theme/README.md || -f .gitmodules ]] || fail "facodi-theme placeholder or submodule is required"

[[ -f scripts/attach-submodules.sh ]] || fail "attach-submodules.sh is required"
grep -Fq 'marcelo-m7/facodi-learning.git' scripts/attach-submodules.sh || fail "learning repository URL missing"
grep -Fq 'marcelo-m7/facodi-theme.git' scripts/attach-submodules.sh || fail "theme repository URL missing"

[[ -f scripts/deploy-image.sh ]] || fail "deploy-image.sh is required"
if grep -Eq 'git[[:space:]]+(pull|fetch|checkout|clone)' scripts/deploy-image.sh; then
  fail "runtime deployment must not update application source with git"
fi

grep -Fq 'FACODI_IMAGE' infrastructure/docker-compose.yml || fail "Compose must consume FACODI_IMAGE"
if grep -Fq '../addons:/mnt/extra-addons' infrastructure/docker-compose.yml; then
  fail "Compose must not bind-mount addon source into the immutable runtime image"
fi

[[ -f .github/workflows/build-image.yml ]] || fail "build-image workflow is required"
grep -Fq 'id-token: write' .github/workflows/build-image.yml || fail "build workflow must request GitHub OIDC token permission"
grep -Fq 'google-github-actions/auth@' .github/workflows/build-image.yml || fail "build workflow must authenticate to Google Cloud with google-github-actions/auth"
grep -Fq 'submodules: recursive' .github/workflows/build-image.yml || fail "build workflow must checkout submodules recursively"

if grep -R -nE --exclude='validate-repository.sh' 'service[_-]?account.*\.json|GOOGLE_APPLICATION_CREDENTIALS.*\.json' .github scripts infrastructure docker 2>/dev/null; then
  fail "long-lived Google service-account JSON credentials must not be referenced"
fi

echo "repository contract passed"
