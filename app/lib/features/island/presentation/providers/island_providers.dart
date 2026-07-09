import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/island_repository.dart';

final islandRepositoryProvider = Provider<IslandRepository>((ref) {
  return IslandRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(fragmentRepositoryProvider),
  );
});

/// 本地优先的 islandsProvider：fragments 已就绪时直接由本地推导，再后台拉远端覆盖；
/// 这样切到「屿」页面不会先闪一帧空岛文案再被远端结果替换。
final islandsProvider =
    AsyncNotifierProvider<IslandsNotifier, List<IslandModel>>(
  IslandsNotifier.new,
);

class IslandsNotifier extends AsyncNotifier<List<IslandModel>> {
  @override
  Future<List<IslandModel>> build() async {
    final repo = ref.watch(islandRepositoryProvider);
    final fragmentsAsync = ref.watch(fragmentsProvider);
    final fragments = fragmentsAsync.valueOrNull ?? const [];

    if (fragments.isNotEmpty) {
      final local = repo.computeIslandsFromFragments(fragments);
      unawaited(_refreshFromRemote(repo, hasLocal: local.isNotEmpty));
      return local;
    }
    // 本地暂无 fragment（新装/重装）→ 直接等远端，避免拿到空 fragments 推不出岛而误显示空态。
    final remote = await repo.tryListRemoteIslands();
    return remote ?? const [];
  }

  Future<void> _refreshFromRemote(
    IslandRepository repo, {
    required bool hasLocal,
  }) async {
    final remote = await repo.tryListRemoteIslands();
    if (remote == null) return;
    if (remote.isEmpty && hasLocal) return;
    state = AsyncData(remote);
  }
}
