import '../domain/ai_request.dart';
import '../domain/ai_response.dart';
import 'ai_api.dart';

class AIRepositoryImpl {
  const AIRepositoryImpl(this._api);

  final AIApi _api;

  Future<AIResponse> glowSummary(AIRequest request) async {
    final body = await _api.glowSummary({
      'mode': request.mode,
      'fragment_ids': request.fragmentIds,
      if (request.context != null) 'context': request.context,
    });
    return AIResponse(
      summary: body['summary_text'] as String? ??
          body['status'] as String? ??
          '请求已交给星图管理员。',
      emotionTitle: body['emotion_title'] as String?,
      keywords: (body['keywords'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      suggestions: (body['suggestion_ids'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList(),
    );
  }
}
