class SyncStatus {
  const SyncStatus({
    required this.lastServerRev,
    required this.pendingCount,
    required this.lastSyncAt,
    required this.isSyncing,
  });

  final int lastServerRev;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final bool isSyncing;
}
