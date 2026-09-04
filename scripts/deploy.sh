#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-}"
if [[ -z "$BRANCH" ]]; then
  echo "usage: $0 <branch>" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "missing $ROOT_DIR/.env" >&2
  exit 66
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${ODOO_DB:?ODOO_DB must be set in .env}"
: "${POSTGRES_USER:=odoo}"

COMPOSE=(docker compose -f infrastructure/docker-compose.yml)

echo "Deploying branch $BRANCH"
git fetch --prune origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

"${COMPOSE[@]}" pull
"${COMPOSE[@]}" up -d db

module_state="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$ODOO_DB" -tAc \
  "SELECT state FROM ir_module_module WHERE name = 'facodi_core' LIMIT 1" 2>/dev/null || true)"

"${COMPOSE[@]}" stop odoo >/dev/null 2>&1 || true

if [[ "$module_state" == "installed" ]]; then
  module_action=(-u facodi_core)
  echo "Updating facodi_core"
else
  module_action=(-i facodi_core)
  echo "Installing facodi_core"
fi

"${COMPOSE[@]}" run --rm odoo \
  --stop-after-init \
  --without-demo=all \
  -d "$ODOO_DB" \
  "${module_action[@]}"

"${COMPOSE[@]}" up -d odoo
"$ROOT_DIR/scripts/healthcheck.sh" "${ODOO_HEALTHCHECK_URL:-http://127.0.0.1:${ODOO_PORT:-8069}/web/login}"

echo "Deploy completed"
