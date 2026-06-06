import '../domain/sync_status.dart';

class SyncEngine {
  SyncStatus _status = const SyncStatus(
    lastServerRev: 0,
    pendingCount: 0,
    lastSyncAt: null,
    isSyncing: false,
  );

  SyncStatus get status => _status;

  Future<void> syncNow() async {
    _status = SyncStatus(
      lastServerRev: _status.lastServerRev,
      pendingCount: 0,
      lastSyncAt: DateTime.now(),
      isSyncing: false,
    );
  }
}
