# 隙光（Xiguang）技术架构报告

> **版本**：v0.2 MVP  
> **日期**：2026-06-06  
> **作者**：技术团队  
> **适用范围**：内部技术评审、架构备案

---

## 目录

1. [项目概述](#1-项目概述)
2. [系统总览](#2-系统总览)
3. [后端架构](#3-后端架构)
4. [前端架构](#4-前端架构)
5. [数据库设计](#5-数据库设计)
6. [API 接口设计](#6-api-接口设计)
7. [部署架构](#7-部署架构)
8. [设计系统](#8-设计系统)
9. [关键模块详解](#9-关键模块详解)
10. [离线同步机制](#10-离线同步机制)
11. [AI 集成](#11-ai-集成)
12. [实施状态与度量](#12-实施状态与度量)
13. [技术决策记录](#13-技术决策记录)
14. [已知问题与后续规划](#14-已知问题与后续规划)

---

## 1. 项目概述

### 1.1 产品定义

「隙光」是一款**私人多媒体碎片记录与回看工具**，面向有碎片记录习惯、注重内心体验的年轻人。核心能力是轻量捕捉文字、图片与情绪光片，并通过时间河流、旧光回访、AI 柔光整理和小宇宙聚合，解决日常感受分散记录、难以回看和难以形成个人脉络的问题。

### 1.2 产品隐喻体系

| 原始概念 | 隙光命名 | 原始概念 | 隙光命名 |
|---------|---------|---------|---------|
| 记录 | 捕光 | 标签 | 给光命名 |
| 单条记录 | 光片 | AI 总结 | 柔光整理 |
| 时间线 | 时间河流 | AI 助手 | 星图管理员 |
| 关联 | 织线 | 主题聚合 | 主题星点 / 小岛 |
| 相关记录 | 旧光 / 回声 | 个人空间 | 屿 / 小宇宙 |

### 1.3 技术栈

| 层 | 选型 | 版本/说明 |
|---|-----|---------|
| **移动端** | Flutter + Riverpod | SDK ≥3.3.0, iOS + Android |
| **后端** | Go + Chi + pgx | Go 1.24, 模块化单体 |
| **数据库** | PostgreSQL | 16-alpine |
| **缓存** | Redis | 7-alpine |
| **对象存储** | MinIO | S3-compatible |
| **反向代理** | Nginx | alpine |
| **AI 服务** | DeepSeek | deepseek-v4-flash |
| **部署** | Docker Compose | 5 容器单机编排 |

---

## 2. 系统总览

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App (iOS + Android)                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────────┐             │
│  │ 隙(捕光) │ │ 线(河流) │ │ 屿(宇宙) │ │ 我的(设置) │             │
│  └─────────┘ └─────────┘ └─────────┘ └───────────┘             │
│                        │ dio + Riverpod                          │
│  ┌──────────────────────┴──────────────────────────────┐        │
│  │      Drift (本地 SQLite)  +  Sync Engine             │        │
│  └─────────────────────────────────────────────────────┘        │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS (TLS 1.2/1.3)
┌──────────────────────────▼──────────────────────────────────────┐
│                    Nginx :443 (反向代理)                          │
│     /api/* → Go Backend   /media/* → MinIO   / → Flutter Web    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    Go Backend :8080                               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  16 业务模块 (Module Monolith)                             │   │
│  │  auth · fragment · media · emotion · tag · timeline      │   │
│  │  stats · relation · starmap · island · space             │   │
│  │  whitenoise · sync · ai                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│           │                  │                    │               │
└───────────┼──────────────────┼────────────────────┼──────────────┘
            │                  │                    │
    ┌───────▼──────┐  ┌────────▼───────┐  ┌───────▼──────┐
    │ PostgreSQL:16│  │   Redis:7      │  │  MinIO       │
    │   (pg_data)  │  │  (redis_data)  │  │ (minio_data) │
    └──────────────┘  └────────────────┘  └──────────────┘
```

### 2.2 核心数据流

```
用户捕光 → Flutter 本地 SQLite → OpLog 入队 → Sync Push
                                                ↓
        时间河流 ← Flutter API 查询 ←── Go Backend → PostgreSQL
                                                ↓
        AI 柔光整理 → DeepSeek API → 结果写入 ai_requests
```

### 2.3 模块依赖关系

```
shared ← infra ← auth → fragment → timeline/stats/relation/starmap
                         ↓
                       island (依赖 tag + fragment)
                         
独立模块: emotion, space, whitenoise (无 DB 依赖)
预留模块: ai (依赖 infra/config + DB)
基础模块: sync (依赖 fragment + media + relation)
```

---

## 3. 后端架构

### 3.1 分层设计

每个模块采用统一的分层结构：

```
internal/{module}/
├── domain/          # 实体定义、接口契约（零依赖）
├── repository/      # 数据库实现（PG实现，实现领域接口）
├── service/         # 业务逻辑编排（调用 repository）
└── handler/         # HTTP 处理器（参数校验、序列化）
```

**模块入口文件** (`{module}.go`)：统一构造函数 `New(db, cfg)` → 组装三层 → 返回 Handler。

### 3.2 基础设施层

| 组件 | 包 | 核心能力 |
|-----|---|---------|
| **配置** | `infra/config` | 环境变量读取，37 个配置项，生产环境校验 |
| **数据库** | `infra/db` | pgxpool 连接池，嵌入式幂等 DDL 迁移 |
| **Redis** | `infra/redis` | 配置结构定义（客户端由调用方初始化） |
| **存储** | `infra/storage` | Provider 接口（PresignedPut/Get/Delete），MinIO/S3 适配 |
| **日志** | `infra/logger` | slog JSON 输出，环境区分日志级别 |
| **路由** | `infra/router` | Chi v5 组装，中间件链 + 模块挂载 |
| **共享** | `shared` | APIResponse 信封、WriteJSON/WriteError、DecodeJSON |

### 3.3 中间件链

```
RequestID → RealIP → Recoverer → Timeout(30s) → CORS → [Auth JWT]
```

- 公开路由：`/healthz`, `/api/v1/auth/*`, `/api/v1/emotions`
- 保护路由：其余全部 `/api/v1/*` 需 Bearer Token

### 3.4 模块清单

| # | 模块 | 依赖 DB | 核心功能 | 状态 |
|---|-----|---------|---------|------|
| 1 | **auth** | ✅ | 注册/登录/刷新Token/用户管理，自定义JWT，bcrypt密码 | ✅ 完成 |
| 2 | **fragment** | ✅ | 光片 CRUD，标签关联，媒体关联，岛屿生长触发，织线入口 | ✅ 完成 |
| 3 | **media** | ✅ | Presigned URL 签发，上传确认，媒体元数据管理 | ⚠️ Presign 为占位 |
| 4 | **emotion** | ❌ | 8 种情绪静态列表（莫兰迪色 + 诗意描述） | ✅ 完成 |
| 5 | **tag** | ✅ | 标签 CRUD（upsert），使用计数，按频率排序 | ✅ 完成 |
| 6 | **timeline** | ✅ | 时间河流查询，日期分组 | 🔄 与 fragment 有重复 |
| 7 | **stats** | ✅ | 7 天情绪密度，高频标签词 | ⚠️ Redis 缓存未启用 |
| 8 | **relation** | ✅ | 织线创建/查询/删除，自引用防护 | ✅ 完成 |
| 9 | **starmap** | ✅ | 星图数据（螺旋布局），力导向布局接口预留 | ⚠️ Builder 未实现 |
| 10 | **island** | ✅ | 岛屿 CRUD，生长引擎，光片关联，静默检测 | ✅ 完成 |
| 11 | **space** | ❌ | 空间主题配置（硬编码返回星空调） | ⚠️ 存根 |
| 12 | **whitenoise** | ❌ | 4 种白噪音静态列表 | ✅ 完成 |
| 13 | **sync** | ✅ | Push/Pull 操作日志同步，幂等去重 | ⚠️ 分页未完成 |
| 14 | **ai** | ✅ | 柔光整理（存根），岛屿 AI 构建，文案润色 | 🔄 部分可用 |

### 3.5 关键后端指标

| 指标 | 数值 |
|-----|------|
| Go 源文件 | 99 个 |
| Go 代码行数 | ~5,892 行 |
| 直接依赖 | 3 个（chi, pgx, crypto） |
| 间接依赖 | 5 个 |
| 总 API 端点 | 45 个（6 公开 + 39 保护） |

---

## 4. 前端架构

### 4.1 技术栈

| 用途 | 包 | 说明 |
|-----|---|------|
| 状态管理 | flutter_riverpod | FutureProvider + StateProvider + AsyncNotifier |
| 路由 | go_router | StatefulShellRoute.indexedStack（4 Tab） |
| 本地数据库 | drift + sqlite3_flutter_libs | 离线优先存储 |
| 网络 | dio | 统一拦截器 + 自动 Token 刷新 |
| 安全存储 | flutter_secure_storage | JWT Token 持久化 |
| 图片 | image_picker + flutter_image_compress | 多选 + 压缩 |
| 录音 | record + just_audio + audio_session | 语音 + 白噪音播放 |
| 语音识别 | speech_to_text | 捕光语音输入 |
| 崩溃上报 | sentry_flutter | 异常追踪 |

### 4.2 模块结构

```
lib/
├── design/                  # 设计令牌系统
│   ├── tokens/              # colors, spacing, radius, typography, shadows, blur, motion
│   └── themes/              # ThemeData + 3 ThemeExtensions (Blur, Glow, Space)
├── ui/                      # 通用 UI 组件
│   ├── primitives/          # BlurBox, BreathingWidget, GlowButton, MorandiCard, RippleTap
│   ├── composites/          # EmotionPicker, LightCard, TagChip, ImageGrid, MediaImage
│   └── spaces/              # SpaceCanvas, StarrySpace, OceanSpace, IslandSpace(空)
├── features/                # 10 个业务模块（每模块 domain/data/presentation）
│   ├── auth/                # 登录/注册/会话管理
│   ├── fragment/            # 捕光/光片详情/编辑/媒体上传
│   ├── timeline/            # 时间河流/日期分组/筛选/批量操作
│   ├── stats/               # 情绪密度图/高频词云
│   ├── relation/            # 织线页/关系选择
│   ├── starmap/             # 星图画布/节点拖拽
│   ├── island/              # 小宇宙页/岛屿详情/光片选择器
│   ├── space/               # 沉浸式空间页
│   ├── whitenoise/          # 白噪音页面/播放器
│   ├── sync/                # 同步引擎/冲突解决
│   ├── ai/                  # 柔光整理对话页/建议卡
│   └── shared/data/         # ApiClient（统一HTTP客户端）
└── app/                     # App入口 + 路由 + 全局Provider
```

### 4.3 底部导航结构

| Tab | 名称 | 路由 | 核心页面 |
|-----|------|------|---------|
| 隙 | 捕光 | `/capture` | CapturePage（多媒体输入 + 情绪选择 + 黑胶唱片播放） |
| 线 | 时间河流 | `/timeline` | TimeRiverPage（日期分组 + 筛选 + 多选批处理） |
| 屿 | 小宇宙 | `/universe` | UniversePage（星空画布 + 岛屿网格 + 统计面板） |
| 我的 | 设置 | `/mine` | MinePage（资料编辑 + AI 开关 + 同步状态 + 退出） |

### 4.4 路由架构

```
GoRouter
├── /auth-restoring          # 会话恢复中
├── /login                   # 登录
├── /register                # 注册
├── /space                   # 沉浸式空间（全屏）
├── /starmap                 # 星图（全屏）
├── /whitenoise              # 白噪音管理
├── /glow-organize           # 柔光整理
├── /ai/build-islands        # AI 岛屿构建
├── StatefulShellRoute (4 Tab)
│   ├── Tab 1 (隙): /capture, /fragments/:id, /fragments/:id/edit
│   ├── Tab 2 (线): /timeline
│   ├── Tab 3 (屿): /universe, /islands/:id, /islands/create
│   └── Tab 4 (我的): /mine, /settings
└── /weave/:sourceId         # 织线（全屏上下文页面）
```

**关键设计决策**：
- 路由在 session 变更时**完全重建**（保证无过期状态）
- 全局 `MediaQuery.withNoTextScaling` 锁定系统字体缩放
- 底部导航栏为自定义浮动手势栏（非 Material BottomNavigationBar）

### 4.5 关键前端指标

| 指标 | 数值 |
|-----|------|
| Dart 源文件 | 165 个 |
| Dart 代码行数 | ~14,705 行 |
| 功能模块 | 10 个 + 1 共享基础设施 |
| 页面组件 | 17 个 |
| 自定义 Widget | 20+ 个 |
| Provider 总数 | 25+ 个 |
| CustomPainter 实现 | 8+ 个 |

---

## 5. 数据库设计

### 5.1 表结构总览

共 **11 张表** + **3 个 PostgreSQL 自定义枚举类型**。

#### 枚举类型

| 枚举名 | 值 |
|-------|---|
| `fragment_status` | twilight, stardust, echo, seed, tide, island_core |
| `media_type` | image, audio |
| `island_status` | star_point, growing, formed, dormant, relit |

#### 核心表

| 表名 | 主键 | 索引数 | 增长等级 | 用途 |
|-----|------|-------|---------|------|
| `users` | BIGSERIAL | 2 | 🟢 低 | 用户账户 |
| `fragments` | BIGSERIAL | 3 | 🔴 高 | 光片（核心实体） |
| `tags` | BIGSERIAL | 2 | 🟡 中 | 标签 |
| `fragment_tags` | 复合 | 1 | 🔴 高 | 光片-标签关联 |
| `media_files` | BIGSERIAL | 2 | 🔴 高 | 媒体文件元数据 |
| `relations` | BIGSERIAL | 3 | 🟡 中 | 织线关联 |
| `islands` | BIGSERIAL | 3 | 🟢 低 | 主题岛 |
| `island_fragments` | 复合 | 1 | 🟡 中 | 岛-光片关联 |
| `refresh_tokens` | BIGSERIAL | 1 | 🟢 低 | 刷新令牌 |
| `oplog` | BIGSERIAL | 3 | 🔴 极高 | 同步操作日志 |
| `ai_requests` | BIGSERIAL | 1 | 🟢 低 | AI 请求记录 |

### 5.2 核心设计决策

| 决策 | 说明 |
|-----|------|
| **双 ID 策略** | BIGSERIAL（服务端内部）+ UUID public_id（客户端离线预生成） |
| **软删除** | 所有表使用 `deleted_at TIMESTAMPTZ`，fragments 额外使用 `is_deleted BOOLEAN` |
| **部分索引** | 所有索引使用 `WHERE deleted_at IS NULL`（fragments: `WHERE is_deleted = FALSE`） |
| **外键** | 全部使用 FOREIGN KEY 保证引用完整性 |
| **密码存储** | bcrypt 哈希，原始密码不落库 |
| **Token 存储** | SHA-256 哈希存储 refresh token，原始不落库 |
| **oplog 幂等** | `UNIQUE(user_id, client_op_id)` 唯一约束 |
| **DDL 策略** | 嵌入式 inline migration（Go 常量），保证单二进制部署即可建库 |

### 5.3 岛屿生长引擎

标签触发的状态机（`island/rules/engine.go`）：

```
同标签 3 次 → star_point → 4 次 → growing → 5 次 → formed
                                                    ↓ (30天无新光片)
                                                  dormant
                                                    ↓ (新光片出现)
                                                  relit → formed
```

阈值常量：`StarPointThreshold=3`, `FormedThreshold=5`, `DormantDays=30`

---

## 6. API 接口设计

### 6.1 规范

| 维度 | 规范 |
|-----|------|
| 风格 | RESTful，`/api/v1` 前缀 |
| URL | kebab-case，复数名词 |
| 字段 | snake_case（JSON + Query + DB） |
| 响应信封 | `{"ok": bool, "data": T, "error": {"code": "...", "message": "..."}}` |
| 分页-游标 | `CursorPage[T]`：items + next_cursor + has_more |
| 分页-传统 | `Page[T]`：items + page + page_size + total + total_pages |
| 同步协议 | `next_since_rev` 替代 cursor |
| 错误码 | `module.semantic_description`（如 `auth.invalid_credentials`） |

### 6.2 完整端点清单（45 个）

| 方法 | 路径 | 模块 | 认证 | 说明 |
|-----|------|------|------|------|
| GET | `/healthz` | infra | 否 | 健康检查 |
| POST | `/api/v1/auth/register` | auth | 否 | 注册 |
| POST | `/api/v1/auth/login` | auth | 否 | 登录 |
| POST | `/api/v1/auth/refresh` | auth | 否 | 刷新令牌 |
| GET | `/api/v1/emotions` | emotion | 否 | 情绪列表 |
| GET | `/api/v1/users/me` | auth | 是 | 当前用户 |
| PUT | `/api/v1/users/me` | auth | 是 | 更新用户 |
| POST | `/api/v1/fragments` | fragment | 是 | 创建光片 |
| GET | `/api/v1/fragments` | fragment | 是 | 光片列表 |
| GET | `/api/v1/fragments/{id}` | fragment | 是 | 光片详情 |
| PUT | `/api/v1/fragments/{id}` | fragment | 是 | 编辑光片 |
| DELETE | `/api/v1/fragments/{id}` | fragment | 是 | 软删除光片 |
| POST | `/api/v1/fragments/{id}/weave` | fragment | 是 | 从光片发起织线 |
| GET | `/api/v1/timeline` | timeline | 是 | 时间河流 |
| GET | `/api/v1/tags` | tag | 是 | 标签列表 |
| POST | `/api/v1/tags` | tag | 是 | 创建标签 |
| PUT | `/api/v1/tags/{id}` | tag | 是 | 编辑标签 |
| DELETE | `/api/v1/tags/{id}` | tag | 是 | 删除标签 |
| GET | `/api/v1/stats/emotion-density` | stats | 是 | 情绪密度 |
| GET | `/api/v1/stats/freq-words` | stats | 是 | 高频词 |
| GET | `/api/v1/relations` | relation | 是 | 织线列表 |
| POST | `/api/v1/relations` | relation | 是 | 创建织线 |
| DELETE | `/api/v1/relations/{id}` | relation | 是 | 删除织线 |
| GET | `/api/v1/starmap` | starmap | 是 | 星图数据 |
| GET | `/api/v1/islands` | island | 是 | 岛列表 |
| POST | `/api/v1/islands` | island | 是 | 创建岛 |
| GET | `/api/v1/islands/{id}` | island | 是 | 岛详情 |
| PUT | `/api/v1/islands/{id}` | island | 是 | 编辑岛 |
| DELETE | `/api/v1/islands/{id}` | island | 是 | 删除岛 |
| POST | `/api/v1/islands/{id}/fragments` | island | 是 | 添加光片到岛 |
| DELETE | `/api/v1/islands/{id}/fragments` | island | 是 | 从岛移除光片 |
| GET | `/api/v1/islands/{name}/fragments` | island | 是 | 岛内光片列表 |
| POST | `/api/v1/media/presign-upload` | media | 是 | 签发上传凭证 |
| POST | `/api/v1/media/confirm-upload` | media | 是 | 确认上传 |
| GET | `/api/v1/media/{id}` | media | 是 | 媒体详情 |
| DELETE | `/api/v1/media/{id}` | media | 是 | 删除媒体 |
| GET | `/api/v1/space/config` | space | 是 | 空间配置 |
| PUT | `/api/v1/space/config` | space | 是 | 更新空间配置 |
| GET | `/api/v1/whitenoise` | whitenoise | 是 | 白噪音列表 |
| POST | `/api/v1/sync/push` | sync | 是 | 推送本地变更 |
| GET | `/api/v1/sync/pull` | sync | 是 | 拉取远程变更 |
| POST | `/api/v1/ai/glow-summary` | ai | 是 | 柔光整理 |
| GET | `/api/v1/ai/requests` | ai | 是 | AI 请求历史 |
| POST | `/api/v1/ai/build-islands` | ai | 是 | AI 岛屿构建 |
| POST | `/api/v1/ai/polish` | ai | 是 | AI 文案润色 |

### 6.3 错误码体系

| code | 含义 |
|------|-----|
| `success` | 成功 |
| `auth.unauthorized` | 未认证 |
| `auth.token_expired` | Token 过期 |
| `auth.invalid_credentials` | 用户名或密码错误 |
| `auth.username_taken` | 用户名已占用 |
| `fragment.not_found` | 光片不存在 |
| `fragment.access_denied` | 无权访问 |
| `media.upload_too_large` | 文件过大 |
| `media.unsupported_format` | 不支持的格式 |
| `relation.not_found` | 织线不存在 |
| `relation.invalid_type` | 无效关系类型 |
| `relation.self_link` | 不能关联自己 |
| `island.not_found` | 岛不存在 |
| `sync.conflict` | 同步冲突 |
| `validation.invalid_param` | 参数校验失败 |
| `common.internal_error` | 服务器内部错误 |

---

## 7. 部署架构

### 7.1 Docker Compose 编排

```
                          Nginx (:8088, :8443)
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
    Go Backend              MinIO               Flutter Web
     (:8080)               (:9000)              (静态文件)
          │
    ┌─────┴─────┐
    ▼           ▼
PostgreSQL    Redis
(:5432)      (:6379)
```

### 7.2 资源分配

| 容器 | 镜像 | 内存限制 | 暴露端口 | 持久化 |
|-----|------|---------|---------|--------|
| nginx | nginx:alpine | 64M | 8088:80, 8443:443 | 无（配置 bind mount） |
| app | scratch（自构建） | 256M | 8080（内部） | 无 |
| postgres | postgres:16-alpine | 512M | 5432（内部） | ✅ pg_data |
| redis | redis:7-alpine | 128M | 6379（内部） | ❌ 缓存可丢 |
| minio | minio:latest | 256M | 9000, 9001（内部） | ✅ minio_data |

**总资源需求**：~1.2GB 内存（单机 2C2G 可运行）

### 7.3 构建流程

```
1. Go 交叉编译 → backend/bin/xiguang-linux-{arm64|amd64}
2. Flutter build web → app/build/web/
3. docker compose up -d
   ├── postgres + redis + minio 启动
   ├── Go app 等待 postgres 健康 → 自动 migrate → 启动
   └── nginx 等待 app 健康 → 启动
```

### 7.4 健康检查

| 组件 | 检查方式 | 间隔 |
|-----|---------|------|
| Go Backend | `/healthz` HTTP 200 | 15s |
| PostgreSQL | `pg_isready` | 10s |
| MinIO | `mc ready local` | 10s |

外部探活建议使用 UptimeRobot 每 30s 探测 `/healthz`。

---

## 8. 设计系统

### 8.1 色彩系统（莫兰迪色系）

| Token | 色值 | 用途 |
|-------|------|------|
| `paper` | #F6F3EC | 全局背景（暖白） |
| `ink` | #233332 | 主文字色（深青黑） |
| `inkMuted` | #78827D | 辅助文字 |
| `line` | #E4DDD0 | 分割线 |
| `teaGreen` | #72A58F | 品牌主色 |
| `mistBlue` | #9EBBCC | 辅助色一 |
| `sunsetCoral` | #E9A18B | 辅助色二 |
| `lilac` | #D9CCE8 | 辅助色三 |

### 8.2 情绪色彩映射

| 情绪 | 色彩 |
|-----|------|
| 平静 | #9CB7AD（灰绿） |
| 开心 | #E6BE8A（暖金） |
| 疲惫 | #A8A1B8（灰紫） |
| 焦虑 | #C58F8D（暖粉） |
| 失落 | #8EA4BF（灰蓝） |
| 被击中 | #D8A48F（暖杏） |
| 混乱 | #B7A58E（灰棕） |
| 说不清 | #B9B9A8（灰绿黄，默认） |

### 8.3 动效体系

| 层级 | 场景 | 技术 | 时长 |
|-----|------|------|------|
| 微交互 | 按钮/页面切换 | AnimatedContainer/Opacity | 200-400ms |
| 呼吸感 | 星点浮动/光束/涟漪 | AnimationController.repeat + CustomPainter | 2-4s |
| 水波 | 触摸反馈 | 自定义 RipplePainter | ~600ms |

### 8.4 自定义 UI 基元

| 组件 | 技术 | 说明 |
|-----|------|------|
| **BlurBox** | BackdropFilter + ImageFilter.blur | 毛玻璃容器（4 级模糊度） |
| **BreathingWidget** | AnimationController.repeat | 呼吸感动画包装器（opacity + scale） |
| **GlowButton** | FilledButton | 微光按钮（glow 效果预留） |
| **MorandiCard** | Container + softDecoration | 莫兰迪风格卡片（所有卡片的基础） |
| **RippleTap** | GestureDetector + CustomPainter | 触摸涟漪（从触点点扩散） |
| **StarrySpace** | CustomPainter + 粒子系统 | 22 背景星点 + 5 星座节点 + 连线 |
| **OceanSpace** | CustomPainter + 3 层正弦波 | 海洋波浪（不同振幅/频率/透明度） |

---

## 9. 关键模块详解

### 9.1 捕光页（CapturePage）— 最复杂页面

约 1,916 行代码，集成以下子系统：

- **情绪驱动背景**：`_MoodBackgroundPainter`（CustomPainter），根据当前情绪切换渐变 + 波浪线
- **黑胶唱片播放器**：`_VinylLightSource`，just_audio 驱动，情绪变化时自动切歌
- **语音输入**：speech_to_text 包，中文识别，按讲模式，完整状态机（idle→preparing→listening→success→failed）
- **图片选择**：多选（最多 6 张），压缩至 960px/质量 76
- **草稿持久化**：SharedPreferences 自动保存/恢复，420ms 防抖
- **提交流程**：fragmentsProvider.captureWithResult() → 清除草稿 → 成功 SnackBar

### 9.2 时间河流页（TimeRiverPage）

约 1,035 行，核心功能：

- **日期导航栏**：最多 3 个月快捷入口 + 年/月自定义滚轮选择器
- **日期分组列表**：每组标题栏（绿色圆点 + 标签 + 计数）+ LightFragmentCard
- **多选模式**：长按激活 → 底部操作栏 → 批量删除 / 批量 AI 润色
- **离线回退**：API 失败时本地 `_FallbackTimeline` 客户端分组

### 9.3 织线页（WeavePage）

约 820 行，织线交互核心：

- **源光片展示** + 候选光片列表（排除自身）
- **6 种关系类型选择器**：回声/伏笔/余震/平行宇宙/小小救命/旧光
- **关系注释**（最多 60 字符）
- **自定义装饰**：`_ThreadMist`（波浪背景）、`_StepThread`（曲线路径）、`_LightSketchPainter`（迷你艺术品）
- **提交动画**：成功复选标记 toast

### 9.4 小宇宙页（UniversePage）

约 902 行，数据驱动的星空：

- **UniverseSkyBanner**：基于岛屿数据的星座图（黄金角螺旋布局，连线 <160px 的节点）
- **主题岛屿网格**：状态徽章（"已织线"/"生长中"/"正在靠近"）
- **统计面板**：高频词云 + 情绪密度图
- **AI 入口**：柔光整理对话导航

### 9.5 AI 模块

| 功能 | 端点 | 状态 |
|-----|------|------|
| 柔光整理 | POST /ai/glow-summary | ⚠️ 硬编码 "not_implemented" |
| 岛屿构建 | POST /ai/build-islands | ✅ 可用（日配额 3 次，DeepSeek API） |
| 文案润色 | POST /ai/polish | ✅ 可用（DeepSeek API） |
| 请求历史 | GET /ai/requests | ✅ 可用 |

**岛屿构建 Prompt 设计**：
- 系统提示要求 AI 发现主题联系，建议岛屿名称（2-6 个中文字，诗意化）
- 描述 10-30 字，语气温和
- 最多 5 组，每组最少 2 个光片
- 响应 JSON 格式严格校验

---

## 10. 离线同步机制

### 10.1 数据流

```
用户操作 → OpLog 生成 (client_op_id + client_seq)
                ↓
        本地 Drift 存储 + 入队
                ↓
        Sync Engine Push → POST /sync/push
                ↓ (幂等: client_op_id 去重)
        服务端 oplog 表 (server_rev 自增)
                ↓
        Sync Engine Pull ← GET /sync/pull?since_rev=N
                ↓
        应用到本地 Drift → 冲突处理
```

### 10.2 冲突策略

- **乐观并发**：操作携带 `base_server_version`，服务端对比当前 `server_rev`
- `base == server_rev` → 接受更新
- `base < server_rev` → 返回 conflict（不静默覆盖）
- **标签/媒体/关联**：尽量自动合并
- **Fragment 正文冲突**：客户端生成冲突副本

### 10.3 MVP 状态

| 组件 | 状态 |
|-----|------|
| OpLog 生成 | ✅ 接口定义 + Go 端存储 |
| Push 端点 | ✅ 幂等实现 |
| Pull 端点 | ✅ 可用（has_more 恒 false） |
| Sync Engine (Flutter) | ⚠️ 骨架（syncNow 仅设置状态） |
| 冲突解决 | ✅ 版本对比逻辑 |
| 任务调度 | ❌ 未实现后台定时同步 |

---

## 11. AI 集成

### 11.1 DeepSeek 配置

```
AI_PROVIDER=deepseek
AI_DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
AI_DEEPSEEK_MODEL=deepseek-v4-flash
AI_MAX_TOKENS=2048
AI_TIMEOUT=60s
AI_DAILY_QUOTA_PER_USER=50
```

### 11.2 Provider 接口

```go
type Provider interface {
    Chat(ctx, systemPrompt, userMessage string) (response string, tokensUsed int, err error)
}
```

### 11.3 AI 行为约束

按产品规范，AI 模块遵循：
- ✅ 所有 AI 功能由用户主动触发（非后台自动）
- ✅ AI 只提供候选建议，用户决定采纳/修改/忽略
- ✅ 交互语气克制："这几束光似乎有一点相似"
- ✅ AI 不强绑定产品，产品脱离 AI 也可正常使用
- ❌ 不做心理诊断、不评判用户

---

## 12. 实施状态与度量

### 12.1 代码量统计

| 类别 | 文件数 | 代码行数 |
|-----|-------|---------|
| **Go 后端** | 99 | ~5,892 |
| **Dart 前端** | 165 | ~14,705 |
| **SQL 迁移** | 1 | 185 |
| **配置文件** | 5 | ~200 |
| **测试文件** | 10 | ~800 |
| **总计（核心源码）** | ~280 | ~21,500 |

### 12.2 模块完成度

| 模块 | 后端 | 前端 | 测试 |
|-----|------|------|------|
| auth | ✅ 完整 | ✅ 完整 | ✅ 部分 |
| fragment | ✅ 完整 | ✅ 完整 | ✅ 部分 |
| media | ⚠️ Presign 占位 | ⚠️ 基础 | ❌ |
| emotion | ✅ 完整 | ✅ 完整 | ❌ |
| tag | ✅ 完整 | ✅ 完整 | ❌ |
| timeline | 🔄 有重复 | ✅ 完整 | ❌ |
| stats | ⚠️ 缓存未启用 | ✅ 完整 | ❌ |
| relation | ✅ 完整 | ✅ 完整 | ❌ |
| starmap | ⚠️ Builder 未实现 | ✅ 基础 | ❌ |
| island | ✅ 完整 | ✅ 完整 | ❌ |
| space | ⚠️ 硬编码 | ✅ 基础 | ❌ |
| whitenoise | ✅ 完整 | ✅ 完整 | ✅ |
| sync | ⚠️ 分页未完成 | ⚠️ 骨架 | ❌ |
| ai | 🔄 部分可用 | 🔄 部分可用 | ❌ |

### 12.3 已知问题

1. **timeline 模块与 fragment 模块存在大量代码重复**（SQL 查询、scanFragment、分组逻辑）
2. **JWT 为自定义实现**（手动 HMAC-SHA256，非标准 JWT 库），缺少 `kid`、`iss` 等标准字段
3. **Media Presign 为占位符**，未真正调用 MinIO/S3 API 生成预签名 URL
4. **ImageProcessor / AudioProcessor 接口声明但未实现**（缩略图生成、音频波形图）
5. **Starmap Builder 接口已定义**（BuildFullGraph/GetSubGraph），但仅使用简单螺旋布局
6. **Sync 引擎 Flutter 端为骨架**（syncNow 方法仅更新状态，未执行实际网络操作）
7. **Flutter 端两个平行的 Auth Repository**（一个有状态带自动刷新，一个纯契约式存根）
8. **夜间模式音频路径不匹配**（代码引用与 pubspec 注册的路径不同）
9. **IslandSpace CustomPainter 为空实现**
10. **.env 包含实时 DeepSeek API Key**（应轮换并从版本控制移除）

---

## 13. 技术决策记录

| # | 决策 | 理由 | 影响 |
|---|-----|------|------|
| 1 | **Modular Monolith 非微服务** | 2C2G 单机部署，团队规模小 | 降低了部署复杂度，未来拆分成本可控 |
| 2 | **Presigned URL 直传 MinIO** | Go 后端不中转大文件流 | 减少内存压力，提升上传性能 |
| 3 | **嵌入式 ID 迁移** | 避免外部迁移工具依赖 | 单二进制部署即建库，运维简单 |
| 4 | **pgx/v5 直接 SQL** | 无 ORM 开销 | SQL 可读性强，性能可预测，但代码量略增 |
| 5 | **drift 本地 DB + 远程 API** | 离线优先架构 | 网络不可用时核心功能不中断 |
| 6 | **自定义设计系统（非 Material）** | 产品气质需求（莫兰迪/毛玻璃/呼吸感） | 开发成本高，但视觉差异化强 |
| 7 | **CustomPainter 自绘（非图表库）** | 星空/海洋/岛屿为品牌核心视觉 | 灵活性强，无第三方依赖限制 |
| 8 | **Scratch 容器镜像** | 最小攻击面 + 最小体积 | 需外部交叉编译，CI 流程多一步 |
| 9 | **slog 标准库日志（非 zap）** | Go 1.21+ 内置，零依赖 | 功能够用，性能可接受 |
| 10 | **token 刷新用自定义回调（非拦截器链）** | 简化 401 重试逻辑 | 仅重试一次，不会死循环 |

---

## 14. 已知问题与后续规划

### 14.1 MVP 完成后待修复

| 优先级 | 问题 | 影响模块 |
|-------|------|---------|
| 🔴 高 | timeline 与 fragment 代码重复 | timeline, fragment |
| 🔴 高 | JWT 使用标准库替换自定义实现 | auth |
| 🔴 高 | .env API Key 从版本控制移除 | 安全 |
| 🟡 中 | Media Presign 接入真实 MinIO | media |
| 🟡 中 | 缩略图生成实现 | media/processor |
| 🟡 中 | Sync Engine Flutter 端完善 | sync |
| 🟡 中 | 两个 Auth Repository 合并 | auth |
| 🟢 低 | Starmap 力导向布局实现 | starmap |
| 🟢 低 | IslandSpace 实现 | ui/spaces |

### 14.2 P2 功能（后续版本）

- 力导向布局星图 (`starmap/graph/builder.go`)
- AI 柔光整理完整实现（三种模式：轻轻命名/帮我织线/不解释我）
- Redis 统计缓存启用（stats/cache）
- 后台定时同步任务调度
- 桌面小组件、快捷指令
- 拖拽星点建立连线
- 月度报告

### 14.3 性能预留

| 关注点 | MVP 无影响 | 触发条件 |
|-------|-----------|---------|
| oplog 表增长 | 单用户日 15-50 条 | >500 万行或同步延迟超阈值 → 归档 |
| 图片存储 | MinIO 单机够用 | 多用户 → MinIO 纠删码 |
| PG 查询 | 索引覆盖核心查询 | 慢查询日志监控（200ms 阈值已配置） |
| Redis 内存 | 256MB maxmemory, LRU 淘汰 | 后续加密码和持久化 |

---

## 附录

### A. 配置文件索引

| 文件 | 用途 |
|-----|------|
| `.env` | 运行时环境变量（含敏感信息） |
| `.env.example` | 环境变量模板 |
| `docker-compose.yml` | 5 容器编排 |
| `nginx.conf` | 反向代理（HTTP→HTTPS 重定向，SPA 回退，静态缓存） |
| `backend/Dockerfile` | Go 后端 scratch 镜像构建 |
| `backend/go.mod` | Go 模块依赖 |
| `app/pubspec.yaml` | Flutter 依赖配置 |
| `backend/migrations/001_init.sql` | 数据库 DDL（11 表 + 3 枚举） |

### B. 目录结构

```
隙光/
├── app/                    # Flutter 前端（165 个 .dart 文件）
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/            # 入口 + 路由 + 全局 Provider
│   │   ├── design/         # 设计令牌 + 主题
│   │   ├── ui/             # 通用 UI 组件（primitives/composites/spaces）
│   │   └── features/       # 10 个功能模块
│   ├── test/               # 测试文件
│   ├── tool/               # 后端契约验证工具
│   └── assets/             # 字体、图标、音频
├── backend/                # Go 后端（99 个 .go 文件）
│   ├── cmd/server/main.go  # 入口
│   ├── internal/           # 14 个业务模块 + shared + infra
│   └── migrations/         # SQL 迁移脚本
├── docs/                   # 文档
├── docker-compose.yml      # 容器编排
├── nginx.conf              # 反向代理配置
├── .env / .env.example     # 环境变量
├── CLAUDE.md               # AI 行为规范
└── README.md               # 项目说明
```

---

> **文档维护**：本报告基于 2026-06-06 代码库状态生成。架构变更时请同步更新。
