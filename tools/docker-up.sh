#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

target_arch="$("$ROOT_DIR/tools/prepare-docker-backend.sh")"

export DOCKER_TARGETARCH="$target_arch"
docker compose up -d --build
