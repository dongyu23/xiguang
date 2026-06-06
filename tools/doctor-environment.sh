#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  if [[ -x "/Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter" ]]; then
    FLUTTER_BIN="/Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter"
  elif [[ -x "$ROOT_DIR/app/.fvm/flutter_sdk/bin/flutter" ]]; then
    FLUTTER_BIN="$ROOT_DIR/app/.fvm/flutter_sdk/bin/flutter"
  else
    FLUTTER_BIN="flutter"
  fi
fi
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"

status=0

echo "== Docker =="
if ! docker info >/dev/null 2>&1; then
  echo "docker-unavailable"
  status=1
else
  echo "docker-ok"
fi

echo
echo "== Compose images =="
for image in nginx:alpine postgres:16-alpine redis:7-alpine quay.io/minio/minio:latest; do
  if docker image inspect "$image" >/dev/null 2>&1; then
    echo "image-ok $image"
  else
    echo "image-missing $image"
    status=1
  fi
done

echo
echo "== Flutter doctor =="
doctor_output="$("$FLUTTER_BIN" doctor -v 2>&1 || true)"
printf '%s\n' "$doctor_output"

if grep -q "Unable to locate Android SDK" <<<"$doctor_output"; then
  echo "native-env-missing android-sdk"
  status=1
fi
if grep -q "Xcode installation is incomplete" <<<"$doctor_output"; then
  echo "native-env-missing full-xcode"
  status=1
fi
if grep -q "CocoaPods not installed" <<<"$doctor_output"; then
  echo "native-env-missing cocoapods"
  status=1
fi

echo
if [[ "$status" -eq 0 ]]; then
  echo "environment-doctor-ok"
else
  echo "environment-doctor-found-issues"
fi

exit "$status"
