import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/fragment.dart';
import 'fragment_list_controller.dart';

class CaptureState {
  const CaptureState({this.isSaving = false, this.error});

  final bool isSaving;
  final Object? error;
}

/// Owns the capture workflow; the page only owns ephemeral input and media UI.
class CaptureController extends AutoDisposeNotifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  Future<Fragment> capture({
    required String text,
    required String emotion,
    required List<String> tags,
    List<String> mediaUrls = const [],
  }) async {
    if (state.isSaving) throw StateError('capture_in_progress');
    state = const CaptureState(isSaving: true);
    try {
      final fragment =
          await ref.read(fragmentsProvider.notifier).captureWithResult(
                text: text,
                emotion: emotion,
                tags: tags,
                mediaUrls: mediaUrls,
              );
      state = const CaptureState();
      return fragment;
    } catch (error) {
      state = CaptureState(error: error);
      rethrow;
    }
  }
}

final captureControllerProvider =
    AutoDisposeNotifierProvider<CaptureController, CaptureState>(
  CaptureController.new,
);
