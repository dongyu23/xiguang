import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/data/local/app_database.dart' hide OpLog;
import '../data/sync_api.dart';
import '../domain/oplog.dart';
import '../domain/sync_config.dart';
import '../domain/sync_status.dart';

class SyncEngine {
  SyncEngine(
      {required SyncApi api, required SyncConfig config, AppDatabase? db})
      : _api = api,
        _config = config,
        _db = db ?? AppDatabase();

  final SyncApi _api;
  final AppDatabase _db;
  SyncConfig _config;
  final List<OpLog> _pendingOps = [];
  Future<void> _pendingPersistence = Future<void>.value();
  int _seq = 0;

  SyncStatus _status = const SyncStatus(
    lastServerRev: 0,
    pendingCount: 0,
    lastSyncAt: null,
    isSyncing: false,
    connected: false,
  );

  SyncStatus get status => _status;
  SyncConfig get config => _config;
  bool get hasPending => _pendingOps.isNotEmpty;

  void Function()? onStatusChanged;

  /// 新的本地操作入队后调用；恢复历史队列时不触发。
  void Function()? onOperationEnqueued;

  /// Pull 完成后调用（有新数据时），供上层刷新本地缓存
  void Function()? onRemoteChangesApplied;

  void _notifyStatus() {
    onStatusChanged?.call();
  }

  void updateConfig(SyncConfig config) {
    _config = config;
  }

  /// 记录一次本地写操作，入队待推送。
  /// C9: Compaction — merge multiple UPDATE ops for the same entity into the latest one.
  void enqueue(OpLog op) {
    // Compaction: if there's already an UPDATE for this entity, replace it
    if (op.opType == 'UPDATE' || op.opType == 'update') {
      final existingIdx = _pendingOps.indexWhere((e) =>
          e.entityType == op.entityType &&
          e.entityPublicId == op.entityPublicId &&
          (e.opType == 'UPDATE' || e.opType == 'update'));
      if (existingIdx != -1) {
        _pendingOps[existingIdx] = op;
        developer.log(
            'SYNC: compacted UPDATE ${op.entityType}#${op.entityPublicId}');
        _notifyStatus();
        _persistPendingOps();
        onOperationEnqueued?.call();
        return;
      }
    }
    developer.log(
        'SYNC: enqueue ${op.opType} ${op.entityType}#${op.entityPublicId} (pending=${_pendingOps.length + 1})');
    _pendingOps.add(op);
    _status = SyncStatus(
      lastServerRev: _status.lastServerRev,
      pendingCount: _pendingOps.length,
      lastSyncAt: _status.lastSyncAt,
      isSyncing: _status.isSyncing,
      connected: _status.connected,
      error: _status.error,
    );
    _notifyStatus();
    _persistPendingOps();
    onOperationEnqueued?.call();
  }

  /// 应用启动时调用，从本地存储恢复未推送的 OpLog 和 lastServerRev。
  Future<void> restorePendingOps() async {
    await _restoreSyncMeta();
    // C3/H11: Read from drift OpLogs table instead of SharedPreferences
    try {
      final rows = await _db.getPendingOps();
      for (final row in rows) {
        _pendingOps.add(OpLog(
          clientOpId: row.clientOpId,
          entityType: row.entityType,
          opType: row.opType,
          entityPublicId: row.entityPublicId,
          payload: jsonDecode(row.payload) as Map<String, dynamic>,
          clientSeq: row.clientSeq,
          baseServerVersion: row.baseServerVersion,
        ));
      }
      if (_pendingOps.isNotEmpty) {
        _seq = _pendingOps
            .map((op) => op.clientSeq)
            .reduce((a, b) => a > b ? a : b);
        _status = _status.copyWith(pendingCount: _pendingOps.length);
        _notifyStatus();
      }
    } catch (e) {
      developer.log('SYNC: restorePendingOps failed — $e');
    }
  }

  /// 执行一次完整的 push → pull 同步周期。
  Future<SyncStatus> syncNow() async {
    if (_status.isSyncing) return _status;
    _status = SyncStatus(
      lastServerRev: _status.lastServerRev,
      pendingCount: _pendingOps.length,
      lastSyncAt: _status.lastSyncAt,
      isSyncing: true,
      connected: _status.connected,
    );
    var hasRemoteChanges = false;
    try {
      await _pendingPersistence;
      // 1. Push 本地待推送的 OpLog
      if (_pendingOps.isNotEmpty) {
        final ops = _pendingOps.toList();
        developer.log(
            'SYNC: pushing ${ops.length} ops, first op: ${ops.first.clientOpId}');
        final body = <String, dynamic>{
          'device_id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
          'operations': ops.map((op) => op.toJson()).toList(),
        };
        final result = await _api.push(body);
        final results = result['results'] as List<dynamic>? ?? [];
        final newRev = (result['new_server_rev'] as num?)?.toInt() ??
            _status.lastServerRev;
        developer.log(
            'SYNC: push response — ${results.length} results, newRev=$newRev');

        // 清除已接受的 op
        final acceptedIds = results
            .whereType<Map<String, dynamic>>()
            .where((r) => r['status'] == 'applied')
            .map((r) => r['client_op_id'] as String)
            .toSet();
        final failedCount = results.length - acceptedIds.length;
        developer
            .log('SYNC: accepted=${acceptedIds.length}, failed=$failedCount');
        _pendingOps.removeWhere((op) => acceptedIds.contains(op.clientOpId));
        await _persistPendingOps();
        developer.log('SYNC: after push, pendingCount=${_pendingOps.length}');

        _status = _status.copyWith(lastServerRev: newRev);
      } else {
        developer.log('SYNC: no pending ops to push');
      }

      // 2. Pull 远端增量
      final pullResult = await _api.pull(sinceRev: _status.lastServerRev);
      final operations = pullResult['operations'] as List<dynamic>? ?? [];
      final nextRev = (pullResult['next_since_rev'] as num?)?.toInt() ??
          _status.lastServerRev;
      hasRemoteChanges =
          operations.isNotEmpty || nextRev > _status.lastServerRev;

      if (hasRemoteChanges) {
        _status = _status.copyWith(lastServerRev: nextRev);
      }

      _status = SyncStatus(
        lastServerRev: _status.lastServerRev,
        pendingCount: _pendingOps.length,
        lastSyncAt: DateTime.now(),
        isSyncing: false,
        connected: true,
      );
    } catch (e) {
      developer.log('SYNC: failed — $e');
      _status = SyncStatus(
        lastServerRev: _status.lastServerRev,
        pendingCount: _pendingOps.length,
        lastSyncAt: _status.lastSyncAt,
        isSyncing: false,
        // 只有真正的网络/连接错误才标记未连接。
        // 服务器返回 4xx/5xx 或数据解析错误时，连接本身是通的，
        // 不应覆盖 connected（否则登录后 sync 接口报错会误显“后端未连接”）。
        connected: _isConnectionError(e) ? false : _status.connected,
        error: e.toString(),
      );
    }

    _notifyStatus();
    _persistSyncMeta();
    if (hasRemoteChanges) {
      onRemoteChangesApplied?.call();
    }
    return _status;
  }

  /// 检查到服务器的连通性。
  Future<bool> checkConnection() async {
    try {
      final s = await _api.status();
      final rev = (s['server_rev'] as num?)?.toInt() ?? 0;
      if (rev > _status.lastServerRev) {
        _status = _status.copyWith(lastServerRev: rev);
      }
      _status = _status.copyWith(connected: true, error: null);
      _notifyStatus();
      return true;
    } catch (_) {
      _status = _status.copyWith(connected: false, error: 'connection_failed');
      _notifyStatus();
      return false;
    }
  }

  /// 生成下一个 client_op_id。
  String nextOpId(String entityType, String opType) {
    _seq++;
    return '$entityType-${opType.toLowerCase()}-$_seq-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 返回当前 server_rev（用于 OpLog 的 base_server_version）。
  int get currentServerRev => _status.lastServerRev;

  // ── C3/H11: OpLog 持久化 — drift table instead of SharedPreferences ──

  static const _lastServerRevKey = 'xiguang.sync.last_server_rev';
  static const _lastSyncAtKey = 'xiguang.sync.last_sync_at';

  Future<void> _persistPendingOps() {
    final snapshot = List<OpLog>.of(_pendingOps);
    _pendingPersistence = _pendingPersistence.then((_) async {
      await _db.clearOpLogs();
      for (final op in snapshot) {
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
    });
    return _pendingPersistence;
  }

  Future<void> _persistSyncMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastServerRevKey, _status.lastServerRev);
    if (_status.lastSyncAt != null) {
      await prefs.setString(
          _lastSyncAtKey, _status.lastSyncAt!.toIso8601String());
    }
  }

  /// 启动时恢复 lastServerRev，避免全量重拉。
  Future<void> _restoreSyncMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final rev = prefs.getInt(_lastServerRevKey) ?? 0;
    final ts = prefs.getString(_lastSyncAtKey);
    if (rev > 0) {
      _status = _status.copyWith(
        lastServerRev: rev,
        lastSyncAt: ts != null ? DateTime.tryParse(ts) : null,
      );
    }
  }
}

// SyncStatus.copyWith is now generated by freezed.

/// 判断错误是否为真正的网络/连接错误（而非服务器返回的 4xx/5xx 或数据解析错误）。
/// 只有连接级错误才应将 `connected` 标记为 false -- 服务器报错时连接本身是通的。
bool _isConnectionError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }
  return false;
}
