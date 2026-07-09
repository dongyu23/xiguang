import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/island_model.dart';
import 'island_providers.dart';

class IslandCreateState {
  const IslandCreateState({this.isCreating = false, this.error});

  final bool isCreating;
  final Object? error;
}

class IslandCreateController extends AutoDisposeNotifier<IslandCreateState> {
  @override
  IslandCreateState build() => const IslandCreateState();

  Future<IslandModel> create({
    required String name,
    required String description,
  }) async {
    if (state.isCreating) throw StateError('island_create_in_progress');
    state = const IslandCreateState(isCreating: true);
    try {
      final island = await ref
          .read(islandRepositoryProvider)
          .createIsland(name, description);
      ref.invalidate(islandsProvider);
      state = const IslandCreateState();
      return island;
    } catch (error) {
      state = IslandCreateState(error: error);
      rethrow;
    }
  }
}

final islandCreateControllerProvider =
    AutoDisposeNotifierProvider<IslandCreateController, IslandCreateState>(
        IslandCreateController.new);
