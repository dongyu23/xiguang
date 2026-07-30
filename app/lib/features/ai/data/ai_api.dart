import 'package:dio/dio.dart';
import '../../../design/tokens/motion.dart';
import '../../shared/data/api_client.dart';

class AIApi {
  const AIApi(this._api);
  final ApiClient _api;
  static final _options = Options(
      receiveTimeout: AppTiming.aiRequestTimeout,
      sendTimeout: AppTiming.aiRequestTimeout);
  Future<Map<String, dynamic>> previewSummary(Map<String, dynamic> body) =>
      _api.post('/ai/summaries/preview', body, options: _options);
  Future<Map<String, dynamic>> saveSummary(Map<String, dynamic> body) =>
      _api.post('/ai/summaries', body, options: _options);
  Future<Map<String, dynamic>> previewIslandGroups() =>
      _api.post('/ai/island-groups/preview', const {}, options: _options);
  Future<Map<String, dynamic>> createIslandGroup(Map<String, dynamic> body) =>
      _api.post('/island-groups', body, options: _options);
  Future<Map<String, dynamic>> polishFragment(
          String text, String emotion, List<String> tags) =>
      _api.post('/ai/polish/preview',
          {'content_text': text, 'emotion': emotion, 'tags': tags},
          options: _options);
  Future<Map<String, dynamic>> feedback(
          int id, String action, String? reason) =>
      _api.post('/ai/feedback', {
        'request_id': id,
        'action': action,
        if (reason != null) 'reason': reason
      });
  Future<Map<String, dynamic>> glowSummary(Map<String, dynamic> body) =>
      _api.post('/ai/glow-summary', body, options: _options);
  Future<Map<String, dynamic>> buildIslands({int rangeDays = 0}) => _api.post(
      '/ai/build-islands', {if (rangeDays > 0) 'range_days': rangeDays},
      options: _options);
}
