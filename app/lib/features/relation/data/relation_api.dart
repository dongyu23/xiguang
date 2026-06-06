import '../../shared/data/api_client.dart';

class RelationApi {
  const RelationApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) {
    return _api.post('/relations', body);
  }

  Future<Map<String, dynamic>> list({int? fragmentId}) {
    return _api.get('/relations', query: {
      if (fragmentId != null) 'fragment_id': fragmentId,
    });
  }

  Future<void> delete(int id) async {
    await _api.delete('/relations/$id');
  }
}
