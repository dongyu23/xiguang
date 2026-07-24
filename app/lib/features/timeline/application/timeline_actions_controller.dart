import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../fragment/domain/fragment.dart';

class TimelinePolishItem {
  const TimelinePolishItem({
    required this.fragment,
    required this.polishedText,
  });

  final Fragment fragment;
  final String polishedText;
}

class TimelineActionsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// 批量润色：只调用 AI 获取润色候选，不写库。
  /// 调用方拿到结果后展示候选 sheet，由用户确认后才写入
  /// （决策 3：AI 输出不替换原始内容，作为候选让用户挑选）。
  Future<List<TimelinePolishItem>> polish(List<Fragment> fragments) async {
    if (state.isLoading) throw StateError('timeline_action_in_progress');
    state = const AsyncLoading();
    try {
      final valid = fragments
          .where((item) => item.contentText.trim().isNotEmpty)
          .toList();
      const concurrency = 3;
      final results = <TimelinePolishItem>[];
      for (var index = 0; index < valid.length; index += concurrency) {
        final batch = await Future.wait(
          valid.skip(index).take(concurrency).map(_polishOne),
        );
        results.addAll(batch);
      }
      state = const AsyncData(null);
      return results;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<TimelinePolishItem> _polishOne(Fragment fragment) async {
    try {
      final result = await ref.read(aiRepositoryProvider).polishFragment(
            fragment.contentText,
            fragment.emotion,
          );
      if (result['status'] == 'error') {
        return TimelinePolishItem(fragment: fragment, polishedText: '');
      }
      final polished = (result['polished_text'] as String? ?? '').trim();
      if (polished.isEmpty || polished == fragment.contentText.trim()) {
        return TimelinePolishItem(fragment: fragment, polishedText: '');
      }
      return TimelinePolishItem(fragment: fragment, polishedText: polished);
    } catch (_) {
      return TimelinePolishItem(fragment: fragment, polishedText: '');
    }
  }
}

final timelineActionsControllerProvider =
    AutoDisposeAsyncNotifierProvider<TimelineActionsController, void>(
        TimelineActionsController.new);
