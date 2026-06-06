#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/app"

FLUTTER_BIN="${FLUTTER_BIN:-/Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter}"
XCODE_DEVELOPER_DIR="${XCODE_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -x "$XCODE_DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "ios-build-missing-full-xcode: expected xcodebuild at $XCODE_DEVELOPER_DIR/usr/bin/xcodebuild" >&2
  echo "Install full Xcode, then run:" >&2
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
  echo "  sudo xcodebuild -runFirstLaunch" >&2
  exit 2
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "ios-build-missing-cocoapods" >&2
  exit 2
fi

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$FLUTTER_BIN" build ios --debug --no-codesign
echo "ios-build-ok"
