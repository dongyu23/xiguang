import '../../shared/data/api_client.dart';

class IslandApi {
  const IslandApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> list() => _api.get('/islands');
  Future<Map<String, dynamic>> get(String idOrName) =>
      _api.get('/islands/$idOrName');
  Future<Map<String, dynamic>> fragments(String name) =>
      _api.get('/islands/$name/fragments');
}
