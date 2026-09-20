#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT/workspace"
mkdir -p "$WORKSPACE"

repos=(
  "facodi-learning"
  "facodi-theme"
  "facodi-ai"
  "monodoo"
  "monynha-odoo"
  "facodi-deploy"
)

for repo in "${repos[@]}"; do
  target="$WORKSPACE/$repo"
  url="https://github.com/marcelo-m7/$repo.git"
  if [[ -d "$target/.git" ]]; then
    echo "[exists] $repo"
    git -C "$target" fetch --all --prune
  else
    echo "[clone] $repo"
    git clone "$url" "$target"
  fi
done

echo
echo "Workspace ready at: $WORKSPACE"
echo "Run ./scripts/workspace-status.sh to inspect branches and SHAs."
