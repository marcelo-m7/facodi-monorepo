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
[[ "$(git config -f .gitmodules --get submodule.vendor/odoo-design-themes.url || true)" == "https://github.com/odoo/design-themes.git" ]] || fail "odoo design-themes submodule URL is incorrect"

git ls-files --stage addons/facodi-learning | grep -Eq '^160000 ' || fail "addons/facodi-learning must be a Git submodule"
git ls-files --stage addons/facodi-theme | grep -Eq '^160000 ' || fail "addons/facodi-theme must be a Git submodule"
git ls-files --stage vendor/odoo-design-themes | grep -Eq '^160000 ' || fail "vendor/odoo-design-themes must be a Git submodule"

[[ -f addons/facodi-learning/facodi_learning/__manifest__.py ]] || fail "facodi_learning manifest is missing from learning submodule"
[[ -f addons/facodi-theme/theme_facodi/__manifest__.py ]] || fail "theme_facodi manifest is missing from theme submodule"
[[ -f vendor/odoo-design-themes/theme_common/__manifest__.py ]] || fail "pinned theme_common manifest is missing"

grep -Fq 'FACODI_MODULES=facodi_learning,theme_facodi' .env.example || fail "runtime module list must use theme_facodi"
grep -Fq 'vendor/odoo-design-themes/theme_common/' docker/Dockerfile || fail "Dockerfile must bake only theme_common"
if grep -Eq 'COPY[[:space:]]+vendor/odoo-design-themes/[[:space:]]' docker/Dockerfile; then
  fail "Dockerfile must not bake every upstream design theme"
fi

[[ -f scripts/deploy-image.sh ]] || fail "deploy-image.sh is required"
if grep -Eq 'git[[:space:]]+(pull|fetch|checkout|clone)' scripts/deploy-image.sh; then
  fail "runtime deployment must not update application source with git"
fi

grep -Fq 'migrate-theme-module-name.sh' scripts/deploy-image.sh || fail "deploy must run legacy theme transition before module state resolution"
grep -Fq 'apply-facodi-theme.sh' scripts/deploy-image.sh || fail "deploy must apply the native theme after Odoo module operations"

[[ -x scripts/migrate-theme-module-name.sh ]] || fail "theme transition migration must be executable"
grep -Fq 'website_facodi' scripts/migrate-theme-module-name.sh || fail "migration must recognize the legacy module"
grep -Fq 'theme_facodi' scripts/migrate-theme-module-name.sh || fail "migration target missing"
grep -Fq 'ir_module_module' scripts/migrate-theme-module-name.sh || fail "migration must reconcile the module registry"
grep -Fq 'ir_model_data' scripts/migrate-theme-module-name.sh || fail "migration must reconcile XML-ID ownership"
grep -Fq 'website_page' scripts/migrate-theme-module-name.sh && fail "migration must not mutate Website Builder pages"
grep -Fq 'pg_isready' scripts/migrate-theme-module-name.sh || fail "migration must wait for PostgreSQL readiness before registry queries"
if grep -n "old_state=.*|| true\|new_state=.*|| true" scripts/migrate-theme-module-name.sh; then
  fail "migration must not reinterpret registry query failures as an absent legacy module"
fi

[[ -x scripts/apply-facodi-theme.sh ]] || fail "theme application helper must be executable"
grep -Fq 'button_choose_theme' scripts/apply-facodi-theme.sh || fail "theme application must use Odoo standard theme selection API"
grep -Fq 'website_id' scripts/apply-facodi-theme.sh || fail "theme application must support website-scoped selection"
grep -Fq 'odoo shell' scripts/apply-facodi-theme.sh || fail "theme helper must invoke the Odoo shell through the official image entrypoint"

bash -n scripts/deploy-image.sh
bash -n scripts/migrate-theme-module-name.sh
bash -n scripts/apply-facodi-theme.sh

for workflow in .github/workflows/deploy-staging.yml .github/workflows/deploy-production.yml; do
  grep -Fq 'scripts/migrate-theme-module-name.sh' "$workflow" || fail "$workflow must copy the legacy transition helper"
  grep -Fq 'scripts/apply-facodi-theme.sh' "$workflow" || fail "$workflow must copy the standard theme application helper"
done

[[ -x tests/test_theme_transition.sh ]] || fail "disposable theme transition integration test must be executable"
bash -n tests/test_theme_transition.sh
[[ "$(grep -Fc 'odoo shell' tests/test_theme_transition.sh)" -ge 2 ]] || fail "transition test must invoke Odoo shell through the official image entrypoint"
grep -Fq 'test_theme_transition.sh' .github/workflows/ci.yml || fail "CI must exercise the legacy-to-native theme transition"
grep -Fq 'theme_bewise' .github/workflows/ci.yml || fail "CI must verify unrelated design themes are absent from the image"

grep -Fq 'FACODI_IMAGE' infrastructure/docker-compose.yml || fail "Compose must consume FACODI_IMAGE"
if grep -Fq '../addons:/mnt/extra-addons' infrastructure/docker-compose.yml; then
  fail "Compose must not bind-mount addon source into the immutable runtime image"
fi

# Odoo 19 makes admin_passwd a file-only setting. The persistent server must
# therefore create a private runtime config instead of passing --admin-passwd.
if grep -Fq -- '--admin-passwd' infrastructure/docker-compose.yml; then
  fail "Odoo 19 server must not receive the file-only admin_passwd as a CLI option"
fi
[[ -f docker/facodi-odoo-server.sh ]] || fail "Odoo 19 runtime config wrapper is required"
bash -n docker/facodi-odoo-server.sh
grep -Fq 'ODOO_ADMIN_PASSWD' infrastructure/docker-compose.yml || fail "Compose must pass the Odoo master password to the runtime wrapper"
grep -Fq '/usr/local/bin/facodi-odoo-server' infrastructure/docker-compose.yml || fail "Compose must start Odoo through the runtime config wrapper"
if grep -Eq -- '^[[:space:]]+- -d=' infrastructure/docker-compose.yml; then
  fail "Odoo short -d option must receive the database name as a separate argument"
fi
grep -Eq -- '^[[:space:]]+- -d[[:space:]]*$' infrastructure/docker-compose.yml || fail "persistent Odoo server must declare the -d database option"
grep -Fq -- '- ${ODOO_DB:?ODOO_DB is required}' infrastructure/docker-compose.yml || fail "persistent Odoo server must pass ODOO_DB after -d"
grep -Fq 'COPY docker/facodi-odoo-server.sh /usr/local/bin/facodi-odoo-server' docker/Dockerfile || fail "Docker image must install the runtime config wrapper"
grep -Fq 'admin_passwd' docker/facodi-odoo-server.sh || fail "runtime wrapper must write admin_passwd to Odoo config"
grep -Fq 'chmod 600' docker/facodi-odoo-server.sh || fail "runtime Odoo config must be private"
grep -Fq 'exec /entrypoint.sh odoo' docker/facodi-odoo-server.sh || fail "runtime wrapper must delegate to the official Odoo Docker entrypoint"

[[ -f .github/workflows/build-image.yml ]] || fail "build-image workflow is required"
grep -Fq 'id-token: write' .github/workflows/build-image.yml || fail "build workflow must request GitHub OIDC token permission"
grep -Fq 'google-github-actions/auth@' .github/workflows/build-image.yml || fail "build workflow must authenticate to Google Cloud with google-github-actions/auth"
grep -Fq 'submodules: recursive' .github/workflows/build-image.yml || fail "build workflow must checkout submodules recursively"

if grep -R -nE --exclude='validate-repository.sh' 'service[_-]?account.*\.json|GOOGLE_APPLICATION_CREDENTIALS.*\.json' .github scripts infrastructure docker 2>/dev/null; then
  fail "long-lived Google service-account JSON credentials must not be referenced"
fi

bash scripts/validate-repository.sh

echo "repository contract passed"
