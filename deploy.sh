#!/usr/bin/env bash
set -euo pipefail

# ─── 隙光一键部署脚本 ───
# 用法: curl -sL https://raw.githubusercontent.com/dongyu23/xiguang/main/deploy.sh | bash
# 或者: bash deploy.sh

REPO="dongyu23/xiguang"
BRANCH="main"
INSTALL_DIR="${XIGUANG_INSTALL_DIR:-$HOME/xiguang}"

# ─── 颜色 ───
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── 检查前置条件 ───
check_prereqs() {
    if ! command -v docker &>/dev/null; then
        err "未找到 Docker，请先安装: https://docs.docker.com/engine/install/"
        exit 1
    fi

    if docker compose version &>/dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &>/dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        err "未找到 Docker Compose，请先安装"
        exit 1
    fi

    ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
    ok "Docker Compose $($COMPOSE_CMD version 2>/dev/null | awk '{print $NF}')"
}

# ─── 生成随机密钥 ───
generate_secret() {
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64
}

# ─── 创建 .env ───
create_env() {
    local env_file="$1"

    if [ -f "$env_file" ]; then
        warn ".env 已存在，跳过生成"
        return
    fi

    info "生成 .env 配置文件..."

    local jwt_secret
    jwt_secret=$(generate_secret)

    local db_password
    db_password=$(generate_secret | head -c 32)

    local minio_user="glimmer_minio"
    local minio_password
    minio_password=$(generate_secret | head -c 32)

    cat > "$env_file" <<EOF
# ─── 隙光 环境变量 ───
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 应用
APP_ENV=production
APP_PORT=8080

# JWT（请勿泄露）
JWT_SECRET=${jwt_secret}
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=720h

# PostgreSQL
DB_USER=glimmer
DB_PASSWORD=${db_password}
DB_NAME=glimmer

# MinIO 对象存储
MINIO_ACCESS_KEY=${minio_user}
MINIO_SECRET_KEY=${minio_password}
MINIO_BUCKET=glimmer-media

# CORS（生产环境请改为实际域名）
ALLOWED_ORIGIN=*

# DeepSeek AI（可选，留空则 AI 功能不可用）
AI_DEEPSEEK_API_KEY=
AI_DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
AI_DEEPSEEK_MODEL=deepseek-v4-flash
AI_DAILY_QUOTA_PER_USER=50
EOF

    ok ".env 已生成（密钥已随机创建）"
    warn "请检查 .env 中的配置，特别是 ALLOWED_ORIGIN"
}

# ─── 下载配置文件 ───
download_configs() {
    info "下载部署配置文件..."

    # docker-compose.yml
    curl -sL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/docker-compose.yml" \
        -o "$INSTALL_DIR/docker-compose.yml"

    # nginx.conf
    curl -sL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/nginx.conf" \
        -o "$INSTALL_DIR/nginx.conf" 2>/dev/null || true

    ok "配置文件已下载"
}

# ─── 拉取镜像并启动 ───
pull_and_start() {
    cd "$INSTALL_DIR"

    info "拉取镜像（首次可能需要几分钟）..."
    $COMPOSE_CMD pull

    info "启动服务..."
    $COMPOSE_CMD up -d

    info "等待服务就绪..."
    sleep 5

    # 检查健康状态
    local retries=12
    while [ $retries -gt 0 ]; do
        if curl -sf http://127.0.0.1:8088/healthz &>/dev/null; then
            ok "后端服务已就绪"
            break
        fi
        retries=$((retries - 1))
        sleep 5
    done

    if [ $retries -eq 0 ]; then
        warn "后端服务启动超时，请检查日志: $COMPOSE_CMD logs app"
    fi
}

# ─── 打印结果 ───
print_result() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  隙光部署完成！${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  API 地址:     ${CYAN}http://127.0.0.1:8088/api/v1${NC}"
    echo -e "  健康检查:     ${CYAN}http://127.0.0.1:8088/healthz${NC}"
    echo -e "  MinIO 控制台: ${CYAN}http://127.0.0.1:9001${NC}"
    echo ""
    echo -e "  安装目录:     ${YELLOW}${INSTALL_DIR}${NC}"
    echo -e "  配置文件:     ${YELLOW}${INSTALL_DIR}/.env${NC}"
    echo ""
    echo -e "  常用命令:"
    echo -e "    查看状态:   ${CYAN}cd ${INSTALL_DIR} && ${COMPOSE_CMD} ps${NC}"
    echo -e "    查看日志:   ${CYAN}cd ${INSTALL_DIR} && ${COMPOSE_CMD} logs -f app${NC}"
    echo -e "    重启服务:   ${CYAN}cd ${INSTALL_DIR} && ${COMPOSE_CMD} restart${NC}"
    echo -e "    停止服务:   ${CYAN}cd ${INSTALL_DIR} && ${COMPOSE_CMD} down${NC}"
    echo -e "    更新版本:   ${CYAN}cd ${INSTALL_DIR} && ${COMPOSE_CMD} pull && ${COMPOSE_CMD} up -d${NC}"
    echo ""
}

# ─── 主流程 ───
main() {
    echo ""
    echo -e "${CYAN}  隙光 — 一键部署${NC}"
    echo -e "${CYAN}  隙中捕光 → 光入成线 → 线间可织 → 织久成屿${NC}"
    echo ""

    check_prereqs

    mkdir -p "$INSTALL_DIR"
    download_configs
    create_env "$INSTALL_DIR/.env"
    pull_and_start
    print_result
}

main "$@"
