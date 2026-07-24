import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_state.dart';
import '../../../app/providers.dart';
import '../domain/ai_request.dart';
import '../domain/ai_response.dart';

class GlowOrganizeController extends AutoDisposeAsyncNotifier<AIResponse?> {
  @override
  Future<AIResponse?> build() async => null;

  Future<AIResponse> request(AIRequest request) async {
    if (!ref.read(aiEnabledProvider)) {
      state = const AsyncData(null);
      return const AIResponse();
    }
    if (state.isLoading) throw StateError('glow_request_in_progress');
    state = const AsyncLoading();
    try {
      final response =
          await ref.read(aiRepositoryProvider).glowSummary(request);
      state = AsyncData(response);
      return response;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final glowOrganizeControllerProvider =
    AutoDisposeAsyncNotifierProvider<GlowOrganizeController, AIResponse?>(
        GlowOrganizeController.new);
