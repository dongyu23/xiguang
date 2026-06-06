# 手动岛屿管理 + AI 辅助构建岛屿

**日期**: 2026-06-06
**状态**: 已确认

---

## 一、概述

在现有屿功能基础上新增两个能力：

1. **手动岛屿管理**：用户可以自由选择任意光片添加到岛屿中（不限于同标签），岛屿可以"慢慢生长"
2. **AI 辅助构建岛屿**：在我的页触发 AI，分析所有光片，建议岛屿分组，用户确认后创建

---

## 二、后端：新增接口

### 2.1 手动岛屿管理端点

| 方法 | 路径 | 用途 | 请求体 |
|------|------|------|--------|
| POST | `/api/v1/islands/{id}/fragments` | 添加光片 | `{"fragment_ids": [1,2,3]}` |
| DELETE | `/api/v1/islands/{id}/fragments` | 移除光片 | `{"fragment_ids": [1]}` |

**约束**：
- 仅对 `source_tag_id IS NULL` 的手动岛屿开放
- 自动生长的岛屿（有 source_tag_id）光片由标签自动管理，不允许手动增删
- 每次增删后更新 `fragment_count`，用 `rules.StatusForFragmentCount(newCount)` 重算 status（手动岛屿不参与 dormant/relit 生命周期，因为没有标签驱动的事件流）

### 2.2 AI 构建岛屿端点

| 方法 | 路径 | 用途 |
|------|------|------|
| POST | `/api/v1/ai/build-islands` | AI 分析光片，返回候选岛屿（不自动创建） |

**流程**：
1. 拉取当前用户所有未删除光片（content_text, tags, emotion, id）
2. 组装 prompt → DeepSeek `deepseek-v4-flash`，`response_format: json_object`
3. 解析响应 → `{islands: [{name, description, fragment_ids, confidence}]}`
4. 返回前端展示，**不自动创建**——等用户确认
5. 用户确认后，前端分别调 `POST /islands` + `POST /islands/{id}/fragments` 批量创建

**限流**：每日每用户最多 3 次（AI 构建消耗 token 较多）

### 2.3 DeepSeek Provider 实现

当前 `provider/deepseek.go` 的 `Chat()` 只返回 `ErrNotConfigured`。需要实现真正的 HTTP 调用：

```
POST https://api.deepseek.com/v1/chat/completions
Authorization: Bearer {AI_DEEPSEEK_API_KEY}
Content-Type: application/json
{
  "model": "deepseek-v4-flash",
  "messages": [
    {"role": "system", "content": "<system prompt>"},
    {"role": "user", "content": "<fragment data JSON>"}
  ],
  "temperature": 0.7,
  "max_tokens": 4096,
  "response_format": {"type": "json_object"}
}
```

**配置**：
- API Key: 环境变量 `AI_DEEPSEEK_API_KEY`
- Base URL: 环境变量 `AI_DEEPSEEK_BASE_URL`（默认 `https://api.deepseek.com/v1`）
- Model: 环境变量 `AI_DEEPSEEK_MODEL`（默认 `deepseek-v4-flash`）
- Timeout: 60s

---

## 三、AI Prompt 设计

### System Prompt

```
你是隙光 App 的星图管理员。用户记录了许多"光片"（包含文字内容、情绪和标签的碎片记录）。

你的任务：分析用户的所有光片，发现它们之间隐秘的联系，将属于同一主题或情感脉络的光片分组为"小岛"。

规则：
- 每组建议一个岛名：温柔、诗意的中文名，2-6个字，像一首小诗的题目
- 每组一段描述（10-30字）：为什么这些光片属于一起，用温柔克制的语气
- 一束光片可以属于多个岛
- 只返回有意义的分组（每组至少2束光片），不要强行分组
- 最多返回5组
- 如果光片太少（少于3束），诚实地说"光还不够多"
- 语气：不说"你应该""这是"，说"似乎""好像""要不要"

严格按以下 JSON 格式返回：
{
  "islands": [
    {
      "name": "岛名",
      "description": "简短描述",
      "fragment_ids": [1, 5, 12],
      "confidence": "high|medium|low"
    }
  ]
}
```

### User Message

传递所有光片的 JSON 数组：
```json
[
  {"id": 1, "content_text": "...", "emotion": "平静", "tags": ["咖啡", "独处"]},
  ...
]
```

---

## 四、后端：文件变更清单

### 新增/修改文件

| 文件 | 动作 | 内容 |
|------|------|------|
| `ai/provider/deepseek.go` | 修改 | 实现真正的 HTTP Chat 调用 |
| `ai/service/service.go` | 修改 | 新增 `BuildIslands` 方法（含 prompt 组装+解析） |
| `ai/handler/handler.go` | 修改 | 新增 `POST /build-islands` 端点 |
| `ai/domain/ai.go` | 修改 | 新增 `BuildIslandsResponse` 结构体 |
| `ai/repository/repository.go` | 修改 | LogBuildIslands + 日额度检查 |
| `island/repository/repository.go` | 修改 | 新增 `AddFragments`, `RemoveFragments` 方法 |
| `island/service/service.go` | 修改 | 新增 `AddFragments`, `RemoveFragments` 方法 |
| `island/handler/handler.go` | 修改 | 新增 `POST/DELETE /{id}/fragments` 端点 |
| `island/domain/island.go` | 修改 | 新增 `FragmentAction` 结构体 |
| `ai/ai.go` | 修改 | 工厂函数传入 config（需要 DeepSeek key） |
| `infra/router/router.go` | 修改 | 工厂函数传入 config 给 ai.New |

---

## 五、前端：页面与组件

### 5.1 手动岛屿管理

**三路径**：
- **创建岛屿**：屿页 → "新建小岛"按钮 → 输入岛名+描述 → 创建空岛 → 跳转岛详情
- **岛详情页增强**：浮动的"添加光片"按钮 → 弹出光片选择器 BottomSheet
- **光片选择器**：全屏 BottomSheet，搜索+标签筛选+多选

### 5.2 AI 辅助构建岛屿

**入口**：我的页 → "星图管理员"卡片 → 「让 AI 帮我发现小岛」按钮

**`/ai/build-islands` 页面**：
- **分析阶段**：全屏动画——星点浮动+光线连接，文案分阶段变化：
  "正在读你的光片…" → "发现了一些隐秘的联系…" → "正在给它们取名字…"
- **结果展示**：卡片流展示 AI 候选岛屿，每张卡片有岛名、描述、光片预览、操作按钮
- **确认操作**：「就这样」创建 / 「跳过」忽略

### 5.3 文件变更清单

| 文件 | 动作 | 内容 |
|------|------|------|
| `island/data/island_repository.dart` | 修改 | 新增 `createIsland`, `addFragments`, `removeFragments` |
| `island/presentation/pages/island_detail_page.dart` | 修改 | 新增"添加光片"浮动按钮 |
| `island/presentation/pages/universe_page.dart` | 修改 | 新增"新建小岛"入口 |
| `island/presentation/pages/island_create_page.dart` | **新增** | 创建岛屿页面 |
| `island/presentation/widgets/fragment_picker_sheet.dart` | **新增** | 光片选择器 BottomSheet |
| `ai/data/ai_api.dart` | 修改 | 新增 `buildIslands()` |
| `ai/data/ai_repository_impl.dart` | 修改 | 新增 `buildIslands()` |
| `ai/presentation/pages/glow_organize_page.dart` | 修改 | 新增"构建岛屿"模式 |
| `ai/presentation/pages/ai_build_islands_page.dart` | **新增** | AI 构建岛屿页面 |
| `profile/presentation/pages/mine_page.dart` | 修改 | 新增"星图管理员"卡片 |
| `app/router.dart` | 修改 | 新增路由 `/ai/build-islands` |

---

## 六、数据流

```
用户触发 AI 构建
  ↓
POST /api/v1/ai/build-islands
  ↓ Go Backend
  ├── 查所有 fragments (WHERE user_id=? AND is_deleted=FALSE)
  ├── 组装 prompt (system + fragments JSON)
  ├── DeepSeek Chat() → JSON response
  ├── 解析 → BuildIslandsResponse
  └── 返回 {islands: [...]}
  ↓ Flutter
  ├── 展示候选岛屿卡片
  └── 用户确认每个岛屿
      ├── POST /islands {name, description}
      ├── POST /islands/{id}/fragments {fragment_ids: [...]}
      └── 下一个...
  ↓
invalidate(islandsProvider) → 屿页刷新
```
