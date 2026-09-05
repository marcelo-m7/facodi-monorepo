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

"${COMPOSE[@]}" run --rm -T odoo shell -d "$ODOO_DB" <<'PY'
theme = env["ir.module.module"].search(
    [("name", "=", "theme_facodi"), ("state", "=", "installed")], limit=1
)
if not theme:
    raise RuntimeError("theme_facodi must be installed before applying it")

websites = env["website"].search([])
if not websites:
    raise RuntimeError("no website record found")

for website in websites:
    if website.theme_id == theme:
        continue
    theme.with_context(website_id=website.id).button_choose_theme()

env.cr.commit()
PY

echo "theme_facodi is applied through Odoo's standard theme selection API."
