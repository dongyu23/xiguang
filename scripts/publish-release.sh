#!/usr/bin/env bash
# ─── 隙光 App 版本发布脚本 ───
#
# 把构建好的 APK 上传到服务器静态目录，并调用后端 /admin/releases 注册版本元信息。
# 用法：
#   ./scripts/publish-release.sh <apk路径> <version> <build_number> <release_note> [channel] [platform]
#
# 示例：
#   ./scripts/publish-release.sh app/build/app/outputs/flutter-apk/app-release.apk 0.2.0 5 "修复登录闪屏" stable android
#
# 前置：
#   1. 服务器已部署（deploy.sh 跑过）
#   2. .env 里配好 SERVER_HOST（或导出 XIGUANG_HOST）、RELEASE_STATIC_DIR
#   3. 至少一个用户已被设为管理员：UPDATE users SET is_admin=TRUE WHERE id=1;
#   4. 本机能 ssh 到服务器、能 curl 到后端 admin 接口

set -euo pipefail

APK_PATH="${1:-}"
VERSION="${2:-}"
BUILD_NUMBER="${3:-}"
RELEASE_NOTE="${4:-}"
CHANNEL="${5:-stable}"
PLATFORM="${6:-android}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[i]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
die()   { echo -e "${RED}[x]${NC} $1" >&2; exit 1; }

# ── 1. 参数校验 ──
[ -n "$APK_PATH" ]        || die "用法: $0 <apk路径> <version> <build_number> <release_note> [channel] [platform]"
[ -f "$APK_PATH" ]        || die "APK 文件不存在: $APK_PATH"
[ -n "$VERSION" ]         || die "缺少 version 参数"
[ -n "$BUILD_NUMBER" ]    || die "缺少 build_number 参数"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "build_number 必须是数字"
[ -n "$RELEASE_NOTE" ]    || die "缺少 release_note 参数"

# ── 2. 加载 .env（取 SERVER_HOST / SSH_USER / RELEASE_STATIC_DIR）──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

SERVER_HOST="${XIGUANG_HOST:-${SERVER_HOST:-}}"
SSH_USER="${XIGUANG_SSH_USER:-root}"
REMOTE_DIR="${RELEASE_STATIC_DIR:-/var/xiguang/app-releases}"
ADMIN_BASE="${XIGUANG_ADMIN_BASE:-http://${SERVER_HOST}:8088}"
ADMIN_TOKEN="${XIGUANG_ADMIN_TOKEN:-}"

[ -n "$SERVER_HOST" ]  || die "请在 .env 里配置 XIGUANG_HOST（服务器 IP/域名）"
[ -n "$ADMIN_TOKEN" ]  || die "请在 .env 或环境变量里配置 XIGUANG_ADMIN_TOKEN（管理员 access_token）"

# ── 3. 计算 SHA-256 与大小 ──
APK_NAME="$(basename "$APK_PATH")"
[[ "$APK_NAME" == *.apk ]] || die "文件名必须以 .apk 结尾: $APK_NAME"
SHA256=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
SIZE=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH")

info "版本: $VERSION (build $BUILD_NUMBER) [$CHANNEL/$PLATFORM]"
info "APK:  $APK_NAME ($SIZE bytes)"
info "SHA:  $SHA256"
info "服务器: $SSH_USER@$SERVER_HOST:$REMOTE_DIR"

# ── 4. 上传 APK 到服务器静态目录 ──
info "上传 APK 到服务器..."
scp -q "$APK_PATH" "$SSH_USER@$SERVER_HOST:$REMOTE_DIR/$APK_NAME"
ok "APK 已上传"

# ── 5. 调用 admin 接口注册版本 ──
info "注册版本元信息..."
RESPONSE=$(curl -s -m 15 -X POST "$ADMIN_BASE/api/v1/admin/releases" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(cat <<EOF
{
  "channel": "$CHANNEL",
  "platform": "$PLATFORM",
  "version": "$VERSION",
  "build_number": $BUILD_NUMBER,
  "apk_file_name": "$APK_NAME",
  "apk_size_bytes": $SIZE,
  "sha256": "$SHA256",
  "release_note": "$RELEASE_NOTE",
  "force_update": false
}
EOF
)")

# 检查响应
if echo "$RESPONSE" | grep -q '"ok":true'; then
  PUBLIC_ID=$(echo "$RESPONSE" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['public_id'])" 2>/dev/null || echo "?")
  ok "发布成功！public_id=$PUBLIC_ID"
  echo ""
  info "客户端打开 App → 我的 → 检查更新 即可看到此版本"
else
  die "发布失败，后端响应: $RESPONSE"
fi
