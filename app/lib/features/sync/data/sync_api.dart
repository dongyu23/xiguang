import '../../shared/data/api_client.dart';

class SyncApi {
  const SyncApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> push(Map<String, dynamic> body) {
    return _api.post('/sync/push', body);
  }

  Future<Map<String, dynamic>> pull({required int sinceRev}) {
    return _api.get('/sync/pull', query: {'since_rev': sinceRev.toString()});
  }

  Future<Map<String, dynamic>> status() {
    return _api.get('/sync/status');
  }
}
