#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

arch="$(docker info --format '{{.Architecture}}' 2>/dev/null || true)"
case "$arch" in
  aarch64|arm64) target_arch="arm64" ;;
  x86_64|amd64) target_arch="amd64" ;;
  *)
    echo "Unsupported Docker architecture: ${arch:-unknown}" >&2
    exit 1
    ;;
esac

mkdir -p backend/bin
(
  cd backend
  CGO_ENABLED=0 GOOS=linux GOARCH="$target_arch" go build -o "bin/xiguang-linux-${target_arch}" ./cmd/server
)

echo "$target_arch"
