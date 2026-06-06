#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

POSTGRES_CONTAINER="xiguang-verify-postgres"
APP_CONTAINER="xiguang-verify-app"
APP_PORT="${XIGUANG_VERIFY_PORT:-18086}"
base="http://127.0.0.1:${APP_PORT}"
DART_BIN="${DART_BIN:-/Users/jinzihan/.cache/codex-flutter-sdk/bin/dart}"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter}"
PYTHON_BIN="${PYTHON_BIN:-/Users/jinzihan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}"

cleanup() {
  docker rm -f "$APP_CONTAINER" "$POSTGRES_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

target_arch="$("$ROOT_DIR/tools/prepare-docker-backend.sh")"
export DOCKER_TARGETARCH="$target_arch"
docker compose build app >/tmp/xiguang-verify-build.log

cleanup
docker run --rm -d \
  --name "$POSTGRES_CONTAINER" \
  -e POSTGRES_USER=glimmer \
  -e POSTGRES_PASSWORD=glimmer_dev_password \
  -e POSTGRES_DB=glimmer \
  -p 15432:5432 \
  postgres:16-alpine >/dev/null

for _ in $(seq 1 30); do
  if docker exec "$POSTGRES_CONTAINER" pg_isready -U glimmer -d glimmer >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker exec "$POSTGRES_CONTAINER" pg_isready -U glimmer -d glimmer >/dev/null

docker run --rm -d \
  --name "$APP_CONTAINER" \
  -p "${APP_PORT}:8080" \
  -e APP_ENV=test \
  -e APP_PORT=8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=15432 \
  -e DB_USER=glimmer \
  -e DB_PASSWORD=glimmer_dev_password \
  -e DB_NAME=glimmer \
  -e DB_SSLMODE=disable \
  -e JWT_SECRET=test_secret_64_chars_for_xiguang_container_verify_runs \
  xiguang-app:latest >/dev/null

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${APP_PORT}/healthz" >/tmp/xiguang-verify-health.json 2>/dev/null; then
    break
  fi
  sleep 1
done

curl -fsS "http://127.0.0.1:${APP_PORT}/healthz" >/tmp/xiguang-verify-health.json
curl -fsS "$base/api/v1/emotions" >/tmp/xiguang-verify-emotions.json
docker exec "$APP_CONTAINER" /app/xiguang healthcheck

username="verify$(date +%s%N)"
register_body="$(curl -fsS -X POST "$base/api/v1/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$username\",\"password\":\"xiguang-verify\",\"nickname\":\"Verify\"}")"
token="$(printf '%s' "$register_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["tokens"]["access_token"])')"
refresh_token="$(printf '%s' "$register_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["tokens"]["refresh_token"])')"
curl -fsS -X POST "$base/api/v1/auth/refresh" \
  -H 'Content-Type: application/json' \
  -d "{\"refresh_token\":\"$refresh_token\"}" >/tmp/xiguang-verify-refresh.json

fragment_ids=()
for i in 1 2 3; do
  fragment_body="$(curl -fsS -X POST "$base/api/v1/fragments" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "{\"content_text\":\"verify light $i\",\"emotion\":\"平静\",\"tag_names\":[\"verify\",\"微光\"],\"client_op_id\":\"$username-fragment-$i\"}")"
  fragment_ids+=("$(printf '%s' "$fragment_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')")
done

first_fragment_id="${fragment_ids[0]}"
second_fragment_id="${fragment_ids[1]}"

curl -fsS "$base/api/v1/users/me" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-me.json
curl -fsS -X PUT "$base/api/v1/users/me" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d '{"nickname":"Verify Updated","ai_enabled":true,"privacy_mode":"private"}' >/tmp/xiguang-verify-me-update.json
curl -fsS "$base/api/v1/fragments" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-fragments.json
curl -fsS "$base/api/v1/fragments/$first_fragment_id" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-fragment.json
scratch_body="$(curl -fsS -X POST "$base/api/v1/fragments" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"content_text\":\"scratch light\",\"emotion\":\"说不清\",\"tag_names\":[\"scratch\"],\"client_op_id\":\"$username-scratch\"}")"
scratch_id="$(printf '%s' "$scratch_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')"
curl -fsS -X PUT "$base/api/v1/fragments/$scratch_id" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d '{"content_text":"scratch light updated","emotion":"开心","tag_names":["scratch","updated"]}' >/tmp/xiguang-verify-fragment-update.json
curl -fsS -X DELETE "$base/api/v1/fragments/$scratch_id" \
  -H "Authorization: Bearer $token" >/tmp/xiguang-verify-fragment-delete.json
curl -fsS "$base/api/v1/timeline" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-timeline.json
curl -fsS "$base/api/v1/tags" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-tags.json
curl -fsS "$base/api/v1/islands" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-islands.json
curl -fsS "$base/api/v1/islands/verify/fragments" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-island-fragments.json
curl -fsS "$base/api/v1/stats/emotion-density" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-emotion-density.json
curl -fsS "$base/api/v1/stats/freq-words" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-freq-words.json
curl -fsS "$base/api/v1/starmap" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-starmap-before.json
curl -fsS -X POST "$base/api/v1/fragments/$first_fragment_id/weave" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"target_fragment_id\":$second_fragment_id,\"relation_type\":\"reminds_me\",\"note\":\"verify weave\"}" >/tmp/xiguang-verify-weave.json
curl -fsS "$base/api/v1/relations?fragment_id=$first_fragment_id" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-relations.json
curl -fsS "$base/api/v1/starmap" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-starmap.json
presign_body="$(curl -fsS -X POST "$base/api/v1/media/presign-upload" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"fragment_id\":$first_fragment_id,\"file_name\":\"verify.png\",\"content_type\":\"image/png\",\"file_size\":128}")"
printf '%s' "$presign_body" >/tmp/xiguang-verify-media-presign.json
object_key="$(printf '%s' "$presign_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["object_key"])')"
media_body="$(curl -fsS -X POST "$base/api/v1/media/confirm-upload" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"fragment_id\":$first_fragment_id,\"object_key\":\"$object_key\",\"file_name\":\"verify.png\",\"mime_type\":\"image/png\",\"file_size\":128}")"
printf '%s' "$media_body" >/tmp/xiguang-verify-media-confirm.json
media_id="$(printf '%s' "$media_body" | "$PYTHON_BIN" -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')"
curl -fsS "$base/api/v1/media/$media_id" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-media-get.json
curl -fsS -X DELETE "$base/api/v1/media/$media_id" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-media-delete.json
curl -fsS "$base/api/v1/space/config" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-space.json
curl -fsS "$base/api/v1/whitenoise" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-whitenoise.json
curl -fsS -X POST "$base/api/v1/ai/glow-summary" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"mode\":\"dont_explain_me\",\"fragment_ids\":[$first_fragment_id,$second_fragment_id],\"context\":\"verify\"}" >/tmp/xiguang-verify-ai.json
curl -fsS "$base/api/v1/ai/requests" -H "Authorization: Bearer $token" >/tmp/xiguang-verify-ai-requests.json
curl -fsS -X POST "$base/api/v1/sync/push" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "{\"device_id\":\"verify-device\",\"operations\":[{\"client_op_id\":\"$username-sync\",\"entity_type\":\"fragment\",\"op_type\":\"INSERT\",\"entity_public_id\":\"$username-sync-public\",\"payload\":{\"content_text\":\"sync verify\"},\"client_seq\":1,\"base_server_version\":0}]}" >/tmp/xiguang-verify-sync-push.json
curl -fsS "$base/api/v1/sync/pull?since_rev=0" \
  -H "Authorization: Bearer $token" >/tmp/xiguang-verify-sync-pull.json

"$PYTHON_BIN" - <<'PY'
import json
emotions = json.load(open('/tmp/xiguang-verify-emotions.json'))['data']
refresh = json.load(open('/tmp/xiguang-verify-refresh.json'))['data']
me = json.load(open('/tmp/xiguang-verify-me.json'))['data']
me_update = json.load(open('/tmp/xiguang-verify-me-update.json'))['data']
fragments = json.load(open('/tmp/xiguang-verify-fragments.json'))['data']
fragment = json.load(open('/tmp/xiguang-verify-fragment.json'))['data']
fragment_update = json.load(open('/tmp/xiguang-verify-fragment-update.json'))['data']
fragment_delete = json.load(open('/tmp/xiguang-verify-fragment-delete.json'))['data']
timeline = json.load(open('/tmp/xiguang-verify-timeline.json'))['data']['groups']
tags = json.load(open('/tmp/xiguang-verify-tags.json'))['data']['items']
islands = json.load(open('/tmp/xiguang-verify-islands.json'))['data']['islands']
island_fragments = json.load(open('/tmp/xiguang-verify-island-fragments.json'))['data']['fragments']
emotion_density = json.load(open('/tmp/xiguang-verify-emotion-density.json'))['data']
freq_words = json.load(open('/tmp/xiguang-verify-freq-words.json'))['data']['words']
weave = json.load(open('/tmp/xiguang-verify-weave.json'))['data']
relations = json.load(open('/tmp/xiguang-verify-relations.json'))['data']['relations']
starmap = json.load(open('/tmp/xiguang-verify-starmap.json'))['data']
media_presign = json.load(open('/tmp/xiguang-verify-media-presign.json'))['data']
media_confirm = json.load(open('/tmp/xiguang-verify-media-confirm.json'))['data']
media_get = json.load(open('/tmp/xiguang-verify-media-get.json'))['data']
media_delete = json.load(open('/tmp/xiguang-verify-media-delete.json'))['data']
space = json.load(open('/tmp/xiguang-verify-space.json'))['data']
whitenoise = json.load(open('/tmp/xiguang-verify-whitenoise.json'))['data']
ai = json.load(open('/tmp/xiguang-verify-ai.json'))['data']
ai_requests = json.load(open('/tmp/xiguang-verify-ai-requests.json'))['data']['requests']
sync_push = json.load(open('/tmp/xiguang-verify-sync-push.json'))['data']
sync = json.load(open('/tmp/xiguang-verify-sync-pull.json'))['data']['operations']
assert len(emotions) == 8 and any(e['name'] == '说不清' for e in emotions), emotions
assert refresh['access_token'] and refresh['refresh_token'], refresh
assert me['username'].startswith('verify'), me
assert me_update['nickname'] == 'Verify Updated' and me_update['ai_enabled'] is True, me_update
assert len(fragments) >= 3, fragments
assert fragment['content_text'].startswith('verify light'), fragment
assert fragment_update['content_text'] == 'scratch light updated' and fragment_update['emotion'] == '开心', fragment_update
assert fragment_delete['deleted'] is True, fragment_delete
assert timeline and sum(len(g['fragments']) for g in timeline) >= 3, timeline
assert len(tags) >= 2, tags
assert any(i['name'] == 'verify' and i['fragment_count'] == 3 for i in islands), islands
assert len(island_fragments) >= 3, island_fragments
assert emotion_density['total'] >= 3, emotion_density
assert any(w['text'] == 'verify' and w['count'] >= 3 for w in freq_words), freq_words
assert weave['relation_type'] == 'reminds_me', weave
assert relations and relations[0]['relation_type'] == 'reminds_me', relations
assert starmap['metadata']['total_nodes'] >= 3, starmap
assert starmap['metadata']['total_edges'] >= 1, starmap
assert media_presign['object_key'].startswith('users/'), media_presign
assert media_confirm['id'] == media_get['id'], (media_confirm, media_get)
assert media_delete['deleted'] is True, media_delete
assert space['theme'] == 'starry', space
assert any(n['id'] == 'rain' for n in whitenoise), whitenoise
assert ai['status'] == 'not_implemented' and '不解释' in ai['message'], ai
assert ai_requests and ai_requests[0]['status'] == 'not_implemented', ai_requests
assert sync_push['results'] and sync_push['results'][0]['status'] == 'accepted', sync_push
assert len(sync) >= 4, sync
print('backend-api-contract-ok')
PY

(
  cd "$ROOT_DIR/app"
  "$FLUTTER_BIN" pub get >/dev/null
  API_BASE_URL="$base/api/v1" "$DART_BIN" run tool/backend_contract.dart
)

echo "backend-container-verify-ok"
