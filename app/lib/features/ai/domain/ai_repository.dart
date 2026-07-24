import 'ai_request.dart';
import 'ai_response.dart';

abstract interface class AIRepositoryPort {
  Future<AIResponse> glowSummary(AIRequest request);
  Future<Map<String, dynamic>> buildIslands({int rangeDays = 0});
  Future<Map<String, dynamic>> polishFragment(
      String contentText, String emotion);
}
