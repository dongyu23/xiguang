import 'package:dio/dio.dart';

import '../../../design/tokens/motion.dart';
import '../../shared/data/api_client.dart';

class AIApi {
  const AIApi(this._api);

  final ApiClient _api;
  static final _aiOptions = Options(
    receiveTimeout: AppTiming.aiRequestTimeout,
    sendTimeout: AppTiming.aiRequestTimeout,
  );

  Future<Map<String, dynamic>> glowSummary(Map<String, dynamic> body) {
    return _api.post('/ai/glow-summary', body, options: _aiOptions);
  }

  Future<Map<String, dynamic>> buildIslands() {
    return _api.post('/ai/build-islands', {}, options: _aiOptions);
  }

  Future<Map<String, dynamic>> polishFragment(
      String contentText, String emotion) {
    return _api.post(
        '/ai/polish',
        {
          'content_text': contentText,
          'emotion': emotion,
        },
        options: _aiOptions);
  }
}
