#!/usr/bin/env bash
set -Eeuo pipefail

# 生产部署执行器：部署不可变 GHCR digest，验证失败时恢复上一镜像。
# 用法：BACKEND_IMAGE=ghcr.io/ORG/IMAGE@sha256:... ./scripts/deploy-production.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.production.yml}"
STATE_DIR="${DEPLOY_STATE_DIR:-$ROOT_DIR/.deploy}"
STATE_FILE="$STATE_DIR/backend-image"
LOCK_FILE="$STATE_DIR/deploy.lock"
TARGET_IMAGE="${BACKEND_IMAGE:-}"
HTTP_PORT="${HTTP_PORT:-8088}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
READY_RETRIES="${DEPLOY_READY_RETRIES:-30}"
READY_INTERVAL="${DEPLOY_READY_INTERVAL:-4}"
SKIP_IMAGE_PULL="${DEPLOY_SKIP_IMAGE_PULL:-false}"

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

[[ -n "$TARGET_IMAGE" ]] || die "BACKEND_IMAGE is required"
[[ "$TARGET_IMAGE" == *@sha256:* ]] || die "BACKEND_IMAGE must use an immutable sha256 digest"
[[ -f "$COMPOSE_FILE" ]] || die "compose file not found: $COMPOSE_FILE"
[[ -f "$ROOT_DIR/.env" ]] || die "missing $ROOT_DIR/.env; copy .env.production.example and configure secrets"

mkdir -p "$STATE_DIR" "$ROOT_DIR/app-releases" "$ROOT_DIR/certs" "$ROOT_DIR/secrets"
chmod 700 "$STATE_DIR" "$ROOT_DIR/secrets"

exec 9>"$LOCK_FILE"
flock -n 9 || die "another deployment is already running"

cd "$ROOT_DIR"
compose=(docker compose --env-file .env -f "$COMPOSE_FILE")
previous_image=""
if [[ -f "$STATE_FILE" ]]; then
  previous_image="$(tr -d '\r\n' < "$STATE_FILE")"
fi

payment_enabled="$(awk -F= '/^PAYMENT_ENABLED=/{print tolower($2)}' .env | tail -n1 | tr -d '\r[:space:]')"
if [[ "$payment_enabled" == "true" ]]; then
  health_url="https://127.0.0.1:${HTTPS_PORT}/healthz"
  ready_url="https://127.0.0.1:${HTTPS_PORT}/readyz"
  curl_tls=(-k)
else
  health_url="http://127.0.0.1:${HTTP_PORT}/healthz"
  ready_url="http://127.0.0.1:${HTTP_PORT}/readyz"
  curl_tls=()
fi

wait_url() {
  local url="$1"
  local label="$2"
  local attempt
  for ((attempt=1; attempt<=READY_RETRIES; attempt++)); do
    if curl "${curl_tls[@]}" --fail --silent --show-error --max-time 5 "$url" >/dev/null; then
      log "$label ready on attempt $attempt"
      return 0
    fi
    sleep "$READY_INTERVAL"
  done
  return 1
}

start_image() {
  local image="$1"
  if [[ "$SKIP_IMAGE_PULL" == "true" ]]; then
    docker image inspect "$image" >/dev/null
    log "using preloaded image $image"
  else
    BACKEND_IMAGE="$image" "${compose[@]}" pull app payment-init
  fi
  BACKEND_IMAGE="$image" "${compose[@]}" up -d --no-build postgres redis minio
  BACKEND_IMAGE="$image" "${compose[@]}" up -d --no-build --pull never app nginx
}

rollback() {
  local failed_image="$1"
  if [[ -z "$previous_image" || "$previous_image" == "$failed_image" ]]; then
    log "no previous image is available for rollback"
    return 1
  fi
  log "rolling back to $previous_image"
  start_image "$previous_image"
  wait_url "$health_url" "rollback health"
  wait_url "$ready_url" "rollback readiness"
  printf '%s\n' "$previous_image" > "$STATE_FILE"
}

on_failure() {
  local exit_code=$?
  trap - ERR
  log "deployment failed for $TARGET_IMAGE"
  BACKEND_IMAGE="$TARGET_IMAGE" "${compose[@]}" ps || true
  BACKEND_IMAGE="$TARGET_IMAGE" "${compose[@]}" logs --tail=120 app nginx payment-init || true
  rollback "$TARGET_IMAGE" || true
  exit "$exit_code"
}
trap on_failure ERR

log "deploying $TARGET_IMAGE"
start_image "$TARGET_IMAGE"
wait_url "$health_url" "application health"

# 初始化任务幂等执行：迁移商品目录、核验渠道映射和生产支付配置。
BACKEND_IMAGE="$TARGET_IMAGE" "${compose[@]}" run --rm --no-deps --pull never payment-init
wait_url "$ready_url" "application readiness"

revision="$(docker image inspect "$TARGET_IMAGE" --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' 2>/dev/null || true)"
deployed_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '%s\n' "$TARGET_IMAGE" > "$STATE_FILE"
cat > "$STATE_DIR/last-success.txt" <<EOF
deployed_at=$deployed_at
image=$TARGET_IMAGE
revision=$revision
previous_image=$previous_image
health_url=$health_url
ready_url=$ready_url
EOF

trap - ERR
log "deployment succeeded: $TARGET_IMAGE"
BACKEND_IMAGE="$TARGET_IMAGE" "${compose[@]}" ps
