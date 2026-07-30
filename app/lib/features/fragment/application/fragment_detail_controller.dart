import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_state.dart';
import '../../../app/providers.dart';
import '../domain/fragment.dart';
import 'fragment_list_controller.dart';

enum FragmentPolishStatus { idle, loading, done, error }

class FragmentDetailState {
  const FragmentDetailState({
    this.isSaving = false,
    this.error,
    this.polishStatus = FragmentPolishStatus.idle,
    this.polishedText = '',
    this.originalText = '',
    this.polishMessage = '',
  });

  final bool isSaving;
  final Object? error;
  final FragmentPolishStatus polishStatus;
  final String polishedText;
  final String originalText;
  final String polishMessage;

  FragmentDetailState copyWith({
    bool? isSaving,
    Object? error,
    FragmentPolishStatus? polishStatus,
    String? polishedText,
    String? originalText,
    String? polishMessage,
  }) {
    return FragmentDetailState(
      isSaving: isSaving ?? this.isSaving,
      error: error,
      polishStatus: polishStatus ?? this.polishStatus,
      polishedText: polishedText ?? this.polishedText,
      originalText: originalText ?? this.originalText,
      polishMessage: polishMessage ?? this.polishMessage,
    );
  }
}

/// Owns persisted fragment mutations. Dialogs, pickers and text controllers stay
/// in the view, while mutation semantics and list consistency stay here.
class FragmentDetailController
    extends AutoDisposeNotifier<FragmentDetailState> {
  @override
  FragmentDetailState build() => const FragmentDetailState();

  Future<void> save({
    required Fragment fragment,
    required String text,
    required String emotion,
    required List<String> tags,
    List<String>? mediaUrls,
  }) async {
    if (state.isSaving) return;
    state = const FragmentDetailState(isSaving: true);
    try {
      await ref.read(fragmentsProvider.notifier).updateText(
            fragment.id,
            text,
            emotion: emotion,
            tags: tags,
            mediaUrls: mediaUrls,
          );
      state = const FragmentDetailState();
    } catch (error) {
      state = FragmentDetailState(error: error);
      rethrow;
    }
  }

  Future<void> delete(Fragment fragment) async {
    if (state.isSaving) return;
    state = const FragmentDetailState(isSaving: true);
    try {
      await ref.read(fragmentsProvider.notifier).deleteMany({fragment.id});
      state = const FragmentDetailState();
    } catch (error) {
      state = FragmentDetailState(error: error);
      rethrow;
    }
  }

  Future<void> polish({
    required String contentText,
    required String emotion,
    List<String> tags = const [],
  }) async {
    if (!ref.read(aiEnabledProvider)) return;
    if (state.polishStatus == FragmentPolishStatus.loading) return;
    state = state.copyWith(
      polishStatus: FragmentPolishStatus.loading,
      polishedText: '',
      originalText: contentText,
      polishMessage: '',
    );
    try {
      final result = await ref
          .read(aiRepositoryProvider)
          .polishFragment(contentText, emotion, tags: tags);
      if (const {
        'error',
        'rate_limited',
        'membership_required',
        'quota_exhausted',
        'parse_error'
      }.contains(result['status'])) {
        state = state.copyWith(
          polishStatus: FragmentPolishStatus.error,
          polishMessage: result['message'] as String? ?? 'AI 服务暂时不可用，请稍后重试。',
        );
        return;
      }
      state = state.copyWith(
        polishStatus: FragmentPolishStatus.done,
        polishedText: result['status'] == 'no_change'
            ? ''
            : result['polished_text'] as String? ?? contentText,
        originalText: result['original_text'] as String? ?? contentText,
        polishMessage: result['message'] as String? ?? '',
      );
    } catch (error) {
      state = state.copyWith(
        error: error,
        polishStatus: FragmentPolishStatus.error,
        polishMessage: 'AI 服务暂时不可用，请稍后重试。',
      );
    }
  }

  void resetPolish() {
    state = state.copyWith(
      polishStatus: FragmentPolishStatus.idle,
      polishedText: '',
      originalText: '',
      polishMessage: '',
    );
  }
}

final fragmentDetailControllerProvider =
    AutoDisposeNotifierProvider<FragmentDetailController, FragmentDetailState>(
  FragmentDetailController.new,
);
