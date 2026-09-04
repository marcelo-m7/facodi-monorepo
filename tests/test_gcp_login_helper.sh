#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCRIPT="scripts/gcp-login.sh"

[[ -f "$SCRIPT" ]] || {
  echo "missing Google Cloud login helper: $SCRIPT" >&2
  exit 1
}

bash -n "$SCRIPT"
grep -qxF '.env' .gitignore

grep -q 'Google Cloud CLI.*instal' "$SCRIPT"
grep -q '\[y/N\]' "$SCRIPT"
grep -q 'packages.cloud.google.com/apt cloud-sdk main' "$SCRIPT"
grep -q 'google-cloud-cli' "$SCRIPT"
grep -q 'gcloud auth login' "$SCRIPT"
grep -q 'gcloud projects list' "$SCRIPT"
grep -q 'gcloud projects describe' "$SCRIPT"
grep -q 'GCP_PROJECT_ID' "$SCRIPT"
grep -q 'GCP_PROJECT_NUMBER' "$SCRIPT"
grep -q 'chmod 600' "$SCRIPT"
grep -q 'upsert_env' "$SCRIPT"

if grep -Eq 'auth print-access-token|application-default print-access-token|BEGIN PRIVATE KEY|private_key[[:space:]]*=' "$SCRIPT"; then
  echo "login helper must not persist or print long-lived/private Google credentials" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/bin"

cat > "$TMP_DIR/bin/gcloud" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  'auth login')
    exit 0
    ;;
  'projects list')
    printf 'PROJECT_ID   NAME\nfacodi-test  FACODI Test\n'
    ;;
  'projects describe')
    if [[ "$*" == *"value(projectNumber)"* ]]; then
      printf '123456789\n'
    fi
    ;;
  'config set')
    exit 0
    ;;
  'auth list')
    printf 'operator@example.com\n'
    ;;
  *)
    printf 'unexpected fake gcloud invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/gcloud"

cat > "$TMP_DIR/.env" <<'EOF'
POSTGRES_PASSWORD=keep-me
GCP_REGION=old-region
EOF
chmod 644 "$TMP_DIR/.env"

printf 'facodi-test\n' | \
  PATH="$TMP_DIR/bin:$PATH" \
  FACODI_ENV_FILE="$TMP_DIR/.env" \
  GCP_REGION=europe-southwest1 \
  bash "$ROOT_DIR/$SCRIPT" >/dev/null

grep -qxF 'POSTGRES_PASSWORD=keep-me' "$TMP_DIR/.env"
grep -qxF 'GCP_PROJECT_ID=facodi-test' "$TMP_DIR/.env"
grep -qxF 'GCP_PROJECT_NUMBER=123456789' "$TMP_DIR/.env"
grep -qxF 'GCP_REGION=europe-southwest1' "$TMP_DIR/.env"
grep -qxF 'GCP_AUTH_ACCOUNT=operator@example.com' "$TMP_DIR/.env"
[[ "$(grep -c '^GCP_REGION=' "$TMP_DIR/.env")" -eq 1 ]]
[[ "$(stat -c '%a' "$TMP_DIR/.env")" == "600" ]]

echo "GCP login helper contract passed"
