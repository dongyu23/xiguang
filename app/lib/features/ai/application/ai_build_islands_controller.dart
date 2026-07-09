import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../island/application/island_providers.dart';

class AiBuildIslandsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Map<String, dynamic>> analyze() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(aiRepositoryProvider).buildIslands();
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createIsland(Map<String, dynamic> suggestion) async {
    final name = suggestion['name'] as String;
    final fragmentIds =
        (suggestion['fragment_ids'] as List<dynamic>? ?? const [])
            .map((item) => (item as num).toInt())
            .toList();
    final repository = ref.read(islandRepositoryProvider);
    final created = await repository.createIsland(
      name,
      suggestion['description'] as String? ?? '',
    );
    if (created.islandId > 0 && fragmentIds.isNotEmpty) {
      await repository.addFragments(created.islandId, fragmentIds);
    }
    ref.invalidate(islandsProvider);
  }
}

final aiBuildIslandsControllerProvider =
    AutoDisposeAsyncNotifierProvider<AiBuildIslandsController, void>(
        AiBuildIslandsController.new);
