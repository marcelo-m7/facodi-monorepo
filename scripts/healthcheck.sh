#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://127.0.0.1:8069/web/login}"
ATTEMPTS="${HEALTHCHECK_ATTEMPTS:-30}"
SLEEP_SECONDS="${HEALTHCHECK_SLEEP_SECONDS:-2}"

for ((attempt=1; attempt<=ATTEMPTS; attempt++)); do
  if curl --fail --silent --show-error --max-time 5 "$URL" >/dev/null; then
    echo "healthy: $URL"
    exit 0
  fi
  sleep "$SLEEP_SECONDS"
done

echo "health check failed after $ATTEMPTS attempts: $URL" >&2
exit 1
