import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/ai/data/ai_api.dart';
import '../features/ai/data/ai_repository_impl.dart';
import '../features/ai/domain/ai_repository.dart';
import '../features/app_update/data/app_update_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/emotion/data/emotion_repository.dart';
import '../features/emotion/domain/emotion_repository.dart';
import '../features/fragment/data/fragment_repository_impl.dart';
import '../features/fragment/domain/fragment_repository.dart';
import '../features/island/data/island_repository.dart';
import '../features/island/domain/island_repository.dart';
import '../features/profile/data/local_archive_exporter.dart';
import '../features/profile/domain/local_archive_repository.dart';
import '../features/relation/data/relation_api.dart';
import '../features/relation/data/relation_repository_impl.dart';
import '../features/relation/domain/relation_repository.dart';
import '../features/reminder/data/local_reminder_service.dart';
import '../features/reminder/domain/local_reminder_port.dart';
import '../features/space/data/space_api.dart';
import '../features/space/data/space_repository_impl.dart';
import '../features/starmap/data/starmap_api.dart';
import '../features/starmap/data/starmap_repository_impl.dart';
import '../features/starmap/domain/starmap_repository.dart';
import '../features/stats/data/stats_api.dart';
import '../features/stats/data/stats_repository_impl.dart';
import '../features/sync/data/sync_api.dart';
import '../features/timeline/data/timeline_api.dart';
import '../features/timeline/data/timeline_repository_impl.dart';
import '../features/whitenoise/data/whitenoise_api.dart';
import '../features/whitenoise/data/whitenoise_repository_impl.dart';
import '../features/whitenoise/domain/whitenoise_repository.dart';
import '../features/shared/data/api_client.dart';
import '../features/shared/data/local/app_database.dart';

const _apiBaseUrlPrefsKey = 'xiguang.api_base_url';
const _legacyApiBaseUrls = <String>{
  'http://101.35.113.175:8088/api/v1',
  'http://192.168.5.200:8088/api/v1',
  'http://127.0.0.1:8088/api/v1',
};

String normalizeApiBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.endsWith('/') && trimmed.length > 1) {
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }
  return trimmed;
}

String resolveInitialApiBaseUrl(String? saved) {
  final normalized = saved == null ? '' : normalizeApiBaseUrl(saved);
  if (normalized.isEmpty || _legacyApiBaseUrls.contains(normalized)) {
    return normalizeApiBaseUrl(ApiClient.defaultBaseUrl);
  }
  return normalized;
}

String? validateApiBaseUrl(String value) {
  final normalized = normalizeApiBaseUrl(value);
  if (normalized.isEmpty) return '请输入后端地址';
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '请输入完整地址，例如 https://api.frozenfish.cn/api/v1';
  }
  if (uri.scheme != 'https') {
    return '后端地址必须使用 HTTPS';
  }
  final isIpv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(uri.host);
  final isDomain =
      RegExp(r'^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$').hasMatch(uri.host);
  if (isIpv4 || !isDomain) {
    return '请使用 HTTPS 域名，不要直接填写 IP 地址';
  }
  if (uri.path != '/api/v1' || uri.hasQuery || uri.hasFragment) {
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
    final resolved = resolveInitialApiBaseUrl(saved);
    if (saved != null && normalizeApiBaseUrl(saved) != resolved) {
      await prefs.remove(_apiBaseUrlPrefsKey);
    }
    return resolved;
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

// ── Repository providers that remain here ──

final aiRepositoryProvider = Provider<AIRepositoryPort>((ref) {
  return AIRepositoryImpl(AIApi(ref.watch(apiClientProvider)));
});

final timelineRepositoryProvider = Provider<TimelineRepositoryImpl>((ref) {
  return TimelineRepositoryImpl(TimelineApi(ref.watch(apiClientProvider)));
});

final spaceRepositoryProvider = Provider<SpaceRepositoryImpl>((ref) {
  return SpaceRepositoryImpl(SpaceApi(ref.watch(apiClientProvider)));
});

final authRepositoryProvider = Provider<AuthRepositoryContract>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final emotionRepositoryProvider = Provider<EmotionRepositoryPort>((ref) {
  return EmotionRepository(ref.watch(appDatabaseProvider));
});

final fragmentRepositoryProvider = Provider<FragmentRepositoryContract>((ref) {
  return FragmentRepositoryImpl(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

final islandRepositoryProvider = Provider<IslandRepositoryPort>((ref) {
  return IslandRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(fragmentRepositoryProvider),
    ref.watch(appDatabaseProvider),
  );
});

final localArchiveRepositoryProvider =
    Provider<LocalArchiveRepositoryPort>((ref) {
  return LocalArchiveExporter(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(apiClientProvider),
  );
});

final relationRepositoryProvider = Provider<RelationRepositoryContract>((ref) {
  return RelationRepositoryImpl(
    RelationApi(ref.watch(apiClientProvider)),
    ref.watch(appDatabaseProvider),
  );
});

final statsRepositoryProvider = Provider<StatsRepositoryImpl>((ref) {
  return StatsRepositoryImpl(StatsApi(ref.watch(apiClientProvider)));
});

final starMapRepositoryProvider = Provider<StarMapRepositoryContract>((ref) {
  return StarMapRepositoryImpl(StarMapApi(ref.watch(apiClientProvider)));
});

final whiteNoiseRepositoryProvider =
    Provider<WhiteNoiseRepositoryContract>((ref) {
  return WhiteNoiseRepositoryImpl(WhiteNoiseApi(ref.watch(apiClientProvider)));
});

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository(ref.watch(apiClientProvider));
});

final syncApiProvider = Provider<SyncApi>((ref) {
  return SyncApi(ref.watch(apiClientProvider));
});

final localReminderServiceProvider = Provider<LocalReminderPort>((ref) {
  return LocalReminderService();
});
