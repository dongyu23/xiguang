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
  onCapture('每次捕光后'),

  /// 每 5 分钟自动检查。
  every5Minutes('使用时每 5 分钟'),

  /// 每小时自动检查。
  hourly('使用时每小时'),

  /// 仅在打开 App 时推送。
  onAppOpen('打开或返回 App 时'),

  /// 旧版持久化值，仅用于迁移，不再展示。
  @Deprecated('关闭云同步后使用“立即同步”代替')
  manual('手动触发');

  const SyncFrequency(this.label);
  final String label;

  static const automaticValues = <SyncFrequency>[
    onCapture,
    every5Minutes,
    hourly,
    onAppOpen,
  ];
}
