import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fragment/application/fragment_list_controller.dart';
import '../../starmap/application/starmap_providers.dart';
import '../domain/relation.dart';
import 'relation_providers.dart';

class WeaveState {
  const WeaveState({
    this.isSubmitting = false,
    this.completed = false,
    this.notice,
  });

  final bool isSubmitting;
  final bool completed;
  final String? notice;
}

class WeaveController extends AutoDisposeNotifier<WeaveState> {
  @override
  WeaveState build() => const WeaveState();

  Future<Relation?> submit({
    required int sourceFragmentId,
    required int targetFragmentId,
    required String relationType,
    String? note,
  }) async {
    if (state.isSubmitting) return null;
    state = const WeaveState(isSubmitting: true);
    try {
      final relation = await ref.read(fragmentRepositoryProvider).weave(
            sourceFragmentId: sourceFragmentId,
            targetFragmentId: targetFragmentId,
            relationType: relationType,
            note: note,
          );
      if (relation == null) {
        state = const WeaveState(notice: '后端暂时没有回应，这条线还没有写入。');
        return null;
      }
      ref.invalidate(fragmentRelationsProvider(sourceFragmentId));
      ref.invalidate(relationsProvider);
      ref.invalidate(relationLedgerProvider);
      ref.invalidate(starGraphProvider);
      state = const WeaveState(completed: true);
      return relation;
    } catch (error) {
      state = const WeaveState(notice: '后端暂时没有回应，这条线还没有写入。');
      rethrow;
    }
  }
}

final weaveControllerProvider =
    AutoDisposeNotifierProvider<WeaveController, WeaveState>(
  WeaveController.new,
);
