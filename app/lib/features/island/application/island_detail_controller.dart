import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fragment/domain/fragment.dart';
import '../domain/island_model.dart';
import 'island_providers.dart';

class IslandDetailData {
  const IslandDetailData({required this.island, required this.fragments});

  final IslandModel island;
  final List<Fragment> fragments;
}

class IslandDetailController
    extends AutoDisposeFamilyAsyncNotifier<IslandDetailData, String> {
  late String _idOrName;

  @override
  Future<IslandDetailData> build(String arg) {
    _idOrName = arg;
    return _load();
  }

  Future<IslandDetailData> addFragments(List<int> fragmentIds) async {
    final current = await future;
    if (current.island.islandId <= 0) {
      throw StateError('island_has_no_remote_id');
    }
    state = const AsyncLoading<IslandDetailData>().copyWithPrevious(state);
    try {
      final updated = await ref.read(islandRepositoryProvider).addFragments(
            current.island.islandId,
            fragmentIds,
          );
      final detail = await _load(seed: updated);
      state = AsyncData(detail);
      ref.invalidate(islandsProvider);
      return detail;
    } catch (error, stackTrace) {
      state = AsyncError<IslandDetailData>(error, stackTrace)
          .copyWithPrevious(AsyncData(current));
      rethrow;
    }
  }

  Future<IslandDetailData> _load({IslandModel? seed}) async {
    final repository = ref.read(islandRepositoryProvider);
    final island = seed ?? await repository.getIsland(_idOrName);
    final displayName = island?.name ?? _idOrName;
    final fragments = await repository.listIslandFragments(
      displayName,
      islandId: island?.islandId,
    );
    return IslandDetailData(
      island: island ??
          IslandModel(
            name: displayName,
            status: 'star_point',
            fragmentCount: 0,
            description: '这些光因为同一个主题靠近。',
            manual: false,
          ),
      fragments: fragments,
    );
  }
}

final islandDetailProvider = AsyncNotifierProvider.autoDispose
    .family<IslandDetailController, IslandDetailData, String>(
        IslandDetailController.new);
