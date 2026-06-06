import '../../shared/data/api_client.dart';

class SpaceApi {
  const SpaceApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> getConfig() => _api.get('/space/config');
  Future<Map<String, dynamic>> saveConfig(Map<String, dynamic> body) =>
      _api.put('/space/config', body);
}
