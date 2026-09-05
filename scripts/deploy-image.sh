#!/usr/bin/env bash
set -euo pipefail

IMAGE_URI="${1:-}"
if [[ -z "$IMAGE_URI" ]]; then
  echo "usage: $0 <artifact-registry-image-uri>" >&2
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
: "${FACODI_MODULES:=facodi_learning,theme_facodi}"

# Existing deployments may still carry the former presentation addon's name
# in .env. Normalize that one known transition without mutating operator config.
if [[ "$FACODI_MODULES" == *website_facodi* ]]; then
  FACODI_MODULES="${FACODI_MODULES//website_facodi/theme_facodi}"
  export FACODI_MODULES
  echo "normalized legacy FACODI_MODULES entry website_facodi -> theme_facodi"
fi

for module in ${FACODI_MODULES//,/ }; do
  if [[ ! "$module" =~ ^[a-z0-9_]+$ ]]; then
    echo "invalid Odoo module name in FACODI_MODULES: $module" >&2
    exit 65
  fi
done

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif sudo -n docker info >/dev/null 2>&1; then
  DOCKER=(sudo -n docker)
else
  echo "docker is unavailable to the deployment user" >&2
  exit 69
fi

export FACODI_IMAGE="$IMAGE_URI"
COMPOSE=("${DOCKER[@]}" compose --env-file "$ROOT_DIR/.env" -f infrastructure/docker-compose.yml)

registry="${IMAGE_URI%%/*}"
if [[ "$registry" == *-docker.pkg.dev ]]; then
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud is required on the VM to authenticate Docker to Artifact Registry" >&2
    exit 69
  fi
  gcloud auth print-access-token \
    | "${DOCKER[@]}" login -u oauth2accesstoken --password-stdin "$registry" >/dev/null
fi

"${COMPOSE[@]}" pull odoo
"${COMPOSE[@]}" up -d db
"${COMPOSE[@]}" stop odoo >/dev/null 2>&1 || true

# This guarded one-time transition removes only the known legacy presentation
# module metadata. It is a no-op once website_facodi is absent.
bash "$ROOT_DIR/scripts/migrate-theme-module-name.sh"

install_modules=()
update_modules=()
IFS=',' read -r -a requested_modules <<< "$FACODI_MODULES"

for module in "${requested_modules[@]}"; do
  state="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$ODOO_DB" -tAc \
    "SELECT state FROM ir_module_module WHERE name = '$module' LIMIT 1" 2>/dev/null || true)"
  if [[ "$state" == "installed" ]]; then
    update_modules+=("$module")
  else
    install_modules+=("$module")
  fi
done

odoo_args=(--stop-after-init --without-demo=all -d "$ODOO_DB")
if (( ${#install_modules[@]} > 0 )); then
  install_csv="$(IFS=,; echo "${install_modules[*]}")"
  odoo_args+=(-i "$install_csv")
  echo "installing modules: $install_csv"
fi
if (( ${#update_modules[@]} > 0 )); then
  update_csv="$(IFS=,; echo "${update_modules[*]}")"
  odoo_args+=(-u "$update_csv")
  echo "updating modules: $update_csv"
fi

"${COMPOSE[@]}" run --rm odoo "${odoo_args[@]}"

# Installing a theme registers its templates. Selecting it on each Website is a
# separate standard Odoo lifecycle step and must happen after module operations.
bash "$ROOT_DIR/scripts/apply-facodi-theme.sh"

"${COMPOSE[@]}" up -d --no-build odoo

bash "$ROOT_DIR/scripts/healthcheck.sh" "${ODOO_HEALTHCHECK_URL:-http://127.0.0.1:${ODOO_PORT:-8069}/web/login}"

echo "deploy completed with image: $IMAGE_URI"
