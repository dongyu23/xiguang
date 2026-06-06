# 隙光

隙光是一款私人多媒体意识流记录工具，面向希望低压力保存生活碎片、情绪片段和灵感瞬间的用户。它不是效率工具，也不是社交平台，而是一个帮助用户温柔保存自己的私人空间。

## 产品定位

隙光聚焦“轻记录、多模态、私人时间线、碎片关联、AI 温柔辅助”。用户可以快速捕捉一句话、一张图片、一段情绪或一个灵感，并在之后通过时间线、标签、关联关系和 AI 柔光整理，重新看见这些碎片之间的联系。

核心体验路径：

```text
快速捕捉 -> 自由放置 -> 柔和回看 -> 主动连接 -> AI 辅助发现 -> 形成内在小宇宙
```

## MVP 目标

MVP 阶段用于验证：年轻人是否愿意在一个柔软、私密、非社交的空间中，持续记录并回看自己的碎片。

当前阶段重点：

- 降低记录门槛，让用户可以快速记录碎片。
- 支持文字、图片、情绪标签和手动标签。
- 通过时间线自然回看记录。
- 通过手动关联与 AI 建议，建立碎片之间的连接。
- 用柔和视觉风格区别于传统效率工具。

## 核心功能

### 快速记录

用户可以在最短路径内创建一条碎片记录，支持文字、图片、基础情绪选择、自动时间戳和手动标签。

### 个人时间线

用户可以按时间查看所有记录，支持今日记录、日期分组、记录卡片展示和标签筛选。

### 记录详情

用户可以查看单条记录的完整内容，包括文字、图片、创建时间、情绪标签、手动标签，并支持编辑和删除。

### 手动关联

用户可以将两条记录建立关系，让碎片之间形成个人脉络。MVP 支持“想起了它”“情绪延续”“灵感来源”“同一阶段”和自定义关系。

### AI 柔光建议

用户主动选择若干条记录后，AI 可以生成关键词、情绪命名、阶段性回顾，并提示可能相关的记录。AI 只做辅助整理，不诊断、不评判、不替用户解释人生。

### 小宇宙概念视图

MVP 以轻量方式展示小宇宙概念，包括星点卡片、标签聚合主题区、近期高频主题和主题记录列表。

## 产品机制

### 捕光

用户创建的每一条记录都被视为一束“光”，保存后成为一张“光片”，进入私人时间线。

### 光片状态

光片可以拥有轻量状态，例如微光、星尘、回声、种子、潮汐和岛屿核心，用于表达它在用户私人宇宙中的位置。

### 织线

用户可以将两条光片建立关系。织线不是传统双链，而是一种更偏情绪和叙事的连接方式。

### 宇宙生长

当用户多次记录相似主题时，系统可以生成主题星点；当主题持续出现时，星点逐渐成长为小岛；当用户主动建立关联时，记录之间出现连接。

## 信息架构

MVP 建议采用 4 个主导航：

- 记录
- 时间线
- 小宇宙
- 我的

## 数据结构草案

### User

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| user_id | string | 用户唯一 ID |
| nickname | string | 用户昵称 |
| avatar | string | 用户头像 |
| created_at | datetime | 注册时间 |
| ai_enabled | boolean | 是否开启 AI 辅助 |
| privacy_mode | string | 隐私模式 |

### Fragment

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| fragment_id | string | 记录唯一 ID |
| user_id | string | 所属用户 |
| content_text | text | 文字内容 |
| media_urls | array | 图片等媒体地址 |
| emotion | string | 情绪标签 |
| tags | array | 用户标签 |
| ai_keywords | array | AI 关键词 |
| created_at | datetime | 创建时间 |
| updated_at | datetime | 更新时间 |
| is_deleted | boolean | 是否删除 |

### Relation

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| relation_id | string | 关联唯一 ID |
| user_id | string | 所属用户 |
| source_fragment_id | string | 源记录 |
| target_fragment_id | string | 目标记录 |
| relation_type | string | 关系类型 |
| created_at | datetime | 创建时间 |

### AISummary

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| summary_id | string | 总结唯一 ID |
| user_id | string | 所属用户 |
| fragment_ids | array | 被总结的记录 |
| keywords | array | 关键词 |
| emotion_title | string | 情绪命名 |
| summary_text | text | 柔光总结 |
| created_at | datetime | 创建时间 |
| saved | boolean | 用户是否保存 |

## 非功能要求

- App 冷启动尽量控制在 3 秒以内。
- 时间线首屏加载不超过 2 秒。
- 用户内容默认仅自己可见。
- AI 功能必须由用户主动触发。
- 产品不提供公开发布、点赞、评论、排名等社交压力机制。
- 视觉风格保持低饱和、大留白、柔和动效和私人空间气质。

## 版本规划

| 版本 | 阶段 | 目标 |
| --- | --- | --- |
| v0.1 | 概念原型 | 展示快速记录、时间线、详情、小宇宙概念页和 AI 柔光总结 Demo |
| v0.2 | MVP 可用版 | 支持账号、文字/图片记录、情绪标签、时间线、编辑删除、手动关联和基础 AI 总结 |
| v0.3 | 内测优化版 | 完善小宇宙视图、标签聚合、主题卡片、AI 关联建议和视觉动效 |
| v1.0 | 公开展示版 | 形成可用于比赛、路演或作品集展示的完整作品 |

## 当前优先级

1. 先做轻记录。
2. 再做时间线。
3. 再做手动关联。
4. 最后加入克制的 AI 柔光总结。
5. 小宇宙视图先做概念表达，不急于复杂实现。

## 当前工程结构

当前仓库已经包含 Flutter App 与 Go 后端 MVP：

- `app/`：Flutter + Riverpod + go_router 前端，底部导航为「隙 / 线 / 屿 / 我的」。
- `backend/`：Go + net/http + Chi 模块化单体后端，提供 `/api/v1` REST API。
- `docker-compose.yml`：Nginx、Go app、PostgreSQL、Redis、MinIO 单机编排。
- `.env.example`：部署环境变量模板；开发时不创建 `.env` 也可使用 Compose 默认值。

Flutter 默认 API 地址为：

```bash
http://127.0.0.1:8088/api/v1
```

如需覆盖：

```bash
flutter run --dart-define=API_BASE_URL=http://你的地址/api/v1
```

## Flutter App

主要代码在 `app/lib/`，核心数据流已接入 API，并保留本地降级，便于无后端时预览。

平台目标：

- Android：已生成 `android/` 工程目录。
- iOS：已生成 `ios/` 工程目录。
- macOS：已生成 `macos/` 工程目录，用于 macOS 桌面预览。
- Windows：已生成 `windows/` 工程目录，用于 Windows 桌面预览。
- Web：未生成 Web 目录。

运行方式：

```bash
flutter pub get
flutter run -d android
flutter run -d ios
flutter run -d macos
```

### macOS 启动交互式预览

macOS 预览需要完整 Xcode，只有 Command Line Tools 不够。

1. 安装 Xcode。
2. 切换开发者目录并完成首次启动：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

3. 进入项目目录并启动：

```bash
cd "/Users/jinzihan/Documents/New project/隙光"
flutter doctor
flutter run -d macos
```

如果本机没有把 Flutter 加入 `PATH`，可以使用本项目当前机器上的 SDK 路径：

```bash
/Users/jinzihan/.cache/codex-flutter-sdk/bin/flutter run -d macos
```

### Windows 启动交互式预览

Windows 预览需要 Flutter SDK、Visual Studio 和桌面 C++ 构建工具。

1. 安装 Flutter SDK，并把 `flutter/bin` 加入系统 `PATH`。
2. 安装 Visual Studio 2022，勾选 `Desktop development with C++` 工作负载。
3. 打开 PowerShell，进入项目目录：

```powershell
cd "你的项目路径\xiguang"
flutter doctor
flutter devices
flutter run -d windows
```

## Go 后端

本地编译与测试：

```bash
cd backend
go test ./...
go build ./cmd/server
```

核心接口：

- `GET /healthz`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET/PUT /api/v1/users/me`
- `GET/POST/PUT/DELETE /api/v1/fragments`
- `POST /api/v1/fragments/{id}/weave`
- `GET/POST/PUT/DELETE /api/v1/tags`
- `POST/GET/DELETE /api/v1/media`
- `GET /api/v1/timeline`
- `GET/POST/PUT/DELETE /api/v1/islands`
- `POST/GET/DELETE /api/v1/relations`
- `GET /api/v1/starmap`
- `POST /api/v1/sync/push`
- `GET /api/v1/sync/pull`
- `POST /api/v1/ai/glow-summary`（MVP 预留，不后台解释用户）

## Docker Compose

推荐启动方式：

```bash
bash ./tools/docker-up.sh
```

脚本会先调用 `tools/prepare-docker-backend.sh`，根据 Docker 的运行架构生成 `backend/bin/xiguang-linux-arm64` 或
`backend/bin/xiguang-linux-amd64`，再执行 `docker compose up -d --build`。
这样后端 app 镜像使用 `scratch` 运行，不需要拉取 `golang` 或 `alpine` 基础镜像。

访问：

```bash
curl http://127.0.0.1:8088/healthz
```

`docker-compose.yml` 已显式设置 `name: xiguang`，当前目录包含中文或空格时也能正常解析项目名。

完整 5 容器 Compose smoke（Nginx + app + PostgreSQL + Redis + MinIO）可单独运行：

```bash
bash ./tools/verify-compose-stack.sh
```

该脚本使用临时 Compose project 和端口 `18088`，退出后会清理容器与卷。首次运行需要能拉取
`nginx:alpine`、`postgres:16-alpine`、`redis:7-alpine`、`quay.io/minio/minio:latest`。
脚本会先检查并拉取这些镜像；如果 Docker 引擎拉取 registry 超时，会明确指出卡住的镜像。
默认 `tools/verify-all.sh` 使用不依赖这些外部镜像拉取的 scratch app 容器验证，保证日常门禁稳定。

环境自检：

```bash
make doctor
```

该命令会检查 Docker、Compose 必需镜像、Android SDK、完整 Xcode 和 CocoaPods。只有这些本机依赖齐全时，才能证明
Android/iOS 原生构建与完整 5 容器 Compose smoke。

如果 `flutter devices` 没看到 Windows，请先启用桌面支持：

```powershell
flutter config --enable-windows-desktop
flutter doctor
flutter run -d windows
```

参考文档：

- Flutter Windows 桌面开发：https://docs.flutter.dev/platform-integration/windows/setup
- Flutter macOS 桌面开发：https://docs.flutter.dev/platform-integration/macos/setup

测试与预览：

```bash
flutter test
flutter test --update-goldens test/golden_test.dart
```

Android 原生构建验证：

```bash
make android-build
```

当前验证使用 Homebrew 安装的 Android command line tools 与 JDK 17：

```bash
flutter config --android-sdk /opt/homebrew/share/android-commandlinetools
flutter config --jdk-dir /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
```

iOS 原生构建验证：

```bash
make ios-build
```

该命令需要完整 Xcode，不是 Command Line Tools。若本机只有 `/Library/Developer/CommandLineTools`，会明确提示安装并切换：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

当前电脑可读预览：

```bash
/Users/jinzihan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/generate_preview.py
```

生成结果位于 `preview/`：

- `preview/01_capture_readable.png`
- `preview/02_timeline_readable.png`
- `preview/03_universe_readable.png`

说明：Flutter 的 headless golden 测试环境会使用测试字体，中文 golden 图可能显示为方块；真实 Android/iOS/macOS 运行时会使用系统中文字体渲染。当前电脑因为缺少完整 Xcode 与 Android SDK，无法直接打开交互式 Flutter 运行窗口，因此提供 `preview/` 下的可读 PNG 作为本机预览。

## 产品信念

隙光真正的竞争力，是让用户感到：

> 我可以在这里不用解释自己。
