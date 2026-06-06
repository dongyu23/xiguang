#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_NAME="${XIGUANG_COMPOSE_VERIFY_PROJECT:-xiguangverify}"
VERIFY_PORT="${XIGUANG_COMPOSE_VERIFY_PORT:-18088}"
COMPOSE_UP_TIMEOUT_SECONDS="${XIGUANG_COMPOSE_UP_TIMEOUT_SECONDS:-180}"
COMPOSE_PULL_TIMEOUT_SECONDS="${XIGUANG_COMPOSE_PULL_TIMEOUT_SECONDS:-120}"
PYTHON_BIN="${PYTHON_BIN:-/Users/jinzihan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"
COMPOSE_OVERRIDE="$(mktemp "${TMPDIR:-/tmp}/xiguang-compose-verify.XXXXXX")"

cleanup() {
  docker compose -p "$PROJECT_NAME" -f docker-compose.yml -f "$COMPOSE_OVERRIDE" down -v >/dev/null 2>&1 || true
  rm -rf "$ROOT_DIR/backend/bin"
  rm -f "$COMPOSE_OVERRIDE"
}
trap cleanup EXIT

cat >"$COMPOSE_OVERRIDE" <<YAML
services:
  nginx:
    ports:
      - "${VERIFY_PORT}:80"
YAML

target_arch="$("$ROOT_DIR/tools/prepare-docker-backend.sh")"
export DOCKER_TARGETARCH="$target_arch"

"$PYTHON_BIN" - "$COMPOSE_PULL_TIMEOUT_SECONDS" <<'PY'
import subprocess
import sys

timeout = int(sys.argv[1])
required_images = [
    "nginx:alpine",
    "postgres:16-alpine",
    "redis:7-alpine",
    "quay.io/minio/minio:latest",
]

for image in required_images:
    present = subprocess.run(
        ["docker", "image", "inspect", image],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0
    if present:
        continue
    try:
        subprocess.run(["docker", "pull", image], check=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        raise SystemExit(
            f"required compose image pull timed out after {timeout}s: {image}"
        ) from exc
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f"required compose image pull failed: {image}") from exc
PY

"$PYTHON_BIN" - "$PROJECT_NAME" "$COMPOSE_OVERRIDE" "$COMPOSE_UP_TIMEOUT_SECONDS" <<'PY'
import subprocess
import sys

project_name, override_file, timeout = sys.argv[1], sys.argv[2], int(sys.argv[3])
cmd = [
    "docker", "compose",
    "-p", project_name,
    "-f", "docker-compose.yml",
    "-f", override_file,
    "up", "-d", "--build",
]
try:
    subprocess.run(cmd, check=True, timeout=timeout)
except subprocess.TimeoutExpired as exc:
    raise SystemExit(
        f"compose stack startup timed out after {timeout}s while building or pulling images"
    ) from exc
PY

base="http://127.0.0.1:${VERIFY_PORT}"
for _ in $(seq 1 60); do
  if curl -fsS "$base/healthz" >/tmp/xiguang-compose-health.json 2>/dev/null; then
    break
  fi
  sleep 1
done

curl -fsS "$base/healthz" >/tmp/xiguang-compose-health.json
curl -fsS "$base/api/v1/emotions" >/tmp/xiguang-compose-emotions.json

username="compose$(date +%s%N)"
register_body="$(curl -fsS -X POST "$base/api/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$username\",\"password\":\"xiguang-compose\",\"nickname\":\"Compose\"}")"
token="$(printf '%s' "$register_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["tokens"]["access_token"])')"

fragment_body="$(curl -fsS -X POST "$base/api/v1/fragments" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"content_text\":\"compose stack light\",\"emotion\":\"平静\",\"tag_names\":[\"compose\",\"微光\"],\"client_op_id\":\"$username-fragment\"}")"
printf '%s' "$fragment_body" >/tmp/xiguang-compose-fragment.json

curl -fsS "$base/api/v1/timeline" -H "Authorization: Bearer $token" >/tmp/xiguang-compose-timeline.json
docker compose -p "$PROJECT_NAME" -f docker-compose.yml -f "$COMPOSE_OVERRIDE" ps --format json >/tmp/xiguang-compose-ps.json

"$PYTHON_BIN" - <<'PY'
import json
from pathlib import Path

health = json.load(open('/tmp/xiguang-compose-health.json'))
emotions = json.load(open('/tmp/xiguang-compose-emotions.json'))['data']
fragment = json.load(open('/tmp/xiguang-compose-fragment.json'))['data']
timeline = json.load(open('/tmp/xiguang-compose-timeline.json'))['data']

raw_ps = Path('/tmp/xiguang-compose-ps.json').read_text().strip()
if raw_ps.startswith('['):
    services = json.loads(raw_ps)
else:
    services = [json.loads(line) for line in raw_ps.splitlines() if line.strip()]

service_names = {item.get('Service') for item in services}
states = {item.get('Service'): item.get('State') for item in services}

assert health['ok'] is True, health
assert len(emotions) == 8, emotions
assert fragment['content_text'] == 'compose stack light', fragment
assert timeline['items'] and timeline['items'][0]['content_text'] == 'compose stack light', timeline
assert {'nginx', 'app', 'postgres', 'redis', 'minio'} <= service_names, services
assert all(states[name] == 'running' for name in ['nginx', 'app', 'postgres', 'redis', 'minio']), states
print('compose-stack-verify-ok')
PY
