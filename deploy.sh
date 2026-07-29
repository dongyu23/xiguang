#!/usr/bin/env bash
set -Eeuo pipefail

# 隙光生产环境首次引导脚本。
# 后续更新由 GitHub Actions Production Deployment 自动完成。

REPO="dongyu23/xiguang"
BRANCH="main"
INSTALL_DIR="${XIGUANG_INSTALL_DIR:-/opt/xiguang}"
BACKEND_TAG="${XIGUANG_BACKEND_IMAGE:-ghcr.io/dongyu23/xiguang:latest}"

log() { printf '[bootstrap] %s\n' "$*"; }
die() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die "Docker is required"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v openssl >/dev/null 2>&1 || die "openssl is required"

if [[ "$(id -u)" -ne 0 && ! -w "$(dirname "$INSTALL_DIR")" ]]; then
  die "run as root or choose a writable XIGUANG_INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR/scripts" "$INSTALL_DIR/app-releases" "$INSTALL_DIR/certs" "$INSTALL_DIR/secrets"
chmod 700 "$INSTALL_DIR/secrets"

download() {
  local source="$1"
  local destination="$2"
  curl --fail --silent --show-error --location \
    "https://raw.githubusercontent.com/${REPO}/${BRANCH}/${source}" \
    --output "$destination"
}

log "downloading production deployment bundle"
download docker-compose.production.yml "$INSTALL_DIR/docker-compose.production.yml"
download nginx.conf "$INSTALL_DIR/nginx.conf"
download nginx.tls.conf "$INSTALL_DIR/nginx.tls.conf"
download scripts/nginx-entrypoint.sh "$INSTALL_DIR/scripts/nginx-entrypoint.sh"
download scripts/deploy-production.sh "$INSTALL_DIR/scripts/deploy-production.sh"
download .env.production.example "$INSTALL_DIR/.env.production.example"
chmod +x "$INSTALL_DIR/scripts/"*.sh

if [[ ! -f "$INSTALL_DIR/.env" ]]; then
  log "creating production .env"
  cp "$INSTALL_DIR/.env.production.example" "$INSTALL_DIR/.env"
  jwt_secret="$(openssl rand -hex 32)"
  db_password="$(openssl rand -hex 24)"
  minio_password="$(openssl rand -hex 24)"
  sed -i \
    -e "s|^JWT_SECRET=.*|JWT_SECRET=$jwt_secret|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=$db_password|" \
    -e "s|^MINIO_SECRET_KEY=.*|MINIO_SECRET_KEY=$minio_password|" \
    "$INSTALL_DIR/.env"
  chmod 600 "$INSTALL_DIR/.env"
  log "created $INSTALL_DIR/.env; fill domain, TLS, AI and payment keys before enabling payment"
else
  log "keeping existing $INSTALL_DIR/.env"
fi

log "pulling $BACKEND_TAG"
docker pull "$BACKEND_TAG"
immutable_image="$(docker image inspect "$BACKEND_TAG" --format '{{index .RepoDigests 0}}')"
[[ "$immutable_image" == *@sha256:* ]] || die "failed to resolve immutable image digest"

cd "$INSTALL_DIR"
BACKEND_IMAGE="$immutable_image" ./scripts/deploy-production.sh

cat <<EOF

Bootstrap completed.
Deployment directory: $INSTALL_DIR
Environment file:     $INSTALL_DIR/.env
Backend image:        $immutable_image

GitHub CD configuration:
  Repository variable CD_ENABLED=true
  Repository variable CD_DEPLOY_PATH=$INSTALL_DIR
  Secrets CD_SSH_HOST, CD_SSH_USER, CD_SSH_PRIVATE_KEY, CD_SSH_KNOWN_HOSTS
EOF
