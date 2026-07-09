# 隙光 Flutter 工程重构设计（v0.3-arch）

- **日期**：2026-07-10
- **状态**：已确认（用户逐项拍板）
- **基线**：commit `0df19f9`（chore: baseline snapshot before flutter architecture refactor）

## 0. 背景与目标

Flutter 端 bug 层出不穷，CLAUDE.md 约束不足以防止 AI 生成跑偏。摸底审计发现：

- **错误吞噬 58 处**（7 处空 catch、6 处注释掩盖、37 处只弹 SnackBar 无日志、2 处 `.then` 无错误分支、8 处 unawaited fire-and-forget）
- **同步引擎 6 类正确性问题**（device_id 不稳定、clientSeq 恒 0、全表重写持久化、无并发保护、文件级全局 Timer、失败 op 毒堆积）
- **conflict_resolver 是 5 行 stub**，后端 push 无条件返回 applied，冲突协议（CLAUDE.md §5.7/§6.2 已定义）从未实现
- **数据流与文档相悖**：文档写"本地优先"，实际是"远端优先 + 离线兜底"，且在线创建不写本地 drift——断网重启后在线创建的光片消失
- **死代码与真代码同名共存**（`fragment_repository_impl.dart` 自认 redundant 但保留），误导后续 AI 生成
- **CLAUDE.md §3.2 逐文件树严重腐烂**：列着已删除文件，缺 profile/app_update/emotion 三个真实 feature
- **设计令牌存量违规约 30+ 处**（硬编码尺寸/时长/字号），现有守卫手段（人工自检清单）无机器强制
- lint 基线：`dart analyze` 7 个问题（4 warning + 3 info），analysis_options 仅 flutter_lints 默认集且关闭了两条

**目标**：四条线并行收口——①运行时正确性修复 ②机器强制层 ③CLAUDE.md 对齐现实并补强 ④死代码清理。

## 1. 范围决策（用户已拍板）

| 决策点 | 结论 |
|---|---|
| 未提交改动 | 已先提交为基线快照 `0df19f9` |
| 重构深度 | 全面重构 4 条线，**但本轮不拆巨石页面**（7 个 >900 行页面原样保留，后续按需拆） |
| 错误处理 | 方案 B：统一 AppException 层级 + AppLogger，保持异常流，不引入 Result 类型 |
| 冲突解决 | 本轮实现冲突副本，**前后端一起闭环**（Go 端补 base_server_version 检查） |
| 数据流 | 镜像写入：保持远端优先读，所有在线写操作成功后镜像写本地 drift |
| 存量令牌违规 | 本轮全部修干净，守卫上线即零违规 |
| 手写 domain 模型 | 文档对齐现实：新增必须 @freezed，存量 9 个手写模型不强制迁移 |
| 死代码 | 本轮清理（已逐个验证无引用） |
| 强制手段 | 严格 lint 集 + 设计令牌守卫脚本；**不做**文件体积红线 |

**明确不做**：拆页面、手写模型迁 freezed、完全本地优先架构、文件体积红线、Result 类型化错误处理。

## 2. 线①-1：错误处理统一（方案 B）

新增共享基础件（`lib/features/shared/`，零新第三方依赖）：

### 2.1 AppException sealed 层级

```dart
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;      // 用户可读（中文，产品语气）
  final Object? cause;       // 原始异常，供日志
}
class NetworkException extends AppException { ... }  // 超时/断网/HTTP 状态码
class AuthException extends AppException { ... }     // 401/token 失效
class StorageException extends AppException { ... }  // drift/secure_storage/文件 IO
class UnknownException extends AppException { ... }
```

- data 层出口统一转换：`on DioException catch (e) → throw NetworkException.fromDio(e)`；drift/存储异常 → `StorageException`
- presentation 层只需 `on AppException catch` 一种分支，修掉"只 catch DioException、其他异常裸奔"的选择性处理（island_detail_page:218 等）

### 2.2 AppLogger

- `AppLogger.debug/warn/error(String message, {Object? error, StackTrace? stackTrace})`
- 内部：`developer.log` 输出 + Sentry（error 级 `captureException`，warn 级 `addBreadcrumb`）
- 替换散落的 `developer.log` 直呼；**存量 58 处 catch 逐个接入**：
  - 空 catch（session_storage:94,111、vinyl_widgets:210、capture_page:634 等 7 处）→ 补 `AppLogger.warn`；确属"尽力而为清理"的场景改 `on XxxException` 窄化 + warn
  - `.then()` 无 catchError（sync_provider:61、sync_providers:79）→ 补错误分支
  - 8 处 fire-and-forget → 显式 `unawaited(... .catchError(...))` 或补 await，注释理由

### 2.3 showAppError

- `void showAppError(BuildContext context, AppException e)`：统一 SnackBar 风格（AppText/AppMotion token、`AppColors.sunsetCoral` 错误色语义），替换 37 处各自为政的错误提示写法。

## 3. 线①-2：同步引擎修复 + 镜像写入 + 冲突闭环

### 3.1 SyncEngine 六项修复（`lib/features/sync/engine/sync_engine.dart`）

| # | 现状 | 修复 |
|---|---|---|
| 1 | `device_id: 'flutter-${DateTime.now().millisecondsSinceEpoch}'` 每次 push 都是新设备 | 首次生成 UUID 持久化 prefs（`xiguang.sync.device_id`），全生命周期稳定 |
| 2 | 所有 OpLog `clientSeq: 0`，设备内顺序失效 | engine 递增分配（`_seq` 已有，接线到 enqueue 方并持久化） |
| 3 | `_persistPendingOps` 每次 enqueue 全表 `clearOpLogs()` + 重插 | 改增量：enqueue→insert、compact→update、accepted→delete（deleteOpLog 已有） |
| 4 | `_pendingOps` 无并发保护：enqueue 与 syncNow 的 removeWhere 竞态 | 轻量 Future 链互斥锁（自写 ~15 行 `_Mutex`，不引第三方） |
| 5 | 文件级全局 `Timer? _autoSyncTimer`（sync_provider.dart）、`_autoSwitchTimer`（providers.dart 夜间模式）游离 Riverpod 之外 | 收进带 `ref.onDispose` 的 provider；随 App 生命周期暂停/恢复（app.dart 的 lifecycle observer 已有挂点） |
| 6 | 非 applied 的 op 留队永久重推（毒堆积） | 失败计数 ≥5 转 parked：不再推送、计入 `SyncStatus.failedCount`、同步设置页显示"N 条同步失败 [清除]"入口 |

### 3.2 镜像写入（`lib/features/fragment/data/fragment_repository.dart`）

- 现状：在线 create 走 REST 后**不写本地 drift**；断网重启后该光片本地不存在。
- 修复：create/update/delete 在线成功后同步镜像写 `FragmentLocalDataSource`（update/delete 已部分有，create 补齐；统一语义）。
- 读路径保持"远端优先、失败回落本地"不变。
- `Fragments` 表已有 `publicId`/`isSynced` 列，镜像写入时填充。

### 3.3 冲突闭环（前后端）

**Go 端**（`backend/internal/sync/`，~30 行 + 测试）：

- `PushFragmentOp` 对 UPDATE/DELETE 校验 `op.BaseServerRev` 与该实体当前最新 server_rev：
  - 落后 → 返回 `PushResult{Status: "conflict", Conflict: &ConflictInfo{CurrentVersion, IncomingVersion, Reason}}`（结构 CLAUDE.md §6.2 已定义，补实现）
  - DELETE 按 §5.7：允许删除旧版本保留 tombstone；本地编辑 vs 远端删除 → conflict
- `domain.PushResult` 增加 `Conflict *ConflictInfo` 字段（§6.2 既定结构，非协议变更）

**Flutter 端**：

- `conflict_resolver.dart` 从 5 行 stub 扩为真实现：收到 `status == "conflict"` → 生成**冲突副本**（远端当前版本保留原位；本地版本另存新光片，正文前缀 `⚠冲突副本`）→ 从 pending 队列移除该 op → `showAppError` 级别的用户可见提示
- 删除重复的 `lib/features/fragment/sync/conflict_resolver.dart`（无引用，见线④）
- 单元测试：mock push 返回 conflict，断言冲突副本落库、op 出队

## 4. 线②：机器强制层

### 4.1 analysis_options.yaml 升级

- `language: strict-casts: true`
- 新增约 15 条**正确性**lint（不加风格类）：`unawaited_futures`、`use_build_context_synchronously`、`avoid_catches_without_on_clauses`、`only_throw_errors`、`cancel_subscriptions`、`close_sinks`、`avoid_dynamic_calls`、`always_declare_return_types`、`unnecessary_statements`、`no_self_assignments`、`throw_in_finally`、`unrelated_type_equality_checks`、`collection_methods_unrelated_type`、`test_types_in_equals`、`avoid_slow_async_io`
- 现有 7 个 analyze 问题一并清零（2 个 unused_import、1 个 invalid_annotation_target、1 个 unused_element `_FallbackTimeline`、1 个 unnecessary_getters_setters、2 个 curly_braces）
- 验收：`dart analyze` 零问题

### 4.2 设计令牌守卫（`test/design_token_guard_test.dart`）

- 纯 Dart 正则扫描，随 `flutter test` 跑，无需外部工具
- 扫描范围：`lib/features/` + `lib/ui/composites/`（§9.12 白名单目录 `lib/ui/spaces/`、`lib/ui/primitives/`、`lib/design/` 不扫）
- 检查项（§9 铁律中机器可判定的子集）：

| 模式 | 对应铁律 |
|---|---|
| `Color(0x` / `Colors.`（除 transparent） | §9.1 硬编码颜色 |
| `fontSize:` | §9.1/§9.3 硬编码字号 |
| `fontWeight: FontWeight.` | §9.1 硬编码字重 |
| 裸 `TextStyle(` | §9.3 必须用 AppText |
| `BorderRadius.circular(数字)` | §9.5 |
| `EdgeInsets.all/symmetric/fromLTRB(裸数字)` | §9.4 |
| `Duration(milliseconds:/seconds: 数字)` | §9.14 |
| `Curves.`（非 AppMotion 内） | §9.14 |

- 豁免机制（对齐 CLAUDE.md 现有规则，不发明新语法）：
  - 文件级：首部 `// MOTION_EXEMPT: self-painted` 头（§9.14 既定）——vinyl_widgets.dart 现在缺这个头，补上
  - 行级：`// non-motion: <理由>` 注释豁免该行 Duration/Curves（网络超时、Timer.periodic 业务定时器、手势窗口判定，§9.14 既定的"不受约束"类）
- `.withValues(alpha:)` 按 §9.6 本就合法，不扫
- **存量违规（约 30+ 处）本轮全部修干净**：逐处按 §9.4 就近原则替换为 token，或按豁免规则登记；守卫上线即零报告

## 5. 线③：CLAUDE.md 补强

### 5.1 对齐现实

- **依赖表更正**：`flutter_riverpod`（非裸 riverpod）、补 shared_preferences/cached_network_image/file_picker/package_info_plus/open_filex/path_provider 等实际清单
- **§3.2 Flutter 端逐文件树废弃**：改为"每 feature 分层契约（domain→data→presentation 职责表）+ 现有 feature 清单（15 个：ai/app_update/auth/emotion/fragment/island/profile/relation/space/starmap/stats/timeline/whitenoise/shared/sync）"，不再维护逐文件清单（已证明必然腐烂）
- **domain 模型规则**：改为"**新增** domain 模型必须 @freezed；存量手写模型（auth/island/starmap/stats/space/whitenoise/ai/app_update/emotion 9 个 feature）不强制迁移、碰到再迁"
- **同步/数据流章节改写**：从"本地优先"改为实际架构——"远端优先读 + 镜像写入 + 离线走 OpLog 队列 + 冲突副本"；补 device_id/clientSeq/parked 语义
- **本地表结构**：记录 drift 三表现实（Fragments/OpLogs/Emotions 单一 AppDatabase 单例）

### 5.2 新增规范（每条都对应本次审计发现的真实 bug 模式）

- **错误处理规范（新 §）**：
  - 禁空 catch、禁 `catch (e)` 不带 `on` 窄化（lint 同步强制）、禁 `.then` 无错误分支、禁只 catch DioException 的选择性处理
  - data 层出口必须转 AppException；presentation 层必须走 showAppError；日志必须走 AppLogger（禁裸 developer.log/debugPrint/print）
  - fire-and-forget 必须显式 `unawaited()` + 错误分支 + 注释理由
- **Riverpod 规范（新 §）**：
  - 禁文件级/全局可变状态（Timer、单例、计数器）——必须住在带 `ref.onDispose` 的 provider 里
  - 禁在 widget 方法内 inline `new` API/Repository（fragment_detail `_polish()`、ai_build_islands `_startAnalysis()` 两处历史违规同步修掉）——必须走 provider
  - `ref.read` 仅限回调内；build 内一律 `ref.watch`
- **守卫机制文档（新 §）**：守卫脚本用法、两种豁免注释语法与适用场景、严格 lint 集清单、"违规=CI 红"的定位

### 5.3 测试对齐

- 更新 `test/claude_constraints_test.dart`：删除对已删死文件（fragment_repository_impl.dart 等）的路径引用

## 6. 线④：死代码清理（已逐个验证无引用）

| 文件 | 证据 |
|---|---|
| `lib/features/fragment/data/fragment_repository_impl.dart` | 注释自认 redundant；仅 claude_constraints_test 路径引用 |
| `lib/features/fragment/sync/conflict_resolver.dart` | 无引用；与 sync/engine/ 下同名文件重复 |
| `lib/features/fragment/sync/oplog_generator.dart` | 无引用 |
| `lib/features/timeline/data/timeline_local_dao.dart` | 空壳 stub（实施时最终确认无引用再删） |
| `lib/features/asr/` 空目录 | 无文件 |
| `time_river_page.dart` 内 `_FallbackTimeline` | analyze unused_element |

同步更新引用这些路径的测试。

## 7. 验收标准

1. `dart analyze` 零问题（新严格 lint 集下）
2. `flutter test` 全绿：现有 3 组真实测试 + 新增——sync engine（并发 enqueue/syncNow、compaction、parked）、conflict resolver（冲突副本落库、op 出队）、AppException 转换、镜像写入、守卫自测（fixture 验证豁免与检出）
3. `go test ./internal/sync/...` 冲突检查测试通过
4. 守卫脚本对扫描范围零报告
5. 手工冒烟：捕光→断网→重启→光片仍在（镜像写入）；双端改同一光片→冲突副本出现且原光片为远端版本

## 8. 风险与缓解

- **修 30+ 存量令牌违规**触碰多页面视觉细节：等值替换（数字→就近 token），逐条 diff 可查；细微视觉偏移风险自担
- **后端冲突检查上线**后，携带 stale base_server_version 的旧客户端 UPDATE 开始收到 conflict：MVP 内部验证设备少，影响可控
- **实施顺序**：错误处理基础件先行 → 同步/镜像/冲突 → 死代码 → 令牌修复 → lint/守卫最后收口（中途 analyze 允许临时噪音，以最终提交为准）→ CLAUDE.md 与代码同步落笔
