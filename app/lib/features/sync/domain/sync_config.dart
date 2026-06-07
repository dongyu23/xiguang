/// 云同步配置，持久化在 SharedPreferences 中。
class SyncConfig {
  const SyncConfig({
    this.enabled = true,
    this.frequency = SyncFrequency.onCapture,
    this.wifiOnly = false,
    this.lastServerRev = 0,
  });

  final bool enabled;
  final SyncFrequency frequency;
  final bool wifiOnly;
  final int lastServerRev;

  SyncConfig copyWith({
    bool? enabled,
    SyncFrequency? frequency,
    bool? wifiOnly,
    int? lastServerRev,
  }) {
    return SyncConfig(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      lastServerRev: lastServerRev ?? this.lastServerRev,
    );
  }
}

enum SyncFrequency {
  /// 每次捕光后立即推送。
  onCapture('每次捕光时'),

  /// 每 5 分钟自动检查。
  every5Minutes('每 5 分钟'),

  /// 每小时自动检查。
  hourly('每小时'),

  /// 仅在打开 App 时推送。
  onAppOpen('打开 App 时'),

  /// 完全手动触发。
  manual('手动触发');

  const SyncFrequency(this.label);
  final String label;
}
