import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../fragment/application/fragment_list_controller.dart';
import '../../island/application/island_providers.dart';
import '../../timeline/application/timeline_providers.dart';
import '../domain/oplog.dart';
import '../domain/sync_config.dart';
import '../domain/sync_status.dart';
import '../engine/sync_engine.dart';

const _enabledKey = 'xiguang.sync.config.enabled';
const _frequencyKey = 'xiguang.sync.config.frequency';
const _wifiOnlyKey = 'xiguang.sync.config.wifi_only';
const _lastServerRevKey = 'xiguang.sync.config.last_server_rev';

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
    final frequencyName = prefs.getString(_frequencyKey);
    final restoredFrequency = SyncFrequency.values.firstWhere(
      (item) => item.name == frequencyName,
      orElse: () => SyncFrequency.onCapture,
    );
    final wasManual = restoredFrequency == SyncFrequency.manual;
    final frequency = wasManual ? SyncFrequency.onCapture : restoredFrequency;
    final enabled = wasManual ? false : prefs.getBool(_enabledKey) ?? true;
    if (!mounted) return;
    state = SyncConfig(
      enabled: enabled,
      frequency: frequency,
      wifiOnly: prefs.getBool(_wifiOnlyKey) ?? false,
      lastServerRev: prefs.getInt(_lastServerRevKey) ?? 0,
    );
    if (wasManual) {
      await prefs.setBool(_enabledKey, false);
      await prefs.setString(_frequencyKey, frequency.name);
    }
  }

  Future<void> _persist(SyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, config.enabled);
    await prefs.setString(_frequencyKey, config.frequency.name);
    await prefs.setBool(_wifiOnlyKey, config.wifiOnly);
    await prefs.setInt(_lastServerRevKey, config.lastServerRev);
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final config = ref.read(syncConfigProvider);
  final engine = SyncEngine(
    api: ref.read(syncApiProvider),
    config: config,
    db: ref.read(appDatabaseProvider),
  );
  final fragmentRepository = ref.read(fragmentRepositoryProvider);

  ref.read(syncStatusProvider.notifier).state = engine.status;
  engine.onStatusChanged = () {
    ref.read(syncStatusProvider.notifier).state = engine.status;
  };
  engine.onRemoteChangesApplied = () {
    ref.invalidate(fragmentsProvider);
    ref.invalidate(islandsProvider);
    ref.invalidate(localTimelineGroupsProvider);
  };
  // 不在 provider 初始化时调 checkConnection()：此时 apiClient 还没有 token，
  // 必然失败（后端不通时还要等 10s connectTimeout）。连接检查由 app.dart 在
  // authRestore 完成和登录成功后分别触发。
  fragmentRepository.onFragmentChanged =
      (entityType, opType, fragmentId, payload) {
    final publicId = (payload['public_id'] as String?) ?? fragmentId.toString();
    engine.enqueue(OpLog(
      clientOpId: engine.nextOpId(entityType, opType),
      entityType: entityType,
      opType: opType,
      entityPublicId: publicId,
      payload: payload,
      clientSeq: 0,
      baseServerVersion: engine.currentServerRev,
    ));
  };
  engine.restorePendingOps();

  ref.onDispose(() {
    engine.onStatusChanged = null;
    engine.onRemoteChangesApplied = null;
    fragmentRepository.onFragmentChanged = null;
  });
  return engine;
});

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
  final status = await engine.syncNow();
  ref.read(syncStatusProvider.notifier).state = status;
});

final syncConnectionProvider = FutureProvider.autoDispose<bool>((ref) async {
  final engine = ref.read(syncEngineProvider);
  final connected = await engine.checkConnection();
  ref.read(syncStatusProvider.notifier).state = engine.status;
  return connected;
});
