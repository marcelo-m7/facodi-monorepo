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

echo "GCP login helper contract passed"
