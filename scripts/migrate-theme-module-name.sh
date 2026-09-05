#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { echo "missing $ROOT_DIR/.env" >&2; exit 66; }
set -a
# shellcheck disable=SC1091
source .env
set +a

: "${ODOO_DB:?ODOO_DB must be set in .env}"
: "${POSTGRES_USER:=odoo}"

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo -n docker info >/dev/null 2>&1; then
  DOCKER=(sudo -n docker)
else
  echo "docker is unavailable" >&2
  exit 69
fi

COMPOSE=("${DOCKER[@]}" compose --env-file "$ROOT_DIR/.env" -f infrastructure/docker-compose.yml)
"${COMPOSE[@]}" up -d db

ready=0
for _attempt in $(seq 1 30); do
  if "${COMPOSE[@]}" exec -T db pg_isready -U "$POSTGRES_USER" -d "$ODOO_DB" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" -eq 1 ]] || { echo "PostgreSQL did not become ready for theme transition" >&2; exit 1; }

psql_query() {
  "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$ODOO_DB" -tAc "$1"
}

# A freshly created PostgreSQL database exists before Odoo has initialized its
# registry tables. That state requires no legacy transition and must remain a
# no-op. Other query/connection errors still fail closed through psql_query.
registry_ready="$(psql_query "SELECT to_regclass('public.ir_module_module') IS NOT NULL")"
if [[ "$registry_ready" != "t" ]]; then
  echo "Odoo registry schema is not initialized; no legacy theme transition required."
  exit 0
fi

# Fail closed on connection/schema errors. An empty result means the row truly
# does not exist; a failed query must never be reinterpreted as that condition.
old_state="$(psql_query "SELECT state FROM ir_module_module WHERE name='website_facodi' LIMIT 1")"
new_state="$(psql_query "SELECT state FROM ir_module_module WHERE name='theme_facodi' LIMIT 1")"

if [[ -z "$old_state" ]]; then
  echo "No legacy website_facodi module record; no transition required."
  exit 0
fi

if [[ -n "$new_state" ]]; then
  echo "Both website_facodi and theme_facodi exist; refusing an ambiguous transition." >&2
  exit 1
fi

unexpected_xmlids="$(psql_query "
SELECT count(*)
FROM ir_model_data
WHERE module='website_facodi'
  AND NOT (model='ir.ui.view' AND name='website_layout');
")"
if [[ "$unexpected_xmlids" != "0" ]]; then
  echo "Legacy website_facodi owns unexpected XML IDs; refusing automatic transition." >&2
  exit 1
fi

legacy_view_id="$(psql_query "
SELECT res_id
FROM ir_model_data
WHERE module='website_facodi'
  AND model='ir.ui.view'
  AND name='website_layout'
LIMIT 1;
")"

if [[ -n "$legacy_view_id" ]]; then
  dependent_views="$(psql_query "
SELECT count(*)
FROM ir_ui_view
WHERE inherit_id=${legacy_view_id}
  AND id <> ${legacy_view_id};
")"
  if [[ "$dependent_views" != "0" ]]; then
    echo "Legacy website_facodi view has dependent custom views; refusing automatic transition." >&2
    exit 1
  fi
fi

"${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$ODOO_DB" <<'SQL'
BEGIN;

DO $$
DECLARE
    legacy_id integer;
    new_count integer;
    unexpected_count integer;
    dependent_count integer;
BEGIN
    SELECT id INTO legacy_id
      FROM ir_module_module
     WHERE name = 'website_facodi'
     LIMIT 1;

    IF legacy_id IS NULL THEN
        RETURN;
    END IF;

    SELECT count(*) INTO new_count
      FROM ir_module_module
     WHERE name = 'theme_facodi';
    IF new_count <> 0 THEN
        RAISE EXCEPTION 'theme_facodi already exists; transition is ambiguous';
    END IF;

    SELECT count(*) INTO unexpected_count
      FROM ir_model_data
     WHERE module = 'website_facodi'
       AND NOT (model = 'ir.ui.view' AND name = 'website_layout');
    IF unexpected_count <> 0 THEN
        RAISE EXCEPTION 'website_facodi owns unexpected XML IDs';
    END IF;

    SELECT count(*) INTO dependent_count
      FROM ir_ui_view child
     WHERE child.inherit_id IN (
         SELECT res_id
           FROM ir_model_data
          WHERE module = 'website_facodi'
            AND model = 'ir.ui.view'
            AND name = 'website_layout'
     );
    IF dependent_count <> 0 THEN
        RAISE EXCEPTION 'website_facodi layout has dependent custom views';
    END IF;
END $$;

DELETE FROM ir_ui_view
 WHERE id IN (
     SELECT res_id
       FROM ir_model_data
      WHERE module = 'website_facodi'
        AND model = 'ir.ui.view'
        AND name = 'website_layout'
 );

DELETE FROM ir_model_data
 WHERE module = 'website_facodi';

DELETE FROM ir_model_data
 WHERE module = 'base'
   AND model = 'ir.module.module'
   AND name = 'module_website_facodi'
   AND res_id IN (
       SELECT id FROM ir_module_module WHERE name = 'website_facodi'
   );

DELETE FROM ir_module_module
 WHERE name = 'website_facodi';

COMMIT;
SQL

echo "Removed legacy website_facodi registry/view metadata. theme_facodi can now be installed as a native Odoo theme."
