import '../../shared/data/api_client.dart';

class StatsApi {
  const StatsApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> emotionDensity() =>
      _api.get('/stats/emotion-density');
  Future<Map<String, dynamic>> frequentWords() => _api.get('/stats/freq-words');
}
