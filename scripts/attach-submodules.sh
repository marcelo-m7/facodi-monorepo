#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LEARNING_URL="https://github.com/marcelo-m7/facodi-learning.git"
THEME_URL="https://github.com/marcelo-m7/facodi-theme.git"

require_remote() {
  local url="$1"
  if ! git ls-remote "$url" HEAD >/dev/null 2>&1; then
    echo "repository is not available yet: $url" >&2
    exit 69
  fi
}

prepare_target() {
  local target="$1"
  if git config -f .gitmodules --get-regexp "^submodule\..*\.path$" 2>/dev/null | grep -Fq " $target"; then
    echo "submodule already attached: $target"
    return 1
  fi

  if [[ -e "$target" ]]; then
    local unexpected
    unexpected="$(find "$target" -mindepth 1 -maxdepth 1 ! -name README.md -print -quit 2>/dev/null || true)"
    if [[ -n "$unexpected" ]]; then
      echo "refusing to replace non-placeholder directory: $target" >&2
      exit 73
    fi
    git rm -r "$target"
  fi
  return 0
}

if [[ -n "$(git status --porcelain)" ]]; then
  echo "working tree must be clean before attaching submodules" >&2
  exit 65
fi

require_remote "$LEARNING_URL"
require_remote "$THEME_URL"

if prepare_target "addons/facodi-learning"; then
  git submodule add "$LEARNING_URL" addons/facodi-learning
fi

if prepare_target "addons/facodi-theme"; then
  git submodule add "$THEME_URL" addons/facodi-theme
fi

git submodule update --init --recursive

echo "FACODI addon submodules attached. Review and commit .gitmodules plus the gitlink entries."
