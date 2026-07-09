import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../fragment/application/fragment_list_controller.dart';
import '../../fragment/domain/fragment.dart';

class TimelinePolishResult {
  const TimelinePolishResult({required this.success, required this.failed});

  final int success;
  final int failed;
}

class TimelineActionsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<TimelinePolishResult> polish(List<Fragment> fragments) async {
    if (state.isLoading) throw StateError('timeline_action_in_progress');
    state = const AsyncLoading();
    var success = 0;
    var failed = 0;
    try {
      final valid = fragments
          .where((item) => item.contentText.trim().isNotEmpty)
          .toList();
      const concurrency = 3;
      for (var index = 0; index < valid.length; index += concurrency) {
        final results = await Future.wait(
          valid.skip(index).take(concurrency).map(_polishOne),
        );
        success += results.where((result) => result).length;
        failed += results.where((result) => !result).length;
      }
      state = const AsyncData(null);
      return TimelinePolishResult(success: success, failed: failed);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> _polishOne(Fragment fragment) async {
    try {
      final result = await ref.read(aiRepositoryProvider).polishFragment(
            fragment.contentText,
            fragment.emotion,
          );
      if (result['status'] == 'error') return false;
      final polished = (result['polished_text'] as String? ?? '').trim();
      if (polished.isEmpty) return false;
      await ref.read(fragmentsProvider.notifier).updateText(
            fragment.id,
            polished,
            emotion: fragment.emotion,
            tags: fragment.tags,
          );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final timelineActionsControllerProvider =
    AutoDisposeAsyncNotifierProvider<TimelineActionsController, void>(
        TimelineActionsController.new);
