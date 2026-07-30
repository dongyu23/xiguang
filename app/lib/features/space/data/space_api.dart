import '../../shared/data/api_client.dart';

class SpaceApi {
  SpaceApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> themes() => _api.get('/space/themes');

  Future<void> selectTheme(String id) async {
    final config = await _api.get('/space/config');
    await _api.put('/space/config', {
      'theme': id,
      'breathing_motion': config['breathing_motion'] as bool? ?? true,
      'white_noise_enabled': config['white_noise_enabled'] as bool? ?? false,
    });
  }
}
