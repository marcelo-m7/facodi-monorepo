#!/usr/bin/env bash
set -euo pipefail

IMAGE_URI="${1:-}"
MODE="${2:-}"

if [[ -z "$IMAGE_URI" ]]; then
  echo "usage: $0 <image-uri> [--push]" >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/validate-repository.sh

docker build \
  --pull \
  --label "org.opencontainers.image.revision=${GITHUB_SHA:-local}" \
  -f docker/Dockerfile \
  -t "$IMAGE_URI" \
  .

if [[ "$MODE" == "--push" ]]; then
  docker push "$IMAGE_URI"
elif [[ -n "$MODE" ]]; then
  echo "unknown mode: $MODE" >&2
  exit 64
fi

echo "image ready: $IMAGE_URI"
