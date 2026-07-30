import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app_state.dart';
import '../../../app/providers.dart';

class IslandGroupController
    extends AutoDisposeAsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async => null;
  Future<Map<String, dynamic>> preview() async {
    if (!ref.read(aiEnabledProvider)) {
      return {
        'status': 'disabled',
        'message': '星图管理员已关闭。',
        'proposals': const []
      };
    }
    state = const AsyncLoading();
    try {
      final result = await ref.read(aiRepositoryProvider).previewIslandGroups();
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> createSelected(List<Map<String, dynamic>> proposals) async {
    for (final proposal in proposals) {
      await ref.read(aiRepositoryProvider).createIslandGroup(proposal);
    }
  }
}

final islandGroupControllerProvider = AutoDisposeAsyncNotifierProvider<
    IslandGroupController, Map<String, dynamic>?>(IslandGroupController.new);
