import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/ai/data/ai_api.dart';
import '../features/ai/data/ai_repository_impl.dart';
import '../features/fragment/data/fragment_repository.dart';
import '../features/island/data/island_repository.dart';
import '../features/relation/data/relation_api.dart';
import '../features/relation/data/relation_repository_impl.dart';
import '../features/relation/domain/relation.dart';
import '../features/space/data/space_api.dart';
import '../features/space/data/space_repository_impl.dart';
import '../features/starmap/data/starmap_api.dart';
import '../features/starmap/data/starmap_repository_impl.dart';
import '../features/stats/data/stats_api.dart';
import '../features/stats/data/stats_repository_impl.dart';
import '../features/timeline/domain/date_group.dart';
import '../features/timeline/domain/timeline_query.dart';
import '../features/timeline/data/timeline_api.dart';
import '../features/timeline/data/timeline_repository_impl.dart';
import '../features/whitenoise/data/whitenoise_api.dart';
import '../features/whitenoise/data/whitenoise_repository_impl.dart';
import '../features/sync/data/sync_api.dart';
import '../features/sync/domain/sync_config.dart';
import '../features/sync/domain/sync_status.dart';
import '../features/sync/engine/sync_engine.dart';
import '../features/shared/data/api_client.dart';

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
  final url = ref.read(apiBaseUrlProvider).valueOrNull;
  if (url != null) _apiClient.updateBaseUrl(normalizeApiBaseUrl(url));
  ref.listen(apiBaseUrlProvider, (_, next) {
    final nextUrl = next.valueOrNull;
    if (nextUrl != null) {
      _apiClient.updateBaseUrl(normalizeApiBaseUrl(nextUrl));
    }
  });
  return _apiClient;
});

final nightModeProvider = StateProvider<bool>((ref) => false);
final aiPolishEnabledProvider = StateProvider<bool>((ref) => false);
final activeTabIndexProvider = StateProvider<int>((ref) => 0);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final aiRepositoryProvider = Provider<AIRepositoryImpl>((ref) {
  return AIRepositoryImpl(AIApi(ref.watch(apiClientProvider)));
});

final fragmentRepositoryProvider = Provider<FragmentRepository>((ref) {
  return FragmentRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
  );
});

final islandRepositoryProvider = Provider<IslandRepository>((ref) {
  return IslandRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(fragmentRepositoryProvider),
  );
});

final relationRepositoryProvider = Provider<RelationRepositoryImpl>((ref) {
  return RelationRepositoryImpl(RelationApi(ref.watch(apiClientProvider)));
});

final timelineRepositoryProvider = Provider<TimelineRepositoryImpl>((ref) {
  return TimelineRepositoryImpl(TimelineApi(ref.watch(apiClientProvider)));
});

final statsRepositoryProvider = Provider<StatsRepositoryImpl>((ref) {
  return StatsRepositoryImpl(StatsApi(ref.watch(apiClientProvider)));
});

final starMapRepositoryProvider = Provider<StarMapRepositoryImpl>((ref) {
  return StarMapRepositoryImpl(StarMapApi(ref.watch(apiClientProvider)));
});

final spaceRepositoryProvider = Provider<SpaceRepositoryImpl>((ref) {
  return SpaceRepositoryImpl(SpaceApi(ref.watch(apiClientProvider)));
});

final whiteNoiseRepositoryProvider = Provider<WhiteNoiseRepositoryImpl>((ref) {
  return WhiteNoiseRepositoryImpl(WhiteNoiseApi(ref.watch(apiClientProvider)));
});

final sessionProvider = FutureProvider<AuthSession>((ref) {
  final current = ref.watch(authSessionProvider);
  if (current != null) return current;
  return ref.watch(authRepositoryProvider).ensureSession();
});

final authRestoreProvider = FutureProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).restoreSession();
});

final authSessionProvider = StateProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).currentSession;
});

final fragmentsProvider =
    AsyncNotifierProvider<FragmentsNotifier, List<LightFragmentModel>>(
  FragmentsNotifier.new,
);

class FragmentsNotifier extends AsyncNotifier<List<LightFragmentModel>> {
  @override
  Future<List<LightFragmentModel>> build() async {
    return ref.watch(fragmentRepositoryProvider).listFragments();
  }

  Future<void> capture({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    await captureWithResult(
      text: text,
      emotion: emotion,
      tags: tags,
      mediaUrls: mediaUrls,
    );
  }

  Future<LightFragmentModel> captureWithResult({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    final previous = state.value ?? const [];
    state =
        const AsyncLoading<List<LightFragmentModel>>().copyWithPrevious(state);
    try {
      final created =
          await ref.watch(fragmentRepositoryProvider).createFragment(
                text: text,
                emotion: emotion,
                tags: tags,
                mediaUrls: mediaUrls,
              );
      state = AsyncData(
          [created, ...previous.where((item) => item.id != created.id)]);
      ref.invalidate(islandsProvider);
      ref.invalidate(localTimelineGroupsProvider);
      return created;
    } on LocalDraftException catch (error) {
      state = AsyncData([
        error.fragment,
        ...previous.where((item) => item.id != error.fragment.id)
      ]);
      ref.invalidate(islandsProvider);
      ref.invalidate(localTimelineGroupsProvider);
      return error.fragment;
    } catch (error, stackTrace) {
      state = AsyncError<List<LightFragmentModel>>(error, stackTrace)
          .copyWithPrevious(AsyncData(previous));
      rethrow;
    }
  }

  Future<void> refresh() async {
    state =
        const AsyncLoading<List<LightFragmentModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () => ref.watch(fragmentRepositoryProvider).listFragments());
  }

  Future<void> deleteMany(Set<int> ids) async {
    if (ids.isEmpty) return;
    final previous = state.value ?? const [];
    state =
        AsyncData(previous.where((item) => !ids.contains(item.id)).toList());
    try {
      final repository = ref.watch(fragmentRepositoryProvider);
      for (final id in ids) {
        await repository.deleteFragment(id);
      }
      ref.invalidate(islandsProvider);
      ref.invalidate(localTimelineGroupsProvider);
    } catch (error, stackTrace) {
      state = AsyncError<List<LightFragmentModel>>(error, stackTrace)
          .copyWithPrevious(AsyncData(previous));
      rethrow;
    }
  }
}

final islandsProvider = FutureProvider<List<IslandModel>>((ref) async {
  return ref.watch(islandRepositoryProvider).listIslands();
});

final localTimelineGroupsProvider =
    FutureProvider<List<DateGroup>>((ref) async {
  return ref.watch(timelineRepositoryProvider).list(const TimelineQuery());
});

final fragmentRelationsProvider =
    FutureProvider.family<List<Relation>, int>((ref, fragmentId) {
  return ref.watch(relationRepositoryProvider).list(fragmentId: fragmentId);
});

final relationsProvider = FutureProvider<List<Relation>>((ref) {
  return ref.watch(relationRepositoryProvider).list();
});

// ── 云同步 ──

final syncConfigProvider = StateProvider<SyncConfig>((ref) {
  return const SyncConfig();
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final api = SyncApi(ref.watch(apiClientProvider));
  final config = ref.watch(syncConfigProvider);
  return SyncEngine(api: api, config: config);
});

final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return ref.watch(syncEngineProvider).status;
});

final syncNowProvider = FutureProvider.autoDispose<void>((ref) async {
  final engine = ref.read(syncEngineProvider);
  final newStatus = await engine.syncNow();
  ref.read(syncStatusProvider.notifier).state = newStatus;
});

final syncConnectionProvider = FutureProvider.autoDispose<bool>((ref) async {
  final engine = ref.read(syncEngineProvider);
  final ok = await engine.checkConnection();
  ref.read(syncStatusProvider.notifier).state = engine.status;
  return ok;
});
