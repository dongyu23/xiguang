import '../../shared/data/api_client.dart';

class WhiteNoiseApi {
  const WhiteNoiseApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> list() => _api.get('/whitenoise');
}
