import '../domain/ai_request.dart';
import '../domain/ai_repository.dart';
import '../domain/ai_response.dart';
import 'ai_api.dart';

class AIRepositoryImpl implements AIRepositoryPort {
  const AIRepositoryImpl(this._api);

  final AIApi _api;

  @override
  Future<AIResponse> glowSummary(AIRequest request) async {
    final body = await _api.glowSummary({
      'mode': request.mode,
      'fragment_ids': request.fragmentIds,
      if (request.context != null) 'context': request.context,
    });
    final status = body['status'] as String?;
    return AIResponse(
      summary: body['summary_text'] as String? ??
          _summaryForStatus(status) ??
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

  @override
  Future<Map<String, dynamic>> buildIslands({int rangeDays = 0}) =>
      _api.buildIslands(rangeDays: rangeDays);

  @override
  Future<Map<String, dynamic>> polishFragment(
    String contentText,
    String emotion,
  ) =>
      _api.polishFragment(contentText, emotion);
}

String? _summaryForStatus(String? status) {
  return switch (status) {
    'not_implemented' => '柔光整理还没有接上真正的星图管理员，但你的捕光、回看和织线都可以继续使用。',
    'rate_limited' => '今天已经整理得够多了，先让这些光安静放一会儿。',
    'not_enough' => '现在的光还不够多。再捕几束之后，我会更容易看见它们之间的线。',
    'error' || 'parse_error' => '柔光整理暂时没有回应，请稍后再试。',
    _ => null,
  };
}
