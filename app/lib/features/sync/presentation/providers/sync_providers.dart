import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/providers.dart';
import '../../data/sync_api.dart';
import '../../domain/oplog.dart';
import '../../domain/sync_config.dart';
import '../../domain/sync_status.dart';
import '../../engine/sync_engine.dart';

const _syncConfigEnabledKey = 'xiguang.sync.config.enabled';
const _syncConfigFrequencyKey = 'xiguang.sync.config.frequency';
const _syncConfigWifiOnlyKey = 'xiguang.sync.config.wifi_only';
const _syncConfigLastServerRevKey = 'xiguang.sync.config.last_server_rev';

final syncConfigProvider =
    StateNotifierProvider<SyncConfigNotifier, SyncConfig>((ref) {
  return SyncConfigNotifier();
});

class SyncConfigNotifier extends StateNotifier<SyncConfig> {
  SyncConfigNotifier() : super(const SyncConfig()) {
    _restore();
  }

  void update(SyncConfig config) {
    state = config;
    _persist(config);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final frequencyName = prefs.getString(_syncConfigFrequencyKey);
    final frequency = SyncFrequency.values.firstWhere(
      (item) => item.name == frequencyName,
      orElse: () => SyncFrequency.onCapture,
    );
    if (!mounted) return;
    state = SyncConfig(
      enabled: prefs.getBool(_syncConfigEnabledKey) ?? true,
      frequency: frequency,
      wifiOnly: prefs.getBool(_syncConfigWifiOnlyKey) ?? false,
      lastServerRev: prefs.getInt(_syncConfigLastServerRevKey) ?? 0,
    );
  }

  Future<void> _persist(SyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncConfigEnabledKey, config.enabled);
    await prefs.setString(_syncConfigFrequencyKey, config.frequency.name);
    await prefs.setBool(_syncConfigWifiOnlyKey, config.wifiOnly);
    await prefs.setInt(_syncConfigLastServerRevKey, config.lastServerRev);
  }
}

/// 全局 SyncEngine — 生命周期与应用一致，不随 URL/Config 变化重建
final syncEngineProvider = Provider<SyncEngine>((ref) {
  // 用 ref.read 而非 ref.watch：config 变化时不应重建引擎
  final config = ref.read(syncConfigProvider);
  final api = SyncApi(ref.read(apiClientProvider));
  final engine = SyncEngine(api: api, config: config, db: ref.read(appDatabaseProvider));

  // 初始同步
  ref.read(syncStatusProvider.notifier).state = engine.status;

  // 同步状态变化 → 更新 UI
  engine.onStatusChanged = () {
    ref.read(syncStatusProvider.notifier).state = engine.status;
  };

  // Pull 到远端变更后刷新本地缓存
  engine.onRemoteChangesApplied = () {
    ref.invalidate(fragmentsProvider);
    ref.invalidate(islandsProvider);
    ref.invalidate(localTimelineGroupsProvider);
  };

  // 异步探测连通性（不阻塞 UI）
  engine.checkConnection().then((_) {
    ref.read(syncStatusProvider.notifier).state = engine.status;
  });

  // Fragment 变更 → 入队 OpLog
  ref.read(fragmentRepositoryProvider).onFragmentChanged =
      (entityType, opType, fragmentId, payload) {
    final currentConfig = ref.read(syncConfigProvider);
    if (!currentConfig.enabled) return;
    // public_id (UUID) 优先，数字 id 兜底（离线 fragment 无 UUID）
    final publicId = (payload['public_id'] as String?) ?? fragmentId.toString();
    final op = OpLog(
      clientOpId: engine.nextOpId(entityType, opType),
      entityType: entityType,
      opType: opType,
      entityPublicId: publicId,
      payload: payload,
      clientSeq: 0,
      baseServerVersion: engine.currentServerRev,
    );
    engine.enqueue(op);
  };

  // 启动时恢复持久化状态
  engine.restorePendingOps();

  ref.onDispose(() {
    engine.onStatusChanged = null;
    engine.onRemoteChangesApplied = null;
    ref.read(fragmentRepositoryProvider).onFragmentChanged = null;
  });

  return engine;
});

/// 同步状态 — engine.onStatusChanged 中更新
final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return const SyncStatus(
    lastServerRev: 0,
    pendingCount: 0,
    lastSyncAt: null,
    isSyncing: false,
    connected: false,
  );
});

final syncNowProvider = FutureProvider.autoDispose<void>((ref) async {
  final engine = ref.read(syncEngineProvider);
  final newStatus = await engine.syncNow();
  ref.read(syncStatusProvider.notifier).state = newStatus;
});

final syncConnectionProvider = FutureProvider.autoDispose<bool>((ref) async {
  final engine = ref.read(syncEngineProvider);
  final ok = await engine.checkConnection();
  ref.read(syncStatusProvider.notifier).state = engine.status;
  return ok;
});
