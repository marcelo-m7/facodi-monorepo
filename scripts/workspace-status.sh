#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT/workspace"

repos=(
  "facodi-learning"
  "facodi-theme"
  "facodi-ai"
  "monodoo"
  "monynha-odoo"
  "facodi-deploy"
)

printf "%-18s %-36s %-12s %s\n" "repository" "branch" "dirty" "sha"
printf "%-18s %-36s %-12s %s\n" "----------" "------" "-----" "---"

for repo in "${repos[@]}"; do
  path="$WORKSPACE/$repo"
  if [[ ! -d "$path/.git" ]]; then
    printf "%-18s %-36s %-12s %s\n" "$repo" "NOT_CLONED" "-" "-"
    continue
  fi

  branch="$(git -C "$path" branch --show-current)"
  [[ -n "$branch" ]] || branch="DETACHED"
  sha="$(git -C "$path" rev-parse --short=12 HEAD)"
  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    dirty="yes"
  else
    dirty="no"
  fi
  printf "%-18s %-36s %-12s %s\n" "$repo" "$branch" "$dirty" "$sha"
done
