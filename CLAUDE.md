# 隙光 — CLAUDE.md

> **本质**：这是你和 AI 的合作协议。项目是什么、做什么、不做什么、怎么组织、
> 接口怎么设计、数据库怎么建、遇到不确定情况怎么处理——写清楚了，AI 后续生成
> 代码时就有了明确约束。

---

## 一、项目概述

### 一句话定义

> 「隙光」是一款私人多媒体碎片记录与回看工具，面向有碎片记录习惯、注重内心体验
> 的年轻人，核心能力是轻量捕捉文字、图片与情绪光片，并通过时间河流、旧光回访、
> AI 柔光整理和小宇宙聚合，解决日常感受分散记录、难以回看和难以形成个人脉络的问题。

### 产品信念

隙光真正的竞争力，是让用户感到：

> **我可以在这里不用解释自己。**

### 产品气质

**有趣、美丽、柔软、意识流、内向。** 像一个可以被轻轻打开的私人空间，而不是一个
要求用户完成任务的效率工具。

- 色彩：低饱和莫兰迪色系，微光渐变，模拟晨昏、月光、雾气和天色变化。不追求强
  烈冲击，追求舒缓、包裹和安全感
- 质感：圆角、毛玻璃、轻微投影、大量留白。元素像漂浮在轻雾里，避免过度锐利和
  冰冷。真正的主角是用户的思绪，不是功能按钮
- 动效："呼吸感"——水波、涟漪、光束轻移、星点浮动。不急促、不打扰
- 声音：加白噪音背景（雨声、翻书声、风声、心跳声等），增强私密、安全、沉浸的
  记录体验
- 界面：大量留白，避免拥挤。产品视觉服务于用户的表达，而不是抢走用户的注意力

### 交互设计原则

「隙光」采用 **"成熟交互骨架 + 原创产品语言"** 的方式。交互降低用户学习成本，原
创产品语言建立差异化。

**四项原则：**

1. **基础操作不反常识**：输入、保存、浏览、编辑、删除沿用用户熟悉的移动端交
   互。按钮可以叫"捕光"，但旁边必须有明确反馈；删除可用温柔文案，但必须提醒
   不可恢复；AI 输出可有诗意，但不能让用户不知道下一步怎么操作
2. **核心体验重新命名**：不叫"笔记""关联""分类""总结"，转译为"光片""织线""小
   宇宙""柔光整理"
3. **情绪体验优先于效率体验**：页面不追求信息密度，追求低压力、柔和、可回看
4. **借鉴交互逻辑，不照搬产品目标**：flomo、Day One、Obsidian 等产品的交互模式
   可借鉴，但隙光的目标不是知识管理、传统日记或研究白板，而是私人感受的保存
   与生长

### 8 竞品交互转化总表

| 竞品 | 核心交互 | 隙光转化 | 借鉴什么 | 避免什么 |
|------|---------|---------|---------|---------|
| **flomo** | 快速输入、memo 卡片、轻量标签 | 捕光入口、光片卡片、给光命名、旧光回访 | 快速输入和卡片流，输入框如聊天窗口般低压力 | 不做成知识卡片库。flomo 偏思考沉淀，隙光保存未必有用的感受 |
| **Day One** | 时间线、多媒体日记、生活档案 | 时间河流、多媒体光片、当天的光 | 时间线和多媒体记录方式，自动时间戳+媒体 | 不要求用户"写完整的一天"。隙光允许只留一句话、一张图、一段说不清的情绪 |
| **How We Feel** | 情绪 check-in、颜色矩阵、情绪词 | 微光情绪选择器、说不清、潮汐提示 | 低压力情绪选择，通过颜色和词汇帮用户靠近感受 | 不做成情绪打卡/追踪工具。情绪选择是辅助表达，不是要求每天打卡 |
| **Obsidian** | 双链、节点、图谱视图 | 织线、回声、伏笔、内在星图 | 节点—边—图谱结构，可视化关系网络 | 不做复杂双链语法，不要求学习知识库逻辑。图谱为了看见情绪联系，不是构建知识系统 |
| **Heptabase** | 白板、卡片、空间组织 | 小宇宙、主题星点、小岛 | 卡片+空间的可视化方式 | 不做复杂白板。第一版避免拖拽、缩放、自由布局，先做系统轻量聚合 |
| **mymind** | 私密收纳、AI 自动整理、搜索 | AI 柔光建议、旧光回访、星图管理员 | 私密+AI 自动辅助+少分类逻辑 | 不要让 AI 替用户整理一切。隙光核心不是"自动归档"，是"用户保有解释权" |
| **Cosmos** | 视觉灵感流、收藏、颜色搜索 | 光片墙、氛围回看、主题小岛 | 视觉吸引力和灵感墙，图片瀑布流浏览 | 不做审美社区。隙光中的视觉不是为了展示品味，是为了回看"我被什么击中过" |
| **Reflectly** | AI 日记、情绪陪伴、引导问题 | 柔光整理、轻轻命名、不解释我 | AI 陪伴感，引导式交互 | 不要把 AI 做成心理咨询师。隙光不是心理治疗工具，不替用户下判断 |

### 竞品转化方法

对每个竞品，分析三步：
1. **竞品中怎么呈现**：具体的交互模式和用户流程
2. **底层设计逻辑**：它解决什么问题，核心假设是什么
3. **隙光怎么转译**：保留交互骨架，替换为隙光的产品语言和约束

flomo 案例：flomo 的逻辑是"快速捕捉想法 → 轻量标签沉淀 → 定期回顾 → 形成知识
资产"（解决"想法容易流失"）。隙光转译为"快速记录 → 捕光 → 光片进入时间河流 →
未来形成回声"（解决"感受值得被安放"）。入口文案不写"记录想法"，写"把这一刻轻
轻放在这里"。保存按钮不叫"保存"，叫"捕光"。

Day One 案例：Day One 逻辑是"记录生活事件 → 自动补充时间/地点/媒体 → 形成长期
生活档案"（解决"记忆归档"）。隙光转译为"时间线 → 时间河流；日记条目 → 光片；
生活档案 → 内在叙事"。不要求用户写完整日记，只展示当天散落的光片；同一天的文
字、图片、情绪并列出现，不必合并成一篇文章。

Obsidian 案例：Obsidian 逻辑是"笔记不是孤立的，通过链接形成知识网络"（解决"知
识点之间关系难以显性化"）。隙光转译为"笔记节点 → 光片；双链 → 织线；知识图谱
→ 内在星图"。关系类型不使用"引用/相关"，使用"回声/伏笔/余震/平行宇宙/小小救
命/潮汐/旧光"。

How We Feel 案例：逻辑是"先降低情绪表达门槛 → 再帮用户命名情绪 → 最后观察情绪
模式"（解决"用户不知道如何准确描述情绪"）。隙光转译为"情绪 check-in → 微光色
调选择；情绪词 → 光片氛围；趋势观察 → 潮汐提示"。情绪词贴近日常表达（平静/开
心/疲惫/焦虑/失落/被击中/混乱/说不清），不使用过度医学化或心理学化词汇。

Heptabase 案例：逻辑是"把抽象思考外化为可视化空间"（解决"理解复杂内容"）。隙
光转译为"白板 → 小宇宙；卡片 → 光片；主题区 → 小岛"。第一版不做自由拖拽大量
卡片——"可以建议美工做一套形成 IP 的小图画以及概念图仅作为示意，如果都是这个颜色
和光效会有些视觉疲劳。期待简约元素，点线面的结合。"

mymind 案例：逻辑是"用户负责收集，AI 负责隐藏式整理，搜索负责重新找回"（解决
"资料太多、分类太麻烦"）。隙光转译为"保存资料 → 安放光片；自动分类 → 柔光建
议；搜索资料 → 旧光回访"。AI 只做候选，用户一键采纳或忽略。星图管理员不叫"智能
整理助手"。

Cosmos 案例：逻辑是"视觉内容先吸引用户，再通过收藏/搜索/聚合形成灵感库"（解决
"创作者保存灵感"）。隙光转译为"灵感收藏 → 光片墙；视觉搜索 → 氛围回看；
collection → 主题小岛"。不设置点赞、评论、关注和公开主页。

Reflectly 案例：逻辑是"通过持续日记和 AI 引导建立情绪觉察习惯"（解决"用户不知
道写什么"）。隙光转译为"AI 陪伴 → 星图管理员；情绪引导 → 柔光提问；每日总结
→ 阶段性星图注释"。AI 不主动评价用户状态，不用"你应该……"这类指导式语言。三种
模式：轻轻命名 / 帮我织线 / 不解释我。AI 输出保留模糊性："这几束光里，似乎都有
一种'很累，但被小小事物接住'的感觉。要不要把它命名为：被轻轻安慰的一天？"

### 创新边界——你不能逾越的线

- **不要为了创新而破坏易用性**。基础操作必须清晰，不要过度诗化。删除可用温柔
  文案，但必须提醒不可恢复。AI 输出可有诗意，但不能让用户不知道下一步怎么操作
- **产品语言要统一**。若采用"光"的隐喻，所有核心功能都要围绕它展开
- **第一版避免复杂可视化**。小宇宙页不做 3D、不做自由拖拽、不做复杂图谱。推荐
  先做：主题星点、光片卡片、关系线、小岛入口、AI 星图注释。建议美工做形成 IP
  的小图画和概念图作为示意（简约元素，点线面结合）
- **AI 需克制**：AI 不应主动解释用户，更不应做心理判断，不应强行分析。推荐语
  气："这几束光似乎有一点相似""要不要把它们织在一起？""如果你愿意，可以给这段
  时间取一个名字""也可以什么都不解释，只把它放在这里"

### 产品隐喻体系（全系统统一命名）

| 原始概念 | 隙光命名 |
|---------|---------|
| 记录 | 捕光 |
| 单条记录 | 光片 |
| 时间线 | 时间河流 |
| 关联 | 织线 |
| 相关记录 | 旧光 / 回声 |
| 标签 | 给光命名 |
| AI 总结 | 柔光整理 |
| AI 助手 | 星图管理员 |
| 主题聚合 | 主题星点 / 小岛 |
| 个人空间 | 小宇宙 |

### MVP 功能决策

**基础能力**

| 功能 | MVP | 程度 |
|-----|-----|------|
| 用户注册/登录 | ✅ | 用户名+密码 |
| 个人信息管理 | ✅ | 昵称+头像，不做隐私设置/AI 开关 |

**隙 — 极速捕捉**

| 功能 | MVP | 程度 |
|-----|-----|------|
| 快速记录入口 | ✅ | 仅 App 内入口（不做桌面小组件、快捷指令） |
| 多模态输入 | ✅ | 文字 + 拍照（含相册导入）+ 录音。**不做涂鸦、不做短视频** |
| 自动时间戳 | ✅ | 自动带上 |
| 微光情绪选择器 | ✅ | 柔和色点+情绪词（平静/开心/疲惫/焦虑/失落/被击中/混乱/说不清），可跳过，默认"说不清"。**不做 AI 辅助** |
| 手动标签 | ✅ | 用户打字输入，暂不联想 |
| AI 柔光建议卡 | ❌ | 后期 |
| 光片详情 | ✅ | 查看/编辑/软删除 |

**光 — 个人时间线**

| 功能 | MVP | 程度 |
|-----|-----|------|
| 时间河流视图 | ✅ | 日期分组（今天/昨天/某天）+ 光片卡片 + 情绪色点 + 图片缩略图 + 光片状态 |
| 情绪/关键词/媒介筛选 | ✅ | 全做 |
| 阶段性情绪密度+高频词 | ✅ | 全做 |
| AI 推荐"那一刻的光" | ❌ | 后期，预留 AI 接入渠道 |

**织 — 碎片连结**

| 功能 | MVP | 程度 |
|-----|-----|------|
| 手动织线 | ✅ | 拖拽星点建立连线（必须开发，可拉长周期） |
| 关系类型 | ✅ | 全部：起因/灵感来源/情绪延续/同一阶段/想起了它/自定义（可写关系说明） |
| 柔光整理 | ❌ | 后期，预留按钮入口 |
| AI 隐性关联发现 | ❌ | 后期 |
| 可视化个人星图 | ✅ | 完整实现，星点+连线+可拖拽 |

**屿 — 我的小宇宙**

| 功能 | MVP | 程度 |
|-----|-----|------|
| 主题岛 | ✅ | 同一主题光片凝聚成岛（失眠岛/通勤岛/电影岛等） |
| 岛屿详情 | ✅ | 进入岛查看关联碎片、情绪、图片、录音、时间线 |
| 沉浸式空间 | ✅ | 星空/海/房间/岛屿等视觉容器，可切换 |
| 白噪音背景 | ✅ | 雨声/翻书声/风声/心跳声，可切换播放 |

**系统能力**

| 功能 | MVP | 程度 |
|-----|-----|------|
| 本地与云端同步 | ✅ | 后台自动同步，用户可手动设置时限 |
| 离线记录支持 | ✅ | 必须做。离线正常记录，联网后自动同步 |

### 明确不做什么

- ❌ 不做社交功能：不提供公开发布、点赞、评论、排名、关注
- ❌ 不做效率工具：不以任务管理或产出为导向
- ❌ 不做心理诊断：AI 不诊断、不评判、不替用户解释人生
- ❌ MVP 不做 AI 柔光建议卡、AI 推荐"那一刻的光"、柔光整理、AI 隐性关联发现
- ❌ 不做涂鸦、短视频输入（MVP 仅文字+拍照+录音）
- ❌ 不做桌面小组件、快捷指令（MVP 仅 App 内入口）
- ❌ 不做隐私设置、AI 开关（MVP 阶段无此需求）

### AI 与被辅助的关系定调

- AI 功能必须由用户主动触发，不能后台自动拉取或推送
- AI 只提供候选建议（采纳/改一改/忽略），不替用户做最终判断
- AI 交互语气克制：如"这几束光似乎有一点相似""要不要把它们织在一起？"
- AI 输出保留模糊性，不强行解释用户
- AI 不叫"智能整理助手"，叫"星图管理员"
- AI 不强绑定产品——以应用本身为主，AI 为辅助。所有 AI 接入点预留，但产品离开 AI 也能正常使用

### 核心约束

| 维度 | 约束 |
|-----|------|
| 团队 | 多人团队 |
| 平台 | Flutter 跨平台（iOS + Android） |
| 部署 | 自有服务器 2C2G，Docker Compose 单机多容器 |
| 阶段 | MVP 内部可用性验证，一期内部能跑通就行 |
| 加密 | 服务端加密 |

### 版本节奏

| 版本 | 阶段 | 目标 |
|-----|------|-----|
| v0.1 | 概念原型 | 展示快速记录、时间线、详情、小宇宙概念页和 AI 柔光总结 Demo |
| v0.2 | MVP 可用版 | 账号、文字/图片/录音记录、情绪标签、时间线、编辑删除、手动关联、基础 AI 总结 |
| v0.3 | 内测优化版 | 完善小宇宙视图、标签聚合、主题卡片、AI 关联建议、视觉动效 |
| v1.0 | 公开展示版 | 形成可用于比赛、路演或作品集展示的完整作品 |

### 功能优先级顺序

1. 先做轻记录
2. 再做时间线
3. 再做手动关联
4. 最后加入克制的 AI 柔光总结
5. 小宇宙视图先做概念表达

---

## 二、技术栈

| 层 | 选型 | 备注 |
|---|-----|------|
| 平台 | Flutter + Riverpod | iOS + Android 跨平台 |
| 后端 | Go + net/http + Chi | Chi 做路由 |
| AI 服务 | DeepSeek | 环境变量可切换 |
| 关系型数据库 | PostgreSQL 16 | 主存储 |
| 缓存 | Redis 7 | 统计缓存 + 会话 + 限流 |
| 对象存储 | MinIO / S3 兼容 | 图片/录音文件存储 |
| 接口风格 | RESTful API | `/api/v1` 前缀 |
| 部署 | Docker Compose | 单机 5 容器 |
| 日志 | slog/zap + Sentry | Go 端；Flutter 端用 sentry_flutter |
| 探活 | UptimeRobot | `/healthz` |
| 数据库监控 | PostgreSQL 慢查询日志 | — |

### Flutter 端核心依赖

| 用途 | 包 |
|-----|---|
| 状态管理 | Riverpod |
| 本地数据库 | drift + sqlite3_flutter_libs |
| 数据模型 | freezed + json_serializable |
| 路由 | go_router（StatefulShellRoute.indexedStack 主结构） |
| 网络 | dio |
| 图片选择+压缩 | image_picker + flutter_image_compress |
| 录音 | record |
| 音频播放 | just_audio + audio_session |
| 安全存储 | flutter_secure_storage（JWT token） |
| 权限 | permission_handler |
| 崩溃上报 | sentry_flutter |
| 织线拖拽 | GestureDetector + CustomPainter + InteractiveViewer（不走第三方拖拽库） |

### 项目目录与工程入口

```
隙光/
├── CLAUDE.md                   # 本文件 — AI 行为规范（项目根目录，全局生效）
├── README.md                   # 项目说明
├── backend/                    # Go 后端 (Modular Monolith)
│   ├── cmd/server/main.go      # 入口
│   ├── internal/               # 内部包（16 业务模块 + shared + infra）
│   ├── migrations/             # golang-migrate SQL 文件
│   ├── Dockerfile
│   └── go.mod
├── app/                        # Flutter App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/                # MaterialApp + ThemeData + go_router + providers
│   │   ├── design/             # 设计令牌
│   │   ├── ui/                 # 通用 UI 组件（primitives / composites / spaces）
│   │   └── features/           # 10 个业务 feature 模块
│   ├── pubspec.yaml
│   └── ios/ / android/
├── docker-compose.yml          # 5 容器编排
├── nginx.conf                  # 反向代理配置
└── .env.example                # 环境变量模板
```

### Flutter UI 设计系统 — 四核心决策

隙光的视觉要求——莫兰迪色系、毛玻璃、呼吸感动效、沉浸式空间——标准
Material/Cupertino 组件完全不够用。需要一套自有设计系统。

**决策一：完全绕过 Material 默认样式。**

`ThemeData` 的 `colorScheme` 用莫兰迪色系全覆盖。`cardTheme`、
`inputDecorationTheme`、`textTheme` 全部自定义——不要任何 Material 自带的蓝色、
ElevationButton 的默认阴影。`useMaterial3: true` 但所有语义色都用自己的 Token。

**决策二：毛玻璃和微光效果用 `BackdropFilter` + `ShaderMask`，不用第三方包。**

`ImageFilter.blur()` 做背景虚化。`ShaderMask` 加径向渐变做光晕。这是产品气质的核
心技术点，自绘保证性能和可控性。

**决策三：动效分层，不同场景不同策略。**

| 层级 | 场景 | 技术 | 时长 |
|-----|------|------|------|
| 微交互 | 按钮点击、页面切换、hover | `AnimatedContainer` / `AnimatedOpacity` | 200-400ms |
| 呼吸感 | 星点浮动、光束轻移、涟漪 | `AnimationController.repeat()` 驱动 `CustomPainter`，正弦缓动 | 2-4s 周期 |
| 水波涟漪 | 触摸反馈 | 自定义 `RipplePainter`，从触摸点向外扩散 | ~600ms |

动效不应急促打扰，而应像轻轻回应用户的动作。

**决策四：沉浸式空间用 `CustomPainter` 自绘，不用任何图表库。**

- 星空：粒子系统（随机位置 + 亮度 + 大小 + 正弦微动），每个粒子独立运动相位
- 海洋：叠加多层正弦波，不同振幅/频率/相位，产生自然波浪感
- 岛屿：贝塞尔曲线画轮廓，柔和颜色填充
- 连线：二次贝塞尔画弧，`source → control_point(中点偏移) → target`

**⚠️ 交互冲突警告：InteractiveViewer + GestureDetector 手势优先级**

`InteractiveViewer` 自带缩放/平移手势。星点上的 `GestureDetector` 又有拖拽手
势（织线用 `onPanStart/Update/End`）。两者在同一个星图画布上共存时，双指手势由
`InteractiveViewer` 处理（缩放平移），单指手势由星点的 `GestureDetector` 处理
（拖动星点建立连线）。`InteractiveViewer` 的缩放通过双指区分，不拦截单指事件。

### 技术选型核心原则

- 选最熟的，不选最新的
- 稳定性 > 新特性。部署简单 > 架构优雅
- 不做过度工程化——CI/CD、监控、告警链路可以先不管，先保证能跑起来

---

## 三、架构设计

### 3.1 应用架构模式

**后端：Modular Monolith（多包模块化单体）**

- Go 单二进制编译、部署、运行。不做伪微服务
- 按业务域拆独立 package，每个包有独立的 domain/repository/service/handler
- 模块间通过 service interface 通信，禁止直接引用其他模块的 repository/DAO/数据库表
- 编译打包时是一个整体，部署时是一个东西，运行时是一个进程

**前端：Flutter 按业务域拆模块**

- `lib/features/{domain}/` 每个业务域独立文件夹
- 模块内分层：domain/（实体+抽象接口）→ data/（drift DAO + dio API + repository 实现）→ presentation/（Riverpod provider + Widget + Page）

### 3.2 模块完整结构

**Go 后端 — 18 个包**

```
internal/
├── shared/                  # 零依赖公共层
│   ├── errors.go            # AppError + ErrorCode
│   ├── id.go                # 各实体 ID 类型定义 (UserID/FragmentID/RelationID 等)
│   └── pagination.go        # CursorQuery / PageQuery / CursorPage / Page 通用结构
│
├── infra/                   # 基础设施层（只依赖 shared）
│   ├── config/config.go     # 环境变量 → Config struct (DB/Redis/MinIO/DeepSeek)
│   ├── db/                  # PostgreSQL 连接池 (pgxpool) + golang-migrate 迁移入口
│   ├── redis/redis.go       # go-redis 客户端初始化
│   ├── storage/             # StorageProvider interface (Put/Get/Delete/PresignedURL)
│   │   ├── provider.go
│   │   ├── minio.go         # MinIO adapter
│   │   └── s3.go            # S3 adapter
│   ├── logger/logger.go     # slog/zap 封装 + 中间件日志注入
│   └── router/              # Chi router 组装 + 全局中间件链 (requestID/logging/recover/cors)
│
├── auth/                    # 认证模块
│   ├── domain/              # User 实体、TokenPair
│   ├── repository/          # UserRepository interface + PG impl
│   ├── service/             # AuthService interface + Register/Login/RefreshToken impl
│   ├── handler/             # POST /auth/register, /auth/login, /auth/refresh, GET/PUT /users/me
│   └── middleware/jwt.go    # JWT 解析 + 注入 user_id 到 context
│
├── fragment/                # 光片 (隙)
│   ├── domain/              # Fragment 实体、FragmentStatus 枚举、CreateFragmentParams
│   ├── repository/          # FragmentRepository interface + PG: CRUD + 软删除 + 按条件筛选
│   ├── service/             # FragmentService interface + 创建/编辑/软删除/状态计算
│   ├── sync/oplog.go        # 写操作生成 OpLog 事件
│   └── handler/             # CRUD 端点 + DTO
│
├── media/                   # 媒体文件
│   ├── domain/              # MediaFile 实体、MediaType (image/audio)
│   ├── repository/          # MediaMetadataRepository interface + PG 元数据持久化
│   ├── storage/uploader.go  # 调用 infra/storage 接口 (签发 presigned URL / 确认上传 / 生成签名URL)
│   ├── processor/           # 图片处理 (WebP 缩略图生成) / 音频处理占位
│   ├── service/             # MediaService interface + Upload/Presign/Confirm/GetSignedURL/Delete
│   └── handler/             # 媒体端点 + DTO
│
├── emotion/                 # 微光情绪
│   ├── domain/emotion.go    # Emotion 常量 (平静/开心/疲惫/焦虑/失落/被击中/混乱/说不清)
│   ├── service/             # EmotionService interface + List/GetByID (静态数据，不存 DB)
│   └── handler/             # GET /emotions
│
├── tag/                     # 标签
│   ├── domain/tag.go        # Tag 实体
│   ├── repository/          # TagRepository interface + PG: CRUD + 频率统计
│   ├── service/             # TagService interface + 业务逻辑
│   └── handler/             # 标签 CRUD 端点 + DTO
│
├── timeline/                # 时间河流 (光)
│   ├── domain/              # TimelineQuery、DateGroup
│   ├── repository/          # TimelineRepository interface + PG: 按日期 GROUP BY + 游标分页
│   ├── service/             # TimelineService interface + 日期分组/筛选/排序
│   └── handler/             # GET /timeline + DTO
│
├── stats/                   # 情绪密度 + 高频词
│   ├── domain/              # EmotionDensity、FreqWordsResult
│   ├── repository/          # StatsRepository interface + PG 聚合查询 (情绪分布/标签频率)
│   ├── cache/redis_cache.go # 统计结果 Redis 缓存 (TTL + 写操作主动失效)
│   ├── service/             # StatsService interface + 查缓存→miss→PG聚合→写缓存
│   └── handler/             # GET /stats/emotion-density, GET /stats/freq-words + DTO
│
├── relation/                # 织线 (织)
│   ├── domain/              # Relation 实体、RelationType 枚举
│   ├── repository/          # RelationRepository interface + PG: CRUD + 双向查询
│   ├── service/             # RelationService interface + Create/Delete/GetRelationsOf
│   └── handler/             # POST/DELETE /relations + DTO
│
├── starmap/                 # 个人星图
│   ├── domain/
│   │   ├── star_node.go         # StarNode — fragment_id, position{x,y}, status_color, label(截取前20字)
│   │   ├── star_edge.go         # StarEdge — source_id, target_id, relation_type, curve_type(二次贝塞尔/直线)
│   │   └── star_graph.go        # StarGraph — nodes[], edges[], metadata{total_nodes, total_edges}
│   ├── graph/
│   │   ├── builder.go           # 图构建: 从 relation 表遍历 → 收集节点和边 → 调用 layout
│   │   │                        # BuildFullGraph(userID) → BFS 展开全图
│   │   │                        # GetSubGraph(userID, rootFragmentID, depth) → BFS depth步
│   │   ├── layout.go            # 力导向布局: 斥力∝1/d² + 边引力(胡克) + 迭代100轮
│   │   │                        # 环形布局(GetSubGraph): root在中心, depth递增向外同心圆
│   │   └── curve.go             # 二次贝塞尔控制点计算: 两点中点 + 按关系类型偏移方向/偏移量
│   ├── service/
│   │   ├── interface.go         # StarMapService interface
│   │   └── starmap.go           # GetFullGraph / GetSubGraph(从某光片展开N步) + 坐标缓存
│   └── handler/
│       ├── starmap_handler.go   # GET /starmap?root_fragment_id=&depth=
│       └── dto.go               # StarGraphDTO (前端渲染数据，含预计算坐标)
│
├── island/                  # 主题岛 (屿)
│   ├── domain/              # Island 实体、IslandStatus、GrowthRule (StarPoint/Growing/Formed/Dormant/Relit)
│   ├── repository/          # IslandRepository interface + PG: CRUD + 按用户/标签查询
│   ├── rules/engine.go      # 生长引擎: 标签出现N次 → 星点 → 小岛；静默检测；旧光重亮
│   ├── service/             # IslandService interface + Create/Update/List/GetDetail/计算生长
│   └── handler/             # 岛 CRUD + GET /islands/{id}/fragments + DTO
│
├── space/                   # 沉浸式空间
│   ├── domain/space_theme.go# SpaceTheme 枚举 (星空/海/房间/岛屿)
│   ├── service/             # SpaceService interface + 获取/切换用户空间配置
│   └── handler/             # GET/PUT /space/config
│
├── whitenoise/              # 白噪音
│   ├── domain/noise_audio.go# NoiseAudio 元信息
│   ├── service/             # WhiteNoiseService interface + List/Get (静态配置驱动)
│   └── handler/             # GET /whitenoise
│
├── sync/                    # 数据同步
│   ├── domain/
│   │   ├── oplog.go             # OpLog — user_id, server_rev, op_type, entity_type, entity_id, entity_public_id, payload(JSONB), client_op_id, client_seq, device_id
│   │   ├── sync_event.go        # SyncEvent — push/pull 协议定义
│   │   └── server_rev.go        # ServerRev — 服务端版本号类型
│   ├── repository/
│   │   ├── interface.go         # OpLogRepository interface
│   │   └── pg.go                # PG: Insert(幂等检查) / FindSinceRev(按server_rev ASC增量) / FindByClientOpID(去重)
│   ├── engine/
│   │   ├── conflict.go          # 冲突解决策略: last-write-wins / user-choose / auto-merge(标签/媒体/关联)
│   │   ├── diff.go              # Diff 计算: 比较本地 payload 和远端当前状态
│   │   └── merge.go             # 自动合并逻辑: tags/relations/media 无冲突合并, fragment 正文冲突标记
│   ├── service/
│   │   ├── interface.go         # SyncService interface
│   │   └── sync.go              # Push(遍历操作→幂等→冲突检测→执行→写oplog) / Pull(since_rev增量拉取)
│   └── handler/
│       ├── sync_handler.go      # POST /sync/push, GET /sync/pull
│       └── dto.go               # SyncPushRequest/SyncPullResponse/SyncPushResult/ConflictInfo
│
└── ai/                      # AI 服务 (预留)
    ├── domain/              # AIRequest、AIResponse
    ├── provider/            # AIProvider interface + DeepSeek HTTP 实现
    ├── service/             # AIService interface + prompt 组装 → 调 provider → 解析响应
    └── handler/             # POST /ai/glow-summary (预留) + DTO
```

**Go 端关键模块补充 — island / media / ai 完整文件清单**

island 模块（主题岛 + 生长引擎）：
- `domain/island.go` — Island 实体: id, public_id, name, description, cover_fragment_id, status, source_tag_id, fragment_count(冗余字段), dormant_at, relit_at
- `domain/island_status.go` — IslandStatus 枚举: star_point, growing, formed, dormant, relit
- `domain/growth_rule.go` — 生长规则常量: STAR_POINT_THRESHOLD=3, FORMED_THRESHOLD=5, DORMANT_DAYS=30
- `repository/interface.go` — IslandRepository interface: Create/Update/SoftDelete/FindByUser/FindByTag/FindDormant
- `repository/pg.go` — PG 实现: 含 FindDormant 查询 (status=formed AND 最近关联光片距今>30天)
- `rules/engine.go` — 生长引擎核心:
  - `CheckAndGrow(userID, tagID, newFragmentCount)` → 事件驱动，fragment创建/tag变更时触发
  - newCount≥3 → star_point 或 star_point→growing
  - newCount≥5 → growing→formed
  - formed 连续30天无新光片 → dormant (记录dormant_at)
  - dormant 重新出现新光片 → relit (记录relit_at)
  - relit 持续有新光片 → formed (清除relit_at)
  - `RecalculateIslandFragments(islandID)` → 重新关联符合标签条件的光片
- `service/interface.go` — IslandService interface
- `service/island.go` — CRUD + List/GetDetail + CalculateGrowth(在fragment.create/tag.change事件后调用)
- `handler/island_handler.go` — CRUD 端点 + GET /islands/{id}/fragments
- `handler/dto.go` — IslandDTO, IslandDetailDTO (含最近光片预览、生长历史)

media 模块（媒体上传 + 缩略图）：
- `domain/media_file.go` — MediaFile: id, public_id, media_type, object_key, file_name, file_size, mime_type, width/height, duration_ms, thumbnail_key
- `domain/media_type.go` — MediaType 枚举: image, audio
- `repository/interface.go` — MediaMetadataRepository: Insert/UpdateThumbKey/SoftDelete/FindByFragment
- `repository/pg.go` — PG 实现
- `storage/uploader.go` — 核心上传逻辑:
  - `PresignUpload(ctx, userID, fragmentID, fileName, contentType, fileSize)` → 校验权限+白名单+大小 → 生成 objectKey → 调 infra/storage.PresignedPutObject(5min TTL)
  - `ConfirmUpload(ctx, userID, fragmentID, objectKey)` → StatObject确认文件存在 → INSERT media_files → UPDATE fragment.media_urls → go async GenerateThumbnail
  - `GetSignedURL(ctx, objectKey)` → infra/storage.PresignedGetObject(5min TTL)
- `processor/image.go` — 缩略图生成: 下载原图 → imaging库 resize(最大宽300px) → WebP编码 → PUT {objectKey}_thumb.webp → UPDATE media_files.thumbnail_key
- `processor/audio.go` — MVP 占位，不做波形图
- `service/interface.go` — MediaService interface
- `service/media.go` — PresignUpload / ConfirmUpload / GetSignedURL / SoftDelete 编排
- `handler/media_handler.go` — POST /media/presign-upload, POST /media/confirm-upload, GET /media/{id}, DELETE /media/{id}
- `handler/dto.go` — PresignRequest/Response, ConfirmRequest, MediaDTO

ai 模块（MVP 全空壳 + 环境变量可切换）：
- `domain/ai_request.go` — AIRequest: mode(light_name/help_weave/dont_explain_me), fragment_ids[], context
- `domain/ai_response.go` — AIResponse: keywords[], emotion_title, summary_text, suggestion_ids[]
- `provider/interface.go` — AIProvider interface: Chat(ctx, prompt, model) → (response, tokenUsed, error)
- `provider/deepseek.go` — DeepSeek HTTP 实现: POST {AI_DEEPSEEK_BASE_URL}/chat/completions, Header: Bearer {AI_DEEPSEEK_API_KEY}
  - 环境变量控制: AI_DEEPSEEK_API_KEY, AI_DEEPSEEK_BASE_URL, AI_DEEPSEEK_MODEL, AI_MAX_TOKENS, AI_TIMEOUT
  - MVP 阶段 API_KEY 留空，模块可编译但不调用
- `service/interface.go` — AIService interface
- `service/ai.go` — GenerateGlowSummary / GenerateKeywords / SuggestRelations
  - MVP 返回 mock 或 "not_implemented"
  - 编排流程: 选 prompt 模板 → 拼上下文(fragment内容+用户历史) → 调 provider → 解析 JSON 响应 → 写 ai_requests 表(pending→processing→completed/failed)
  - 日额度检查: AI_DAILY_QUOTA_PER_USER (默认50次/天)
- `handler/ai_handler.go` — POST /ai/glow-summary (预留，返回 "not_implemented"), GET /ai/requests (预留)
- `handler/dto.go` — GlowSummaryRequest/Response, AIRequestDTO

**Flutter 端 — 10 个 feature 模块（完整文件明细）**

```
lib/
├── design/                              # 设计令牌 — 不依赖任何组件
│   ├── tokens/
│   │   ├── colors.dart                  # 莫兰迪色系 + 微光渐变色板（primary/secondary/surface/emotion 色点）
│   │   ├── spacing.dart                 # 留白系统 (xs=4/sm=8/md=16/lg=24/xl=32/xxl=48)
│   │   ├── radius.dart                  # 圆角体系 (sm=8/md=12/lg=16/xl=24/full=999)
│   │   ├── typography.dart              # 字体层级 (caption/body/callout/title/headline/largeTitle)
│   │   ├── shadows.dart                 # 柔和投影（带色彩倾向，非纯黑 shadow）
│   │   ├── blur.dart                    # 毛玻璃模糊量 (light=4/medium=8/heavy=12)
│   │   └── motion.dart                  # 动效时长/曲线
│   │       ├── duration_fast=200ms
│   │       ├── duration_normal=400ms
│   │       ├── duration_breath=3000ms   # 呼吸周期
│   │       ├── curve_ease_out/micromovement/sine
│   └── themes/
│       ├── theme.dart                   # ThemeData 组装 (完全绕过 Material 默认，useMaterial3:true)
│       └── extensions/                  # ThemeExtension 自定义属性
│           ├── blur_theme.dart          # 毛玻璃参数（模糊量/透明度/着色）
│           ├── glow_theme.dart          # 微光参数（径向渐变颜色/半径/强度）
│           └── space_theme.dart         # 空间主题参数（星空密度/海洋波浪振幅/岛屿间距）
│
├── ui/                                  # 通用 UI 组件 — 只依赖 design
│   ├── primitives/                      # 原子组件
│   │   ├── blur_box.dart                # 毛玻璃容器 (ClipRect > BackdropFilter > ImageFilter.blur)
│   │   ├── glow_button.dart             # 微光按钮 (Stack: 底层 Container + 顶层 ShaderMask 径向渐变)
│   │   ├── ripple_tap.dart              # 水波纹点击反馈 (GestureDetector > CustomPaint > RipplePainter)
│   │   ├── breathing_widget.dart        # 呼吸感动画包装器 (AnimationController.repeat > FadeTransition + ScaleTransition)
│   │   └── morandi_card.dart            # 莫兰迪风格卡片 (圆角+低饱和底色+柔和投影+毛玻璃可选)
│   ├── composites/                      # 组合组件 — 由 primitives 组装
│   │   ├── emotion_picker.dart          # 微光情绪选择器（一排柔和色点，每点对应情绪词，点击选中，长按看解释）
│   │   ├── light_card.dart              # 光片卡片（文字摘要+图片缩略图+情绪色点+光片状态+时间）
│   │   ├── time_river_item.dart         # 时间河流条目（日期分组头+光片卡片列表+底部渐变分割线）
│   │   ├── tag_chip.dart                # 标签芯片（圆角+低饱和底色+标签名+可选删除按钮）
│   │   └── image_grid.dart              # 图片缩略图网格（瀑布流/柔和网格，点击放大）
│   └── spaces/                          # 沉浸式空间 — CustomPainter 自绘
│       ├── space_canvas.dart            # 空间画布基类（AnimationController 驱动 + CustomPainter 绑定）
│       ├── starry_space.dart            # 星空 （粒子系统: 每个粒子 {x,y,radius,brightness,phase}，正弦缓动位置+亮度）
│       ├── ocean_space.dart             # 海（三层叠加正弦波: 不同振幅/频率/相位/颜色透明度，产生纵深波浪感）
│       └── island_space.dart            # 岛屿群（每个岛=贝塞尔曲线轮廓+柔和颜色填充+标签文字，可点击进入）
│
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── user.dart                # User (freezed) — id, public_id, username, nickname, avatar_key, created_at
│   │   │   ├── token.dart               # TokenPair (freezed) — access_token, refresh_token, expires_at
│   │   │   └── auth_repository.dart     # abstract class AuthRepository
│   │   ├── data/
│   │   │   ├── auth_api.dart            # dio: POST /auth/register, /auth/login, /auth/refresh
│   │   │   ├── token_storage.dart       # flutter_secure_storage: read/save/delete token
│   │   │   └── auth_repository_impl.dart # implements AuthRepository
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart   # AuthNotifier (StateNotifier) — login/logout/refresh/autoLogin
│   │       └── pages/
│   │           ├── login_page.dart      # 登录页：用户名+密码+捕光按钮风格
│   │           └── register_page.dart   # 注册页：用户名+密码+昵称+头像(可选)
│   │
│   ├── fragment/
│   │   ├── domain/
│   │   │   ├── fragment.dart            # Fragment (freezed) — id, public_id, user_id, content_text, emotion, status, tags, media_urls, created_at
│   │   │   ├── fragment_status.dart     # enum FragmentStatus { twilight, stardust, echo, seed, tide, islandCore }
│   │   │   ├── emotion.dart             # class Emotion — id, name, colorHex, description
│   │   │   ├── create_params.dart       # CreateFragmentParams (freezed) — content_text, emotion, tag_names, media_paths
│   │   │   └── fragment_repository.dart # abstract class FragmentRepository
│   │   ├── data/
│   │   │   ├── local/
│   │   │   │   ├── fragment_dao.dart    # drift DAO: CRUD + 按时间/情绪/标签筛选
│   │   │   │   ├── fragment_drift.dart  # drift 表定义 (DataClass + Table)
│   │   │   │   └── fragment_local_ds.dart # 本地数据源封装
│   │   │   ├── remote/
│   │   │   │   ├── fragment_api.dart    # dio: CRUD /api/v1/fragments
│   │   │   │   └── fragment_remote_ds.dart
│   │   │   ├── media_uploader.dart       # presigned URL 上传流程 (presign → PUT → confirm)
│   │   │   └── fragment_repository_impl.dart # 本地优先: 先写 drift → 后台 push OpLog
│   │   ├── sync/
│   │   │   ├── oplog_generator.dart     # 写操作生成 OpLog {client_op_id, entity_type, op_type, payload, client_seq}
│   │   │   └── conflict_resolver.dart   # base_server_version 冲突 → 生成冲突副本
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── fragment_list_provider.dart   # AsyncNotifier — 光片列表
│   │       │   ├── fragment_detail_provider.dart # AsyncNotifier — 单条光片详情
│   │       │   └── capture_provider.dart         # StateNotifier — 捕光表单状态
│   │       ├── pages/
│   │       │   ├── capture_page.dart     # 捕光页：今日提示+输入框+图片/情绪/标签快捷入口+捕光按钮
│   │       │   ├── fragment_detail_page.dart # 光片详情页：完整内容+媒体+情绪+标签+织线入口+编辑+删除
│   │       │   └── fragment_edit_page.dart   # 编辑页
│   │       └── widgets/
│   │           ├── capture_input.dart    # 文字输入框 "把这一刻轻轻放在这里。"
│   │           ├── media_picker.dart     # 底部弹窗：拍照/相册导入/录音 三个入口
│   │           ├── emotion_picker_sheet.dart # 捕光内嵌情绪选择器（调用 ui/composites/emotion_picker）
│   │           └── tag_input.dart        # 标签输入框（手动打字，无联想）
│   │
│   ├── timeline/
│   │   ├── domain/
│   │   │   ├── timeline_query.dart       # TimelineQuery (freezed) — date, emotion, media_type, cursor, limit
│   │   │   ├── date_group.dart           # DateGroup — date_label, fragments[], emotion_dots[]
│   │   │   └── timeline_repository.dart  # abstract class TimelineRepository
│   │   ├── data/
│   │   │   ├── timeline_api.dart         # dio: GET /api/v1/timeline?cursor=&limit=&emotion=&media_type=
│   │   │   ├── timeline_local_dao.dart   # drift: 本地时间线查询 (离线用)
│   │   │   └── timeline_repository_impl.dart # 在线走 API，离线走本地
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── timeline_provider.dart # AsyncNotifier — CursorPage<FragmentDTO>
│   │       │   └── filter_provider.dart   # StateNotifier — 当前筛选条件
│   │       ├── pages/
│   │       │   └── time_river_page.dart  # 时间河流页：SliverList + 日期分组头 + 光片卡片 + 底部捕光浮动按钮
│   │       └── widgets/
│   │           ├── date_group_widget.dart # 日期分组组件
│   │           ├── timeline_light_card.dart # 时间线专用光片卡片
│   │           └── filter_bar.dart        # 筛选条（情绪/媒介/关键词 横向滚动 chip）
│   │
│   ├── stats/
│   │   ├── domain/
│   │   │   ├── emotion_density.dart      # EmotionDensity — period, emotions[{name, count, percentage}]
│   │   │   ├── freq_words.dart           # FreqWordsResult — words[{text, count}]
│   │   │   └── stats_repository.dart     # abstract class StatsRepository
│   │   ├── data/
│   │   │   ├── stats_api.dart            # dio: GET /api/v1/stats/emotion-density, /api/v1/stats/freq-words
│   │   │   └── stats_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── stats_provider.dart   # AsyncNotifier — 情绪密度 + 高频词
│   │       └── widgets/
│   │           ├── emotion_density_chart.dart # 情绪分布图（柔和色条，横条图而非饼图）
│   │           └── freq_words_cloud.dart     # 高频词云（大小+透明度表示频率）
│   │
│   ├── relation/
│   │   ├── domain/
│   │   │   ├── relation.dart             # Relation (freezed) — id, public_id, source, target, type, custom_label, note
│   │   │   ├── relation_type.dart        # enum RelationType { cause, inspiration, emotionContinue, samePhase, remindsMe, custom }
│   │   │   └── relation_repository.dart  # abstract class RelationRepository
│   │   ├── data/
│   │   │   ├── relation_api.dart         # dio: POST /api/v1/relations, DELETE /api/v1/relations/{id}
│   │   │   ├── relation_local_dao.dart   # drift: 本地织线暂存
│   │   │   └── relation_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── relation_provider.dart # StateNotifier — 当前织线操作状态
│   │       ├── pages/
│   │       │   ├── weave_page.dart        # 织线主页（可选：从光片详情页入口触发）
│   │       │   └── relation_select_page.dart # 搜索/浏览历史光片，选择目标光片
│   │       └── widgets/
│   │           ├── relation_type_picker.dart # 关系类型选择器（回声/伏笔/余震/平行宇宙/小小救命/潮汐/旧光/自定义）
│   │           └── relation_note_input.dart  # 关系说明输入框（可选）
│   │
│   ├── starmap/
│   │   ├── domain/
│   │   │   ├── star_node.dart            # StarNode — fragment_id, position, status_color, label
│   │   │   ├── star_edge.dart            # StarEdge — source_id, target_id, relation_type, curve
│   │   │   ├── star_graph.dart           # StarGraph — nodes[], edges[]
│   │   │   └── starmap_repository.dart   # abstract class StarMapRepository
│   │   ├── data/
│   │   │   ├── starmap_api.dart          # dio: GET /api/v1/starmap?root_fragment_id=&depth=
│   │   │   └── starmap_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── starmap_provider.dart # AsyncNotifier — StarGraph 数据 + 选中状态
│   │       └── widgets/
│   │           ├── starmap_canvas.dart    # InteractiveViewer 包裹 CustomPaint
│   │           │                          # ⚠️ 手势冲突：双指→InteractiveViewer(缩放平移)；单指拖星点→GestureDetector(onPan)
│   │           ├── star_node_widget.dart  # 可拖拽星点：Positioned + GestureDetector(onPanUpdate) 更新位置
│   │           └── edge_painter.dart      # CustomPainter 连线绘制：二次贝塞尔弧线，颜色按关系类型
│   │
│   ├── island/
│   │   ├── domain/
│   │   │   ├── island.dart               # Island (freezed) — id, public_id, name, description, cover, status, source_tag, fragment_count
│   │   │   ├── island_status.dart        # enum IslandStatus { starPoint, growing, formed, dormant, relit }
│   │   │   └── island_repository.dart
│   │   ├── data/
│   │   │   ├── island_api.dart           # dio: CRUD /api/v1/islands, GET /api/v1/islands/{id}/fragments
│   │   │   └── island_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── island_provider.dart  # AsyncNotifier — 岛列表 + 当前选中岛详情
│   │       ├── pages/
│   │       │   ├── universe_page.dart     # 小宇宙页：今日微光/主题星点区/小岛区/最近柔光整理
│   │       │   └── island_detail_page.dart # 岛详情：岛内光片列表+时间线
│   │       └── widgets/
│   │           ├── island_card.dart       # 岛卡片（名称+封面缩略图+光片计数+状态指示）
│   │           └── island_canvas.dart     # 岛屿自定义绘制（贝塞尔轮廓+标签+光片缩略图散布）
│   │
│   ├── space/
│   │   ├── domain/
│   │   │   ├── space_theme.dart          # enum SpaceTheme { starry, ocean, room, island }
│   │   │   └── space_repository.dart
│   │   ├── data/
│   │   │   ├── space_api.dart            # dio: GET/PUT /api/v1/space/config
│   │   │   └── space_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── space_provider.dart   # StateNotifier — 当前空间主题+配置
│   │       └── pages/
│   │           └── space_page.dart        # 沉浸式空间页（全屏 Canvas + 白噪音背景 + 光片浮现）
│   │
│   ├── whitenoise/
│   │   ├── domain/
│   │   │   ├── noise_audio.dart          # NoiseAudio — id, name, icon, audio_file (asset或remote URL), category
│   │   │   └── whitenoise_repository.dart
│   │   ├── data/
│   │   │   ├── whitenoise_api.dart       # dio: GET /api/v1/whitenoise (扩展音频)
│   │   │   ├── whitenoise_assets.dart    # 内置音频清单
│   │   │   └── whitenoise_repository_impl.dart # 内置音频+远端音频合并
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── whitenoise_provider.dart # StateNotifier — 当前播放音频+音量+播放状态
│   │       └── widgets/
│   │           ├── noise_player.dart     # just_audio AudioPlayer 包装 + 播放/暂停/音量
│   │           └── noise_selector.dart   # 横向滚动白噪音卡片列表（雨声/翻书/风/心跳…）
│   │
│   ├── sync/
│   │   ├── domain/
│   │   │   ├── oplog.dart                # OpLog (freezed) — client_op_id, entity_type, op_type, entity_public_id, payload, client_seq, base_server_version
│   │   │   └── sync_status.dart          # SyncStatus — last_server_rev, pending_count, last_sync_at, is_syncing
│   │   └── engine/
│   │       ├── sync_engine.dart          # 后台定时同步 (WorkManager/timer) + 手动触发
│   │       │                              # Push: 收集未推送 OpLog → POST /sync/push
│   │       │                              # Pull: GET /sync/pull?since_rev=N → 应用到 drift
│   │       └── conflict_resolver.dart    # 冲突策略：
│   │                                      # - base_server_version == server_rev → 接受
│   │                                      # - base_server_version < server_rev → 生成冲突副本
│   │                                      # - 标签/媒体/关联尽量自动合并
│   │
│   └── ai/                              # MVP 全空壳，所有文件预留
│       ├── domain/
│       │   ├── ai_request.dart           # AIRequest (freezed) — mode, fragment_ids, context
│       │   └── ai_response.dart          # AIResponse (freezed) — keywords, emotion_title, summary, suggestions
│       ├── data/
│       │   ├── ai_api.dart               # dio: POST /api/v1/ai/glow-summary (预留)
│       │   └── ai_repository_impl.dart
│       └── presentation/
│           ├── providers/
│           │   └── ai_provider.dart      # 预留
│           ├── pages/
│           │   └── glow_organize_page.dart # 柔光整理页（预留按钮 → MVP 显示"即将开放"）
│           └── widgets/
│               └── glow_suggestion_card.dart # 柔光建议卡（预留）
│
├── app/
│   ├── app.dart                         # MaterialApp.router + ThemeData(design/tokens) + ProviderScope
│   ├── router.dart                      # GoRouter + StatefulShellRoute.indexedStack
│   │                                     # Tab 1: 捕光 (/capture)
│   │                                     # Tab 2: 时间河 (/timeline)
│   │                                     # Tab 3: 织线 (/weave)
│   │                                     # Tab 4: 小宇宙 (/universe)
│   │                                     # 子路由: /fragments/:id, /islands/:id, /space, /settings
│   └── providers.dart                   # 全局 Provider 注册（authProvider, syncEngineProvider 等）
│
└── main.dart                            # runApp + ProviderScope
```

**4 个底部 Tab：捕光 / 时间河 / 织线 / 小宇宙**

### 3.3 模块内部分层职责

**Go 端**

| 层 | 可以做什么 | 不能做什么 |
|---|----------|----------|
| `domain/` | 定义实体、值对象、service/repository interface 契约 | 不依赖任何外部库，不依赖其他业务模块 |
| `repository/` | SQL 查询、DB 事务、PG 实现 | 不含业务逻辑。不跨模块查其他域的表 |
| `service/` | 业务规则、流程编排、事务管理。跨模块调用只走其他模块的 service interface | 不直接写 SQL，不直接调其他模块的 repository |
| `handler/` | 参数校验、调用 service、序列化响应 | 不含业务逻辑。不含 SQL |

**Flutter 端**

| 层 | 可以做什么 | 不能做什么 |
|---|----------|----------|
| `domain/` | 实体（freezed）、repository 抽象接口 | 不依赖任何 Flutter 包，纯 Dart |
| `data/` | drift DAO、本地文件 I/O、dio API 调用、repository 实现 | 不含 UI 代码 |
| `presentation/` | Riverpod provider、Widget、Page | 不直接操作数据库/网络，只通过 provider 调 repository |
| `sync/` (模块内) | OpLog 生成、冲突解决逻辑 | — |

### 3.4 跨模块调用铁律

**Go 端：**

```
✅ 模块 A → 模块 B 的 service interface
❌ 模块 A → 模块 B 的 repository / domain struct 内部字段 / 直接 SQL 查其他域的表
```

举例：`stats` 需要统计碎片数据 → 调用 `fragment.Service` 接口，不能直接查 `fragments` 表。

**Flutter 端：**

```
✅ 模块 A → 模块 B 暴露的 provider / repository interface
❌ 模块 A → 模块 B 的 data/DAO / 内部实现
```

**铁律级别**：严格执行，所有跨模块调用必须走 interface。这条是所有规范里对未来扩展能力影响最大的一条。本地调用换成远程调用时，interface 签名不用变，改动量可控。

### 3.5 依赖方向

**Go 端**：

```
shared ← infra ← 业务模块
```

| 模块 | 依赖 |
|-----|------|
| shared | 无 |
| infra | shared |
| auth | shared + infra |
| fragment | shared + infra |
| media | shared + infra |
| emotion | shared |
| tag | shared + infra + fragment |
| timeline | shared + infra + fragment |
| stats | shared + infra + fragment + timeline + tag |
| relation | shared + infra + fragment |
| starmap | shared + relation + fragment |
| island | shared + infra + tag + fragment + stats |
| space | shared + infra |
| whitenoise | shared |
| sync | shared + infra + fragment + media + relation |
| ai | shared + infra |

依赖方向严格单向，零循环。

### 3.6 外部依赖调用设计

| 外部服务 | MVP 调用 | 方案 |
|---------|---------|------|
| MinIO/S3 | ✅ 是 | Docker Compose 同机部署，Presigned URL 直传 |
| DeepSeek API | ❌ 不做 | 预留环境变量，后端代理调用 |

**媒体上传策略（核心）**：Presigned URL 直传 MinIO——Go 后端不触碰文件流，只签发上传凭证、鉴权、写元数据。

**上传链路（完整 6 步，含时序预估）：**

```
Flutter App（用户点击捕光，选择图片）
  │
  ├── 1. image_picker(拍照或相册导入) + flutter_image_compress(压缩到合理尺寸，~200ms)
  ├── 2. 写本地文件系统（App 沙盒目录，~10ms）
  │
  ├── 3. dio POST /api/v1/media/presign-upload
  │     Body: { fragment_id, file_name, content_type, file_size }
  │     ↓ Go Backend → 鉴权(JWT user_id == fragment.user_id)
  │     ↓            → 生成 object_key: users/{user_public_id}/media/{yyyy}/{mm}/{media_id}.{ext}
  │     ↓            → 调 MinIO PresignedPutObject(5min TTL)
  │     返回: { upload_url, object_key }  (~50ms)
  │
  ├── 4. dio PUT upload_url (数据流直传 MinIO:9000，不经过 Go)
  │     Body: 图片二进制流
  │     ↓ MinIO: 直接写入 minio_data volume  (~200-800ms，取决于文件大小和磁盘I/O)
  │     返回: 200 OK
  │
  ├── 5. dio POST /api/v1/media/confirm-upload
  │     Body: { fragment_id, object_key }
  │     ↓ Go Backend → INSERT media_files (元数据)
  │     ↓            → UPDATE fragments SET media_urls = array_append(media_urls, object_key)
  │     ↓            → 异步触发: processor/image.go 生成 WebP 缩略图 → PUT thumbnail_key 到 MinIO
  │     返回: { media_id, file_url }  (~80ms)
  │
  └── 6. Flutter 本地 drift: 更新 fragment 的 media_urls → OpLog 入队 → 等待后台 sync push
     总耗时: ~600ms-1200ms（图片压缩 + 直传 + 元数据写入）
```

**请求链路 B：创建纯文字光片**

```
Flutter App
  ↓ dio POST /api/v1/fragments  { content_text, emotion, tag_names }
Nginx :443 → Go Backend :8080
  ├── fragment.service.Create()
  │   ├── INSERT fragments (public_id 由客户端预生成 UUID)
  │   ├── INSERT fragment_tags (如果关联了已有 tag)
  │   ├── INSERT/UPDATE tags (如果有新标签)
  │   ├── INSERT oplog (server_rev 自增, client_op_id 幂等)
  │   └── Redis: DEL app:prod:stats:emotion_density:user_{id} (失效统计缓存)
  └── 返回: ApiResponse[FragmentDTO] (~60ms)
Flutter: 本地 drift INSERT → 记录 server_rev
```

**请求链路 C：查看时间河流**

```
Flutter App
  ↓ dio GET /api/v1/timeline?cursor=&limit=20&emotion=&media_type=
Nginx → Go Backend :8080
  ├── timeline.service.GetTimeline()
  │   └── PG: SELECT * FROM fragments
  │       WHERE user_id=? AND is_deleted=FALSE
  │       AND (emotion=? OR ? IS NULL)  -- 可选筛选
  │       AND created_at < cursor_time  -- 游标
  │       ORDER BY created_at DESC LIMIT 21  -- 多查一条判断 has_more
  │   └── has_more = len(results) > 20
  │   └── next_cursor = base64({created_at: last_item.created_at, id: last_item.id}) + HMAC
  └── 返回: ApiResponse[CursorPage[FragmentDTO]] (~30-80ms，有索引)
```

**请求链路 D：情绪密度统计（Redis 缓存路径）**

```
Flutter App
  ↓ dio GET /api/v1/stats/emotion-density?period=7d
Nginx → Go Backend :8080
  ├── stats.service.GetEmotionDensity()
  │   ├── Redis: GET app:prod:stats:emotion_density:user_{id}:7d
  │   │   ├── 命中 → 直接返回 (~5ms)
  │   │   └── 未命中 ↓
  │   ├── PG: SELECT emotion, COUNT(*) FROM fragments
  │   │     WHERE user_id=? AND created_at > NOW()-INTERVAL'7d' AND is_deleted=FALSE
  │   │     GROUP BY emotion ORDER BY count DESC (~100-200ms)
  │   └── Redis: SET app:prod:stats:emotion_density:user_{id}:7d {result} EX 3600
  └── 返回: ApiResponse[EmotionDensity] (~5ms 命中 / ~150ms 未命中)
```

**请求链路 E：数据同步 Push**

```
Flutter App（联网后触发）
  ├── sync_engine 收集本地未推送 OpLog (按 client_seq 排序)
  │   ↓ dio POST /api/v1/sync/push
  │   Body: { operations: [
  │     { client_op_id, entity_type, op_type, entity_public_id, payload, base_server_version, client_seq }
  │   ], device_id }
  │
Nginx → Go Backend :8080
  ├── sync.service.Push()
  │   For each operation:
  │   ├── 幂等检查: SELECT FROM oplog WHERE user_id=? AND client_op_id=?
  │   │   └── 已存在 → 跳过，返回已有 server_rev
  │   ├── 新增(fragment INSERT):
  │   │   └── 创建实体 → 分配 BIGSERIAL id + 记录 public_id 映射
  │   ├── 更新(fragment UPDATE):
  │   │   ├── IF base_server_version == 当前 server_version → 接受更新
  │   │   └── IF base_server_version < 当前 server_version → 返回 conflict，不静默覆盖
  │   ├── 删除(fragment DELETE):
  │   │   ├── 允许删除旧版本，保留 tombstone (deleted_at)
  │   │   └── 本地编辑与远端删除冲突 → 返回 conflict
  │   ├── 标签/媒体/关联: 尽量自动合并
  │   ├── INSERT oplog (server_rev 自增)
  │   └── 收集每个操作的执行结果
  │
  └── 返回: { results: [{ client_op_id, status, server_rev?, conflict? }], new_server_rev }
Flutter: 更新本地 drift → 清除已推送 OpLog → 冲突项 → 本地生成冲突副本
```

**请求链路 F：数据同步 Pull**

```
Flutter App
  ↓ dio GET /api/v1/sync/pull?since_rev=42&limit=100
Nginx → Go Backend :8080
  ├── sync.service.Pull()
  │   └── PG: SELECT * FROM oplog WHERE user_id=? AND server_rev > 42 ORDER BY server_rev ASC LIMIT 100
  └── 返回: {
        operations: [...],
        next_since_rev: 142,   // 本批次最大 server_rev，下次请求 since_rev=143
        has_more: true,
        full_sync_required: false  // 若 since_rev 落入已归档区间，标记 true
      }
Flutter: 按 server_rev ASC 顺序应用到 drift → 更新本地 last_server_rev
```

### Docker Compose 完整结构

```yaml
# docker-compose.yml
version: "3.9"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro       # SSL 证书
    depends_on:
      - app
    mem_limit: 64M
    restart: unless-stopped

  app:                                     # Go 后端
    build:
      context: ./backend
      dockerfile: Dockerfile
    expose:
      - "8080"
    env_file:
      - .env                               # DB/Redis/MinIO/DeepSeek 配置
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
      minio:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 15s
      timeout: 5s
      retries: 3
    mem_limit: 256M
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"

  postgres:
    image: postgres:16-alpine
    expose:
      - "5432"
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pg_data:/var/lib/postgresql/data   # ✅ 持久化 — 不可丢
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    mem_limit: 512M
    restart: unless-stopped
    command: |
      -c shared_buffers=128MB
      -c log_min_duration_statement=200ms    # 慢查询日志阈值

  redis:
    image: redis:7-alpine
    expose:
      - "6379"
    volumes:
      - redis_data:/data                    # MVP 不持久化，但挂载以防万一
    command: >
      redis-server
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
    mem_limit: 128M
    restart: unless-stopped

  minio:
    image: quay.io/minio/minio:latest
    expose:
      - "9000"                              # API (对 Nginx 暴露)
      - "9001"                              # Console (docker 内部，不对外)
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data                    # ✅ 持久化 — 图片/录音不可丢
    command: server /data --console-address ":9001"
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      timeout: 5s
      retries: 5
    mem_limit: 256M
    restart: unless-stopped

volumes:
  pg_data:        # PG 数据 — ✅ 持久化，必须
  minio_data:     # 媒体文件 — ✅ 持久化，必须
  redis_data:     # 缓存 — ❌ MVP 不要求持久化，丢得起
```

---

## 四、部署架构

### 4.1 当前部署拓扑

```
┌──────────────────────────────────────────────────┐
│              自有服务器 2C2G                       │
│                                                   │
│  Flutter App                                       │
│    │                                               │
│    ├── HTTPS                                      │
│    ▼                                               │
│  Nginx :443                                       │
│    ├── /api/*  ──────────────► Go Backend :8080   │
│    └── /media/* (扩展音频)  ──► MinIO :9000        │
│                                                   │
│  MinIO :9000 (API — 对 Nginx 暴露)                 │
│  MinIO :9001 (Console — docker 内部，不对外)        │
│                                                   │
│  Go Backend :8080                                  │
│    ├── /healthz → UptimeRobot 探活                │
│    ├── 签发 presigned URL                          │
│    ├── 写元数据、鉴权                               │
│    └── → PostgreSQL :5432 / Redis :6379            │
│                                                   │
│  Volumes:                                          │
│    pg_data    — ✅ 持久化                          │
│    minio_data — ✅ 持久化                          │
│    redis_data — ❌ MVP 不持久化                    │
└──────────────────────────────────────────────────┘
```

### 4.2 Docker Compose 资源分配

| 容器 | 内存 | 说明 |
|-----|------|------|
| Nginx | 64M | 纯转发 |
| Go app | 256M | 16 模块够用 |
| PostgreSQL | 512M | 合理缓冲 |
| Redis | 128M | 轻量缓存，maxmemory 256MB |
| MinIO | 256M | 对象存储内存缓冲 |
| OS + 预留 | ~780M | — |
| **合计** | **~2G** | |

### 4.3 持久化与静态资源

- **pg_data**：必须持久化 volume，用户数据不可丢
- **minio_data**：必须持久化 volume，图片/录音不可丢
- **redis_data**：MVP 不持久化 volume，缓存丢了重算
- **白噪音基础音频**：打包进 Flutter App 包内
- **白噪音扩展音频**：放 MinIO，走 Nginx 直接 serve，不经过 Go
- **MinIO Console**：不对外暴露

### 4.4 性能瓶颈预判

核心瓶颈：**磁盘 I/O**。PG 表数据 + MinIO 对象文件在同一块盘上读写——用户上传图片时 MinIO 写文件 + PG 写元数据，同时其他用户可能在刷时间线。但 MVP 阶段（内部验证、个位数用户、无高并发）此问题不构成实际约束。

### 4.5 监控与可观测性（MVP 最小组合）

| 组件 | 方案 | 说明 |
|-----|------|------|
| Go 后端日志 | slog/zap 结构化 JSON 日志 | 标准输出，Docker logs 收集 |
| 错误告警 | Sentry (Go: sentry-go + Flutter: sentry_flutter) | 崩溃/异常主动上报，包含 requestID/userID 上下文 |
| 健康检查 | `/healthz` (Chi middleware) | Docker healthcheck 依赖，UptimeRobot 每 30s 探测 |
| 探活 | UptimeRobot / Better Stack | 外部探测 API 可达性，宕机自动通知 |
| 数据库监控 | PG `log_min_duration_statement = 200ms` | 慢查询日志，超过 200ms 的 SQL 自动记录 |
| AI 调用记录 | ai_requests 表（预留） | AI 调用追踪：模式、token 数、耗时、状态 |
| 关键业务表 | oplog 增长监控（行数）、fragments 增长监控 | 手动 SQL 查询或简单的 CLI 脚本 |

这套覆盖 MVP 80% 早期问题。

| MVP 不做 | 理由 |
|---------|------|
| Loki 日志聚合 | Docker logs + slog 标准输出够用 |
| Prometheus + Grafana | 内部验证没这需求 |
| 分布式追踪 (OpenTelemetry) | 单机单体，不需要 |
| 消息队列 | 用户量没到 |

### 4.6 .env 环境变量模板

```bash
# .env.example — 复制为 .env 后填入真实值

# Go 后端
APP_ENV=production                           # production / staging / development
APP_PORT=8080
JWT_SECRET=replace_with_64char_random        # HS256 签名密钥
JWT_ACCESS_EXPIRY=15m                        # Access Token 有效期
JWT_REFRESH_EXPIRY=720h                      # Refresh Token 有效期 (30天)

# PostgreSQL
DB_HOST=postgres
DB_PORT=5432
DB_USER=glimmer
DB_PASSWORD=replace_with_strong_password
DB_NAME=glimmer
DB_SSLMODE=disable                           # docker 内部不走 TLS

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=                              # MVP 无密码

# MinIO / S3
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=replace_with_minio_user
MINIO_SECRET_KEY=replace_with_minio_password
MINIO_BUCKET=glimmer-media
MINIO_USE_SSL=false                          # docker 内部 HTTP
MINIO_PRESIGN_UPLOAD_TTL=5m
MINIO_PRESIGN_DOWNLOAD_TTL=5m
MEDIA_MAX_IMAGE_SIZE=10485760                # 10MB
MEDIA_MAX_AUDIO_SIZE=52428800                # 50MB
MEDIA_IMAGE_FORMATS=JPEG,PNG,HEIC,WebP
MEDIA_AUDIO_FORMATS=M4A,AAC,MP3,WAV

# DeepSeek AI（预留，MVP 不调用）
AI_PROVIDER=deepseek
AI_DEEPSEEK_API_KEY=                         # MVP 留空
AI_DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
AI_DEEPSEEK_MODEL=deepseek-chat
AI_MAX_TOKENS=2048
AI_TIMEOUT=60s
AI_DAILY_QUOTA_PER_USER=50                   # 每日每用户 AI 额度

# Sentry
SENTRY_DSN=                                  # MVP 留空或填入
SENTRY_ENVIRONMENT=production
SENTRY_SAMPLE_RATE=1.0
```

| 分类 | 事项 | 理由 |
|-----|------|-----|
| ✅ 做 | Docker Compose + volume 持久化 pg_data/minio_data | 上线必需 |
| ✅ 做 | presigned URL 直传 MinIO | 避免 Go 中转文件流 |
| ✅ 做 | /healthz + UptimeRobot 探活 | 基础存活监控 |
| ✅ 做 | golang-migrate 版本化迁移脚本 | 表结构变更可控 |
| ✅ 做 | Nginx client_max_body_size 限制 | 上传体积安全 |
| ✅ 做 | slog/zap 日志 + Sentry 错误告警 | 覆盖 MVP 80% 问题 |
| ✅ 做 | PG 慢查询日志 | 数据库问题排查 |
| 👀 暂缓 | Redis 持久化 | 缓存丢了重算 |
| 👀 暂缓 | PG 主从复制 | MVP 数据量小，单节点够 |
| 👀 暂缓 | MinIO 多节点纠删码 | 单机够用 |
| 👀 暂缓 | 日志聚合 (Loki) | Sentry + slog 标准输出够用 |
| ❌ 不做 | K8s / 服务网格 | 2C2G 单机，过度工程化 |
| ❌ 不做 | CDN | 内部验证无外部流量 |
| ❌ 不做 | 消息队列削峰 | 用户量没到 |
| ❌ 不做 | Prometheus + Grafana | MVP 不需要 |

---

## 五、数据模型

### 5.1 核心实体关系

```
User 1───N Fragment          (用户 → 光片)
User 1───N Tag               (用户 → 标签)
User 1───N Island            (用户 → 主题岛)
User 1───N OpLog             (用户 → 同步日志)
User 1───N RefreshToken      (用户 → 刷新令牌)

Fragment 1───N FragmentTag   (光片 → 标签)  M───1 Tag
Fragment 1───N MediaFile     (光片 → 媒体文件)
Fragment 1───N Relation (source)  (光片作为关联起点)
Fragment 1───N Relation (target)  (光片作为关联终点)
Fragment N───M Island (via IslandFragment)    (光片 ↔ 主题岛)

Island 1───N IslandFragment  (主题岛 → 岛内光片)
```

### 5.2 核心数据对象清单（11 张表）与增长预判

| # | 表名 | 用途 | 增长等级 | 增长驱动 | 日均预估（单活跃用户） | 应对策略 |
|---|-----|------|---------|---------|---------------------|---------|
| 1 | users | 用户账户 | 🟢 低 | 注册 | 0-1 条 | 无 |
| 2 | fragments | 光片 | 🔴 核心高增长 | 每次记录一条 | 3-10 条 | 索引覆盖核心查询（user_id+created_at、user_id+emotion）；后续可选：超 6 个月归档到 fragment_archive |
| 3 | tags | 标签 | 🟡 中等 | 每个新标签一条，重复使用 | 0-5 条 | 无额外 |
| 4 | fragment_tags | 光片-标签关联 | 🔴 随光片增长 | 每条光片 N 个标签 | 5-20 条 | 无额外 |
| 5 | media_files | 媒体文件元数据 | 🔴 随光片增长 | 每条照片/录音一条 | 2-8 条 | 无额外（文件本体在 MinIO） |
| 6 | relations | 织线关联 | 🟡 中等 | 每次织线一条 | 1-5 条 | 无额外 |
| 7 | islands | 主题岛 | 🟢 低（聚合产物） | 标签出现 3 次才触发 | 0-1 条 | 无额外 |
| 8 | island_fragments | 岛-光片关联 | 🟡 中等 | 岛生长时批量关联 | 0-10 条 | 无额外 |
| 9 | refresh_tokens | 刷新令牌 | 🟢 低 | 每次登录/刷新一条 | 1-3 条 | 定期清理过期 revoked token |
| 10 | oplog | 同步操作日志 | 🔴 **极高增长** | 每条写操作 1 条（fragment 创建/编辑/删除 + tag 变更 + relation 变更），是 fragments 写入量的 3-5 倍 | 15-50 条 | **唯一需要特别关心的表**。MVP 全量保留；后续触发条件：单表 >500 万行或同步延迟超阈值→启动 server_rev 范围归档 |
| 11 | ai_requests | AI 请求记录（预留） | 🟢 MVP 极低 | MVP 无 AI 调用 | 0 | 无 |

### 5.3 完整 DDL

**表结构定义是项目核心资产。以下 11 张表为权威数据模型，所有代码生成必须以此为准。**

#### users

```sql
CREATE TABLE users (
    id              BIGSERIAL       PRIMARY KEY,
    public_id       UUID            NOT NULL,
    username        VARCHAR(64)     NOT NULL,
    password_hash   VARCHAR(256)    NOT NULL,           -- bcrypt
    nickname        VARCHAR(128)    NOT NULL DEFAULT '',
    avatar_key      VARCHAR(512),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_public_id UNIQUE (public_id)
);
```

#### fragments

```sql
CREATE TYPE fragment_status AS ENUM (
    'twilight',         -- 微光
    'stardust',         -- 星尘
    'echo',             -- 回声
    'seed',             -- 种子
    'tide',             -- 潮汐
    'island_core'       -- 岛屿核心
);

CREATE TABLE fragments (
    id              BIGSERIAL           PRIMARY KEY,
    public_id       UUID                NOT NULL,
    user_id         BIGINT              NOT NULL,
    content_text    TEXT                NOT NULL DEFAULT '',
    emotion         VARCHAR(32),                        -- 情绪值，NULL = 未选
    status          fragment_status     NOT NULL DEFAULT 'twilight',
    is_deleted      BOOLEAN             NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT fk_fragments_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uq_fragments_public_id UNIQUE (public_id)
);

CREATE INDEX idx_fragments_user_created ON fragments (user_id, created_at DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_fragments_user_emotion ON fragments (user_id, emotion) WHERE is_deleted = FALSE AND emotion IS NOT NULL;
CREATE INDEX idx_fragments_user_status  ON fragments (user_id, status) WHERE is_deleted = FALSE;
```

#### tags

```sql
CREATE TABLE tags (
    id              BIGSERIAL       PRIMARY KEY,
    public_id       UUID            NOT NULL,
    user_id         BIGINT          NOT NULL,
    name            VARCHAR(128)    NOT NULL,
    color           VARCHAR(7),                     -- 可选，十六进制色值 #aabbcc
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT fk_tags_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uq_tags_public_id UNIQUE (public_id)
);

CREATE UNIQUE INDEX uq_tags_user_name ON tags (user_id, name) WHERE deleted_at IS NULL;
CREATE INDEX idx_tags_user ON tags (user_id, created_at DESC) WHERE deleted_at IS NULL;
```

#### fragment_tags

```sql
CREATE TABLE fragment_tags (
    fragment_id     BIGINT          NOT NULL,
    tag_id          BIGINT          NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (fragment_id, tag_id),
    CONSTRAINT fk_ft_fragment FOREIGN KEY (fragment_id) REFERENCES fragments(id),
    CONSTRAINT fk_ft_tag      FOREIGN KEY (tag_id)      REFERENCES tags(id)
);

CREATE INDEX idx_ft_tag ON fragment_tags (tag_id);
```

#### media_files

```sql
CREATE TYPE media_type AS ENUM ('image', 'audio');

CREATE TABLE media_files (
    id              BIGSERIAL       PRIMARY KEY,
    public_id       UUID            NOT NULL,
    user_id         BIGINT          NOT NULL,
    fragment_id     BIGINT          NOT NULL,
    media_type      media_type      NOT NULL,
    object_key      VARCHAR(512)    NOT NULL,           -- MinIO/S3 key
    file_name       VARCHAR(512)    NOT NULL,           -- 原始文件名
    file_size       BIGINT          NOT NULL,           -- 字节数
    mime_type       VARCHAR(128)    NOT NULL,           -- image/jpeg, audio/m4a
    width           INT,                                -- 图片宽（像素）
    height          INT,                                -- 图片高（像素）
    duration_ms     INT,                                -- 音频时长（毫秒）
    thumbnail_key   VARCHAR(512),                       -- 缩略图 MinIO key (WebP)
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT fk_media_user     FOREIGN KEY (user_id)     REFERENCES users(id),
    CONSTRAINT fk_media_fragment FOREIGN KEY (fragment_id) REFERENCES fragments(id),
    CONSTRAINT uq_media_public_id UNIQUE (public_id)
);

CREATE INDEX idx_media_fragment ON media_files (fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_user     ON media_files (user_id, created_at DESC) WHERE deleted_at IS NULL;
```

#### relations

```sql
CREATE TYPE relation_type AS ENUM (
    'cause',            -- 起因
    'inspiration',      -- 灵感来源
    'emotion_continue', -- 情绪延续
    'same_phase',       -- 同一阶段
    'reminds_me',       -- 想起了它
    'custom'            -- 自定义
);

CREATE TABLE relations (
    id                  BIGSERIAL       PRIMARY KEY,
    public_id           UUID            NOT NULL,
    user_id             BIGINT          NOT NULL,
    source_fragment_id  BIGINT          NOT NULL,
    target_fragment_id  BIGINT          NOT NULL,
    relation_type       relation_type   NOT NULL,
    custom_label        VARCHAR(128),                   -- relation_type=custom 时使用
    note                TEXT,                           -- 关系说明（可选）
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT fk_relation_user        FOREIGN KEY (user_id)             REFERENCES users(id),
    CONSTRAINT fk_relation_source      FOREIGN KEY (source_fragment_id) REFERENCES fragments(id),
    CONSTRAINT fk_relation_target      FOREIGN KEY (target_fragment_id) REFERENCES fragments(id),
    CONSTRAINT ck_relation_no_self     CHECK (source_fragment_id <> target_fragment_id),
    CONSTRAINT ck_relation_uniq        UNIQUE (source_fragment_id, target_fragment_id, relation_type),
    CONSTRAINT uq_relation_public_id   UNIQUE (public_id)
);

CREATE INDEX idx_relation_source  ON relations (source_fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_relation_target  ON relations (target_fragment_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_relation_user    ON relations (user_id, created_at DESC) WHERE deleted_at IS NULL;
```

#### islands

```sql
CREATE TYPE island_status AS ENUM (
    'star_point',       -- 星点（同标签 3 次）
    'growing',          -- 生长中
    'formed',           -- 小岛已成（5 次以上）
    'dormant',          -- 静默（主题很久未出现）
    'relit'             -- 旧光重亮（静默主题重新出现）
);

CREATE TABLE islands (
    id                  BIGSERIAL       PRIMARY KEY,
    public_id           UUID            NOT NULL,
    user_id             BIGINT          NOT NULL,
    name                VARCHAR(256)    NOT NULL,           -- 岛名（默认用触发标签名）
    description         TEXT,                               -- 用户自定义描述
    cover_fragment_id   BIGINT,                             -- 封面光片
    status              island_status   NOT NULL DEFAULT 'star_point',
    source_tag_id       BIGINT,                             -- 触发生长的标签
    fragment_count      INT             NOT NULL DEFAULT 0, -- 关联光片数（冗余加速）
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    dormant_at          TIMESTAMPTZ,                        -- 进入静默的时间
    relit_at            TIMESTAMPTZ,                        -- 重新点亮的时间
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT fk_island_user     FOREIGN KEY (user_id)           REFERENCES users(id),
    CONSTRAINT fk_island_cover    FOREIGN KEY (cover_fragment_id) REFERENCES fragments(id),
    CONSTRAINT fk_island_tag      FOREIGN KEY (source_tag_id)     REFERENCES tags(id),
    CONSTRAINT uq_island_public_id UNIQUE (public_id)
);

CREATE INDEX idx_island_user        ON islands (user_id, updated_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_island_user_status ON islands (user_id, status) WHERE deleted_at IS NULL;
```

#### island_fragments

```sql
CREATE TABLE island_fragments (
    island_id       BIGINT          NOT NULL,
    fragment_id     BIGINT          NOT NULL,
    added_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (island_id, fragment_id),
    CONSTRAINT fk_if_island   FOREIGN KEY (island_id)   REFERENCES islands(id),
    CONSTRAINT fk_if_fragment FOREIGN KEY (fragment_id) REFERENCES fragments(id)
);

CREATE INDEX idx_if_fragment ON island_fragments (fragment_id);
```

#### refresh_tokens

```sql
CREATE TABLE refresh_tokens (
    id              BIGSERIAL       PRIMARY KEY,
    user_id         BIGINT          NOT NULL,
    token_hash      VARCHAR(256)    NOT NULL,           -- SHA-256(refresh_token)
    device_info     VARCHAR(512),                       -- 设备标识（可选）
    expires_at      TIMESTAMPTZ     NOT NULL,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX uq_refresh_token_hash ON refresh_tokens (token_hash);
CREATE INDEX idx_rt_user ON refresh_tokens (user_id, expires_at DESC) WHERE revoked_at IS NULL;
```

#### oplog

```sql
CREATE TYPE op_type AS ENUM ('INSERT', 'UPDATE', 'DELETE');
CREATE TYPE entity_type AS ENUM ('fragment', 'tag', 'relation', 'island', 'media_file');

CREATE TABLE oplog (
    id                  BIGSERIAL       PRIMARY KEY,
    user_id             BIGINT          NOT NULL,
    server_rev          BIGSERIAL       NOT NULL,           -- 全局自增版本号（同步核心）
    op_type             op_type         NOT NULL,
    entity_type         entity_type     NOT NULL,
    entity_id           BIGINT          NOT NULL,           -- 服务端内部 BIGSERIAL ID
    entity_public_id    UUID,                               -- 客户端 public_id
    payload             JSONB           NOT NULL DEFAULT '{}',
    client_op_id        VARCHAR(64)     NOT NULL,           -- 客户端幂等 ID
    client_seq          INT,                                -- 设备内顺序号
    device_id           VARCHAR(64),                        -- 发起操作的设备标识
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_oplog_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE UNIQUE INDEX uq_oplog_server_rev  ON oplog (server_rev);
CREATE INDEX idx_oplog_user_rev          ON oplog (user_id, server_rev);
CREATE UNIQUE INDEX uq_oplog_client_op_id ON oplog (user_id, client_op_id);
```

#### ai_requests（预留）

```sql
CREATE TYPE ai_mode AS ENUM ('light_name', 'help_weave', 'dont_explain_me');
CREATE TYPE ai_status AS ENUM ('pending', 'processing', 'completed', 'failed');

CREATE TABLE ai_requests (
    id              BIGSERIAL       PRIMARY KEY,
    user_id         BIGINT          NOT NULL,
    mode            ai_mode         NOT NULL,
    fragment_ids    BIGINT[]        NOT NULL,
    input_prompt    TEXT,
    output_raw      TEXT,                               -- AI 原始响应 JSON
    keywords        TEXT[],
    emotion_title   VARCHAR(256),
    summary_text    TEXT,
    suggestion_ids  BIGINT[],
    token_used      INT,
    status          ai_status       NOT NULL DEFAULT 'pending',
    error_message   TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,

    CONSTRAINT fk_ai_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_ai_user_status ON ai_requests (user_id, status, created_at DESC);
```

### 5.4 数据库设计规范

| 规范项 | 决策 | 理由 |
|-------|------|-----|
| 通用字段 | id BIGSERIAL（全部）+ created_at（全部）+ updated_at（需追踪变更的表）+ deleted_at（软删除表） | 基础可追溯性 |
| 同步实体双 ID | id BIGSERIAL（服务端内部） + public_id UUID（客户端生成全局唯一） | 离线优先架构：客户端离线创建时不依赖服务端 ID |
| 主键策略 | BIGSERIAL | 单机部署，顺序写磁盘，索引紧凑 |
| NULL 处理 | 有区分使用：确实"不存在"的用 NULL，"空白"用默认值（如 `content_text NOT NULL DEFAULT ''`） | 语义准确 |
| 枚举字段 | 系统状态机用 PG ENUM（fragment_status / media_type / relation_type / island_status / op_type / entity_type / ai_mode / ai_status） | DB 层强校验 |
| 情绪字段 | VARCHAR(32)，不用 ENUM | 情绪是用户可见内容，可能变化，不应 DB 约束 |
| 数据库外键 | 使用 FOREIGN KEY | 单机场景性能无影响，引用完整性由 DB 保证 |
| 密码存储 | bcrypt 哈希，原始密码不落库 | 安全基线 |
| Token 存储 | SHA-256(token) 哈希存 refresh_tokens，原始 token 不落库 | 防泄露 |
| oplog.payload | 全链路 HTTPS + user_id 隔离 + API 不暴露原始 payload；MVP 不做字段级加密。传输层 HTTPS、存储层 PG 服务端加密、访问层只返回当前用户自己的 oplog | MVP 够用。后续可加 payload 保留策略（如 90 天归档） |
| oplog 清理 | MVP 全量保留；后续触发条件：单表 >500 万行或同步延迟超阈值；清理粒度按 server_rev 范围切；客户端 `since_rev` 不返回已归档区间 | 预留清理能力不提前实现 |
| 字符集 | UTF-8（PostgreSQL 默认），无特殊需求 | — |

**⚠️ fragments 表 is_deleted 与其他表 deleted_at 的不一致**：
- `fragments` 表使用 `is_deleted BOOLEAN NOT NULL DEFAULT FALSE` + `deleted_at TIMESTAMPTZ` 两个字段共存
- 其他软删除表使用 `deleted_at TIMESTAMPTZ`（NULL = 未删除）
- 原因：fragments 表是核心高频查询表，布尔 is_deleted 比 `deleted_at IS NULL` 索引更紧凑，同时保留 deleted_at 记录删除时间
- 索引条件格式：fragments 用 `WHERE is_deleted = FALSE`，其他表用 `WHERE deleted_at IS NULL`
- 后续可考虑统一。MVP 保持现状，不做迁移

### 5.5 索引规范

| 规范 | 决策 |
|-----|------|
| 高频筛选字段 | 所有 `WHERE user_id = ? ORDER BY created_at DESC` 类查询必须建复合索引 |
| 软删除字段进索引 | 是。`WHERE deleted_at IS NULL` 作为部分索引条件（fragments 表暂用 is_deleted 布尔） |
| 组合索引列顺序 | 等值查询列在前，排序/范围列在后。如 `(user_id, created_at DESC)` |
| 多对多双向索引 | 是。`fragment_tags` 和 `island_fragments` 两方向都有索引 |
| 唯一约束在 DB 层 | 强制。所有业务唯一性必须在数据库层有唯一索引/约束，不能只靠代码判断 |
| 大文本字段不建索引 | 禁止。`content_text` 等 TEXT 字段不建普通 B-Tree 索引。如需搜索引入 PG 全文索引或 ES |
| 新增索引原则 | **任何新增索引必须先附查询场景说明**：目标 SQL、WHERE 条件、ORDER BY、预期数据量级、收益量化。无场景不建索引 |

### 5.6 分页规范

| 场景 | 分页方式 | 请求格式 | 默认 limit | 最大 limit |
|-----|---------|---------|-----------|-----------|
| 时间河流 | 游标 | `GET /timeline?cursor=&limit=` | 20 | 50 |
| 标签筛选光片 | 游标 | `GET /fragments?tag_id=&cursor=&limit=` | 20 | 50 |
| 织线选光片 | 游标 | `GET /fragments?q=&cursor=&limit=` | 30 | 50 |
| island 光片 | 游标 | `GET /islands/{id}/fragments?cursor=&limit=` | 20 | 50 |
| oplog 同步 | since_rev | `GET /sync/pull?since_rev=&limit=` | 100 | 500 |
| 标签列表 | 传统 | `GET /tags?page=&page_size=` | 20 | 100 |
| island 列表 | 传统 | `GET /islands?page=&page_size=` | 10 | 50 |
| AI 请求历史 | 传统 | `GET /ai/requests?page=&page_size=` | 20 | 50 |

**游标格式**：`base64(json{sort_field_values, version, filter_hash}) + "." + HMAC`
- 排序字段绑定——不同排序用不同 cursor 编码
- filter_hash 防条件篡改——换筛选条件后旧 cursor 失效
- version 留升级空间
- 客户端不解析 cursor，只透传

**传统分页**：page 从 1 开始，page_size 不允许超过最大值。MAX_OFFSET 额外限制 10000 条。

**COUNT 策略**：游标分页不查 total——只返回 `has_more: bool`。传统分页在第一页返回 total，翻页时客户端传回。

**sync 特殊协议**：`next_since_rev` 替代 cursor。返回值为本批次最大 server_rev，客户端下次请求用 `since_rev = next_since_rev + 1`。

### 5.7 特殊存储规范

**MinIO / S3 对象存储**

| 规范项 | 决策 |
|-------|------|
| 上传方式 | Presigned URL 直传，Go 只签发凭证+鉴权+写元数据，不做大文件中转 |
| Object Key | `users/{user_public_id}/media/{yyyy}/{mm}/{media_id}.{ext}` |
| 缩略图 | 图片上传完成后异步生成 WebP；MVP 做图片缩略图，不做录音波形图 |
| Presigned URL 有效期 | 上传 5min，下载 5min |
| 大小限制 | 图片 10MB，录音 50MB |
| 格式白名单 | 图片：JPEG / PNG / HEIC / WebP · 录音：M4A / AAC / MP3 / WAV |
| 临时文件清理 | 超 24h 未 confirm 的上传任务自动清理 |
| 访问控制 | 下载走 presigned URL 或 Nginx 代理（扩展音频），不直接暴露 MinIO 端口 |

**Redis 缓存**

| 规范项 | 决策 |
|-------|------|
| 缓存内容 | 情绪密度统计、高频词统计、会话辅助、限流计数、AI 额度短期计数 |
| **不缓存** | 笔记正文（光片内容）、同步状态、refresh token 原文、关键业务状态 |
| Key 命名 | `app:{env}:{domain}:{name}:{scope}`（如 `app:prod:stats:emotion_density:user_42:7d`） |
| TTL | 统计类 1h · 会话辅助 15min · 限流按窗口期 · AI 日额度到当天结束 |
| 失效策略 | 写操作主动删除相关统计 key + TTL 兜底 |
| 内存策略 | maxmemory 256MB · maxmemory-policy allkeys-lru |

**为什么这些不缓存**：
- 笔记正文：私人数据每个用户只看到自己的，天然不聚集，数据库索引优化比缓存更有效
- 同步状态：需要实时准确，缓存导致不一致
- refresh token 原文：安全敏感，只存哈希
- 关键业务状态：需要事务一致性

**OpLog 同步协议 — 完整规则**

| 规范项 | 决策 |
|-------|------|
| 幂等 | `client_op_id` · UNIQUE(user_id, client_op_id) · 重复 push 返回已有 server_rev 不重复执行 |
| 新增类操作 | entity_id 不存在则创建；重复 client_op_id 幂等返回已存在的 entity |
| 标签/媒体/关联 | 尽量自动合并——这些是辅助数据，不需要像 fragment 正文一样严格冲突检测 |
| Fragment 更新 | `base_server_version == 当前 server_rev` → 接受更新 · `base_server_version < 当前 server_rev` → 返回 conflict，不静默覆盖 |
| 删除操作 | 允许删除旧版本（base_server_version 落后），但保留 tombstone（deleted_at 标记）· 本地编辑与远端删除冲突 → 返回 conflict |
| MVP 冲突处理 | 客户端收到 conflict 后，本地生成一份"冲突副本"（原始内容保留，冲突版本另存为新光片草案），用户手动选择 |
| Push 批次 | 默认 50，最大 100 |
| Pull 批次 | 默认 100，最大 500 |
| 设备内顺序 | client_seq（设备内自增整数）保证设备内操作顺序 |
| 服务端全局顺序 | server_rev（BIGSERIAL 全局自增）保证跨设备合并后的全局顺序 |
| Pull 协议 | `since_rev` 增量拉取 · 按 server_rev ASC 返回 · next_since_rev 替代 cursor · 预留 full_sync_required 标记（当 since_rev 落入已归档区间时） |
| 同步触发 | 后台自动同步（用户可设置时限：实时/每5分钟/每小时/仅WiFi/手动）。手动触发入口：设置页"立即同步"按钮 |

### 5.8 岛屿生长引擎 — 完整规则

岛的生长由 `island/rules/engine.go` 实现，规则如下：

| 触发条件 | 状态变化 | 说明 |
|---------|---------|------|
| 同一标签出现第 3 次 | `null` → `star_point` | 生成主题星点 |
| 同一标签出现第 3-4 次之间 | `star_point` → `growing` | 生长中 |
| 同一标签出现第 5 次及以上 | `growing` → `formed` | 小岛成形 |
| 某主题连续 30 天无新光片 | `formed` → `dormant` | 进入静默状态（`dormant_at` 记录时间） |
| 静默主题重新出现新光片 | `dormant` → `relit` | 旧光被重新点亮（`relit_at` 记录时间） |
| 重亮后持续有新光片 | `relit` → `formed` | 恢复成形 |

`fragment_count` 是一个冗余字段，每次有新光片加入岛时递增，避免每次查询都要
COUNT island_fragments。

**岛屿的生长检测时机**：在光片创建、标签关联变更、标签新增时触发。不设定时任
务——事件驱动，保证实时性。

### 5.9 Nginx 配置要点

```
# nginx.conf 核心配置摘要
server {
    listen 443 ssl;
    client_max_body_size 11m;     # 图片最大 10MB + 余量
    proxy_request_buffering off;  # 关闭请求缓冲（流式上传不适用，但 presigned 直传不经过此）
    proxy_buffering off;          # ⚠️ 关键：关闭响应缓冲，否则 SSE/流式响应失效
                                  # 未来柔光整理等 AI 流式场景需要此配置
    
    # API 转发
    location /api/ {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;  # 预留长连接（AI 调用可能超 30s）
    }
    
    # 扩展音频直接 serve（从 MinIO 拉取或本地静态文件）
    location /media/audio/ {
        proxy_pass http://minio:9000/whitenoise/;
        proxy_set_header Host $host;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## 六、接口规范

### 6.1 URL 风格

- RESTful + 动词子资源。`/api/v1` 版本前缀
- URL path 使用 `kebab-case`
- 资源名统一复数名词
- Query 参数、JSON 字段、数据库字段使用 `snake_case`
- 非 CRUD 操作用动词子资源附加在资源路径后

**完整路由表：**

| 方法 | 路径 | 用途 | 模块 |
|-----|------|------|------|
| POST | `/api/v1/auth/register` | 注册 | auth |
| POST | `/api/v1/auth/login` | 登录 | auth |
| POST | `/api/v1/auth/refresh` | 刷新 token | auth |
| GET | `/api/v1/users/me` | 获取当前用户信息 | auth |
| PUT | `/api/v1/users/me` | 更新当前用户信息 | auth |
| GET | `/api/v1/fragments` | 光片列表（游标分页） | fragment |
| POST | `/api/v1/fragments` | 创建光片 | fragment |
| GET | `/api/v1/fragments/{id}` | 光片详情 | fragment |
| PUT | `/api/v1/fragments/{id}` | 编辑光片 | fragment |
| DELETE | `/api/v1/fragments/{id}` | 软删除光片 | fragment |
| POST | `/api/v1/fragments/{id}/weave` | 从光片发起织线 | relation |
| GET | `/api/v1/tags` | 标签列表（传统分页） | tag |
| POST | `/api/v1/tags` | 创建标签 | tag |
| PUT | `/api/v1/tags/{id}` | 编辑标签 | tag |
| DELETE | `/api/v1/tags/{id}` | 删除标签 | tag |
| GET | `/api/v1/emotions` | 情绪列表 | emotion |
| POST | `/api/v1/media/presign-upload` | 签发上传凭证 | media |
| POST | `/api/v1/media/confirm-upload` | 确认上传完成 | media |
| GET | `/api/v1/media/{id}` | 获取媒体元数据 | media |
| DELETE | `/api/v1/media/{id}` | 删除媒体 | media |
| GET | `/api/v1/timeline` | 时间河流（游标分页） | timeline |
| GET | `/api/v1/stats/emotion-density` | 情绪密度统计 | stats |
| GET | `/api/v1/stats/freq-words` | 高频词统计 | stats |
| POST | `/api/v1/relations` | 创建织线 | relation |
| DELETE | `/api/v1/relations/{id}` | 删除织线 | relation |
| GET | `/api/v1/starmap` | 获取个人星图 | starmap |
| GET | `/api/v1/islands` | 岛列表（传统分页） | island |
| POST | `/api/v1/islands` | 创建岛 | island |
| PUT | `/api/v1/islands/{id}` | 编辑岛 | island |
| GET | `/api/v1/islands/{id}` | 岛详情 | island |
| GET | `/api/v1/islands/{id}/fragments` | 岛内光片列表（游标） | island |
| DELETE | `/api/v1/islands/{id}` | 删除岛 | island |
| GET | `/api/v1/space/config` | 获取空间配置 | space |
| PUT | `/api/v1/space/config` | 更新空间配置 | space |
| GET | `/api/v1/whitenoise` | 白噪音列表 | whitenoise |
| POST | `/api/v1/sync/push` | 推送本地变更 | sync |
| GET | `/api/v1/sync/pull` | 拉取远程变更 | sync |
| POST | `/api/v1/ai/glow-summary` | 柔光整理（预留） | ai |
| GET | `/api/v1/ai/requests` | AI 请求历史（传统分页，预留） | ai |
| GET | `/healthz` | 健康检查（不走 /api/v1） | infra |

### 6.2 统一响应结构 — Go 类型定义

```go
// shared/response.go
type ApiResponse[T any] struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Data    T      `json:"data"`
}

// shared/pagination.go
type CursorQuery struct {
    Cursor string `json:"cursor"` // 客户端透传，不解析
    Limit  int    `json:"limit"`  // 默认 20，最大 50
}

type CursorPage[T any] struct {
    Items      []T    `json:"items"`
    NextCursor string `json:"next_cursor,omitempty"` // 无下一页时 omit
    HasMore    bool   `json:"has_more"`
}

type PageQuery struct {
    Page     int `json:"page"`      // 从 1 开始
    PageSize int `json:"page_size"` // 默认 20
}

type Page[T any] struct {
    Items      []T   `json:"items"`
    Page       int   `json:"page"`
    PageSize   int   `json:"page_size"`
    Total      int64 `json:"total"`
    TotalPages int   `json:"total_pages"`
}

// 同步专用响应（不走 CursorPage/Page）
type SyncPullResponse struct {
    Operations        []OpLogDTO `json:"operations"`
    NextSinceRev      int64      `json:"next_since_rev"`
    HasMore           bool       `json:"has_more"`
    FullSyncRequired  bool       `json:"full_sync_required"`
}

type SyncPushRequest struct {
    Operations []OpLogEntry `json:"operations"`
    DeviceID   string       `json:"device_id"`
}

type OpLogEntry struct {
    ClientOpID         string          `json:"client_op_id"`
    EntityType         string          `json:"entity_type"`
    OpType             string          `json:"op_type"`
    EntityPublicID     string          `json:"entity_public_id"`
    Payload            json.RawMessage `json:"payload"`
    BaseServerVersion  int64           `json:"base_server_version"`
    ClientSeq          int             `json:"client_seq"`
}

type SyncPushResult struct {
    ClientOpID string `json:"client_op_id"`
    Status     string `json:"status"`    // "applied" | "conflict" | "skipped"
    ServerRev  int64  `json:"server_rev,omitempty"`
    Conflict   *ConflictInfo `json:"conflict,omitempty"`
}

type ConflictInfo struct {
    CurrentVersion  json.RawMessage `json:"current_version"`
    IncomingVersion json.RawMessage `json:"incoming_version"`
    Reason          string          `json:"reason"`
}
```

### 6.3 分页响应格式

**游标分页 — `CursorPage[T]`：**

```json
{
  "code": "success",
  "message": "ok",
  "data": {
    "items": [...],
    "next_cursor": "xxx.yyy",
    "has_more": true
  }
}
```

**传统分页 — `Page[T]`：**

```json
{
  "code": "success",
  "message": "ok",
  "data": {
    "items": [...],
    "page": 1,
    "page_size": 20,
    "total": 143,
    "total_pages": 8
  }
}
```

**sync 特殊**：`SyncPullResponse` 返回 `next_since_rev`，不使用 cursor 或 page。

### 6.4 空值返回约定

| 情况 | 返回 |
|-----|------|
| 列表为空（items 为 []） | `"items": []` 空数组，不返回 null |
| 字符串字段为空 | `""` 空字符串，除非字段语义是"未设置"则用 `null` |
| JSON 字段 | 默认不 `omitempty`，避免 Flutter 端解析结构不稳定 |
| 单对象不存在（GET by id） | HTTP 404，`code: "module.not_found"`，不走 HTTP 200 + null |

### 6.5 错误码规范

采用 **`模块.语义_描述` 小写点号风格**：

| code | 含义 |
|------|-----|
| `success` | 成功 |
| `auth.unauthorized` | 未认证 |
| `auth.token_expired` | Token 过期 |
| `auth.invalid_credentials` | 用户名或密码错误 |
| `auth.username_taken` | 用户名已占用 |
| `fragment.not_found` | 光片不存在 |
| `fragment.access_denied` | 无权访问该光片 |
| `media.upload_too_large` | 文件超过大小限制 |
| `media.unsupported_format` | 不支持的格式 |
| `media.presign_failed` | 上传凭证签发失败 |
| `media.not_found` | 媒体文件不存在 |
| `relation.not_found` | 关联不存在 |
| `relation.invalid_type` | 无效的关系类型 |
| `relation.self_link` | 不能关联自己 |
| `relation.already_exists` | 关联已存在 |
| `island.not_found` | 岛不存在 |
| `sync.conflict` | 同步冲突 |
| `sync.invalid_rev` | 无效的版本号 |
| `sync.full_sync_required` | 需要全量同步 |
| `validation.invalid_param` | 参数校验失败 |
| `validation.missing_field` | 必填字段缺失 |
| `common.internal_error` | 服务器内部错误 |
| `common.rate_limited` | 请求过于频繁 |
| `common.service_unavailable` | 服务暂时不可用 |

**不使用裸 `not_found`、`error` 等太泛的码。**

### 6.6 AI 行为边界指令

以下规则约束 AI（Claude Code 等工具）在此项目中写代码时的行为。优先级高于模型默认习惯。

**一、禁止事项（绝对不能做的事）**

- 不擅自扩大需求边界——不添加需求里没有的功能模块，不"觉得用户可能需要就自动加上"
- 不私自重构架构——不改模块划分、不改依赖方向、不改分层结构
- 不引入未批准的第三方依赖——任何新库/新包必须先说明理由，等确认后引入
- 不绕过已定规范——URL 风格、响应结构、错误码格式、数据库命名、索引规则一律遵守
- 不自创接口格式——不用 CLAUDE.md 未约定的 API 模式
- 不擅自改数据库字段——不增、删、改列，不调整索引，不改变约束。所有 DDL 变更必须走 migration
- 不擅自改同步协议——OpLog 格式、冲突策略、push/pull 语义不可动
- 不"顺手优化"无关模块——让它改 A，不能顺便动 B、C、D
- 不在大文本字段上建普通索引
- 不在代码层做唯一性校验而不加数据库唯一约束——并发场景下代码判断存在竞态
- 不做过度抽象——简单 CRUD 就写三层（handler → service → repository），不引入策略模式、工厂模式等，除非用户明确说需要可扩展的
- 不硬编码配置——所有连接信息、超时时间、开关标志等必须走配置文件/环境变量

**二、主动做的事**

- 发现潜在风险主动提醒：安全、性能、数据一致性、迁移风险、边界条件
- 改动前先说明影响范围：涉及哪些模块、哪些 API、是否需要数据迁移
- 遇到规范冲突时停下来：指出冲突点，列举两个规范的原始决策和各自理由，不自行裁决
- 所有外部调用必须设置超时

**三、自主权分级**

| 级别 | 范围 | 规则 |
|-----|------|------|
| 🟢 可直接执行 | 普通 CRUD、样式小修、测试补全、文档更新、日志补充 | 严格遵守已有规范，不需逐次确认 |
| 🔴 必须先说明后确认 | 数据库 migration、同步协议、认证鉴权、支付/额度、对象存储操作、AI 调用、路由规范、公共响应结构（ApiResponse/CursorPage/Page 等） | 先说明改动范围+影响面+方案，等用户确认后再动手 |

**四、修改已有代码时**

- 先理解相关模块的设计意图再动手，不盲目改
- 不要为了新功能破坏已有接口契约。如需改接口参数结构，先问用户
- 改完确保已有功能不受影响——检查现有测试是否通过
- 不顺手修改无关模块
- 改动前先说明影响范围

**五、不确定时**

- 架构选择：给出 2-3 个方案对比，优缺点说清楚，由用户拍板。不直接给推荐结论
- 规范没覆盖的情况：不要自创规则，先问用户怎么处理，然后用户决定是否把新规则补充到 CLAUDE.md
- 遇到可能影响架构边界的改动：先说明影响范围，等用户确认后再动手

**六、AI 产品层面约束（隙光专属）**

- AI 功能必须由用户主动触发——不能后台自动拉取、推送或预分析
- AI 只提供候选建议（采纳/改一改/忽略），不替用户做最终判断
- AI 交互语气必须克制、不侵入：如"这几束光似乎有一点相似""要不要把它们织在一起？"
- AI 不诊断、不评判、不替用户解释人生
- AI 输出保留模糊性，不强行分析
- AI 不以"智能助手""心理分析"等命名出现，系统内叫"星图管理员"
- AI 不强绑定产品——产品离开 AI 也能正常使用。所有 AI 接入点预留可关闭路径

### 6.7 Flutter 路由树

```dart
// app/router.dart — GoRouter + StatefulShellRoute.indexedStack
//
// 四个底部 Tab 保持页面状态不销毁，用户切换不丢滚动位置/输入状态

GoRouter(
  initialLocation: '/capture',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell),
      branches: [
        // Tab 1: 捕光
        StatefulShellBranch(routes: [
          GoRoute('/capture', builder: (_, __) => CapturePage()),
          GoRoute('/fragments/:id', builder: (_, state) => FragmentDetailPage(id: state.pathParameters['id']!)),
          GoRoute('/fragments/:id/edit', builder: (_, state) => FragmentEditPage(id: state.pathParameters['id']!)),
        ]),
        // Tab 2: 时间河
        StatefulShellBranch(routes: [
          GoRoute('/timeline', builder: (_, __) => TimeRiverPage()),
        ]),
        // Tab 3: 织线（星图为主）
        StatefulShellBranch(routes: [
          GoRoute('/weave', builder: (_, __) => StarmapPage()),
          GoRoute('/weave/select', builder: (_, __) => RelationSelectPage()),  // 选目标光片
        ]),
        // Tab 4: 小宇宙
        StatefulShellBranch(routes: [
          GoRoute('/universe', builder: (_, __) => UniversePage()),
          GoRoute('/islands/:id', builder: (_, state) => IslandDetailPage(id: state.pathParameters['id']!)),
        ]),
      ],
    ),
    // 非 Tab 页面（全屏）
    GoRoute('/space', builder: (_, __) => SpacePage()),          // 沉浸式空间
    GoRoute('/settings', builder: (_, __) => SettingsPage()),     // 设置
    GoRoute('/whitenoise', builder: (_, __) => WhiteNoisePage()), // 白噪音管理
    GoRoute('/glow-organize', builder: (_, __) => GlowOrganizePage()), // 柔光整理（预留）
  ],
);
```

### 6.8 FragmentStatus 计算规则

光片状态由 Go 端 `fragment/service/status.go` 计算，不在 DDL 中写死：

| 状态 | 计算条件 |
|-----|---------|
| `twilight`（微光） | 默认初始状态。新创建的 fragment |
| `stardust`（星尘） | fragment 被至少 1 条织线关联（作为 source 或 target） |
| `echo`（回声） | fragment 创建超过 7 天，且在过去 7 天内被用户重新浏览/编辑过 |
| `seed`（种子） | fragment 所属的 tag 出现了第 3 次（触发 island `star_point` 生长），该岛所有的 fragment 标记为 seed |
| `tide`（潮汐） | fragment 的 emotion 与用户过去 7 天主要情绪不一致（情绪偏离） |
| `island_core`（岛屿核心） | fragment 所属 island 达到 `formed` 状态 |

状态转换在以下时机触发：
- 创建 fragment → `twilight`
- 织线创建/删除 → 重算 source 和 target 的 status
- 用户浏览 fragment 详情 → 记录访问时间，定时任务每日批量重算 echo
- 标签出现次数变化 → 触发 island 生长检测 → 关联 fragment 状态级联更新
- stats 情绪密度变化 → 检测潮汐 fragment

### 6.9 标签与光片的业务逻辑

- 标签是用户级别的资源（同一用户下不重复），不是全系统共享的
- 创建光片时可以带已有标签名（按名称匹配）或新建标签
- 标签名称唯一约束包含 `WHERE deleted_at IS NULL`，意味着软删除后可重建同名标签
- 标签删除时：`fragment_tags` 关联行保留（不做级联删除），历史关联可查询。但通过已删除标签筛选光片时返回空（因为 tag.deleted_at IS NOT NULL，不在标签列表中显示）
- 标签频率统计只计算 `WHERE deleted_at IS NULL` 的标签

### 6.10 Cursor 生成算法

```
// Go: shared/cursor.go
type CursorPayload struct {
    SortFields  map[string]interface{} `json:"sf"`  // {"created_at": "2024-...", "id": 42}
    FilterHash  string                 `json:"fh"`  // SHA-256(query params 序列化)
    Version     int                    `json:"v"`   // cursor 格式版本号（初始=1）
}

// EncodeCursor: payload → JSON → base64 → "." → HMAC-SHA256(base64, secret)
// 客户端拿到的是 "eyJzZiI6....abc123def456"
// 客户端不解包，只透传
//
// DecodeCursor: 拆 "." → 验 HMAC → 解 base64 → JSON unmarshal → 验 filter_hash
// filter_hash 不匹配 → 返回 validation.invalid_cursor
```

**Cursor 使用约束**：
- 不同排序字段产生的 cursor 不可混用（sort_fields 编码了排序键和值）
- 更换筛选条件后旧 cursor 失效（filter_hash 校验不通过）
- version 字段预留格式升级——若 cursor 格式变更，递增 version，旧版 cursor 校验失败后客户端重新请求第一页
- HMAC 密钥为服务端配置常量，所有 cursor 共享同一密钥

### 6.11 Media Presigned URL 签发流程（Go 端）

```
// media/storage/uploader.go

PresignUpload(ctx, userID, fragmentID, fileName, contentType, fileSize) → PresignResult
  1. 校验: userID 是否拥有 fragmentID 所指的光片
  2. 校验: contentType 是否在白名单 (JPEG/PNG/HEIC/WebP 或 M4A/AAC/MP3/WAV)
  3. 校验: fileSize ≤ maxSize (图片 10MB / 录音 50MB)
  4. 生成 objectKey: users/{user_public_id}/media/{yyyy}/{mm}/{media_id}.{ext}
  5. 调 infra/storage.StorageProvider.PresignedPutObject(objectKey, 5min TTL)
  6. 返回 { upload_url, object_key, expires_at }

ConfirmUpload(ctx, userID, fragmentID, objectKey) → MediaFileDTO
  1. 校验权限
  2. 调 MinIO StatObject 确认文件存在 + 获取实际 size/contentType
  3. INSERT media_files (id=UUID, user_id, fragment_id, media_type, object_key, file_name, file_size, mime_type, width/height/duration_ms)
  4. UPDATE fragments SET media_urls = array_append(media_urls, objectKey)
  5. 异步: go processor.GenerateThumbnail(objectKey) → PUT {objectKey}_thumb.webp → UPDATE media_files SET thumbnail_key
  6. 返回 MediaFileDTO
```

### 6.12 星图构建算法（Go 端）

```
// starmap/graph/builder.go

BuildFullGraph(userID) → StarGraph
  1. 查该用户所有 relation (is_deleted=FALSE)
  2. 节点: 每个被关联的 fragment → StarNode{id, label(截取前20字), status, status_color, emotion}
  3. 边: 每个 relation → StarEdge{source, target, relation_type, curve(二次贝塞尔)}
  4. 布局: layout.go → 力导向布局 (Force-Directed)
     - 节点间斥力 ∝ 1/distance²
     - 边提供引力 (胡克定律)
     - 迭代 100 轮或总位移 < 阈值
     - 最终坐标归一化到 [0,1] 范围
  5. 返回 StarGraph{nodes[], edges[]}

GetSubGraph(userID, rootFragmentID, depth) → StarGraph
  1. BFS 从 rootFragmentID 出发，沿 relation 双向扩展 depth 步
  2. 收集范围内的 fragment 和 relation
  3. 同 BuildFullGraph 的节点和边构建
  4. 布局: 环形布局(同心圆，root 在中心，depth 递增向外)
```

### 6.13 JWT 认证中间件与鉴权流程

```
Go: auth/middleware/jwt.go

1. 从 Authorization: Bearer <access_token> 提取 token
2. HMAC-SHA256 验签 (密钥: JWT_SECRET 环境变量)
3. 解析 claims: { user_id, token_type: "access", exp, iat }
4. 注入 context: ctx = context.WithValue(ctx, "user_id", claims.UserID)
5. 后续 handler 从 ctx 取 user_id，用于所有 user_id 过滤

Token 对:
- Access Token: 15min 有效期，承载认证
- Refresh Token: 30天 有效期，仅用于换取新 Access Token
- Refresh 接口: 验 refresh token 哈希 → 检查是否 revoked → 检查是否过期 → 签发新 token pair → 旧 refresh token 标记 revoked

Go: auth/service/auth.go
- Register(username, password, nickname) → bcrypt(password) → INSERT users → 返回 TokenPair
- Login(username, password) → 查用户 → bcrypt.Compare → 签发 TokenPair
- RefreshToken(rawRefreshToken) → SHA-256(raw) → 查 refresh_tokens → 验有效性 → 新 TokenPair
- ChangePassword(userID, oldPW, newPW) → 验旧密码 → bcrypt(newPW) → UPDATE

Flutter: auth interceptor (dio)
- 请求前: 从 flutter_secure_storage 读 access_token → 注入 Authorization header
- 收到 401: 用 refresh_token 调 /auth/refresh → 更新存储 → 重试原请求
- refresh 也失败: 清除 token → 跳转登录页
```

### 6.14 已解决的核心矛盾

以下矛盾在设计过程中被识别并解决：

1. **"快速捕捉" vs 情绪标签选择** → 情绪可选、可跳过，默认"说不清"。微光情绪选择器只在保存前弹出柔和色点，轻点即选，不强制停留
2. **"不用解释自己" vs 结构化元数据** → AI 只给候选建议（采纳/改一改/忽略），用户保有解释权。标签/情绪/关系类型都是帮用户自己整理的，不是向他人解释
3. **"自由放置" vs MVP 只有时间线** → "自由放置"是中长期功能（沉浸式空间做），MVP 时间河流是被动接收而非主动摆放，描述准确
4. **"多模态"宣传 vs MVP 仅文字+图片+录音** → 产品定位写"多媒体"但功能表明确标注"不做涂鸦和短视频"。MVP 和内测版不对外宣称"全模态"
5. **AI 柔光整理在一句话定义中 vs MVP 不做** → 定义描述完整产品形态，MVP 是当前交付范围。两者不矛盾，AI 按钮预留即可
6. **光片状态在产品机制中 vs 数据结构缺失** → 已补 `fragment_status` ENUM 和 `fragment/service/status.go` 计算规则，状态由事件驱动而非用户手动设置

### 6.15 SDD（规范驱动开发）闭环

```
AI 跑偏了
  ↓
分析是不是规范没覆盖
  ↓
补充 CLAUDE.md 里的对应规范
  ↓
下次 AI 就少犯同类错误
```

CLAUDE.md 不需要一开始就完美。一开始覆盖核心规范即可。后续每次 AI 跑偏，都问自己"是不是该补一条规范"，然后加到 CLAUDE.md 里。

---

## 七、非功能要求

- App 冷启动尽量控制在 3 秒以内
- 时间线首屏加载不超过 2 秒
- 用户内容默认仅自己可见
- AI 功能必须由用户主动触发
- 产品不提供公开发布、点赞、评论、排名等社交压力机制
- 视觉风格保持低饱和、大留白、柔和动效和私人空间气质
- 基础操作不反常识：输入、保存、浏览、编辑、删除沿用用户熟悉的移动端交互
- 情绪体验优先于效率体验：页面不追求信息密度
- 借鉴交互逻辑，不照搬产品目标

---

## 八、交互设计核心模块

### 捕光页

- 顶部今日提示："今天有什么光落下来吗？"
- 中部大面积输入框："把这一刻轻轻放在这里。"
- 底部快捷入口：图片 / 情绪 / 标签
- 主按钮："捕光"
- 保存成功反馈："这一束光，已经落进你的宇宙。"

### 时间河流页

- 顶部：今日日期 + 当日情绪色点
- 日期分组：今天 / 昨天 / 五月某日
- 光片卡片：文字摘要 + 图片缩略图 + 情绪标签 + 光片状态
- 底部浮动按钮：捕光

### 微光情绪选择器

- 保存光片前出现一排柔和色点
- 每个色点对应一个情绪词：平静/开心/疲惫/焦虑/失落/被击中/混乱/说不清
- 用户轻点选择，长按可看简短解释
- 默认"说不清"
- 文案："不一定要说清楚，选一个靠近的感觉就好。"

### 织线页

- 入口：光片详情页底部按钮"和另一束光织在一起"
- 流程：选目标光片 → 选关系类型 → 可选关系说明 → "织好这条线"
- 完成提示："这两束光之间，有了一条细细的线。"
- 关系类型：回声/伏笔/余震/平行宇宙/小小救命/潮汐/旧光/自定义

### 小宇宙页

- 模块：今日微光 / 最近反复出现的主题 / 主题星点区 / 已形成的小岛 / 最近一次柔光整理
- 主题生长规则：同标签 3 次 → 星点 · 5 次 → 小岛 · 静默 → 旧光重亮
- 第一版不做 3D、不做自由拖拽、不做复杂图谱
- 可做概念 IP 图画（美工），简约元素，点线面结合

### 柔光整理页（预留）

- 入口：多选光片后点击"柔光整理" / 小宇宙页"让柔光帮我看一看"
- AI 输出：关键词 / 情绪命名 / 柔光回顾 / 可选织线建议
- 三种模式：轻轻命名 / 帮我织线 / 不解释我
- 按钮：保存为星图注释 / 改一个名字 / 不保存
- MVP 不做实现，预留按钮和 UI 入口

---

## 九、监控与可观测性（MVP 最小组合）

| 组件 | 方案 | 说明 |
|-----|------|------|
| Go 后端日志 | slog/zap 结构化日志 | 标准输出 |
| 错误告警 | Sentry (Go + Flutter) | 崩溃/异常主动上报 |
| 健康检查 | `/healthz` | Docker healthcheck + UptimeRobot 探活 |
| 数据库监控 | PostgreSQL slow query log | 慢查询定位 |
| 关键业务表 | ai_requests 表（预留） | AI 调用追踪 |

这套覆盖 MVP 80% 早期问题。Loki 日志聚合、Prometheus + Grafana 放后期。

---

## 十、待决策事项（远期）

以下条目在阶段讨论中标注为"后期"或"待定"，不在 MVP 范围：

- AI 柔光建议卡（上传图片后自动推荐标签）
- AI 推荐"那一刻的光"
- 柔光整理（三种 AI 模式）
- AI 隐性关联发现
- 桌面小组件、快捷指令
- 涂鸦、短视频多模态输入
- 隐私设置、AI 开关
- 数据导出与备份
- 全文搜索
- 通知与推送策略
- 商业/付费模式
- 国际化 (i18n)
- 无障碍设计 (Accessibility)
- oplog 自动归档清理机制
- PG 主从复制
- MinIO 多节点纠删码
- 消息队列削峰
- CDN
- K8s / 服务网格
