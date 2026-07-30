import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app_state.dart';
import '../../../app/providers.dart';
import '../domain/ai_request.dart';
import '../domain/ai_response.dart';

class GlowOrganizeController extends AutoDisposeAsyncNotifier<AISummaryDraft?> {
  @override
  Future<AISummaryDraft?> build() async => null;
  Future<AISummaryDraft> preview(AIScope scope) async {
    if (!ref.read(aiEnabledProvider)) {
      final draft = AISummaryDraft(
          status: 'disabled', scope: scope, message: '星图管理员已关闭。');
      state = AsyncData(draft);
      return draft;
    }
    state = const AsyncLoading();
    try {
      final draft = await ref.read(aiRepositoryProvider).previewSummary(scope);
      state = AsyncData(draft);
      return draft;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  Future<void> save(
      {required AISummaryDraft draft,
      required String title,
      required String summary,
      required List<AISummaryPoint> points,
      required bool edited}) async {
    await ref.read(aiRepositoryProvider).saveSummary(
        draft: draft,
        title: title,
        summary: summary,
        keyPoints: points,
        userEdited: edited);
    await ref
        .read(aiRepositoryProvider)
        .feedback(draft.requestId, edited ? 'modified' : 'accepted');
  }

  Future<void> reject(AISummaryDraft draft, String? reason) => ref
      .read(aiRepositoryProvider)
      .feedback(draft.requestId, 'rejected', reason: reason);
}

final glowOrganizeControllerProvider =
    AutoDisposeAsyncNotifierProvider<GlowOrganizeController, AISummaryDraft?>(
        GlowOrganizeController.new);
