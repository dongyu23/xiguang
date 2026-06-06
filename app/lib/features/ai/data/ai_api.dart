import '../../shared/data/api_client.dart';

class AIApi {
  const AIApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> glowSummary(Map<String, dynamic> body) {
    return _api.post('/ai/glow-summary', body);
  }
}
