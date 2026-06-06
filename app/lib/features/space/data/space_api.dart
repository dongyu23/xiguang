import '../../shared/data/api_client.dart';

class SpaceApi {
  SpaceApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> currentTheme() {
    return _api.get('/space/theme');
  }
}
