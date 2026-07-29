#!/bin/sh
set -eu

if [ -n "${TLS_CERT_BASE64:-}" ] && [ -n "${TLS_KEY_BASE64:-}" ]; then
  printf '%s' "$TLS_CERT_BASE64" | base64 -d > /tmp/tls.crt
  printf '%s' "$TLS_KEY_BASE64" | base64 -d > /tmp/tls.key
  chmod 600 /tmp/tls.key
  exec nginx -g 'daemon off;' -c /etc/nginx/nginx.tls.conf
fi

if [ "${PAYMENT_ENABLED:-false}" = "true" ]; then
  echo "PAYMENT_ENABLED=true requires TLS_CERT_BASE64 and TLS_KEY_BASE64" >&2
  exit 1
fi

exec nginx -g 'daemon off;' -c /etc/nginx/nginx.conf
