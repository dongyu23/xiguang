# 隙光

> **隙中捕光 → 光入成线 → 线间可织 → 织久成屿**
>
> 一款私人多媒体碎片记录与回看工具。不社交、不打卡、不诊断——只是温柔地保存你的感受。

---

## 这是什么

隙光（Xiguang）是一个帮助你记录生活碎片的私人空间。你可以在这里：

- 🖊️ **轻轻记一下**——一句话、一张图、一段情绪
- 🌊 **在时间河流里回看**——按日期浏览过去的光片
- 🧵 **把相似的感受织在一起**——发现碎片之间隐秘的联系
- 🏝️ **看主题长成小岛**——反复出现的情绪和场景沉淀为个人脉络
- ✨ **让 AI 帮你柔光整理**——克制地辅助，不替你下判断

## 产品语言

隙光有一套自己的命名体系——它不叫"笔记"，叫"光片"；不叫"分类"，叫"小岛"：

| 叫法 | 意思 |
|-----|------|
| 捕光 | 记录一条碎片 |
| 光片 | 单条记录 |
| 微光 | 情绪选择（8 种莫兰迪色） |
| 时间河流 | 按时间排列的光片流 |
| 织线 | 把两条光片建立关联 |
| 给光命名 | 打标签 |
| 小宇宙 | 个人空间总览 |
| 星点/小岛 | 同主题出现 3/5 次后自动生成 |
| 柔光整理 | AI 辅助回顾 |
| 星图管理员 | AI 助手（不叫"智能助手"） |

## 技术栈

| 层 | 选型 |
|---|-----|
| 移动端 | Flutter 3.x + Riverpod + Drift |
| 后端 | Go + Chi + pgx（模块化单体） |
| 数据库 | PostgreSQL 16 |
| 缓存 | Redis 7 |
| 对象存储 | MinIO（S3 兼容） |
| AI | DeepSeek |
| 部署 | Docker Compose 单机 5 容器 |

## 快速开始

### 前置条件

- Flutter SDK ≥3.3.0
- Go 1.24+
- Docker + Docker Compose
- （iOS）Xcode 16+
- （Android）Android SDK + JDK 17

### 1. 启动后端

```bash
# 一键启动全部 5 个容器（Nginx + Go + PostgreSQL + Redis + MinIO）
bash tools/docker-up.sh

# 验证
curl http://127.0.0.1:8088/healthz
# → {"ok":true,"service":"xiguang-backend"}
```

容器启动后数据库会自动建表（DDL 内嵌在 Go 二进制中，零配置）。

### 2. 启动 Flutter App

```bash
cd app
flutter pub get

# Android
flutter run -d android

# iOS
flutter run -d ios

# macOS 桌面预览
flutter run -d macos
```

App 默认连接 `http://127.0.0.1:8088/api/v1`。如需自定义：

```bash
flutter run --dart-define=API_BASE_URL=http://你的地址/api/v1
```

### 3. 跑测试

```bash
# 后端
cd backend && go test ./...

# 前端
cd app && flutter test

# 全链路契约验证
cd app && dart run tool/backend_contract.dart
```

## 项目结构

```
隙光/
├── app/                          # Flutter 前端
│   ├── lib/
│   │   ├── main.dart             # 入口
│   │   ├── app/                  # App 壳 + 路由 + 全局 Provider
│   │   ├── design/               # 设计令牌（色彩/间距/字体/动效）
│   │   ├── ui/                   # 通用 UI 组件
│   │   │   ├── primitives/       # BlurBox · BreathingWidget · GlowButton · RippleTap
│   │   │   ├── composites/       # EmotionPicker · LightCard · TagChip · ImageGrid
│   │   │   └── spaces/           # StarrySpace · OceanSpace（CustomPainter 自绘）
│   │   └── features/             # 10 个业务模块
│   │       ├── auth/             #   登录/注册/会话
│   │       ├── fragment/         #   捕光/光片详情/媒体上传
│   │       ├── timeline/         #   时间河流/日期分组/筛选
│   │       ├── island/           #   小宇宙/岛屿详情
│   │       ├── relation/         #   织线
│   │       ├── starmap/          #   星图
│   │       ├── stats/            #   情绪密度/高频词
│   │       ├── space/            #   沉浸式空间
│   │       ├── whitenoise/       #   白噪音
│   │       ├── sync/             #   离线同步引擎
│   │       ├── ai/               #   柔光整理
│   │       └── shared/data/      #   ApiClient（统一 HTTP 客户端）
│   ├── test/
│   ├── tool/                     # 后端契约验证脚本
│   └── assets/                   # 字体/图标/音频
│
├── backend/                      # Go 后端
│   ├── cmd/server/main.go        # 入口
│   ├── internal/
│   │   ├── shared/               # 通用错误/响应信封/分页
│   │   ├── infra/                # config · db · redis · storage · logger · router
│   │   ├── auth/                 # 认证 · JWT · 中间件
│   │   ├── fragment/             # 光片 CRUD · 织线入口 · 岛屿生长触发
│   │   ├── media/                # Presigned URL · 上传确认
│   │   ├── emotion/              # 8 种情绪静态列表
│   │   ├── tag/                  # 标签 CRUD
│   │   ├── timeline/             # 时间河流查询
│   │   ├── stats/                # 情绪密度 · 高频词
│   │   ├── relation/             # 织线 CRUD
│   │   ├── starmap/              # 星图数据 · 螺旋布局
│   │   ├── island/               # 岛屿 CRUD · 生长引擎
│   │   ├── space/                # 空间主题配置
│   │   ├── whitenoise/           # 白噪音列表
│   │   ├── sync/                 # Push/Pull 操作日志同步
│   │   └── ai/                   # DeepSeek 集成 · 岛屿构建 · 文案润色
│   └── migrations/               # 数据库 DDL
│
├── docker-compose.yml            # 5 容器编排
├── nginx.conf                    # 反向代理配置
├── .env.example                  # 环境变量模板
├── CLAUDE.md                     # AI 行为规范（项目宪法）
└── README.md                     # 本文件
```

## 架构预览

```
Flutter App ──HTTPS──▶ Nginx :443 ──/api/*──▶ Go Backend :8080
                           │                    │
                           │ /media/*           ├──▶ PostgreSQL :5432
                           ▼                    │
                         MinIO :9000            ├──▶ Redis :6379
                           │                    │
                           └── / ──▶ Flutter Web  └──▶ DeepSeek API
                                    静态文件
```

**后端分层**：每个模块独立 `domain/ → repository/ → service/ → handler/`，模块间通过 service interface 通信，禁止直接跨模块查数据库。

**前端分层**：每个 feature 独立 `domain/ → data/ → presentation/`，使用 Riverpod 做状态管理，Drift 做本地 SQLite 存储，Dio 做网络请求。

## API 概览

基础地址：`http://127.0.0.1:8088/api/v1`

### 公开接口（无需登录）

| 方法 | 路径 | 说明 |
|-----|------|------|
| GET | `/healthz` | 健康检查 |
| POST | `/auth/register` | 注册 |
| POST | `/auth/login` | 登录 |
| POST | `/auth/refresh` | 刷新 Token |
| GET | `/emotions` | 情绪列表 |

### 保护接口（需 Bearer Token）

| 模块 | 端点 | 说明 |
|-----|------|------|
| 用户 | `GET/PUT /users/me` | 查看/更新个人信息 |
| 光片 | `GET/POST /fragments` | 光片列表/创建 |
| 光片 | `GET/PUT/DELETE /fragments/{id}` | 光片详情/编辑/删除 |
| 光片 | `POST /fragments/{id}/weave` | 从光片发起织线 |
| 时间线 | `GET /timeline` | 时间河流（日期分组） |
| 标签 | `GET/POST/PUT/DELETE /tags` | 标签 CRUD |
| 统计 | `GET /stats/emotion-density` | 7 天情绪分布 |
| 统计 | `GET /stats/freq-words` | 高频标签词 |
| 织线 | `GET/POST/DELETE /relations` | 织线 CRUD |
| 星图 | `GET /starmap` | 个人星图数据 |
| 岛屿 | `GET/POST /islands` | 岛屿列表/创建 |
| 岛屿 | `GET/PUT/DELETE /islands/{id}` | 岛屿详情/编辑/删除 |
| 岛屿 | `POST/DELETE /islands/{id}/fragments` | 添加/移除光片 |
| 媒体 | `POST /media/presign-upload` | 签发上传凭证 |
| 媒体 | `POST /media/confirm-upload` | 确认上传完成 |
| 同步 | `POST /sync/push` | 推送本地变更 |
| 同步 | `GET /sync/pull` | 拉取远程变更 |
| AI | `POST /ai/glow-summary` | 柔光整理 |
| AI | `POST /ai/build-islands` | AI 岛屿发现 |
| AI | `POST /ai/polish` | AI 文案润色 |

> **共 45 个端点**（6 公开 + 39 保护）。完整规范见 [CLAUDE.md](CLAUDE.md) §6。

## 数据库

**11 张表**：`users` · `fragments` · `tags` · `fragment_tags` · `media_files` · `relations` · `islands` · `island_fragments` · `refresh_tokens` · `oplog` · `ai_requests`

**核心设计**：
- 双 ID 策略（BIGSERIAL 服务端 + UUID 公开 ID，支持离线创建）
- 软删除 + 部分索引（`WHERE deleted_at IS NULL`）
- 岛屿生长引擎：同标签 3 次 → 星点，5 次 → 小岛，30 天静默 → 休眠
- oplog 表支撑离线同步（幂等去重 + server_rev 版本号）

## 部署

### 环境变量

复制模板并填入真实值：

```bash
cp .env.example .env
```

关键配置项：

```bash
APP_ENV=production          # 生产环境必须改
JWT_SECRET=<64字符随机串>    # 生产环境必须改
DB_PASSWORD=<强密码>         # 生产环境必须改
AI_DEEPSEEK_API_KEY=sk-...  # 使用 AI 功能才需要
```

### 容器资源分配

| 容器 | 内存 | 持久化 |
|-----|------|--------|
| Nginx | 64 MB | — |
| Go App | 256 MB | — |
| PostgreSQL | 512 MB | ✅ pg_data |
| Redis | 128 MB | 缓存可丢 |
| MinIO | 256 MB | ✅ minio_data |
| **总计** | **~1.2 GB** | |

单机 2C2G 可运行。完整部署说明见 [docs/technical-report.md](docs/technical-report.md)。

## 版本规划

| 版本 | 阶段 | 目标 |
|-----|------|------|
| v0.1 | 概念原型 | 快速记录 + 时间线 + 小宇宙概念页 |
| **v0.2** | **MVP 可用版（当前）** | 账号 · 文字/图片记录 · 情绪 · 时间线 · 织线 · 岛屿 · AI |
| v0.3 | 内测优化 | 完善小宇宙视图 · 标签聚合 · 主题卡片 · 视觉动效 |
| v1.0 | 公开版 | 比赛/路演/作品集展示 |

## 更多文档

| 文档 | 内容 |
|-----|------|
| [CLAUDE.md](CLAUDE.md) | 项目宪法——产品定义 · 架构规范 · 接口标准 · AI 行为约束 |
| [docs/technical-report.md](docs/technical-report.md) | 技术架构报告——模块分析 · 数据库设计 · 实施状态 · 度量数据 |

## 产品信念

> **我可以在这里不用解释自己。**
>
> 隙光不追求效率、不要求打卡、不评判你记录了什么。它只是一个可以被轻轻打开的私人空间——有趣、柔软、内向，像晨昏的一束光。
