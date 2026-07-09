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
  }) = _SyncStatus;
}
