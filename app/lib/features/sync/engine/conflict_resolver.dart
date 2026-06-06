class SyncConflictResolver {
  bool canApply({required int baseServerVersion, required int serverVersion}) {
    return baseServerVersion >= serverVersion;
  }
}
