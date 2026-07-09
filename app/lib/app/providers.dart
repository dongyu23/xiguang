import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ai/data/ai_api.dart';
import '../features/ai/data/ai_repository_impl.dart';
import '../features/space/data/space_api.dart';
import '../features/space/data/space_repository_impl.dart';
import '../features/timeline/data/timeline_api.dart';
import '../features/timeline/data/timeline_repository_impl.dart';
import '../features/shared/data/api_client.dart';
import '../features/shared/data/local/app_database.dart';

// Re-export all feature-level providers so existing imports don't break.
export '../features/auth/presentation/providers/auth_providers.dart';
export '../features/fragment/presentation/providers/fragment_providers.dart';
export '../features/timeline/presentation/providers/timeline_providers.dart';
export '../features/island/presentation/providers/island_providers.dart';
export '../features/sync/presentation/providers/sync_providers.dart';
export '../features/relation/presentation/providers/relation_providers.dart';
export '../features/stats/presentation/providers/stats_providers.dart';
export '../features/starmap/presentation/providers/starmap_providers.dart';
export '../features/whitenoise/presentation/providers/whitenoise_providers.dart';

const _apiBaseUrlPrefsKey = 'xiguang.api_base_url';

String normalizeApiBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.endsWith('/') && trimmed.length > 1) {
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
  return trimmed;
}

String? validateApiBaseUrl(String value) {
  final normalized = normalizeApiBaseUrl(value);
  if (normalized.isEmpty) return '请输入后端地址';
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '请输入完整地址，例如 http://192.168.1.2:8088/api/v1';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return '仅支持 http 或 https 地址';
  }
  if (!normalized.endsWith('/api/v1')) {
    return '地址需要以 /api/v1 结尾';
  }
  return null;
}

final apiBaseUrlProvider =
    AsyncNotifierProvider<ApiBaseUrlNotifier, String>(ApiBaseUrlNotifier.new);

/// 全局 AppDatabase 单例 - fragment / sync / emotion 三个模块共用同一实例，
/// 避免各自 new AppDatabase() 导致多连接打开同一 sqlite 文件（卡顿 + 锁竞争）。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

class ApiBaseUrlNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_apiBaseUrlPrefsKey);
    return normalizeApiBaseUrl(saved ?? ApiClient.defaultBaseUrl);
  }

  Future<void> save(String value) async {
    final error = validateApiBaseUrl(value);
    if (error != null) throw ArgumentError(error);
    final normalized = normalizeApiBaseUrl(value);
    state = AsyncData(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlPrefsKey, normalized);
  }

  Future<void> reset() async {
    final defaultUrl = normalizeApiBaseUrl(ApiClient.defaultBaseUrl);
    state = AsyncData(defaultUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiBaseUrlPrefsKey);
  }
}

final _apiClient = ApiClient();

final apiClientProvider = Provider<ApiClient>((ref) {
  // reactively rebuild when apiBaseUrlProvider changes — no ref.listen leak
  final urlAsync = ref.watch(apiBaseUrlProvider);
  final url = urlAsync.valueOrNull ?? _apiClient.baseUrl;
  final normalized = normalizeApiBaseUrl(url);
  if (normalized.isNotEmpty && normalized != _apiClient.baseUrl) {
    _apiClient.updateBaseUrl(normalized);
  }
  return _apiClient;
});

/// 夜间模式选项
enum NightModeOption {
  /// 跟随系统时间自动切换（6:00-18:00 日间，其余夜间）
  system,

  /// 强制日间模式
  light,

  /// 强制夜间模式
  dark,
}

/// 夜间模式选项 Provider — 存储用户选择的模式
final nightModeOptionProvider = StateProvider<NightModeOption>(
  (ref) => NightModeOption.system,
);

/// 夜间模式初始化：从磁盘读取上次状态，并启动定时器
final nightModeLoadedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // 读取模式选项（兼容旧版本：如果没有 option 字段，根据 night_mode 推断）
  final optionIndex = prefs.getInt('xiguang.night_mode_option');
  NightModeOption option;
  if (optionIndex != null) {
    option = NightModeOption.values[optionIndex];
  } else {
    // 兼容旧版本：如果之前保存了 night_mode，转换为对应选项
    final oldNightMode = prefs.getBool('xiguang.night_mode') ?? false;
    option = oldNightMode ? NightModeOption.dark : NightModeOption.system;
  }
  ref.read(nightModeOptionProvider.notifier).state = option;

  // 计算当前夜间模式状态
  final isNight = _resolveNightMode(option);
  ref.read(nightModeProvider.notifier).state = isNight;

  // 启动定时器，每分钟检查一次（用于 system 模式）
  _startAutoSwitchTimer(ref);

  return isNight;
});

/// 根据选项解析当前是否为夜间模式
bool _resolveNightMode(NightModeOption option) {
  switch (option) {
    case NightModeOption.system:
      final hour = TimeOfDay.now().hour;
      // 6:00-18:00 日间，其余夜间
      return hour < 6 || hour >= 18;
    case NightModeOption.light:
      return false;
    case NightModeOption.dark:
      return true;
  }
}

Timer? _autoSwitchTimer;

/// 启动自动切换定时器
void _startAutoSwitchTimer(Ref ref) {
  _autoSwitchTimer?.cancel();
  _autoSwitchTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    final option = ref.read(nightModeOptionProvider);
    if (option == NightModeOption.system) {
      final isNight = _resolveNightMode(option);
      ref.read(nightModeProvider.notifier).state = isNight;
    }
  });
}

/// 停止自动切换定时器（用于测试或清理）
void stopAutoSwitchTimer() {
  _autoSwitchTimer?.cancel();
  _autoSwitchTimer = null;
}

final nightModeProvider = StateProvider<bool>((ref) => false);

/// 持久化夜间模式选项到磁盘
Future<void> persistNightModeOption(NightModeOption option) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('xiguang.night_mode_option', option.index);
  // 同时保存 night_mode 以兼容旧版本
  await prefs.setBool('xiguang.night_mode', _resolveNightMode(option));
}

/// 更新夜间模式选项并立即生效
Future<void> updateNightModeOption(
    WidgetRef ref, NightModeOption option) async {
  ref.read(nightModeOptionProvider.notifier).state = option;
  final isNight = _resolveNightMode(option);
  ref.read(nightModeProvider.notifier).state = isNight;
  await persistNightModeOption(option);
}

final aiPolishEnabledProvider = StateProvider<bool>((ref) => false);
final activeTabIndexProvider = StateProvider<int>((ref) => 0);

/// 点击当前标签页时递增，触发对应页面滚动到顶部。
final scrollToTopSignalProvider = StateProvider<int>((ref) => 0);

// ── Repository providers that remain here ──

final aiRepositoryProvider = Provider<AIRepositoryImpl>((ref) {
  return AIRepositoryImpl(AIApi(ref.watch(apiClientProvider)));
});

final timelineRepositoryProvider = Provider<TimelineRepositoryImpl>((ref) {
  return TimelineRepositoryImpl(TimelineApi(ref.watch(apiClientProvider)));
});

final spaceRepositoryProvider = Provider<SpaceRepositoryImpl>((ref) {
  return SpaceRepositoryImpl(SpaceApi(ref.watch(apiClientProvider)));
});
