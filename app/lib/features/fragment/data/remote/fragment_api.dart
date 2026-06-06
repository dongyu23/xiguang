import '../../../shared/data/api_client.dart';

class FragmentApi {
  const FragmentApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> list({int limit = 100}) {
    return _api.get('/fragments', query: {'limit': limit});
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) {
    return _api.post('/fragments', body);
  }

  Future<Map<String, dynamic>> getById(int id) => _api.get('/fragments/$id');
}
