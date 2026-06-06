import '../../shared/data/api_client.dart';

class RelationApi {
  const RelationApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) {
    return _api.post('/relations', body);
  }

  Future<void> delete(int id) async {
    await _api.delete('/relations/$id');
  }
}
