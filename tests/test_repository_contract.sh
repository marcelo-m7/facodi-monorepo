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

[[ -f .gitmodules ]] || fail ".gitmodules is required once addon repositories exist"
[[ "$(git config -f .gitmodules --get submodule.addons/facodi-learning.url || true)" == "https://github.com/marcelo-m7/facodi-learning.git" ]] || fail "facodi-learning submodule URL is incorrect"
[[ "$(git config -f .gitmodules --get submodule.addons/facodi-theme.url || true)" == "https://github.com/marcelo-m7/facodi-theme.git" ]] || fail "facodi-theme submodule URL is incorrect"

git ls-files --stage addons/facodi-learning | grep -Eq '^160000 ' || fail "addons/facodi-learning must be a Git submodule"
git ls-files --stage addons/facodi-theme | grep -Eq '^160000 ' || fail "addons/facodi-theme must be a Git submodule"

[[ -f addons/facodi-learning/facodi_learning/__manifest__.py ]] || fail "facodi_learning manifest is missing from learning submodule"
[[ -f addons/facodi-theme/website_facodi/__manifest__.py ]] || fail "website_facodi manifest is missing from theme submodule"

grep -Fq 'FACODI_MODULES=facodi_learning,website_facodi' .env.example || fail "runtime module list must match the actual Odoo technical module names"

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
