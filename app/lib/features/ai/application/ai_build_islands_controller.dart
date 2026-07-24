import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_state.dart';
import '../../../app/providers.dart';
import '../../island/application/island_providers.dart';

class AiBuildIslandsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Map<String, dynamic>> analyze({int rangeDays = 0}) async {
    if (!ref.read(aiEnabledProvider)) {
      return {'status': 'disabled', 'message': '星图管理员已关闭，可在设置中开启。'};
    }
    state = const AsyncLoading();
    try {
      final result =
          await ref.read(aiRepositoryProvider).buildIslands(rangeDays: rangeDays);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createIsland(Map<String, dynamic> suggestion) async {
    if (!ref.read(aiEnabledProvider)) return;
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
