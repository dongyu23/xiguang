#!/usr/bin/env bash
set -Eeuo pipefail

NPM_DATA="${NPM_DATA:-/root/madf/data}"
TARGET="$NPM_DATA/nginx/custom/http.conf"
BACKUP="$NPM_DATA/nginx/custom/http.conf.before-xiguang"

if [[ -f "$BACKUP" ]]; then
  cp "$BACKUP" "$TARGET"
else
  rm -f "$TARGET"
fi

docker exec nginx-proxy-manager nginx -t
docker exec nginx-proxy-manager nginx -s reload
printf 'Rolled back api.frozenfish.cn proxy configuration.\n'
