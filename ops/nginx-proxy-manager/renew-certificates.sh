#!/usr/bin/env bash
set -Eeuo pipefail

ACME_HOME="${ACME_HOME:-/root/.acme.sh}"
DOMAIN="${DOMAIN:-api.frozenfish.cn}"

set +e
env \
  -u http_proxy -u https_proxy \
  -u HTTP_PROXY -u HTTPS_PROXY \
  -u ALL_PROXY -u all_proxy \
  "$ACME_HOME/acme.sh" --renew --domain "$DOMAIN" --ecc --home "$ACME_HOME"
status=$?
set -e

# acme.sh uses exit code 2 when the certificate is healthy but not due yet.
if [[ "$status" -eq 0 || "$status" -eq 2 ]]; then
  exit 0
fi

exit "$status"
