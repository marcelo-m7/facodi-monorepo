#!/usr/bin/env bash
set -euo pipefail

: "${ODOO_ADMIN_PASSWD:?ODOO_ADMIN_PASSWD is required}"

RUNTIME_CONFIG="${ODOO_RUNTIME_CONFIG:-/tmp/facodi-odoo.conf}"
umask 077

cat > "$RUNTIME_CONFIG" <<EOF
[options]
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo
admin_passwd = $ODOO_ADMIN_PASSWD
EOF

chmod 600 "$RUNTIME_CONFIG"
export ODOO_RC="$RUNTIME_CONFIG"

# Delegate database readiness and DB connection arguments to the official
# Odoo Docker entrypoint. Only the file-only master password is handled here.
exec /entrypoint.sh odoo "$@"
