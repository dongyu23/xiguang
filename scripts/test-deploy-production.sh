#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/mock-bin" "$TMP_DIR/.deploy"
cp "$ROOT_DIR/scripts/deploy-production.sh" "$TMP_DIR/scripts/"
printf 'services: {}\n' > "$TMP_DIR/docker-compose.production.yml"
printf 'PAYMENT_ENABLED=false\nHTTP_PORT=8088\n' > "$TMP_DIR/.env"

cat > "$TMP_DIR/mock-bin/docker" <<'EOF'
#!/usr/bin/env bash
set -eu
root="${DEPLOY_TEST_ROOT:?}"
printf 'docker %s image=%s\n' "$*" "${BACKEND_IMAGE:-}" >> "$root/commands.log"
if [[ " $* " == *" up "* && " $* " == *" app "* ]]; then
  printf '%s\n' "${BACKEND_IMAGE:-}" > "$root/current-image"
fi
if [[ " $* " == *" image inspect "* ]]; then
  printf 'test-revision\n'
fi
EOF

cat > "$TMP_DIR/mock-bin/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
root="${DEPLOY_TEST_ROOT:?}"
current="$(cat "$root/current-image" 2>/dev/null || true)"
if [[ -n "${DEPLOY_TEST_FAIL_IMAGE:-}" && "$current" == "$DEPLOY_TEST_FAIL_IMAGE" ]]; then
  exit 22
fi
exit 0
EOF
chmod +x "$TMP_DIR/mock-bin/docker" "$TMP_DIR/mock-bin/curl" "$TMP_DIR/scripts/deploy-production.sh"

export PATH="$TMP_DIR/mock-bin:$PATH"
export DEPLOY_TEST_ROOT="$TMP_DIR"
export DEPLOY_READY_RETRIES=2
export DEPLOY_READY_INTERVAL=0

first='ghcr.io/dongyu23/xiguang@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
second='ghcr.io/dongyu23/xiguang@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'

BACKEND_IMAGE="$first" "$TMP_DIR/scripts/deploy-production.sh"
[[ "$(cat "$TMP_DIR/.deploy/backend-image")" == "$first" ]]
grep -q "deployment succeeded" <(BACKEND_IMAGE="$first" "$TMP_DIR/scripts/deploy-production.sh" 2>&1)

export DEPLOY_TEST_FAIL_IMAGE="$second"
if BACKEND_IMAGE="$second" "$TMP_DIR/scripts/deploy-production.sh"; then
  echo "expected second deployment to fail" >&2
  exit 1
fi

[[ "$(cat "$TMP_DIR/.deploy/backend-image")" == "$first" ]]
[[ "$(cat "$TMP_DIR/current-image")" == "$first" ]]
grep -q "image=$second" "$TMP_DIR/commands.log"
grep -q "image=$first" "$TMP_DIR/commands.log"
printf 'deployment success and rollback contracts passed\n'
