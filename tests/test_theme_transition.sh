#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${FACODI_IMAGE:?FACODI_IMAGE must point to the image built by CI}"
: "${POSTGRES_USER:=odoo}"
: "${POSTGRES_PASSWORD:=ci-password}"
: "${ODOO_ADMIN_PASSWD:=ci-admin-password}"

TRANSITION_DB="facodi_theme_transition_ci"
ORIGINAL_ODOO_DB="${ODOO_DB:-}"
ENV_BACKUP=""

COMPOSE=(docker compose -f infrastructure/docker-compose.yml)

cleanup() {
  set +e
  export ODOO_DB="$TRANSITION_DB"
  "${COMPOSE[@]}" stop odoo >/dev/null 2>&1 || true
  "${COMPOSE[@]}" exec -T db dropdb -U "$POSTGRES_USER" --if-exists "$TRANSITION_DB" >/dev/null 2>&1 || true
  rm -f .env
  if [[ -n "$ENV_BACKUP" && -f "$ENV_BACKUP" ]]; then
    mv "$ENV_BACKUP" .env
  fi
  if [[ -n "$ORIGINAL_ODOO_DB" ]]; then
    export ODOO_DB="$ORIGINAL_ODOO_DB"
  else
    unset ODOO_DB
  fi
}
trap cleanup EXIT

if [[ -f .env ]]; then
  ENV_BACKUP="$(mktemp)"
  cp .env "$ENV_BACKUP"
fi

export ODOO_DB="$TRANSITION_DB"

cat > .env <<EOF
FACODI_IMAGE=$FACODI_IMAGE
FACODI_MODULES=facodi_learning,theme_facodi
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
ODOO_DB=$TRANSITION_DB
ODOO_ADMIN_PASSWD=$ODOO_ADMIN_PASSWD
ODOO_PORT=8069
ODOO_GEVENT_PORT=8072
ODOO_WORKERS=0
ODOO_MAX_CRON_THREADS=0
ODOO_HEALTHCHECK_URL=http://127.0.0.1:8069/web/login
EOF

# `docker compose up -d db` returns before PostgreSQL's first-time initdb has
# necessarily completed. Wait on the server itself before creating fixtures.
ready=0
for _attempt in $(seq 1 30); do
  if "${COMPOSE[@]}" exec -T db pg_isready -U "$POSTGRES_USER" -d postgres >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" -eq 1 ]] || { echo "PostgreSQL did not become ready for transition test" >&2; exit 1; }

"${COMPOSE[@]}" exec -T db dropdb -U "$POSTGRES_USER" --if-exists "$TRANSITION_DB" >/dev/null 2>&1 || true
"${COMPOSE[@]}" exec -T db createdb -U "$POSTGRES_USER" "$TRANSITION_DB"

# Create a normal Odoo website database with the new image. theme_facodi is
# discovered but left uninstalled, which gives us a real module-registry row to
# transform into the historical presentation-only module for this disposable DB.
"${COMPOSE[@]}" run --rm odoo \
  --stop-after-init \
  --without-demo=all \
  -d "$TRANSITION_DB" \
  -i website_slides

# Seed the one view owned by the historical website_facodi addon while the
# registry is still valid. We intentionally do this before marking the legacy
# module installed because that code is not present in the new image.
"${COMPOSE[@]}" run --rm -T odoo shell -d "$TRANSITION_DB" <<'PY'
layout = env.ref("website.layout")
legacy = env["ir.ui.view"].create({
    "name": "FACODI Website Layout (legacy transition fixture)",
    "type": "qweb",
    "key": "website_facodi.website_layout",
    "inherit_id": layout.id,
    "arch_db": """
        <data>
            <xpath expr="//div[@id='wrapwrap']" position="attributes">
                <attribute name="t-attf-class" add="facodi-site" separator=" "/>
            </xpath>
            <xpath expr="//head" position="inside">
                <meta name="theme-color" content="#6a4bff"/>
            </xpath>
        </data>
    """,
})
env["ir.model.data"].create({
    "module": "website_facodi",
    "name": "website_layout",
    "model": "ir.ui.view",
    "res_id": legacy.id,
    "noupdate": False,
})
env.cr.commit()
PY

# Re-label the uninstalled native-theme registry row as the historical installed
# module. This keeps all mandatory ir_module_module columns realistic without
# inventing a partial row by hand.
"${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$TRANSITION_DB" <<'SQL'
DO $$
DECLARE
    theme_id integer;
BEGIN
    SELECT id INTO theme_id
      FROM ir_module_module
     WHERE name = 'theme_facodi'
     LIMIT 1;
    IF theme_id IS NULL THEN
        RAISE EXCEPTION 'theme_facodi registry row was not discovered';
    END IF;

    UPDATE ir_module_module
       SET name = 'website_facodi', state = 'installed'
     WHERE id = theme_id;

    UPDATE ir_model_data
       SET name = 'module_website_facodi'
     WHERE module = 'base'
       AND model = 'ir.module.module'
       AND res_id = theme_id
       AND name = 'module_theme_facodi';
END $$;
SQL

page_count_before="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$TRANSITION_DB" -tAc 'SELECT count(*) FROM website_page')"

bash scripts/migrate-theme-module-name.sh

old_count="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$TRANSITION_DB" -tAc "SELECT count(*) FROM ir_module_module WHERE name='website_facodi'")"
legacy_xmlids="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$TRANSITION_DB" -tAc "SELECT count(*) FROM ir_model_data WHERE module='website_facodi'")"
legacy_views="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$TRANSITION_DB" -tAc "SELECT count(*) FROM ir_ui_view WHERE key='website_facodi.website_layout'")"
page_count_after="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$TRANSITION_DB" -tAc 'SELECT count(*) FROM website_page')"

[[ "$old_count" == "0" ]] || { echo "legacy module row survived transition" >&2; exit 1; }
[[ "$legacy_xmlids" == "0" ]] || { echo "legacy XML IDs survived transition" >&2; exit 1; }
[[ "$legacy_views" == "0" ]] || { echo "legacy layout view survived transition" >&2; exit 1; }
[[ "$page_count_before" == "$page_count_after" ]] || { echo "website_page count changed during transition" >&2; exit 1; }

# Idempotency: a second execution must be a no-op.
bash scripts/migrate-theme-module-name.sh

# Reinstall the new native theme through the normal Odoo module lifecycle.
"${COMPOSE[@]}" run --rm odoo \
  --stop-after-init \
  --without-demo=all \
  -d "$TRANSITION_DB" \
  -i theme_facodi

bash scripts/apply-facodi-theme.sh

"${COMPOSE[@]}" run --rm -T odoo shell -d "$TRANSITION_DB" <<'PY'
theme = env["ir.module.module"].search(
    [("name", "=", "theme_facodi"), ("state", "=", "installed")], limit=1
)
assert theme, "theme_facodi is not installed after transition"
websites = env["website"].search([])
assert websites, "transition database has no website"
assert all(website.theme_id == theme for website in websites), "theme_facodi is not selected on every website"
PY

# Runtime smoke: the selected theme must reach both Website and eLearning HTTP
# surfaces, not merely exist as a module/template record.
"${COMPOSE[@]}" up -d odoo
bash scripts/healthcheck.sh "http://127.0.0.1:8069/"
curl --fail --silent --show-error "http://127.0.0.1:8069/" | grep -Fq 'facodi-site'
curl --fail --silent --show-error "http://127.0.0.1:8069/slides" | grep -Fq 'facodi-site'

echo "theme transition integration passed"
