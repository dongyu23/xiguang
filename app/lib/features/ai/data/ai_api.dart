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

  Future<Map<String, dynamic>> buildIslands({int rangeDays = 0}) {
    return _api.post('/ai/build-islands', {
      if (rangeDays > 0) 'range_days': rangeDays,
    }, options: _aiOptions);
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
