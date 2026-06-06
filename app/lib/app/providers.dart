import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/ai/data/ai_api.dart';
import '../features/ai/data/ai_repository_impl.dart';
import '../features/fragment/data/fragment_repository.dart';
import '../features/island/data/island_repository.dart';
import '../features/space/data/space_api.dart';
import '../features/space/data/space_repository_impl.dart';
import '../features/starmap/data/starmap_api.dart';
import '../features/starmap/data/starmap_repository_impl.dart';
import '../features/stats/data/stats_api.dart';
import '../features/stats/data/stats_repository_impl.dart';
import '../features/timeline/data/timeline_api.dart';
import '../features/timeline/data/timeline_repository_impl.dart';
import '../features/whitenoise/data/whitenoise_api.dart';
import '../features/whitenoise/data/whitenoise_repository_impl.dart';
import '../features/shared/data/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

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
  return ref.watch(authRepositoryProvider).me();
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
    } catch (error, stackTrace) {
      state = AsyncError<List<LightFragmentModel>>(error, stackTrace)
          .copyWithPrevious(AsyncData(previous));
    }
  }

  Future<void> refresh() async {
    state =
        const AsyncLoading<List<LightFragmentModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () => ref.watch(fragmentRepositoryProvider).listFragments());
  }
}

final islandsProvider = FutureProvider<List<IslandModel>>((ref) async {
  return ref.watch(islandRepositoryProvider).listIslands();
});
