#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

(
  cd backend
  go test ./...
)

docker compose config --quiet
"$ROOT_DIR/tools/verify-backend-container.sh"

(
  cd app
  /Users/jinzihan/.cache/codex-flutter-sdk/bin/dart analyze .
  /Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter test
)

rm -rf "$ROOT_DIR/app/build" "$ROOT_DIR/app/android/build" "$ROOT_DIR/backend/bin"
echo "verify-all-ok"
