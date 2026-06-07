import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../domain/oplog.dart';
import '../../domain/sync_config.dart';

/// 记录一次捕光操作的 OpLog 并入队。
void enqueueFragmentOp(WidgetRef ref, {
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
    clientSeq: 0,
    baseServerVersion: engine.currentServerRev,
  ));
  ref.read(syncStatusProvider.notifier).state = engine.status;
}

/// SyncEngine 会在配置的时机自动触发同步。
Timer? _autoSyncTimer;

void startAutoSync(WidgetRef ref) {
  _autoSyncTimer?.cancel();
  final config = ref.read(syncConfigProvider);
  if (!config.enabled) return;

  switch (config.frequency) {
    case SyncFrequency.onCapture:
      break;
    case SyncFrequency.every5Minutes:
      _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _doAutoSync(ref);
      });
    case SyncFrequency.hourly:
      _autoSyncTimer = Timer.periodic(const Duration(hours: 1), (_) {
        _doAutoSync(ref);
      });
    case SyncFrequency.onAppOpen:
      _doAutoSync(ref);
    case SyncFrequency.manual:
      break;
  }
}

void _doAutoSync(WidgetRef ref) {
  final engine = ref.read(syncEngineProvider);
  engine.syncNow().then((status) {
    ref.read(syncStatusProvider.notifier).state = status;
  });
}

void stopAutoSync() {
  _autoSyncTimer?.cancel();
  _autoSyncTimer = null;
}
