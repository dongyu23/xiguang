import '../domain/ai_request.dart';
import '../domain/ai_repository.dart';
import '../domain/ai_response.dart';
import 'ai_api.dart';

class AIRepositoryImpl implements AIRepositoryPort {
  const AIRepositoryImpl(this._api);
  final AIApi _api;
  @override
  Future<AISummaryDraft> previewSummary(AIScope scope) async =>
      AISummaryDraft.fromJson(
          await _api.previewSummary({'scope': scope.toJson()}), scope);
  @override
  Future<Map<String, dynamic>> saveSummary(
          {required AISummaryDraft draft,
          required String title,
          required String summary,
          required List<AISummaryPoint> keyPoints,
          required bool userEdited}) =>
      _api.saveSummary({
        'request_id': draft.requestId,
        'scope': draft.scope.toJson(),
        'title': title,
        'summary': summary,
        'key_points': keyPoints.map((e) => e.toJson()).toList(),
        'user_edited': userEdited
      });
  @override
  Future<Map<String, dynamic>> previewIslandGroups() =>
      _api.previewIslandGroups();
  @override
  Future<Map<String, dynamic>> createIslandGroup(
          Map<String, dynamic> proposal) =>
      _api.createIslandGroup({
        'name': proposal['name'],
        'description': proposal['description'] ?? '',
        'source': 'ai',
        'island_ids': proposal['island_ids'] ?? const []
      });
  @override
  Future<Map<String, dynamic>> polishFragment(String text, String emotion,
          {List<String> tags = const []}) =>
      _api.polishFragment(text, emotion, tags);
  @override
  Future<void> feedback(int requestId, String action, {String? reason}) async {
    await _api.feedback(requestId, action, reason);
  }

  @override
  Future<AIResponse> glowSummary(AIRequest request) async {
    final body = await _api.glowSummary({
      'mode': request.mode,
      'fragment_ids': request.fragmentIds,
      if (request.context != null) 'context': request.context,
    });
    return AIResponse(
      summary: body['message'] as String?,
      keywords: (body['keywords'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> buildIslands({int rangeDays = 0}) =>
      _api.buildIslands(rangeDays: rangeDays);
}
