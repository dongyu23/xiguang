# App Release 模块实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给隙光新增"后端发布 + 客户端在线更新"功能，支持上传 APK、版本元信息查询、下载安装替换。

**Architecture:** 后端新增 `app_release` 模块（Modular Monolith 的一个内部包），客户端新增 `app_update` feature。APK 走 Nginx 静态目录直链分发。客户端轮询 + piggyback meta，不做长连接推送。版本比较只看 build_number。

**Tech Stack:** Go + Chi + pgx / Flutter + Riverpod + dio + open_filex + package_info_plus

---

## 现状对照（代码已存在，本 plan 用于固化流程与验证）

下列文件已实现并编译通过。本 plan 的"任务"以"验证 + 补漏"为主，而非从零写。

### Task 1: 后端数据模型

**Files:**
- Create: `backend/migrations/002_app_releases.sql`
- Modify: `backend/internal/infra/db/db.go`（内联 schema 追加 app_releases + is_admin）

- [ ] 验证：`app_releases` 表含 `(channel, platform, build_number)` 唯一约束 + `idx_app_releases_latest` 部分索引
- [ ] 验证：`users.is_admin` 列存在
- [ ] 验证：`go build ./...` 通过

### Task 2: 后端 domain / repository

**Files:**
- Create: `backend/internal/app_release/domain/release.go`
- Create: `backend/internal/app_release/repository/pg.go`

- [ ] 验证：Release / PublishParams / UpdatePolicyParams / PublicView / VersionMeta 定义齐全
- [ ] 验证：repository 6 个方法（Insert/FindLatest/FindByPublicID/List/UpdatePolicy/SoftDelete）实现
- [ ] 验证：FindLatest 按 build_number DESC 取第一条

### Task 3: 后端 service

**Files:**
- Create: `backend/internal/app_release/service/release.go`

- [ ] 验证：Publish 校验四件套——文件存在 / SHA-256 hex64 / build 递增 / 文件名防路径穿越
- [ ] 验证：LatestPublic 找不到返回 nil（不是 error）
- [ ] 验证：LatestMeta 返回 piggyback 用的轻量 VersionMeta
- [ ] 验证：UpdatePolicy 三字段全 nil 时报 ErrInvalidParams

### Task 4: 后端 handler + admin 中间件

**Files:**
- Create: `backend/internal/app_release/handler/handler.go`
- Create: `backend/internal/auth/middleware/admin.go`
- Create: `backend/internal/app_release/app_release.go`（Module 装配）

- [ ] 验证：`GET /app/version` 公开无需登录
- [ ] 验证：`/admin/releases/*` 经 RequireAuth + RequireAdmin 两层
- [ ] 验证：RequireAdmin 查 `users.is_admin`，不放 JWT claims

### Task 5: 路由挂载 + piggyback meta

**Files:**
- Modify: `backend/internal/infra/router/router.go`
- Modify: `backend/internal/auth/handler/handler.go`（me() 用 WriteJSONWithMeta）
- Modify: `backend/internal/shared/http.go`（WriteJSONWithMeta）
- Modify: `backend/internal/infra/config/config.go`（ReleaseStaticDir / ReleaseDownloadBase）

- [ ] 验证：`api.Mount("/app", ...)` + `api.Mount("/admin/releases", ...)`
- [ ] 验证：`/users/me` 响应含 `meta` 字段（有发布时）
- [ ] 验证：`go build ./...` 通过

### Task 6: Flutter domain / data

**Files:**
- Create: `app/lib/features/app_update/domain/app_version.dart`
- Create: `app/lib/features/app_update/domain/update_state.dart`
- Create: `app/lib/features/app_update/data/app_update_repository.dart`

- [ ] 验证：AppVersion 含 latestBuild / minSupportedBuild / downloadUrl / sha256 / forceUpdate
- [ ] 验证：UpdateState 状态机完整
- [ ] 验证：repository 三方法 checkLatest / downloadApk（带进度回调）/ openInstaller

### Task 7: Flutter providers + UI

**Files:**
- Create: `app/lib/features/app_update/presentation/providers/app_update_providers.dart`
- Create: `app/lib/features/app_update/presentation/widgets/update_sheet.dart`
- Modify: `app/lib/features/profile/presentation/pages/mine_page.dart`（检查更新入口 + 红点）
- Modify: `app/lib/features/shared/data/api_client.dart`（拦截 meta → appUpdateBadgeProvider）
- Modify: `app/android/app/src/main/AndroidManifest.xml`（REQUEST_INSTALL_PACKAGES）
- Modify: `app/pubspec.yaml`（open_filex）

- [ ] 验证：`dart analyze app/lib` 0 error
- [ ] 验证：mine_page 有"检查更新"入口且带红点
- [ ] 验证：强更场景 sheet 不可关闭（canPop = false）

### Task 8: 端到端验证

- [x] 启动后端（临时 PG + 二进制直跑，已通过）
- [x] `curl /healthz` 200
- [x] 设 admin + 登录拿 token（已通过）
- [x] `curl -X POST /admin/releases` 发版（已通过，返回完整 release）
- [x] `curl /app/version` 返回正确元信息（已通过）
- [x] `/users/me` 响应含 meta（已通过）
- [x] `flutter build apk` 成功
- [x] 9 个 service 单测全通过
- [x] 业务规则验证：重复发同 build → 409 / 非管理员发版 → 403（已通过）
- [x] Docker 镜像重建 + 线上 `/app/version` 路由生效（已通过，返回 data:null）

### Task 9: 可部署件补齐（本次会话新增）

**Files:**
- Create: `scripts/publish-release.sh`（发布脚本：scp 上传 APK + 调 admin 接口注册）
- Modify: `.env.example`（新增 RELEASE_STATIC_DIR / RELEASE_DOWNLOAD_BASE 条目及注释）
- Modify: `docker-compose.yml`（nginx + app 挂载 app-releases 卷；app 注入 RELEASE_* env）
- Modify: `deploy.sh`（部署时 mkdir app-releases 目录）
- Modify: `backend/bin/xiguang-linux-amd64`（重新交叉编译，含 app_release 路由）

- [x] 发布脚本语法检查通过（`bash -n`）
- [x] .env.example 含 RELEASE_* 条目
- [x] `docker compose config` 解析出 app-releases 卷挂载（nginx + app 双挂载）
- [x] deploy.sh 建静态目录
- [x] 重新编译 linux amd64 二进制
- [x] 重建 Docker 镜像 + 重启 + `/app/version` 路由线上生效

## 关键设计决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 推送方式 | 客户端轮询 + piggyback | 不引第三方、符合"不打扰" |
| APK 存储 | Nginx 静态目录 | 公开资产直链、不入 MinIO |
| 版本对比 | 只比 build_number | 简单可靠 |
| 管理员 | 查 is_admin 不放 claims | 降权即时生效 |
| 验签 | SHA-256 | 防中间人换包 |
| 下架 | 软删除 | 留痕可追溯 |
