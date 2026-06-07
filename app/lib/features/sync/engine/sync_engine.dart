import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/sync_api.dart';
import '../domain/oplog.dart';
import '../domain/sync_config.dart';
import '../domain/sync_status.dart';

class SyncEngine {
  SyncEngine({required SyncApi api, required SyncConfig config})
      : _api = api,
        _config = config;

  final SyncApi _api;
  SyncConfig _config;
  final List<OpLog> _pendingOps = [];
  int _seq = 0;

  SyncStatus _status = const SyncStatus(
    lastServerRev: 0,
    pendingCount: 0,
    lastSyncAt: null,
    isSyncing: false,
  );

  SyncStatus get status => _status;
  SyncConfig get config => _config;
  bool get hasPending => _pendingOps.isNotEmpty;

  void Function()? onStatusChanged;
  /// Pull 完成后调用（有新数据时），供上层刷新本地缓存
  void Function()? onRemoteChangesApplied;

  void _notifyStatus() {
    onStatusChanged?.call();
  }

  void updateConfig(SyncConfig config) {
    _config = config;
  }

  /// 记录一次本地写操作，入队待推送。
  void enqueue(OpLog op) {
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
  }

  /// 应用启动时调用，从本地存储恢复未推送的 OpLog 和 lastServerRev。
  Future<void> restorePendingOps() async {
    await _restoreSyncMeta();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOpsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final entry in list) {
        if (entry is Map<String, dynamic>) {
          _pendingOps.add(OpLog.fromJson(entry));
        }
      }
      if (_pendingOps.isNotEmpty) {
        _status = _status.copyWith(pendingCount: _pendingOps.length);
        _notifyStatus();
      }
    } catch (_) {
      await prefs.remove(_pendingOpsKey);
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
      // 1. Push 本地待推送的 OpLog
      if (_pendingOps.isNotEmpty) {
        final ops = _pendingOps.toList();
        final body = <String, dynamic>{
          'device_id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
          'operations': ops.map((op) => op.toJson()).toList(),
        };
        final result = await _api.push(body);
        final results = result['results'] as List<dynamic>? ?? [];
        final newRev = (result['new_server_rev'] as num?)?.toInt() ?? _status.lastServerRev;

        // 清除已接受的 op
        final acceptedIds = results
            .whereType<Map<String, dynamic>>()
            .where((r) => r['status'] == 'applied')
            .map((r) => r['client_op_id'] as String)
            .toSet();
        _pendingOps.removeWhere((op) => acceptedIds.contains(op.clientOpId));
        _persistPendingOps();

        _status = _status.copyWith(lastServerRev: newRev);
      }

      // 2. Pull 远端增量
      final pullResult = await _api.pull(sinceRev: _status.lastServerRev);
      final operations = pullResult['operations'] as List<dynamic>? ?? [];
      final nextRev = (pullResult['next_since_rev'] as num?)?.toInt() ?? _status.lastServerRev;
      hasRemoteChanges = operations.isNotEmpty || nextRev > _status.lastServerRev;

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
      _status = SyncStatus(
        lastServerRev: _status.lastServerRev,
        pendingCount: _pendingOps.length,
        lastSyncAt: _status.lastSyncAt,
        isSyncing: false,
        connected: false,
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
      _status = _status.copyWith(connected: true);
      return true;
    } catch (_) {
      _status = _status.copyWith(connected: false);
      return false;
    }
  }

  /// 生成下一个 client_op_id。
  String nextOpId(String entityType, String opType) {
    _seq++;
    return '${entityType}-${opType.toLowerCase()}-$_seq-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 返回当前 server_rev（用于 OpLog 的 base_server_version）。
  int get currentServerRev => _status.lastServerRev;

  // ── OpLog 持久化 ──

  static const _pendingOpsKey = 'xiguang.sync.pending_ops';
  static const _lastServerRevKey = 'xiguang.sync.last_server_rev';
  static const _lastSyncAtKey = 'xiguang.sync.last_sync_at';

  Future<void> _persistPendingOps() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pendingOps.isEmpty) {
      await prefs.remove(_pendingOpsKey);
      return;
    }
    await prefs.setString(
      _pendingOpsKey,
      jsonEncode(_pendingOps.map((op) => op.toJson()).toList()),
    );
  }

  Future<void> _persistSyncMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastServerRevKey, _status.lastServerRev);
    if (_status.lastSyncAt != null) {
      await prefs.setString(_lastSyncAtKey, _status.lastSyncAt!.toIso8601String());
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

extension _StatusCopy on SyncStatus {
  SyncStatus copyWith({
    int? lastServerRev,
    int? pendingCount,
    DateTime? lastSyncAt,
    bool? connected,
  }) {
    return SyncStatus(
      lastServerRev: lastServerRev ?? this.lastServerRev,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      isSyncing: isSyncing,
      connected: connected ?? this.connected,
      error: error,
    );
  }
}
