import 'ai_request.dart';
import 'ai_response.dart';

abstract interface class AIRepositoryPort {
  Future<AISummaryDraft> previewSummary(AIScope scope);
  Future<Map<String, dynamic>> saveSummary(
      {required AISummaryDraft draft,
      required String title,
      required String summary,
      required List<AISummaryPoint> keyPoints,
      required bool userEdited});
  Future<Map<String, dynamic>> previewIslandGroups();
  Future<Map<String, dynamic>> createIslandGroup(Map<String, dynamic> proposal);
  Future<Map<String, dynamic>> polishFragment(
      String contentText, String emotion,
      {List<String> tags = const []});
  Future<void> feedback(int requestId, String action, {String? reason});
  Future<AIResponse> glowSummary(AIRequest request);
  Future<Map<String, dynamic>> buildIslands({int rangeDays = 0});
}
