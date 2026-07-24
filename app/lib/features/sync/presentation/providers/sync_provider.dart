import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/motion.dart';
import '../../domain/oplog.dart';
import '../../domain/sync_config.dart';
import '../../domain/sync_status.dart';
import 'sync_providers.dart';

/// 记录一次捕光操作的 OpLog 并入队。
///
/// 云同步关闭时也必须保留本地变更；开关只决定是否自动发送。
void enqueueFragmentOp(
  WidgetRef ref, {
  required String opType,
  required String publicId,
  required Map<String, dynamic> payload,
}) {
  final engine = ref.read(syncEngineProvider);
  final opId = engine.nextOpId('fragment', opType);
  engine.enqueue(OpLog(
    clientOpId: opId,
    entityType: 'fragment',
    opType: opType,
    entityPublicId: publicId,
    payload: payload,
    clientSeq: 0,
    baseServerVersion: engine.currentServerRev,
  ));
  ref.read(syncStatusProvider.notifier).state = engine.status;
}

final syncConnectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

Timer? _autoSyncTimer;
StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

/// 启动当前配置对应的自动同步计时器和网络恢复监听。
void startAutoSync(WidgetRef ref) {
  stopAutoSync();
  final config = ref.read(syncConfigProvider);
  if (!config.enabled) return;

  var hadAllowedNetwork = false;
  var networkInitialized = false;
  final connectivity = ref.read(syncConnectivityProvider);
  connectivity.checkConnectivity().then((results) {
    hadAllowedNetwork = automaticNetworkAllowed(config, results);
    networkInitialized = true;
  });
  _connectivitySubscription = connectivity.onConnectivityChanged.listen(
    (results) {
      final current = ref.read(syncConfigProvider);
      final allowed = automaticNetworkAllowed(current, results);
      if (!networkInitialized) {
        hadAllowedNetwork = allowed;
        networkInitialized = true;
        return;
      }
      if (!hadAllowedNetwork &&
          allowed &&
          ref.read(syncEngineProvider).hasPending) {
        _doAutoSync(ref);
      }
      hadAllowedNetwork = allowed;
    },
  );

  switch (config.frequency) {
    case SyncFrequency.onCapture:
    case SyncFrequency.onAppOpen:
    case SyncFrequency.manual:
      break;
    case SyncFrequency.every5Minutes:
      _autoSyncTimer = Timer.periodic(AppTiming.syncEveryFiveMinutes, (_) {
        triggerAutoSync(ref, SyncFrequency.every5Minutes);
      });
    case SyncFrequency.hourly:
      _autoSyncTimer = Timer.periodic(AppTiming.syncHourly, (_) {
        triggerAutoSync(ref, SyncFrequency.hourly);
      });
  }
}

/// 仅当云同步开启、触发时机匹配且网络策略允许时执行。
Future<SyncStatus?> triggerAutoSync(
  WidgetRef ref,
  SyncFrequency trigger,
) async {
  final config = ref.read(syncConfigProvider);
  if (!config.enabled || config.frequency != trigger) return null;
  final results = await ref.read(syncConnectivityProvider).checkConnectivity();
  if (!automaticNetworkAllowed(config, results)) return null;
  return _doAutoSync(ref);
}

/// 用户明确点击“立即同步”时不受自动同步开关和 Wi-Fi 策略限制。
Future<SyncStatus> syncManually(WidgetRef ref) async {
  final status = await ref.read(syncEngineProvider).syncNow();
  ref.read(syncStatusProvider.notifier).state = status;
  return status;
}

bool automaticNetworkAllowed(
  SyncConfig config,
  List<ConnectivityResult> results,
) {
  if (!config.enabled || results.isEmpty) return false;
  if (results.contains(ConnectivityResult.none)) return false;
  if (!config.wifiOnly) return true;
  return results.contains(ConnectivityResult.wifi);
}

Future<SyncStatus> _doAutoSync(WidgetRef ref) async {
  final status = await ref.read(syncEngineProvider).syncNow();
  ref.read(syncStatusProvider.notifier).state = status;
  return status;
}

void stopAutoSync() {
  _autoSyncTimer?.cancel();
  _autoSyncTimer = null;
  _connectivitySubscription?.cancel();
  _connectivitySubscription = null;
}
