#!/usr/bin/env bash
set -euo pipefail

: "${ODOO_ADMIN_PASSWD:?ODOO_ADMIN_PASSWD is required}"

config_file="$(mktemp)"
trap 'rm -f "$config_file"' EXIT
cp "${ODOO_RC:-/etc/odoo/odoo.conf}" "$config_file"
printf '\nadmin_passwd = %s\n' "$ODOO_ADMIN_PASSWD" >>"$config_file"

exec /entrypoint.sh --config="$config_file" "$@"