#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=zeroclaw-local
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" -f DOCKERFILE .

echo "Running container, mapping port 8080 -> 8080"
docker run --rm -p 8080:8080 \
  -e DATABASE_URL="${DATABASE_URL:-sqlite:///data/zeroclaw.db}" \
  -e ZEROCLAW_MASTER_KEY="${ZEROCLAW_MASTER_KEY:-local_master}" \
  -e ZEROCLAW_SALT_KEY="${ZEROCLAW_SALT_KEY:-local_salt}" \
  "$IMAGE_NAME"
