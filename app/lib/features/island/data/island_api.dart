import '../../shared/data/api_client.dart';

class IslandApi {
  IslandApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> listIslands() {
    return _api.get('/islands');
  }

  Future<Map<String, dynamic>> getIsland(String name) {
    return _api.get('/islands/${Uri.encodeComponent(name)}');
  }

  Future<Map<String, dynamic>> listIslandFragments(String name) {
    return _api.get('/islands/${Uri.encodeComponent(name)}/fragments');
  }
}
