import '../../shared/data/api_client.dart';

class StarMapApi {
  const StarMapApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> load({int? rootFragmentId, int depth = 2}) {
    return _api.get('/starmap', query: {
      if (rootFragmentId != null) 'root_fragment_id': rootFragmentId,
      'depth': depth,
    });
  }
}
