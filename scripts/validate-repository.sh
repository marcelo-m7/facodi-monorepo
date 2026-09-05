#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

THEME_SHA="be35673a5649f5e6f7b01777905d0899e3daaf7b"
DESIGN_THEMES_SHA="a1818df4ade65406c0cacae8b1ea676e6f70095f"

fail() {
  echo "validation failed: $*" >&2
  exit 1
}

[[ -f docker/Dockerfile ]] || fail "docker/Dockerfile is missing"
grep -Eq '^FROM[[:space:]]+odoo:19\.0([[:space:]]|$)' docker/Dockerfile || fail "Dockerfile must use odoo:19.0"
grep -Fq 'COPY addons/ /opt/facodi-addon-sources/' docker/Dockerfile || fail "Dockerfile must copy checked-out addon repositories into the image build"
grep -Fq 'COPY vendor/odoo-design-themes/theme_common/' docker/Dockerfile || fail "Dockerfile must copy the pinned theme_common dependency"
grep -Fq '/mnt/extra-addons' docker/Dockerfile || fail "Dockerfile must expose discovered Odoo modules through /mnt/extra-addons"
if grep -Eq 'COPY[[:space:]]+vendor/odoo-design-themes/[[:space:]]' docker/Dockerfile; then
  fail "Dockerfile must copy only theme_common, not all Odoo design themes"
fi

[[ -f .gitmodules ]] || fail ".gitmodules is missing"
[[ "$(git config -f .gitmodules --get submodule.addons/facodi-learning.url || true)" == "https://github.com/marcelo-m7/facodi-learning.git" ]] || fail "facodi-learning submodule URL is incorrect"
[[ "$(git config -f .gitmodules --get submodule.addons/facodi-theme.url || true)" == "https://github.com/marcelo-m7/facodi-theme.git" ]] || fail "facodi-theme submodule URL is incorrect"
[[ "$(git config -f .gitmodules --get submodule.vendor/odoo-design-themes.url || true)" == "https://github.com/odoo/design-themes.git" ]] || fail "odoo-design-themes submodule URL is incorrect"

git ls-files --stage addons/facodi-learning | grep -Eq '^160000 ' || fail "addons/facodi-learning is not a Gitlink"
git ls-files --stage addons/facodi-theme | grep -Eq '^160000 ' || fail "addons/facodi-theme is not a Gitlink"
git ls-files --stage vendor/odoo-design-themes | grep -Eq '^160000 ' || fail "vendor/odoo-design-themes is not a Gitlink"

[[ -f addons/facodi-learning/facodi_learning/__manifest__.py ]] || fail "facodi_learning manifest is missing"
[[ -f addons/facodi-theme/theme_facodi/__manifest__.py ]] || fail "theme_facodi manifest is missing"
[[ -f vendor/odoo-design-themes/theme_common/__manifest__.py ]] || fail "theme_common manifest is missing"

[[ "$(git -C addons/facodi-theme rev-parse HEAD)" == "$THEME_SHA" ]] || fail "facodi-theme must be pinned to verified SHA $THEME_SHA"
[[ "$(git -C vendor/odoo-design-themes rev-parse HEAD)" == "$DESIGN_THEMES_SHA" ]] || fail "odoo-design-themes must be pinned to $DESIGN_THEMES_SHA"

grep -Fq 'FACODI_MODULES=facodi_learning,theme_facodi' .env.example || fail "runtime module list does not match checked-out addons"

[[ -f scripts/deploy-image.sh ]] || fail "scripts/deploy-image.sh is missing"
[[ -x scripts/migrate-theme-module-name.sh ]] || fail "legacy theme transition helper is missing or not executable"
[[ -x scripts/apply-facodi-theme.sh ]] || fail "theme application helper is missing or not executable"
if grep -Eq 'git[[:space:]]+(pull|fetch|checkout|clone)' scripts/deploy-image.sh; then
  fail "deploy-image.sh must not mutate source with git"
fi
grep -Fq 'migrate-theme-module-name.sh' scripts/deploy-image.sh || fail "deploy-image.sh must run the guarded legacy transition"
grep -Fq 'apply-facodi-theme.sh' scripts/deploy-image.sh || fail "deploy-image.sh must select theme_facodi after module operations"

[[ -f .github/workflows/build-image.yml ]] || fail "build-image workflow missing"
grep -Fq 'id-token: write' .github/workflows/build-image.yml || fail "build workflow lacks OIDC permission"
grep -Fq 'google-github-actions/auth@' .github/workflows/build-image.yml || fail "build workflow lacks Google WIF auth"
grep -Fq 'submodules: recursive' .github/workflows/build-image.yml || fail "build workflow must checkout submodules recursively"

grep -Fq 'FACODI_IMAGE' infrastructure/docker-compose.yml || fail "Compose must reference FACODI_IMAGE"
if grep -Fq '../addons:/mnt/extra-addons' infrastructure/docker-compose.yml; then
  fail "Compose must not bind-mount addon source"
fi

if grep -R -nE --exclude='validate-repository.sh' 'service[_-]?account.*\.json|GOOGLE_APPLICATION_CREDENTIALS.*\.json' .github scripts infrastructure docker 2>/dev/null; then
  fail "long-lived Google JSON credentials are not allowed"
fi

echo "repository validation passed"
