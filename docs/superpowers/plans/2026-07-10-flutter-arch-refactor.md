# 隙光 Flutter 工程重构实施计划（v0.3-arch）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 Flutter 端运行时正确性问题（错误吞噬、同步引擎缺陷、冲突未实现、数据流与文档相悖），建立机器强制层（严格 lint + 设计令牌守卫），对齐并补强 CLAUDE.md，清理死代码。

**Architecture:** 四条线按依赖顺序推进--错误处理基础件先行（AppException/AppLogger/showAppError），同步引擎六项修复 + 镜像写入 + 前后端冲突闭环，死代码清理，设计令牌存量修复，严格 lint + 守卫脚本最后收口，CLAUDE.md 与代码同步落笔。本轮不拆巨石页面。

**Tech Stack:** Flutter + Riverpod 2 + drift + dio + go_router（前端）；Go + net/http + pgx（后端 sync 模块）；flutter_test / go test（测试）

**Spec:** `docs/superpowers/specs/2026-07-10-flutter-arch-refactor-design.md`

**Baseline commit:** `2e7f480`

---

## File Structure

### 新增文件

| 文件 | 职责 |
|---|---|
| `app/lib/features/shared/domain/app_exception.dart` | AppException sealed 层级 + DioException/存储异常转换 |
| `app/lib/features/shared/infra/app_logger.dart` | AppLogger（developer.log + Sentry 面包屑/捕获） |
| `app/lib/features/shared/presentation/app_error.dart` | showAppError 统一错误提示 |
| `app/lib/features/sync/engine/mutex.dart` | 轻量 Future 链互斥锁 |
| `app/test/shared/app_exception_test.dart` | AppException 转换测试 |
| `app/test/shared/app_logger_test.dart` | AppLogger 测试 |
| `app/test/shared/app_error_test.dart` | showAppError 测试 |
| `app/test/sync/mutex_test.dart` | 互斥锁测试 |
| `app/test/sync/sync_engine_test.dart` | 同步引擎修复测试 |
| `app/test/sync/conflict_resolver_test.dart` | 冲突副本测试 |
| `app/test/fragment/mirror_write_test.dart` | 镜像写入测试 |
| `app/test/design_token_guard_test.dart` | 设计令牌守卫（含豁免机制自测） |
| `backend/internal/sync/service/service_test.go` | 后端冲突检查测试（扩展已有或新建） |

### 修改文件

| 文件 | 改动 |
|---|---|
| `app/lib/features/sync/domain/sync_status.dart` | 加 `failedCount`、`parkedCount` 字段 |
| `app/lib/features/sync/engine/sync_engine.dart` | 六项修复 |
| `app/lib/features/sync/engine/conflict_resolver.dart` | 5 行 stub -> 真实现 |
| `app/lib/features/sync/presentation/providers/sync_provider.dart` | Timer 入 provider；clientSeq 接线 |
| `app/lib/features/sync/presentation/providers/sync_providers.dart` | onFragmentChanged/parked 接线 |
| `app/lib/app/providers.dart` | 夜间模式 Timer 入 provider |
| `app/lib/app/app.dart` | lifecycle 挂接新 provider |
| `app/lib/features/fragment/data/fragment_repository.dart` | 镜像写入；AppException 转换 |
| `app/lib/features/fragment/data/local/fragment_local_ds.dart` | 加 mirrorInsert |
| `app/lib/features/fragment/presentation/pages/fragment_detail_page.dart` | inline AIApi -> provider；catch 接入 |
| `app/lib/features/ai/presentation/pages/ai_build_islands_page.dart` | inline AIApi -> provider |
| `app/lib/features/sync/domain/oplog.dart` | 修 invalid_annotation_target |
| `backend/internal/sync/domain/sync.go` | PushResult 加 Conflict 字段 |
| `backend/internal/sync/repository/repository.go` | 加版本检查查询 |
| `backend/internal/sync/service/service.go` | UPDATE/DELETE 冲突逻辑 |
| `app/analysis_options.yaml` | strict-casts + 15 条 lint |
| `app/lib/features/fragment/presentation/widgets/vinyl_widgets.dart` | 补 MOTION_EXEMPT 头 |
| `app/test/claude_constraints_test.dart` | 删除死文件引用 |
| `CLAUDE.md` | 对齐现实 + 新增规范 |
| ~40 个业务文件 | 58 处 catch 接入 + 30+ 处令牌修复（分批） |

### 删除文件

| 文件 | 理由 |
|---|---|
| `app/lib/features/fragment/data/fragment_repository_impl.dart` | 注释自认 redundant，无引用 |
| `app/lib/features/fragment/sync/conflict_resolver.dart` | 无引用，与 sync/engine 下重复 |
| `app/lib/features/fragment/sync/oplog_generator.dart` | 无引用 |
| `app/lib/features/timeline/data/timeline_local_dao.dart` | 空壳（删除前最终确认无引用） |
| `app/lib/features/asr/` 空目录 | 无文件 |

---

## Phase 1：错误处理基础件

### Task 1: AppException sealed 层级

**Files:**
- Create: `app/lib/features/shared/domain/app_exception.dart`
- Test: `app/test/shared/app_exception_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/shared/app_exception_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/domain/app_exception.dart';

void main() {
  group('AppException', () {
    test('NetworkException.fromDio converts connection timeout', () {
      final dio = DioException(
        type: DioExceptionType.connectionTimeout,
        message: 'timeout',
      );
      final ex = NetworkException.fromDio(dio);
      expect(ex, isA<NetworkException>());
      expect(ex, isA<AppException>());
      expect(ex.message, isNotEmpty);
      expect(ex.cause, same(dio));
    });

    test('NetworkException.fromDio converts 401 to AuthException', () {
      final dio = DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 401,
        ),
        message: 'unauthorized',
      );
      final ex = NetworkException.fromDio(dio);
      expect(ex, isA<AuthException>());
    });

    test('NetworkException.fromDio converts 500 to NetworkException', () {
      final dio = DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 500,
        ),
        message: 'server error',
      );
      final ex = NetworkException.fromDio(dio);
      expect(ex, isA<NetworkException>());
      expect(ex, isNot(isA<AuthException>()));
    });

    test('StorageException wraps underlying cause', () {
      final ex = StorageException('drift write failed', cause: StateError('db locked'));
      expect(ex.message, 'drift write failed');
      expect(ex.cause, isA<StateError>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/shared/app_exception_test.dart`
Expected: FAIL — `app_exception.dart` does not exist / import fails.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/features/shared/domain/app_exception.dart
import 'package:dio/dio.dart';

/// 应用统一异常层级。data 层出口转换为 AppException，presentation 层只 catch AppException。
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// 网络/HTTP 异常（超时、断网、5xx 等）。
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});

  /// 从 DioException 转换。401/403 -> AuthException；其余 -> NetworkException。
  factory NetworkException.fromDio(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return AuthException('登录已失效，请重新登录', cause: e);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return NetworkException('网络不太通，请稍后再试', cause: e);
    }
    if (e.type == DioExceptionType.connectionError) {
      return NetworkException('好像没有连上网', cause: e);
    }
    if (code != null && code >= 500) {
      return NetworkException('服务暂时不可用', cause: e);
    }
    return NetworkException('请求失败了，请稍后再试', cause: e);
  }
}

/// 认证异常（token 失效、未登录）。
class AuthException extends NetworkException {
  const AuthException(super.message, {super.cause});
}

/// 本地存储异常（drift、secure_storage、文件 IO）。
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// 未知异常兜底。
class UnknownException extends AppException {
  const UnknownException(super.message, {super.cause});
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/shared/app_exception_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/shared/domain/app_exception.dart app/test/shared/app_exception_test.dart
git commit -m "feat: add AppException sealed hierarchy with Dio conversion"
```

---

### Task 2: AppLogger

**Files:**
- Create: `app/lib/features/shared/infra/app_logger.dart`
- Test: `app/test/shared/app_logger_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/shared/app_logger_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/infra/app_logger.dart';

void main() {
  test('AppLogger.debug/warn/error do not throw without Sentry init', () {
    expect(() => AppLogger.debug('debug msg'), returnsNormally);
    expect(
      () => AppLogger.warn('warn msg', error: StateError('x')),
      returnsNormally,
    );
    expect(
      () => AppLogger.error('err msg', error: StateError('x'), stackTrace: StackTrace.current),
      returnsNormally,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/shared/app_logger_test.dart`
Expected: FAIL — import fails.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/features/shared/infra/app_logger.dart
import 'dart:developer' as developer;

import 'package:sentry_flutter/sentry_flutter.dart';

/// 统一日志入口。替代散落的 developer.log / debugPrint / print 直呼。
/// error 级 -> Sentry captureException；warn 级 -> Sentry breadcrumb；debug 级仅本地。
class AppLogger {
  AppLogger._();

  static void debug(String message, {Object? error}) {
    developer.log(message, name: 'xiguang', level: 0, error: error);
  }

  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'xiguang', level: 500, error: error, stackTrace: stackTrace);
    Sentry.addBreadcrumb(Breadcrumb(
      level: SentryLevel.warning,
      message: message,
      data: error == null ? null : {'error': error.toString()},
    ));
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'xiguang', level: 1000, error: error, stackTrace: stackTrace);
    Sentry.captureException(error ?? message, stackTrace: stackTrace);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/shared/app_logger_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/shared/infra/app_logger.dart app/test/shared/app_logger_test.dart
git commit -m "feat: add AppLogger with Sentry breadcrumb/capture integration"
```

---

### Task 3: showAppError 统一错误提示

**Files:**
- Create: `app/lib/features/shared/presentation/app_error.dart`
- Test: `app/test/shared/app_error_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/shared/app_error_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/shared/domain/app_exception.dart';
import 'package:xiguang/features/shared/presentation/app_error.dart';

void main() {
  testWidgets('showAppError displays a SnackBar with the exception message', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showAppError(context, const NetworkException('网络不太通')),
            child: const Text('trigger'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    expect(find.text('网络不太通'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/shared/app_error_test.dart`
Expected: FAIL — import fails.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/features/shared/presentation/app_error.dart
import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';
import '../../../design/tokens/motion.dart';
import '../../../design/tokens/typography.dart';
import '../domain/app_exception.dart';

/// 统一错误提示。presentation 层 catch AppException 后调此函数，不自造 SnackBar。
void showAppError(BuildContext context, AppException e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.message, style: AppText.body.copyWith(color: AppColors.white)),
      backgroundColor: AppColors.sunsetCoral,
      duration: AppMotion.snackbar,
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/shared/app_error_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/shared/presentation/app_error.dart app/test/shared/app_error_test.dart
git commit -m "feat: add showAppError unified error display"
```

---

## Phase 2：同步引擎六项修复

### Task 4: SyncStatus 加 failedCount / parkedCount 字段

**Files:**
- Modify: `app/lib/features/sync/domain/sync_status.dart`

- [ ] **Step 1: Update the freezed model**

```dart
// app/lib/features/sync/domain/sync_status.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// 同步状态
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus({
    required int lastServerRev,
    required int pendingCount,
    DateTime? lastSyncAt,
    required bool isSyncing,
    @Default(true) bool connected,
    String? error,
    @Default(0) int failedCount,
    @Default(0) int parkedCount,
  }) = _SyncStatus;
}
```

- [ ] **Step 2: Regenerate freezed code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: `sync_status.freezed.dart` regenerated with `failedCount`/`parkedCount`.

- [ ] **Step 3: Verify compilation**

Run: `cd app && dart analyze lib/features/sync/domain/sync_status.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/sync/domain/sync_status.dart app/lib/features/sync/domain/sync_status.freezed.dart
git commit -m "feat: add failedCount/parkedCount to SyncStatus"
```

---

### Task 5: 轻量互斥锁 _Mutex

**Files:**
- Create: `app/lib/features/sync/engine/mutex.dart`
- Test: `app/test/sync/mutex_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/sync/mutex_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/sync/engine/mutex.dart';

void main() {
  test('Mutex serializes overlapping critical sections', () async {
    final mutex = Mutex();
    final log = <int>[];

    Future<void> task(int id, int millis) async {
      await mutex.synchronized(() async {
        log.add(id);
        await Future.delayed(Duration(milliseconds: millis));
      });
    }

    // Start 3 tasks concurrently; they must run sequentially.
    await Future.wait([task(1, 10), task(2, 10), task(3, 10)]);
    expect(log, [1, 2, 3]);
  });

  test('Mutex releases lock even if critical section throws', () async {
    final mutex = Mutex();
    try {
      await mutex.synchronized(() async {
        throw StateError('boom');
      });
      fail('should have thrown');
    } on StateError {
      // expected
    }
    // Lock should be released — next call must not deadlock.
    var ran = false;
    await mutex.synchronized(() async { ran = true; });
    expect(ran, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/sync/mutex_test.dart`
Expected: FAIL — import fails.

- [ ] **Step 3: Write minimal implementation**

```dart
// app/lib/features/sync/engine/mutex.dart
import 'dart:async';

/// 轻量 Future 链互斥锁。不引入第三方依赖。
/// 用于 SyncEngine 串行化 enqueue / syncNow 对 _pendingOps 的访问。
class Mutex {
  Future<void> _tail = Future.value();

  Future<T> synchronized<T>(Future<T> Function() critical) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await critical());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/sync/mutex_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sync/engine/mutex.dart app/test/sync/mutex_test.dart
git commit -m "feat: add lightweight Mutex for sync engine serialization"
```

---

### Task 6: SyncEngine 修复 — device_id 持久化 + clientSeq 分配

**Files:**
- Modify: `app/lib/features/sync/engine/sync_engine.dart`
- Test: `app/test/sync/sync_engine_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/sync/sync_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiguang/features/sync/domain/oplog.dart';
import 'package:xiguang/features/sync/domain/sync_config.dart';
import 'package:xiguang/features/sync/domain/sync_status.dart';
import 'package:xiguang/features/sync/engine/sync_engine.dart';

import '../helpers/fake_sync_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('device_id is stable across SyncEngine instances', () async {
    final api = FakeSyncApi(statusRev: 0);
    final engine1 = SyncEngine(api: api, config: SyncConfig(enabled: true));
    final id1 = await engine1.deviceId;
    final engine2 = SyncEngine(api: api, config: SyncConfig(enabled: true));
    final id2 = await engine2.deviceId;
    expect(id1, isNotEmpty);
    expect(id1, id2);
  });

  test('clientSeq increments across enqueues', () async {
    final api = FakeSyncApi(statusRev: 0);
    final engine = SyncEngine(api: api, config: SyncConfig(enabled: true));
    engine.enqueue(OpLog(
      clientOpId: 'op-1',
      entityType: 'fragment',
      opType: 'INSERT',
      entityPublicId: 'frag-1',
      payload: {},
    ));
    engine.enqueue(OpLog(
      clientOpId: 'op-2',
      entityType: 'fragment',
      opType: 'INSERT',
      entityPublicId: 'frag-2',
      payload: {},
    ));
    final ops = engine.pendingOps;
    expect(ops[0].clientSeq, 1);
    expect(ops[1].clientSeq, 2);
  });
}
```

- [ ] **Step 2: Write the FakeSyncApi helper**

```dart
// app/test/helpers/fake_sync_api.dart
import 'package:xiguang/features/sync/data/sync_api.dart';

class FakeSyncApi extends SyncApi {
  FakeSyncApi({this.statusRev = 0}) : super(null);

  final int statusRev;
  Map<String, dynamic> _pushResponse = {'results': [], 'new_server_rev': 0};
  List<Map<String, dynamic>> _pullOps = const [];

  void setPushResponse(Map<String, dynamic> r) => _pushResponse = r;
  void setPullOps(List<Map<String, dynamic>> ops) => _pullOps = ops;

  @override
  Future<Map<String, dynamic>> push(Map<String, dynamic> body) async => _pushResponse;

  @override
  Future<Map<String, dynamic>> pull({required int sinceRev}) async =>
      {'operations': _pullOps, 'next_since_rev': statusRev, 'has_more': false};

  @override
  Future<Map<String, dynamic>> status() async =>
      {'server_rev': statusRev, 'connected': true};
}
```

> **Note:** If `SyncApi` constructor or method signatures differ from the above, adapt the fake to match the real `SyncApi` in `app/lib/features/sync/data/sync_api.dart` (read it first). The fake must override `push`, `pull`, `status`.

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/sync/sync_engine_test.dart`
Expected: FAIL — `deviceId` getter / `pendingOps` getter / `clientSeq` increment not implemented.

- [ ] **Step 4: Modify SyncEngine — add device_id persistence and clientSeq allocation**

In `app/lib/features/sync/engine/sync_engine.dart`:

Add `device_id` persistence and expose `pendingOps`. Replace the `enqueue` method to assign `clientSeq`. Add `_deviceId` lazy init.

```dart
// Add near the top of the class, after the fields:
String? _deviceId;
int _seq = 0;

/// Stable device_id persisted to prefs. Used in every push.
Future<String> get deviceId async {
  if (_deviceId != null) return _deviceId!;
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_deviceIdKey);
  if (id == null || id.isEmpty) {
    id = 'flutter-${DateTime.now().millisecondsSinceEpoch}-${_randomSuffix()}';
    await prefs.setString(_deviceIdKey, id);
  }
  _deviceId = id;
  return id;
}

static const _deviceIdKey = 'xiguang.sync.device_id';

String _randomSuffix() {
  final r = DateTime.now().microsecondsSinceEpoch;
  return r.toRadixString(36).substring(r.toRadixString(36).length - 6);
}

/// Expose a snapshot of pending ops (read-only).
List<OpLog> get pendingOps => List.unmodifiable(_pendingOps);
```

Replace the `enqueue` method — assign `clientSeq = ++_seq` instead of trusting caller:

```dart
void enqueue(OpLog op) {
  final assigned = op.copyWith(clientSeq: ++_seq);
  // Compaction: if there's already an UPDATE for this entity, replace it
  if (assigned.opType.toUpperCase() == 'UPDATE') {
    final existingIdx = _pendingOps.indexWhere((e) =>
        e.entityType == assigned.entityType &&
        e.entityPublicId == assigned.entityPublicId &&
        e.opType.toUpperCase() == 'UPDATE');
    if (existingIdx != -1) {
      _pendingOps[existingIdx] = assigned;
      AppLogger.debug('SYNC: compacted UPDATE ${assigned.entityType}#${assigned.entityPublicId}');
      _notifyStatus();
      _persistPendingOp(assigned);
      return;
    }
  }
  AppLogger.debug('SYNC: enqueue ${assigned.opType} ${assigned.entityType}#${assigned.entityPublicId} (pending=${_pendingOps.length + 1})');
  _pendingOps.add(assigned);
  _status = _status.copyWith(pendingCount: _pendingOps.length);
  _notifyStatus();
  _persistPendingOp(assigned);
}
```

Replace the `push` body's `device_id` line in `syncNow`:

```dart
// Inside syncNow, replace the hardcoded device_id:
final body = <String, dynamic>{
  'device_id': await deviceId,
  'operations': ops.map((op) => op.toJson()).toList(),
};
```

Replace `_persistPendingOps` (full clear+reinsert) with incremental `_persistPendingOp`:

```dart
Future<void> _persistPendingOp(OpLog op) async {
  await _db.insertOpLog(OpLogsCompanion.insert(
    clientOpId: op.clientOpId,
    entityType: op.entityType,
    opType: op.opType,
    entityPublicId: op.entityPublicId,
    payload: Value(jsonEncode(op.payload)),
    clientSeq: Value(op.clientSeq),
    baseServerVersion: Value(op.baseServerVersion),
  ));
}
```

Delete the old `_persistPendingOps` method (full clear+reinsert).

Add the import for AppLogger at top:
```dart
import '../../shared/infra/app_logger.dart';
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/sync/sync_engine_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sync/engine/sync_engine.dart app/test/sync/sync_engine_test.dart app/test/helpers/fake_sync_api.dart
git commit -m "fix: persist stable device_id and allocate clientSeq in SyncEngine"
```

---

### Task 7: SyncEngine 修复 — Mutex 串行化 + 增量持久化 compaction

**Files:**
- Modify: `app/lib/features/sync/engine/sync_engine.dart`
- Test: `app/test/sync/sync_engine_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `app/test/sync/sync_engine_test.dart`:

```dart
  test('concurrent enqueues are serialized and all persisted', () async {
    final api = FakeSyncApi(statusRev: 0);
    final engine = SyncEngine(api: api, config: SyncConfig(enabled: true));
    // Fire 5 enqueues concurrently (enqueue is sync but _persistPendingOp is async internally).
    for (var i = 0; i < 5; i++) {
      engine.enqueue(OpLog(
        clientOpId: 'op-$i',
        entityType: 'fragment',
        opType: 'INSERT',
        entityPublicId: 'frag-$i',
        payload: {},
      ));
    }
    // All 5 should be in pending with unique clientSeq 1..5.
    final ops = engine.pendingOps;
    expect(ops.length, 5);
    final seqs = ops.map((o) => o.clientSeq).toSet();
    expect(seqs, {1, 2, 3, 4, 5});
  });

  test('compaction replaces previous UPDATE and removes stale drift row', () async {
    final api = FakeSyncApi(statusRev: 0);
    final engine = SyncEngine(api: api, config: SyncConfig(enabled: true));
    engine.enqueue(OpLog(
      clientOpId: 'op-1',
      entityType: 'fragment',
      opType: 'UPDATE',
      entityPublicId: 'frag-1',
      payload: {'content_text': 'v1'},
    ));
    engine.enqueue(OpLog(
      clientOpId: 'op-2',
      entityType: 'fragment',
      opType: 'UPDATE',
      entityPublicId: 'frag-1',
      payload: {'content_text': 'v2'},
    ));
    final ops = engine.pendingOps;
    expect(ops.length, 1, reason: 'compaction should merge UPDATE for same entity');
    expect(ops.first.payload['content_text'], 'v2');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/sync/sync_engine_test.dart`
Expected: FAIL — compaction test may pass already, but concurrent test may show drift row duplication (old `_persistPendingOps` clear+reinsert is gone; need to verify compaction also deletes the stale drift row).

- [ ] **Step 3: Add Mutex to enqueue/syncNow and compaction drift cleanup**

In `app/lib/features/sync/engine/sync_engine.dart`:

Add field and import:
```dart
import 'mutex.dart';
// ...
final Mutex _mutex = Mutex();
```

Wrap `enqueue` body in `_mutex.synchronized`. Since `enqueue` is currently sync, convert it to async or use a sync fire-and-forget on the mutex. Simpler: make `enqueue` call `_mutex.synchronized` and fire-and-forget:

```dart
void enqueue(OpLog op) {
  _mutex.synchronized(() => _enqueueInternal(op));
}

void _enqueueInternal(OpLog op) {
  final assigned = op.copyWith(clientSeq: ++_seq);
  if (assigned.opType.toUpperCase() == 'UPDATE') {
    final existingIdx = _pendingOps.indexWhere((e) =>
        e.entityType == assigned.entityType &&
        e.entityPublicId == assigned.entityPublicId &&
        e.opType.toUpperCase() == 'UPDATE');
    if (existingIdx != -1) {
      final stale = _pendingOps[existingIdx];
      _pendingOps[existingIdx] = assigned;
      AppLogger.debug('SYNC: compacted UPDATE ${assigned.entityType}#${assigned.entityPublicId}');
      _notifyStatus();
      _persistPendingOp(assigned);
      _db.deleteOpLog(stale.clientOpId); // remove stale drift row
      return;
    }
  }
  _pendingOps.add(assigned);
  _status = _status.copyWith(pendingCount: _pendingOps.length);
  _notifyStatus();
  _persistPendingOp(assigned);
}
```

Wrap `syncNow` body in `await _mutex.synchronized(() async { ... })`:

```dart
Future<SyncStatus> syncNow() async {
  if (_status.isSyncing) return _status;
  return _mutex.synchronized(() => _syncNowInternal());
}

Future<SyncStatus> _syncNowInternal() async {
  // ... move existing syncNow body here ...
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/sync/sync_engine_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sync/engine/sync_engine.dart app/test/sync/sync_engine_test.dart
git commit -m "fix: serialize SyncEngine access with Mutex and clean up compacted drift rows"
```

---

### Task 8: SyncEngine 修复 — 失败 op parked 机制

**Files:**
- Modify: `app/lib/features/sync/engine/sync_engine.dart`
- Test: `app/test/sync/sync_engine_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `app/test/sync/sync_engine_test.dart`:

```dart
  test('ops that fail 5 times are parked and not retried', () async {
    final api = FakeSyncApi(statusRev: 0);
    // push returns the op as "failed" every time.
    api.setPushResponse({
      'results': [
        {'client_op_id': 'op-1', 'status': 'failed'}
      ],
      'new_server_rev': 0,
    });
    final engine = SyncEngine(api: api, config: SyncConfig(enabled: true));
    engine.enqueue(OpLog(
      clientOpId: 'op-1',
      entityType: 'fragment',
      opType: 'INSERT',
      entityPublicId: 'frag-1',
      payload: {},
    ));

    // Sync 5 times — each returns failed.
    for (var i = 0; i < 5; i++) {
      await engine.syncNow();
    }
    // Op should now be parked, not in pending.
    expect(engine.pendingOps, isEmpty);
    expect(engine.status.parkedCount, 1);
    expect(engine.status.failedCount, 0); // moved to parked
  });
```

- [ ] **Step 2: Run test to verify it failed**

Run: `cd app && flutter test test/sync/sync_engine_test.dart -p vm --name "ops that fail 5 times"`
Expected: FAIL — `parkedCount` not updated, op stays in pending.

- [ ] **Step 3: Implement parked mechanism**

In `app/lib/features/sync/engine/sync_engine.dart`:

Add a failure counter map and a parked list:

```dart
final Map<String, int> _failureCounts = {};
final List<OpLog> _parkedOps = [];
static const _maxFailures = 5;
```

In `_syncNowInternal`, after push, process failed results:

```dart
// After removing accepted ops, handle failed ops:
final failedIds = results
    .whereType<Map<String, dynamic>>()
    .where((r) => r['status'] == 'failed')
    .map((r) => r['client_op_id'] as String)
    .toSet();

for (final id in failedIds) {
  _failureCounts[id] = (_failureCounts[id] ?? 0) + 1;
  if (_failureCounts[id]! >= _maxFailures) {
    final parked = _pendingOps.where((op) => op.clientOpId == id).toList();
    _pendingOps.removeWhere((op) => op.clientOpId == id);
    _parkedOps.addAll(parked);
    _failureCounts.remove(id);
    await _db.deleteOpLog(id);
    AppLogger.warn('SYNC: parked op $id after $_maxFailures failures');
  }
}

_status = _status.copyWith(
  pendingCount: _pendingOps.length,
  failedCount: _failureCounts.length,
  parkedCount: _parkedOps.length,
);
```

Add a public method to clear parked ops (for the settings page "清除" button):

```dart
Future<void> clearParkedOps() async {
  await _mutex.synchronized(() async {
    _parkedOps.clear();
    _status = _status.copyWith(parkedCount: 0);
    _notifyStatus();
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/sync/sync_engine_test.dart`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sync/engine/sync_engine.dart app/test/sync/sync_engine_test.dart
git commit -m "fix: park sync ops after 5 failures to prevent poison-queue buildup"
```

---

### Task 9: Timer 入 Riverpod provider（autoSync + nightMode）

**Files:**
- Modify: `app/lib/features/sync/presentation/providers/sync_provider.dart`
- Modify: `app/lib/app/providers.dart`
- Test: `app/test/sync/sync_engine_test.dart` (verify no file-level Timer)

- [ ] **Step 1: Refactor sync autoSync Timer into a provider**

Replace the entire content of `app/lib/features/sync/presentation/providers/sync_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/oplog.dart';
import '../../domain/sync_config.dart';
import '../../engine/sync_engine.dart';

/// 记录一次捕光操作的 OpLog 并入队。
void enqueueFragmentOp(
  WidgetRef ref, {
  required String opType,
  required String publicId,
  required Map<String, dynamic> payload,
}) {
  final engine = ref.read(syncEngineProvider);
  final config = ref.read(syncConfigProvider);
  if (!config.enabled) return;

  final opId = engine.nextOpId('fragment', opType);
  engine.enqueue(OpLog(
    clientOpId: opId,
    entityType: 'fragment',
    opType: opType,
    entityPublicId: publicId,
    payload: payload,
    clientSeq: 0, // engine.enqueue assigns the real seq
    baseServerVersion: engine.currentServerRev,
  ));
  ref.read(syncStatusProvider.notifier).state = engine.status;
}

/// 自动同步 Timer 宿主 provider。随 provider 销毁自动 cancel。
final autoSyncTimerProvider = Provider<Timer?>((ref) {
  final config = ref.watch(syncConfigProvider);
  if (!config.enabled) return null;

  Timer? timer;
  switch (config.frequency) {
    case SyncFrequency.every5Minutes:
      timer = Timer.periodic(const Duration(minutes: 5), (_) {
        _doAutoSync(ref);
      });
    case SyncFrequency.hourly:
      timer = Timer.periodic(const Duration(hours: 1), (_) {
        _doAutoSync(ref);
      });
    case SyncFrequency.onAppOpen:
      _doAutoSync(ref);
    case SyncFrequency.onCapture:
    case SyncFrequency.manual:
      timer = null;
  }
  ref.onDispose(() => timer?.cancel());
  return timer;
});

void _doAutoSync(Ref ref) {
  final engine = ref.read(syncEngineProvider);
  // ignore: discarded_futures — fire-and-forget is intentional; errors handled in engine.
  engine.syncNow().then((status) {
    ref.read(syncStatusProvider.notifier).state = status;
  }).catchError((Object e) {
    AppLogger.warn('auto sync failed', error: e);
  });
}
```

Add import at top of file:
```dart
import '../../../shared/infra/app_logger.dart';
```

- [ ] **Step 2: Refactor nightMode autoSwitch Timer into a provider**

In `app/lib/app/providers.dart`, replace the file-level `_autoSwitchTimer` and `_startAutoSwitchTimer`/`stopAutoSwitchTimer` with a provider:

```dart
// Remove these file-level declarations:
//   Timer? _autoSwitchTimer;
//   void _startAutoSwitchTimer(Ref ref) { ... }
//   void stopAutoSyncTimer() { ... }

// Replace the call inside nightModeLoadedProvider:
//   _startAutoSwitchTimer(ref);
// with:
//   ref.watch(nightModeAutoSwitchProvider);

// Add this provider:
final nightModeAutoSwitchProvider = Provider<Timer?>((ref) {
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    final option = ref.read(nightModeOptionProvider);
    if (option == NightModeOption.system) {
      final isNight = _resolveNightMode(option);
      ref.read(nightModeProvider.notifier).state = isNight;
    }
  });
  ref.onDispose(timer.cancel);
  return timer;
});
```

- [ ] **Step 3: Update app.dart to watch the timer providers**

In `app/lib/app/app.dart`, wherever `startAutoSync(ref)` / `stopAutoSync()` is called (lines ~134-145), replace with:

```dart
// Instead of startAutoSync(ref) / stopAutoSync():
// Watch the providers so they are alive while the app runs.
ref.watch(autoSyncTimerProvider);
ref.watch(nightModeAutoSwitchProvider);
```

Read `app.dart` lines 120-150 first to understand the lifecycle observer context, then adapt. The key: remove `startAutoSync`/`stopAutoSync` calls; the providers' `ref.onDispose` handles cleanup. If the lifecycle observer pauses/resumes on backgrounding, add a `ref.invalidate(autoSyncTimerProvider)` on resume to re-evaluate config.

- [ ] **Step 4: Verify no file-level mutable Timer remains**

Run: `cd app && grep -n "^Timer?" lib/features/sync/presentation/providers/sync_provider.dart lib/app/providers.dart`
Expected: No output (no file-level Timer declarations).

- [ ] **Step 5: Run all sync tests + analyze**

Run: `cd app && flutter test test/sync/ && dart analyze lib/features/sync/ lib/app/providers.dart`
Expected: Tests PASS, analyze clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sync/presentation/providers/sync_provider.dart app/lib/app/providers.dart app/lib/app/app.dart
git commit -m "refactor: move autoSync and nightMode Timers into Riverpod providers with onDispose"
```

---

## Phase 3：镜像写入

### Task 10: FragmentLocalDataSource.mirrorInsert

**Files:**
- Modify: `app/lib/features/fragment/data/local/fragment_local_ds.dart`
- Test: `app/test/fragment/mirror_write_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/fragment/mirror_write_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/data/fragment_repository.dart';
import 'package:xiguang/features/fragment/data/local/fragment_local_ds.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';

void main() {
  late AppDatabase db;
  late FragmentLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = FragmentLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('mirrorInsert stores fragment with server id, publicId, isSynced=true', () async {
    final model = LightFragmentModel(
      id: 42,
      contentText: 'mirrored',
      emotion: '平静',
      tags: ['t'],
      mediaUrls: const [],
      createdAt: DateTime(2026, 7, 10),
      status: 'twilight',
    );
    await ds.mirrorInsert(model, publicId: 'pub-42');
    final all = await ds.getAll();
    expect(all, hasLength(1));
    expect(all.first.id, 42);
    expect(all.first.contentText, 'mirrored');
  });

  test('mirrorInsert is idempotent on conflict (same id)', () async {
    final model = LightFragmentModel(
      id: 42,
      contentText: 'v1',
      emotion: '平静',
      tags: const [],
      mediaUrls: const [],
      createdAt: DateTime(2026, 7, 10),
      status: 'twilight',
    );
    await ds.mirrorInsert(model, publicId: 'pub-42');
    await ds.mirrorInsert(model.copyWith(contentText: 'v2'), publicId: 'pub-42');
    final all = await ds.getAll();
    expect(all, hasLength(1));
    expect(all.first.contentText, 'v2');
  });
}
```

- [ ] **Step 2: Add `AppDatabase.forTesting` constructor if missing**

In `app/lib/features/shared/data/local/app_database.dart`, add:

```dart
@DriftDatabase(tables: [Fragments, OpLogs, Emotions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor using an in-memory connection.
  @visibleForTesting
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  // ... rest unchanged
}
```

Add import: `import 'package:flutter/foundation.dart' show visibleForTesting;` (or `package:meta/meta.dart`).

Run `dart run build_runner build --delete-conflicting-outputs` to regenerate if needed.

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/fragment/mirror_write_test.dart`
Expected: FAIL — `mirrorInsert` not defined.

- [ ] **Step 4: Implement mirrorInsert**

In `app/lib/features/fragment/data/local/fragment_local_ds.dart`, add:

```dart
/// 镜像写入：在线 REST 成功后调用，用服务端 id + publicId 写入本地 drift。
/// 幂等：同 id 存在则更新。
Future<void> mirrorInsert(LightFragmentModel fragment, {required String publicId}) async {
  await _db.into(_db.fragments).insert(
    FragmentsCompanion.insert(
      id: Value(fragment.id),
      publicId: Value(publicId),
      contentText: Value(fragment.contentText),
      emotion: Value(fragment.emotion),
      status: Value(fragment.status),
      tags: Value(jsonEncode(fragment.tags)),
      mediaUrls: Value(jsonEncode(fragment.mediaUrls)),
      createdAt: Value(fragment.createdAt),
      isSynced: const Value(true),
    ),
    mode: InsertMode.insertOrReplace,
  );
}
```

The `FragmentLocalDataSource` needs access to `_db.fragments`. It already holds `_db` (AppDatabase), and drift generates `fragments` accessor on the database. Confirm `FragmentsCompanion` has an `id` parameter — since `id` is `autoIncrement()`, `insert` companion makes it optional, which is correct.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/fragment/mirror_write_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/fragment/data/local/fragment_local_ds.dart app/lib/features/shared/data/local/app_database.dart app/lib/features/shared/data/local/app_database.g.dart app/test/fragment/mirror_write_test.dart
git commit -m "feat: add FragmentLocalDataSource.mirrorInsert for online->local write"
```

---

### Task 11: FragmentRepository 在线路径镜像写入

**Files:**
- Modify: `app/lib/features/fragment/data/fragment_repository.dart`
- Test: `app/test/fragment/mirror_write_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `app/test/fragment/mirror_write_test.dart`:

```dart
  test('online createFragment mirrors to local drift', () async {
    // This test uses a stubbed ApiClient + AuthRepository.
    // See test/helpers/stub_api_client.dart and stub_auth.dart.
    final api = StubApiClient();
    final auth = StubAuthRepository(loggedIn: true);
    api.postResponse = {
      'id': 99,
      'content_text': 'online',
      'emotion': '平静',
      'tags': [],
      'media_urls': [],
      'created_at': '2026-07-10T00:00:00Z',
      'status': 'twilight',
    };
    final repo = FragmentRepository(api, auth, db: db);
    final created = await repo.createFragment(
      text: 'online',
      emotion: '平静',
      tags: const [],
    );
    expect(created.id, 99);
    // Mirrored to local:
    final local = await ds.getAll();
    expect(local, hasLength(1));
    expect(local.first.id, 99);
    expect(local.first.contentText, 'online');
  });
```

Create `app/test/helpers/stub_api_client.dart` and `app/test/helpers/stub_auth.dart` as minimal stubs matching `ApiClient` and `AuthRepository` interfaces. Read those interfaces first to match method signatures.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/fragment/mirror_write_test.dart --name "online createFragment mirrors"`
Expected: FAIL — local drift is empty after online create (current behavior doesn't mirror).

- [ ] **Step 3: Add mirror write to online create path**

In `app/lib/features/fragment/data/fragment_repository.dart`, in `createFragment`, the online branch (after `final body = await _api.post(...)`):

```dart
if (_api.hasToken) {
  final body = await _api.post('/fragments', {
    'content_text': text,
    'emotion': emotion,
    'tag_names': tags,
    'media_urls': mediaUrls,
    'client_op_id': 'flutter-${DateTime.now().microsecondsSinceEpoch}',
  });
  final model = LightFragmentModel.fromJson(body);
  // 镜像写入本地 drift，保证断网后仍可回看。
  await _localDs.mirrorInsert(model, publicId: '${model.id}');
  return model;
}
```

Also add mirror write to `updateFragmentText` online path (after `_api.put` succeeds, `_localDs.update(updated)` is already called — verify it's there; if not, add it).

Also in `deleteFragment` online path, `_localDs.delete(id)` is already called at the end — verify.

> **Note on publicId:** The REST response includes `public_id` if the backend returns it. If the response JSON has `public_id`, use `body['public_id'] as String? ?? '${model.id}'`. Read the actual backend fragment response shape in `backend/internal/fragment/handler` to confirm the field name. If the backend doesn't return `public_id`, use the numeric id as a placeholder — this is a known tech-debt note for the mirror (local drift `publicId` column is underused).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/fragment/mirror_write_test.dart`
Expected: PASS (all mirror tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/fragment/data/fragment_repository.dart app/test/fragment/mirror_write_test.dart app/test/helpers/
git commit -m "fix: mirror online fragment writes to local drift for offline availability"
```

---

## Phase 4：冲突闭环（前后端）

### Task 12: 后端 — domain 加 ConflictInfo + PushResult.Conflict 字段

**Files:**
- Modify: `backend/internal/sync/domain/sync.go`

- [ ] **Step 1: Add ConflictInfo struct and Conflict field to PushResult**

In `backend/internal/sync/domain/sync.go`, add after `PushResult`:

```go
type PushResult struct {
	ClientOpID string        `json:"client_op_id"`
	Status     string        `json:"status"` // "applied" | "conflict" | "failed"
	ServerRev  int64         `json:"server_rev,omitempty"`
	Conflict   *ConflictInfo `json:"conflict,omitempty"`
}

type ConflictInfo struct {
	CurrentVersion  map[string]any `json:"current_version"`
	IncomingVersion map[string]any `json:"incoming_version"`
	Reason          string         `json:"reason"`
}
```

(Remove the old `PushResult` definition — this replaces it.)

- [ ] **Step 2: Verify Go compilation**

Run: `cd backend && go build ./internal/sync/...`
Expected: Success.

- [ ] **Step 3: Commit**

```bash
git add backend/internal/sync/domain/sync.go
git commit -m "feat(sync): add ConflictInfo to PushResult domain"
```

---

### Task 13: 后端 — repository 加实体版本查询

**Files:**
- Modify: `backend/internal/sync/repository/repository.go`

- [ ] **Step 1: Add FindFragmentLatestRev to Repository interface and PG impl**

In `backend/internal/sync/repository/repository.go`, add to the `Repository` interface:

```go
// FindFragmentLatestRev returns the highest server_rev among oplog entries
// for the given fragment entity_id, or 0 if none found.
FindFragmentLatestRev(ctx context.Context, userID int64, entityID int64) (int64, error)
```

Add the PG implementation:

```go
func (r *PG) FindFragmentLatestRev(ctx context.Context, userID int64, entityID int64) (int64, error) {
	var rev int64
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(MAX(server_rev), 0) FROM oplog
		 WHERE user_id=$1 AND entity_type='fragment' AND entity_id=$2`,
		userID, entityID,
	).Scan(&rev)
	return rev, err
}
```

Also add a tx-scoped variant for use inside `executeFragmentInTx`:

```go
func findFragmentLatestRevInTx(ctx context.Context, tx pgx.Tx, userID int64, entityID int64) (int64, error) {
	var rev int64
	err := tx.QueryRow(ctx,
		`SELECT COALESCE(MAX(server_rev), 0) FROM oplog
		 WHERE user_id=$1 AND entity_type='fragment' AND entity_id=$2`,
		userID, entityID,
	).Scan(&rev)
	return rev, err
}
```

Also add a `FindFragmentCurrent` method to read the current fragment state (for the `current_version` in ConflictInfo):

```go
func (r *PG) FindFragmentCurrent(ctx context.Context, userID int64, entityID int64) (map[string]any, error) {
	var contentText, emotion string
	var updatedAt time.Time
	err := r.db.QueryRow(ctx,
		`SELECT content_text, emotion, updated_at FROM fragments
		 WHERE id=$1 AND user_id=$2 AND is_deleted=FALSE`,
		entityID, userID,
	).Scan(&contentText, &emotion, &updatedAt)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"content_text": contentText,
		"emotion":      emotion,
		"updated_at":   updatedAt,
	}, nil
}
```

Add to interface:

```go
FindFragmentCurrent(ctx context.Context, userID int64, entityID int64) (map[string]any, error)
```

- [ ] **Step 2: Verify Go compilation**

Run: `cd backend && go build ./internal/sync/...`
Expected: Success.

- [ ] **Step 3: Commit**

```bash
git add backend/internal/sync/repository/repository.go
git commit -m "feat(sync): add fragment version/current-state queries for conflict detection"
```

---

### Task 14: 后端 — service UPDATE/DELETE 冲突检查

**Files:**
- Modify: `backend/internal/sync/service/service.go`
- Test: `backend/internal/sync/service/service_test.go`

- [ ] **Step 1: Write the failing test**

Create `backend/internal/sync/service/service_test.go`:

```go
package service

import (
	"context"
	"testing"

	"xiguang/backend/internal/sync/domain"
)

func TestPush_UPDATE_StaleBaseRev_ReturnsConflict(t *testing.T) {
	// Setup: use a stub repository that returns a known latest rev.
	// See backend test helpers — adapt to the actual repo interface.
	repo := &stubRepo{
		fragmentLatestRev: 10,
		fragmentCurrent:   map[string]any{"content_text": "server", "emotion": "平静"},
	}
	svc := New(repo)

	resp := svc.Push(context.Background(), 1, domain.PushRequest{
		DeviceID: "dev-1",
		Operations: []domain.PushOperation{{
			ClientOpID:     "op-1",
			EntityType:     "fragment",
			OpType:         "UPDATE",
			EntityPublicID: "1",
			BaseServerRev:  5, // stale — server is at 10
			Payload:        map[string]any{"content_text": "local edit"},
		}},
	})

	if len(resp.Results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(resp.Results))
	}
	r := resp.Results[0]
	if r.Status != "conflict" {
		t.Fatalf("expected status=conflict, got %s", r.Status)
	}
	if r.Conflict == nil {
		t.Fatal("expected non-nil Conflict")
	}
	if r.Conflict.CurrentVersion["content_text"] != "server" {
		t.Fatalf("expected current_version content_text=server, got %v", r.Conflict.CurrentVersion["content_text"])
	}
}

func TestPush_UPDATE_CurrentBaseRev_Applied(t *testing.T) {
	repo := &stubRepo{
		fragmentLatestRev:    10,
		fragmentCurrent:      map[string]any{"content_text": "server", "emotion": "平静"},
		executedUpdateRev:    11,
	}
	svc := New(repo)

	resp := svc.Push(context.Background(), 1, domain.PushRequest{
		DeviceID: "dev-1",
		Operations: []domain.PushOperation{{
			ClientOpID:     "op-1",
			EntityType:     "fragment",
			OpType:         "UPDATE",
			EntityPublicID: "1",
			BaseServerRev:  10, // current
			Payload:        map[string]any{"content_text": "local edit"},
		}},
	})

	if resp.Results[0].Status != "applied" {
		t.Fatalf("expected applied, got %s", resp.Results[0].Status)
	}
}
```

Create the stub repo `backend/internal/sync/service/stub_repo_test.go`:

```go
package service

import (
	"context"

	"xiguang/backend/internal/sync/domain"
)

type stubRepo struct {
	fragmentLatestRev int64
	fragmentCurrent   map[string]any
	executedUpdateRev int64
	executedInsertRev int64
	executedDeleteRev int64
}

func (s *stubRepo) InsertOperation(ctx context.Context, userID int64, deviceID string, op domain.PushOperation) (int64, error) {
	return s.executedInsertRev, nil
}
func (s *stubRepo) PushFragmentOp(ctx context.Context, userID int64, deviceID string, op domain.PushOperation) (int64, error) {
	return s.executedUpdateRev, nil
}
func (s *stubRepo) FindSinceRev(ctx context.Context, userID int64, sinceRev int64, limit int) ([]domain.PullOperation, error) {
	return nil, nil
}
func (s *stubRepo) ExecuteFragmentInsert(ctx context.Context, userID int64, payload map[string]any) (int64, error) {
	return s.executedInsertRev, nil
}
func (s *stubRepo) ExecuteFragmentUpdate(ctx context.Context, userID int64, entityID int64, payload map[string]any) error {
	return nil
}
func (s *stubRepo) ExecuteFragmentDelete(ctx context.Context, userID int64, entityID int64) error {
	return nil
}
func (s *stubRepo) FindFragmentByPublicID(ctx context.Context, userID int64, publicID string) (int64, error) {
	return 1, nil
}
func (s *stubRepo) FindFragmentLatestRev(ctx context.Context, userID int64, entityID int64) (int64, error) {
	return s.fragmentLatestRev, nil
}
func (s *stubRepo) FindFragmentCurrent(ctx context.Context, userID int64, entityID int64) (map[string]any, error) {
	return s.fragmentCurrent, nil
}
func (s *stubRepo) FindMostRecentServerRev(ctx context.Context, userID int64) (int64, error) {
	return 0, nil
}
```

> **Note:** The stub must implement the full `repository.Repository` interface. Read `repository.go` interface definition and ensure all methods are stubbed. Add any missing methods.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && go test ./internal/sync/service/ -run TestPush_UPDATE`
Expected: FAIL — current service returns "applied" unconditionally.

- [ ] **Step 3: Implement conflict check in service**

In `backend/internal/sync/service/service.go`, modify `PushFragmentOp` flow. Since `PushFragmentOp` is in the repository, the conflict check must happen before calling it. Add the check in the service layer:

```go
func (s *Service) Push(ctx context.Context, userID int64, req domain.PushRequest) domain.PushResponse {
	results := []domain.PushResult{}
	var newRev int64
	for _, op := range req.Operations {
		if op.ClientOpID == "" {
			continue
		}

		// Conflict check for fragment UPDATE/DELETE.
		if op.EntityType == "fragment" && (op.OpType == "UPDATE" || op.OpType == "DELETE") {
			entityID, err := s.repo.FindFragmentByPublicID(ctx, userID, op.EntityPublicID)
			if err != nil {
				// Entity not found — treat as applied (idempotent delete) or failed (update).
				if op.OpType == "DELETE" {
					results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "applied"})
					continue
				}
				slog.Warn("sync push: fragment not found", "client_op_id", op.ClientOpID, "public_id", op.EntityPublicID)
				results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
				continue
			}
			latestRev, err := s.repo.FindFragmentLatestRev(ctx, userID, entityID)
			if err != nil {
				slog.Warn("sync push: version check failed", "err", err)
				results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
				continue
			}
			if op.BaseServerRev < latestRev {
				current, _ := s.repo.FindFragmentCurrent(ctx, userID, entityID)
				results = append(results, domain.PushResult{
					ClientOpID: op.ClientOpID,
					Status:     "conflict",
					Conflict: &domain.ConflictInfo{
						CurrentVersion:  current,
						IncomingVersion: op.Payload,
						Reason:          "base_server_version_stale",
					},
				})
				continue
			}
		}

		var rev int64
		var err error
		if op.EntityType == "fragment" {
			rev, err = s.repo.PushFragmentOp(ctx, userID, req.DeviceID, op)
		} else {
			if execErr := s.executeEntityOp(ctx, userID, op); execErr != nil {
				slog.Warn("sync push: entity op failed", "client_op_id", op.ClientOpID, "err", execErr)
				results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
				continue
			}
			rev, err = s.repo.InsertOperation(ctx, userID, req.DeviceID, op)
		}
		if err != nil {
			slog.Warn("sync push: op failed", "client_op_id", op.ClientOpID, "err", err)
			results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "failed"})
			continue
		}
		newRev = rev
		results = append(results, domain.PushResult{ClientOpID: op.ClientOpID, Status: "applied", ServerRev: rev})
	}
	return domain.PushResponse{Results: results, NewServerRev: newRev}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && go test ./internal/sync/service/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/sync/service/service.go backend/internal/sync/service/service_test.go backend/internal/sync/service/stub_repo_test.go
git commit -m "feat(sync): server-side conflict check on fragment UPDATE/DELETE"
```

---

### Task 15: 前端 — conflict_resolver 真实现 + 冲突副本生成

**Files:**
- Modify: `app/lib/features/sync/engine/conflict_resolver.dart`
- Modify: `app/lib/features/sync/engine/sync_engine.dart`
- Test: `app/test/sync/conflict_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/sync/conflict_resolver_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/fragment/data/local/fragment_local_ds.dart';
import 'package:xiguang/features/fragment/data/fragment_repository.dart';
import 'package:xiguang/features/shared/data/local/app_database.dart';
import 'package:xiguang/features/sync/engine/conflict_resolver.dart';
import 'package:xiguang/features/sync/domain/oplog.dart';

void main() {
  late AppDatabase db;
  late FragmentLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = FragmentLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('resolveConflict creates a conflict copy and removes the op from pending', () async {
    // Seed: server's current version is already in local drift (mirrored).
    await ds.mirrorInsert(
      LightFragmentModel(
        id: 10,
        contentText: 'server version',
        emotion: '平静',
        tags: const [],
        mediaUrls: const [],
        createdAt: DateTime(2026, 7, 10),
        status: 'twilight',
      ),
      publicId: 'pub-10',
    );

    final op = OpLog(
      clientOpId: 'op-conflict',
      entityType: 'fragment',
      opType: 'UPDATE',
      entityPublicId: '10',
      payload: {'content_text': 'local edit', 'emotion': '焦虑'},
      clientSeq: 1,
      baseServerVersion: 5,
    );

    final conflictInfo = {
      'current_version': {'content_text': 'server version', 'emotion': '平静'},
      'incoming_version': {'content_text': 'local edit', 'emotion': '焦虑'},
      'reason': 'base_server_version_stale',
    };

    final resolver = SyncConflictResolver(ds: ds);
    final result = await resolver.resolveConflict(op, conflictInfo);

    expect(result.handled, isTrue);
    // Conflict copy created with prefix.
    final all = await ds.getAll();
    expect(all, hasLength(2));
    final copy = all.firstWhere((f) => f.contentText.startsWith('⚠冲突副本'));
    expect(copy.contentText, contains('local edit'));
    // Original op should be marked for removal.
    expect(result.removeOp, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/sync/conflict_resolver_test.dart`
Expected: FAIL — `SyncConflictResolver` has no `resolveConflict` method, `ds` param doesn't exist.

- [ ] **Step 3: Implement conflict resolver**

Replace `app/lib/features/sync/engine/conflict_resolver.dart`:

```dart
import '../../fragment/data/fragment_repository.dart';
import '../../fragment/data/local/fragment_local_ds.dart';
import '../domain/oplog.dart';

/// 冲突解决结果。
class ConflictResolution {
  const ConflictResolution({required this.handled, required this.removeOp});
  final bool handled;
  final bool removeOp; // true: 从 pending 队列移除该 op
}

/// 按 CLAUDE.md §5.7 协议处理冲突：远端当前版本保留原位，本地版本另存为冲突副本。
class SyncConflictResolver {
  SyncConflictResolver({required this.ds});

  final FragmentLocalDataSource ds;

  /// 处理一条 conflict 结果。生成冲突副本光片，返回是否移除该 op。
  Future<ConflictResolution> resolveConflict(
    OpLog op,
    Map<String, dynamic> conflictInfo,
  ) async {
    final incoming = (conflictInfo['incoming_version'] as Map<String, dynamic>?) ?? op.payload;
    final contentText = (incoming['content_text'] as String?) ?? '';
    final emotion = (incoming['emotion'] as String?) ?? '说不清';

    // 生成本地冲突副本，正文前缀标记。
    final copy = LightFragmentModel(
      id: 0, // drift autoincrement
      contentText: '⚠冲突副本（$contentText）',
      emotion: emotion,
      tags: const [],
      mediaUrls: const [],
      createdAt: DateTime.now(),
      status: 'twilight',
    );
    await ds.insert(copy);

    return const ConflictResolution(handled: true, removeOp: true);
  }
}
```

- [ ] **Step 4: Wire conflict handling into SyncEngine.syncNow**

In `app/lib/features/sync/engine/sync_engine.dart`, in `_syncNowInternal`, after processing `acceptedIds` and `failedIds`, add conflict handling:

```dart
// After failedIds processing:
final conflictResults = results
    .whereType<Map<String, dynamic>>()
    .where((r) => r['status'] == 'conflict')
    .toList();

for (final r in conflictResults) {
  final clientOpId = r['client_op_id'] as String;
  final conflictInfo = (r['conflict'] as Map<String, dynamic>?) ?? {};
  final opIdx = _pendingOps.indexWhere((op) => op.clientOpId == clientOpId);
  if (opIdx != -1) {
    final op = _pendingOps[opIdx];
    final resolver = SyncConflictResolver(ds: _localDs);
    final resolution = await resolver.resolveConflict(op, conflictInfo);
    if (resolution.removeOp) {
      _pendingOps.removeAt(opIdx);
      await _db.deleteOpLog(clientOpId);
      AppLogger.warn('SYNC: created conflict copy for $clientOpId');
    }
  }
}
```

This requires SyncEngine to hold a `FragmentLocalDataSource`. Add it as a field:

```dart
// In constructor:
_localDs = FragmentLocalDataSource(db ?? AppDatabase());
// Add field:
late final FragmentLocalDataSource _localDs;
```

(If SyncEngine already creates a `FragmentLocalDataSource` internally for restore, reuse it.)

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/sync/conflict_resolver_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sync/engine/conflict_resolver.dart app/lib/features/sync/engine/sync_engine.dart app/test/sync/conflict_resolver_test.dart
git commit -m "feat: implement conflict copy generation per CLAUDE.md §5.7"
```

---

## Phase 5：错误处理接入（58 处 catch 批量修复）

> 本阶段是机械性批量修复。按 transformation type 分组，每组给出完整 pattern + 全部站点清单。每个 task 结束后 `dart analyze` + `flutter test` 必须保持绿。

### Task 16: 修复空 catch（7 处）

**Files:**（逐个处理）
- `app/lib/features/auth/data/session_storage.dart:94` — `} catch (_) {}` secure storage delete
- `app/lib/features/auth/data/session_storage.dart:111` — `} catch (_) {}` bundle read
- `app/lib/features/fragment/presentation/widgets/vinyl_widgets.dart:210` — `} catch (_) {}` audio pause
- `app/lib/features/fragment/presentation/pages/capture_page.dart:634` — `} catch (_) { // If recorder was already stopped... }`
- `app/lib/features/sync/engine/sync_engine.dart` — `checkConnection` `catch (_)` (line ~213)
- `app/lib/features/fragment/data/fragment_local_ds.dart:67` — `_decodeJsonList` `catch (_)`
- Scan for any remaining `catch (_) {}` with: `cd app && grep -rn "catch (_)" lib --include='*.dart'`

- [ ] **Step 1: Apply the transformation pattern to each site**

Pattern A — "尽力而为清理"（资源释放、可选读取）: narrow the exception type + `AppLogger.warn`:

```dart
// BEFORE:
} catch (_) {}

// AFTER:
} on Exception catch (e) {
  AppLogger.warn('secure storage delete failed', error: e);
}
```

Pattern B — JSON decode fallback（已有合理 fallback `return const []`）: keep fallback, add warn:

```dart
// BEFORE (fragment_local_ds.dart _decodeJsonList):
} catch (_) {
  return const [];
}

// AFTER:
} on FormatException catch (e) {
  AppLogger.warn('fragment tags JSON decode failed', error: e);
  return const [];
}
```

Pattern C — Connection check（sync_engine checkConnection）: the `catch (_)` should catch `AppException`/`DioException` and set `connected: false`:

```dart
// BEFORE:
} catch (_) {
  _status = _status.copyWith(connected: false, error: 'connection_failed');
  return false;
}

// AFTER:
} on Exception catch (e) {
  AppLogger.warn('sync connection check failed', error: e);
  _status = _status.copyWith(connected: false, error: 'connection_failed');
  return false;
}
```

For each of the 7 sites, read the surrounding code to choose A/B/C, apply, and add `import '../../shared/infra/app_logger.dart';` (path varies by file depth).

- [ ] **Step 2: Verify no empty catches remain**

Run: `cd app && grep -rn "catch (_)" lib --include='*.dart' | grep -v "on Exception"`
Expected: Only sites with narrow `on FormatException` etc. remain (acceptable). No bare `catch (_)`.

- [ ] **Step 3: Run analyze + tests**

Run: `cd app && dart analyze && flutter test`
Expected: No new issues, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix: replace 7 empty catches with logged warnings"
```

---

### Task 17: 修复 .then() 无错误分支 + fire-and-forget（10 处）

**Files:**
- `app/lib/features/sync/presentation/providers/sync_provider.dart:61` — `engine.syncNow().then(...)` no catchError (now in Task 9's refactor — verify)
- `app/lib/features/sync/presentation/providers/sync_providers.dart:79` — `engine.checkConnection().then(...)` no catchError
- 8 unawaited fire-and-forget sites — scan: `cd app && grep -rn "\.then(" lib --include='*.dart' | grep -v catchError`

- [ ] **Step 1: Apply pattern to each .then() without catchError**

Pattern:

```dart
// BEFORE:
engine.checkConnection().then((_) {
  ref.read(...);
});

// AFTER:
engine.checkConnection().then((_) {
  ref.read(...);
}).catchError((Object e) {
  AppLogger.warn('sync connection check failed', error: e);
});
```

- [ ] **Step 2: Apply pattern to fire-and-forget sites**

For unawaited Futures that are intentionally fire-and-forget, add explicit `unawaited()` + catchError:

```dart
// BEFORE:
ref.read(syncEngineProvider).syncNow();

// AFTER:
unawaited(
  ref.read(syncEngineProvider).syncNow().catchError((Object e) {
    AppLogger.warn('background sync failed', error: e);
  }),
);
```

Add `import 'dart:async';` for `unawaited`.

- [ ] **Step 3: Run analyze (unawaited_futures lint will catch remaining)**

Run: `cd app && dart analyze`
Expected: No `unawaited_futures` warnings.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "fix: add error branches to fire-and-forget Futures and .then() chains"
```

---

### Task 18: 修复选择性 DioException catch + 接入 AppException/showAppError

**Files:**
- `app/lib/features/island/presentation/pages/island_detail_page.dart:218` — only catches `DioException`
- `app/lib/features/fragment/presentation/pages/fragment_detail_page.dart` — `_polish()` inline `AIApi(ref.read(apiClientProvider))` + dynamic JSON access
- `app/lib/features/ai/presentation/pages/ai_build_islands_page.dart:43` — inline `AIApi(ref.read(apiClientProvider))`
- All repository `on DioException` catches in `fragment_repository.dart` (lines 275, 323, 355) — convert to AppException
- Remaining ~37 sites that show SnackBar without AppLogger — scan: `cd app && grep -rn "ScaffoldMessenger" lib/features --include='*.dart'`

- [ ] **Step 1: Convert repository DioException catches to AppException**

In `app/lib/features/fragment/data/fragment_repository.dart`, change each `on DioException` to throw/convert to AppException:

```dart
// BEFORE (listFragments):
} catch (e) {
  developer.log('listFragments remote failed, using local', error: e);
  return _localDs.getAll();
}

// AFTER:
} on DioException catch (e) {
  AppLogger.warn('listFragments remote failed, using local', error: e);
  return _localDs.getAll();
} on Exception catch (e) {
  AppLogger.warn('listFragments unexpected error, using local', error: e);
  return _localDs.getAll();
}
```

For `getFragment` (line 275) and `deleteFragment` (line 323) and `weave` (line 355) — same pattern: catch `DioException` + `Exception`, log via AppLogger, return fallback.

Remove the `import 'dart:developer' as developer;` — replaced by AppLogger.

- [ ] **Step 2: Fix island_detail_page selective catch**

In `app/lib/features/island/presentation/pages/island_detail_page.dart:218`:

```dart
// BEFORE:
} on DioException {
  // ...
}

// AFTER:
} on AppException catch (e) {
  AppLogger.warn('island detail load failed', error: e);
  if (context.mounted) showAppError(context, e);
  // ... fallback state
}
```

Remove `import 'package:dio/dio.dart';` from this file.

- [ ] **Step 3: Fix fragment_detail_page _polish() — extract AIApi to provider**

The inline `final api = AIApi(ref.read(apiClientProvider));` in `_polish()` violates the new Riverpod norm. Create a provider:

In `app/lib/features/ai/data/ai_repository_impl.dart` or `app/lib/app/providers.dart` (where `aiRepositoryProvider` already exists), add:

```dart
final aiApiProvider = Provider<AIApi>((ref) {
  return AIApi(ref.watch(apiClientProvider));
});
```

Then in `fragment_detail_page._polish()`:

```dart
// BEFORE:
final api = AIApi(ref.read(apiClientProvider));

// AFTER:
final api = ref.read(aiApiProvider);
```

Also fix the dynamic JSON access (`result['status']`, `result['polished_text']`) — convert to typed model or at minimum add `as String?` casts with null fallback. If the AI response shape is simple, define a small `PolishResult` class in the ai domain.

- [ ] **Step 4: Fix ai_build_islands_page _startAnalysis() — same provider extraction**

```dart
// BEFORE:
final api = AIApi(ref.read(apiClientProvider));

// AFTER:
final api = ref.read(aiApiProvider);
```

- [ ] **Step 5: Run analyze + tests**

Run: `cd app && dart analyze && flutter test`
Expected: Clean, all pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: convert selective DioException catches to AppException, extract AIApi provider"
```

---

### Task 19: 修复 oplog.dart invalid_annotation_target

**Files:**
- Modify: `app/lib/features/sync/domain/oplog.dart`

- [ ] **Step 1: Move @JsonSerializable to class level**

```dart
// app/lib/features/sync/domain/oplog.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'oplog.freezed.dart';
part 'oplog.g.dart';

/// 同步操作日志
@freezed
@JsonSerializable(fieldRename: FieldRename.snake)
class OpLog with _$OpLog {
  const factory OpLog({
    required String clientOpId,
    required String entityType,
    required String opType,
    required String entityPublicId,
    @Default({}) Map<String, dynamic> payload,
    @Default(0) int clientSeq,
    @Default(0) int baseServerVersion,
  }) = _OpLog;

  factory OpLog.fromJson(Map<String, dynamic> json) => _$OpLogFromJson(json);
}
```

- [ ] **Step 2: Regenerate + verify**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs && dart analyze lib/features/sync/domain/oplog.dart`
Expected: No `invalid_annotation_target` warning.

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/sync/domain/oplog.dart app/lib/features/sync/domain/oplog.freezed.dart app/lib/features/sync/domain/oplog.g.dart
git commit -m "fix: move @JsonSerializable to class level in OpLog"
```

---

## Phase 6：死代码清理

### Task 20: 删除死文件 + 修复 unused warnings

**Files:**
- Delete: `app/lib/features/fragment/data/fragment_repository_impl.dart`
- Delete: `app/lib/features/fragment/sync/conflict_resolver.dart`
- Delete: `app/lib/features/fragment/sync/oplog_generator.dart`
- Delete: `app/lib/features/timeline/data/timeline_local_dao.dart` (confirm no refs first)
- Delete: `app/lib/features/asr/` directory (empty)
- Modify: `app/lib/features/timeline/presentation/pages/time_river_page.dart` (remove `_FallbackTimeline`)
- Modify: `app/test/claude_constraints_test.dart` (remove dead file path references)
- Modify: `app/lib/features/starmap/domain/star_edge.dart` (remove unused import)
- Modify: `app/lib/features/starmap/domain/star_node.dart` (remove unused import)

- [ ] **Step 1: Confirm no references before deleting**

Run:
```bash
cd app
grep -rn "fragment_repository_impl" lib test --include='*.dart'
grep -rn "fragment/sync/conflict_resolver" lib test --include='*.dart'
grep -rn "oplog_generator" lib test --include='*.dart'
grep -rn "timeline_local_dao" lib test --include='*.dart'
```
Expected: Only references in `test/claude_constraints_test.dart` (which we'll update) or none. If any production code references them, stop and surface the finding.

- [ ] **Step 2: Delete the files**

```bash
cd app
rm lib/features/fragment/data/fragment_repository_impl.dart
rm lib/features/fragment/sync/conflict_resolver.dart
rm lib/features/fragment/sync/oplog_generator.dart
rm -rf lib/features/asr
# Only if step 1 confirmed no refs:
grep -rn "timeline_local_dao" lib test --include='*.dart' | grep -v "claude_constraints_test" || rm lib/features/timeline/data/timeline_local_dao.dart
# If fragment/sync/ directory is now empty:
rmdir lib/features/fragment/sync 2>/dev/null || true
```

- [ ] **Step 3: Remove _FallbackTimeline from time_river_page**

In `app/lib/features/timeline/presentation/pages/time_river_page.dart`, delete the `_FallbackTimeline` class (around line 551, flagged as `unused_element`).

- [ ] **Step 4: Remove unused imports in starmap domain**

In `app/lib/features/starmap/domain/star_edge.dart` line 1 and `star_node.dart` line 1, remove:
```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 5: Update claude_constraints_test.dart**

In `app/test/claude_constraints_test.dart`, find the reference to `'lib/features/fragment/data/fragment_repository_impl.dart'` (line ~172) and any other dead file paths. Remove those assertions or update them to assert the files do NOT exist:

```dart
// BEFORE:
test('CLAUDE fragment layer files are pinned', () {
  expect(File('lib/features/fragment/data/fragment_repository_impl.dart').existsSync(), isTrue);
  ...
});

// AFTER:
test('CLAUDE dead code is removed', () {
  expect(File('lib/features/fragment/data/fragment_repository_impl.dart').existsSync(), isFalse);
  expect(File('lib/features/fragment/sync/conflict_resolver.dart').existsSync(), isFalse);
  expect(File('lib/features/fragment/sync/oplog_generator.dart').existsSync(), isFalse);
});
```

Read the full `claude_constraints_test.dart` to find all dead-file references and update each.

- [ ] **Step 6: Fix api_client.dart unnecessary_getters_setters**

In `app/lib/features/shared/data/api_client.dart:34`, the analyzer flagged unnecessary getter/setter wrapping. Read the code and inline the field (remove the getter/setter, rename the private field to public).

- [ ] **Step 7: Fix time_river_page curly_braces warnings**

In `app/lib/features/timeline/presentation/pages/time_river_page.dart` lines 354, 356 — wrap single statements in braces:

```dart
// BEFORE:
if (cond)
  doThing();

// AFTER:
if (cond) {
  doThing();
}
```

- [ ] **Step 8: Run analyze + tests**

Run: `cd app && dart analyze && flutter test`
Expected: 0 issues, all tests pass.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: remove dead code and fix all dart analyze warnings"
```

---

## Phase 7：设计令牌守卫 + 严格 lint

### Task 21: 编写设计令牌守卫测试（先失败）

**Files:**
- Create: `app/test/design_token_guard_test.dart`

- [ ] **Step 1: Write the guard test**

```dart
// app/test/design_token_guard_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 设计令牌守卫：扫描 lib/features/ 和 lib/ui/composites/ 中的硬编码违规。
/// 豁免：文件级 // MOTION_EXEMPT: self-painted 头；行级 // non-motion: <理由> 注释。
/// 白名单目录（不扫）：lib/design/、lib/ui/primitives/、lib/ui/spaces/。
void main() {
  test('no hardcoded design tokens in features/ and ui/composites/', () {
    final violations = <String>[];
    final scanDirs = [
      Directory('lib/features'),
      Directory('lib/ui/composites'),
    ];

    for (final dir in scanDirs) {
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        _scanFile(entity, violations);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '设计令牌违规（${violations.length} 处）：\n${violations.join('\n')}',
    );
  });
}

void _scanFile(File file, List<String> violations) {
  final lines = file.readAsLinesSync();
  final path = file.path;
  bool fileExempt = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i < 5 && line.contains('MOTION_EXEMPT')) {
      fileExempt = true;
    }
    if (fileExempt) continue;

    // Line-level exemption: // non-motion: <reason>
    final lineExempt = line.contains('non-motion:');

    // §9.1 hardcoded color
    if (_hasMatch(line, RegExp(r"Color\(0x[0-9A-Fa-f]+")) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded Color(0x...) — use AppColors.*');
    }
    if (_hasMatch(line, RegExp(r'Colors\.(?!transparent)\w+')) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded Colors.xxx — use AppColors.*');
    }
    // §9.3 hardcoded fontSize / fontWeight / bare TextStyle
    if (_hasMatch(line, RegExp(r'fontSize:\s*\d')) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded fontSize — use AppText.*');
    }
    if (_hasMatch(line, RegExp(r'fontWeight:\s*FontWeight')) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded fontWeight — use AppText.*');
    }
    if (_hasMatch(line, RegExp(r'(?<!App)TextStyle\(')) && !lineExempt) {
      violations.add('$path:${i + 1}: bare TextStyle( — use AppText.*');
    }
    // §9.5 hardcoded borderRadius
    if (_hasMatch(line, RegExp(r'BorderRadius\.circular\(\s*\d')) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded BorderRadius.circular(number) — use AppRadius.*');
    }
    // §9.4 hardcoded EdgeInsets with numbers
    if (_hasMatch(line, RegExp(r'EdgeInsets\.(all|symmetric|fromLTRB)\([^)]*\d')) && !lineExempt) {
      // Allow if all numbers are AppSpacing references — check if digits appear outside AppSpacing
      if (RegExp(r':\s*\d').hasMatch(line) || RegExp(r'\s\d+[,)]').hasMatch(line)) {
        violations.add('$path:${i + 1}: hardcoded EdgeInsets with numbers — use AppSpacing.*');
      }
    }
    // §9.14 hardcoded Duration / Curves (non-motion exempt)
    if (_hasMatch(line, RegExp(r'Duration\((milliseconds|seconds):\s*\d')) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded Duration — use AppMotion.* or add // non-motion: reason');
    }
    if (_hasMatch(line, RegExp(r'Curves\.\w+')) && !lineExempt) {
      violations.add('$path:${i + 1}: hardcoded Curves.xxx — use AppMotion.easeIn/easeOut/microMovement/sine');
    }
  }
}

bool _hasMatch(String line, RegExp pattern) {
  // Skip comment-only lines.
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//') || trimmed.startsWith('*')) return false;
  return pattern.hasMatch(line);
}
```

- [ ] **Step 2: Run the guard test — expect FAIL (existing violations)**

Run: `cd app && flutter test test/design_token_guard_test.dart`
Expected: FAIL — lists all existing hardcoded token violations (30+).

- [ ] **Step 3: Commit the failing test**

```bash
git add app/test/design_token_guard_test.dart
git commit -m "test: add design token guard (failing — existing violations to fix)"
```

---

### Task 22: 修复存量令牌违规（分批，按 feature）

> 守卫测试会列出全部违规站点。按 feature 分批修复，每批修复后重跑守卫验证该 feature 清零。

**Files:**（守卫测试输出的完整站点清单 — 以下为审计已知站点，实际以守卫输出为准）

- `app/lib/features/fragment/presentation/pages/capture_page.dart:180-187` — 5 处 `withValues(alpha: .34/.13/.14/.10/.07)` — **注意：alpha 按 §9.6 合法，不违规**，跳过
- `app/lib/features/fragment/presentation/pages/capture_page.dart:410` — `height: 36` -> `SizedBox(height: AppSpacing.s10)` 或就近 token
- `app/lib/features/fragment/presentation/pages/capture_page.dart:869-870` — `width: 18, height: 18` -> icon size，确认是否该走图标规范
- `app/lib/features/fragment/presentation/pages/capture_page.dart:903` — `width: 32` -> token
- `app/lib/features/fragment/presentation/widgets/vinyl_widgets.dart:47` — `Duration(milliseconds: 5600)` -> 补 MOTION_EXEMPT 头（自绘黑胶旋转，§9.14 豁免）
- `app/lib/features/auth/presentation/pages/login_page.dart:79` — `Duration(seconds: 8)` -> 加 `// non-motion: API timeout` 行级豁免

- [ ] **Step 1: Add MOTION_EXEMPT header to vinyl_widgets.dart**

In `app/lib/features/fragment/presentation/widgets/vinyl_widgets.dart`, add after the imports:

```dart
// MOTION_EXEMPT: self-painted
// 此文件包含自绘动画：黑胶旋转 4200ms / 声波 5600ms / 音乐轨迹 4800ms / 唱针 360ms
// 豁免理由：黑胶/声波/音乐轨迹是互不对齐的长周期自绘动画，对齐 AppMotion 会导致机械感。
// 豁免规则参见 CLAUDE.md §9.14。
```

- [ ] **Step 2: Add line-level exemptions for non-motion Durations**

For `login_page.dart:79` (API timeout), `capture_page.dart:697` (Timer.periodic recording counter), and any other non-motion Durations (network timeout, retry backoff, business timers):

```dart
// BEFORE:
.timeout(const Duration(seconds: 8))

// AFTER:
.timeout(const Duration(seconds: 8)) // non-motion: API timeout
```

- [ ] **Step 3: Fix hardcoded dimensions in capture_page**

Read `capture_page.dart` around each flagged line, apply nearest-token per §9.4:

```dart
// BEFORE (line 410):
SizedBox(height: 36)

// AFTER (36 is closest to s14=14? No — use judgment: 36 is between md=16 and lg=24.
// If it's a button height, it should be 52 (ThemeData). If it's a small spacer,
// check context. Read the surrounding code to decide.
// Likely: SizedBox(height: AppSpacing.lg) if it's a section gap.
```

> **Important:** For each dimension, read the surrounding code and choose the semantically correct token. Do not blindly round. If 36 is a button height, use the button component (height 52). If it's a small gap, use `AppSpacing.md` (16) or `AppSpacing.lg` (24). Document each choice in the commit message.

- [ ] **Step 4: Fix all remaining violations reported by the guard**

Run the guard: `cd app && flutter test test/design_token_guard_test.dart`
For each violation in the output, read the line, apply the correct token or exemption. Repeat until the guard passes.

- [ ] **Step 5: Run guard — expect PASS**

Run: `cd app && flutter test test/design_token_guard_test.dart`
Expected: PASS (zero violations).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: eliminate all hardcoded design tokens in features/ and ui/composites/"
```

---

### Task 23: 升级 analysis_options.yaml + 严格 lint

**Files:**
- Modify: `app/analysis_options.yaml`

- [ ] **Step 1: Replace analysis_options.yaml**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true

linter:
  rules:
    prefer_const_constructors: false
    prefer_const_literals_to_create_immutables: false
    # ── 正确性 lint（对应审计 bug 模式）──
    unawaited_futures: true
    use_build_context_synchronously: true
    avoid_catches_without_on_clauses: true
    only_throw_errors: true
    cancel_subscriptions: true
    close_sinks: true
    avoid_dynamic_calls: true
    always_declare_return_types: true
    unnecessary_statements: true
    no_self_assignments: true
    throw_in_finally: true
    unrelated_type_equality_checks: true
    collection_methods_unrelated_type: true
    test_types_in_equals: true
    avoid_slow_async_io: true
```

- [ ] **Step 2: Run analyze — fix any new violations**

Run: `cd app && dart analyze`
Expected: May surface new violations from the strict lints. Fix each:

- `unawaited_futures`: add `unawaited()` or `await`
- `use_build_context_synchronously`: add `if (!context.mounted) return;` after await
- `avoid_catches_without_on_clauses`: change `catch (e)` to `on Exception catch (e)` or `on Object catch (e)`
- `avoid_dynamic_calls`: add explicit casts (`as Map<String, dynamic>`) or typed models
- `cancel_subscriptions`/`close_sinks`: add `cancel()`/`close()` in `dispose()`

Fix each violation. This may take several iterations.

- [ ] **Step 3: Verify zero analyze issues**

Run: `cd app && dart analyze`
Expected: "No issues found".

- [ ] **Step 4: Run full test suite**

Run: `cd app && flutter test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: enable strict-casts and 15 correctness lints, fix all violations"
```

---

## Phase 8：CLAUDE.md 对齐与补强

### Task 24: CLAUDE.md — 对齐现实

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update Flutter dependencies table**

In CLAUDE.md §二 技术栈 > "Flutter 端核心依赖" table, correct to match actual pubspec:

| 用途 | 包 |
|-----|---|
| 状态管理 | flutter_riverpod + riverpod_annotation + riverpod_generator |
| 本地数据库 | drift + sqlite3_flutter_libs |
| 数据模型 | freezed + freezed_annotation + json_serializable + json_annotation |
| 路由 | go_router |
| 网络 | dio |
| 图片选择+压缩 | image_picker + flutter_image_compress + cached_network_image |
| 文件选择 | file_picker |
| 录音 | record |
| 音频播放 | just_audio + audio_session |
| 安全存储 | flutter_secure_storage |
| 键值存储 | shared_preferences |
| 权限 | permission_handler |
| 崩溃上报 | sentry_flutter |
| 应用信息 | package_info_plus |
| 文件打开 | open_filex |
| 路径 | path_provider + path |

- [ ] **Step 2: Replace §3.2 Flutter 逐文件树 with layer-contract table**

Replace the entire `lib/` file tree under "Flutter 端 - 10 个 feature 模块" with:

```markdown
**Flutter 端 feature 分层契约**（不再维护逐文件清单——逐文件树已多次腐烂。

每个 feature 遵循 domain → data → presentation 三层：

| 层 | 职责 | 禁止 |
|---|---|---|
| domain/ | freezed 实体、repository 抽象接口、枚举 | 依赖任何 Flutter 包 |
| data/ | drift DAO、dio API、repository 实现、本地文件 IO | 含 UI 代码 |
| presentation/ | Riverpod provider、Widget、Page | 直接操作 DB/网络，只通过 provider 调 repository |

**现有 feature 清单**（15 个）：
ai · app_update · auth · emotion · fragment · island · profile · relation · space · starmap · stats · timeline · whitenoise · shared · sync

**本地持久化现状**：
- 单一 `AppDatabase`（drift）单例，3 张表：`Fragments`、`OpLogs`、`Emotions`
- auth: flutter_secure_storage（token）+ shared_preferences（状态）
- 其余 feature 无独立持久化（computed/API-only/config-only）

**domain 模型规则**：
- **新增** domain 模型必须 @freezed
- 存量手写模型（auth/island/starmap/stats/space/whitenoise/ai/app_update/emotion）不强制迁移，碰到再改
```

- [ ] **Step 3: Rewrite sync/data-flow section to match reality**

In CLAUDE.md §5.7 and §3.6, replace "本地优先" descriptions with:

```markdown
**数据流架构（实际）**：远端优先读 + 镜像写入 + 离线走 OpLog 队列 + 冲突副本

- 读路径：远端优先，失败回落本地 drift
- 写路径（在线）：REST 直接写服务端 -> 成功后镜像写本地 drift
- 写路径（离线）：写本地 drift + OpLog 入队 -> 联网后 sync push
- 冲突：服务端校验 base_server_version -> 落后返回 conflict -> 客户端生成冲突副本光片

**SyncEngine 语义**：
- device_id：首次生成 UUID 持久化，全生命周期稳定
- clientSeq：engine 递增分配并持久化，保证设备内顺序
- 并发：Mutex 串行化 enqueue/syncNow
- 失败处理：op 失败 ≥5 次转 parked（不再推送），用户可在设置页清除
- Timer：autoSync/nightMode Timer 住在 Riverpod provider 里，随 onDispose 清理
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: align CLAUDE.md Flutter sections with actual architecture"
```

---

### Task 25: CLAUDE.md — 新增错误处理 / Riverpod / 守卫规范

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add error handling norm section**

After §6.6 (AI 行为边界指令) or as a new §6.16:

```markdown
### 6.16 错误处理规范（铁律）

**禁止**：
- ❌ 空 catch（`catch (_) {}`）
- ❌ `catch (e)` 不带 `on` 窄化（用 `on Exception catch (e)` 或更具体类型）
- ❌ `.then(...)` 无 `.catchError()` 或 `await` 无 try/catch
- ❌ 只 catch `DioException` 的选择性处理（其他异常裸奔）
- ❌ 裸 `developer.log` / `debugPrint` / `print`

**必须**：
- data 层出口：`on DioException catch (e) -> throw NetworkException.fromDio(e)`；存储异常 -> `StorageException`
- presentation 层：`on AppException catch (e) { showAppError(context, e); }` + `if (!context.mounted) return;`
- 日志：全部走 `AppLogger.debug/warn/error`
- fire-and-forget：显式 `unawaited(future.catchError(...))` + 注释理由

参见 `lib/features/shared/domain/app_exception.dart`、`lib/features/shared/infra/app_logger.dart`、`lib/features/shared/presentation/app_error.dart`。
```

- [ ] **Step 2: Add Riverpod norm section**

```markdown
### 6.17 Riverpod 规范（铁律）

**禁止**：
- ❌ 文件级/全局可变状态（`Timer? _x`、单例、计数器）——必须住在带 `ref.onDispose` 的 provider 里
- ❌ 在 widget 方法内 inline `new` API/Repository（如 `AIApi(ref.read(apiClientProvider))`）——必须走 provider
- ❌ build 方法内 `ref.read`（用 `ref.watch`）；`ref.read` 仅限回调内
- ❌ StatefulWidget + setState 混合 ConsumerWidget 状态

**必须**：
- Timer/StreamSubscription 住在 provider 里，`ref.onDispose` 内 cancel
- 跨 widget 共享状态用 provider，不用 InheritedWidget + setState
- API/Repository 实例由 provider 构造（`final xxxProvider = Provider((ref) => Xxx(ref.watch(apiClientProvider)))`）
```

- [ ] **Step 3: Add guard mechanism section**

```markdown
### 6.18 机器强制层（守卫与 lint）

**设计令牌守卫**（`test/design_token_guard_test.dart`，随 `flutter test` 跑）：
- 扫描 `lib/features/` + `lib/ui/composites/` 中的硬编码 Color/fontSize/fontWeight/TextStyle/BorderRadius/EdgeInsets/Duration/Curves
- 白名单目录（不扫）：`lib/design/`、`lib/ui/primitives/`、`lib/ui/spaces/`
- 文件级豁免：首部 `// MOTION_EXEMPT: self-painted` 头（§9.14 自绘动画）
- 行级豁免：`// non-motion: <理由>`（网络超时、Timer.periodic 业务定时器、手势窗口判定）
- **违规 = CI 红**，不允许留 TODO

**严格 lint 集**（`analysis_options.yaml`）：
- `strict-casts: true`
- 正确性 lint：unawaited_futures、use_build_context_synchronously、avoid_catches_without_on_clauses、only_throw_errors、cancel_subscriptions、close_sinks、avoid_dynamic_calls 等 15 条
- `dart analyze` 必须零问题才能合入
```

- [ ] **Step 4: Update §9.14 MOTION_EXEMPT reference to point to guard**

In §9.14, add a note:

```markdown
**守卫强制**：本节规则由 `test/design_token_guard_test.dart` 机器强制。违规直接 `flutter test` 红。
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add error handling, Riverpod, and guard norms to CLAUDE.md"
```

---

## Phase 9：最终验收

### Task 26: 全量验收

- [ ] **Step 1: dart analyze zero issues**

Run: `cd app && dart analyze`
Expected: "No issues found!"

- [ ] **Step 2: flutter test all green**

Run: `cd app && flutter test`
Expected: All tests pass (existing 3 groups + new sync/mutex/conflict/mirror/exception/logger/error/guard tests).

- [ ] **Step 3: go test sync passes**

Run: `cd backend && go test ./internal/sync/... -v`
Expected: All tests pass (existing + new conflict tests).

- [ ] **Step 4: design token guard zero reports**

Run: `cd app && flutter test test/design_token_guard_test.dart`
Expected: PASS (zero violations).

- [ ] **Step 5: Manual smoke test — mirror write**

1. Launch app (online), capture a fragment.
2. Verify it appears in timeline.
3. Kill app, disable network, relaunch.
4. Verify the fragment is still visible (mirror write worked).
5. Re-enable network, verify sync pushes pending ops.

- [ ] **Step 6: Manual smoke test — conflict copy**

1. On device A, edit fragment X (content "v1" -> "v2").
2. On device B (or same device with stale base_server_version), edit fragment X ("v1" -> "v3") before sync pulls v2.
3. Trigger sync on device B.
4. Verify: fragment X shows "v2" (server version), a new "⚠冲突副本（v3）" fragment appears.

- [ ] **Step 7: Final commit + tag**

```bash
git add -A
git commit -m "chore: v0.3-arch refactor complete — all acceptance criteria met"
git tag v0.3-arch
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ 线①-1 错误处理统一（方案 B）→ Tasks 1-3, 16-18
- ✅ 线①-2 同步引擎六项修复 → Tasks 4-9 (device_id=6, clientSeq=6, incremental persist=7, mutex=7, parked=8, Timer=9)
- ✅ 镜像写入 → Tasks 10-11
- ✅ 冲突闭环前后端 → Tasks 12-15
- ✅ 线② 严格 lint + 守卫 → Tasks 21-23
- ✅ 线③ CLAUDE.md 对齐 + 补强 → Tasks 24-25
- ✅ 线④ 死代码清理 → Task 20
- ✅ 验收标准 5 项 → Task 26

**Type consistency check:**
- `AppException` hierarchy consistent across Tasks 1, 3, 16, 18
- `SyncStatus.failedCount/parkedCount` consistent across Tasks 4, 8
- `Mutex.synchronized` signature consistent across Tasks 5, 7, 8
- `FragmentLocalDataSource.mirrorInsert` signature consistent across Tasks 10, 11, 15
- `SyncConflictResolver.resolveConflict` returns `ConflictResolution` consistent across Task 15
- Go `domain.PushResult.Conflict` / `ConflictInfo` consistent across Tasks 12-14

**Known scope boundaries:**
- 58 处 catch 接入和 30+ 令牌修复是机械性批量工作，按 transformation pattern 分组而非逐站点 TDD（对机械重构 TDD 不适用，验证靠 analyze + 守卫 + 现有测试保持绿）
- 守卫测试的违规站点清单在 Task 21 运行后由测试输出动态确定，Task 22 的站点列表是审计已知子集，实际以守卫输出为准
