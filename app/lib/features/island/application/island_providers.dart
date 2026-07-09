import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../fragment/application/fragment_list_controller.dart';
import '../domain/island_model.dart';
import '../domain/island_repository.dart';

export '../../../app/providers.dart' show islandRepositoryProvider;

final islandsProvider =
    AsyncNotifierProvider<IslandsNotifier, List<IslandModel>>(
  IslandsNotifier.new,
);

class IslandsNotifier extends AsyncNotifier<List<IslandModel>> {
  @override
  Future<List<IslandModel>> build() async {
    final repository = ref.watch(islandRepositoryProvider);
    final fragments = ref.watch(fragmentsProvider).valueOrNull ?? const [];
    if (fragments.isNotEmpty) {
      final local = repository.computeIslandsFromFragments(fragments);
      unawaited(_refreshFromRemote(repository, hasLocal: local.isNotEmpty));
      return local;
    }
    return await repository.tryListRemoteIslands() ?? const [];
  }

  Future<void> _refreshFromRemote(
    IslandRepositoryPort repository, {
    required bool hasLocal,
  }) async {
    final remote = await repository.tryListRemoteIslands();
    if (remote == null || (remote.isEmpty && hasLocal)) return;
    state = AsyncData(remote);
  }
}
