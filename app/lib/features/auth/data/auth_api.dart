import '../../shared/data/api_client.dart';

class AuthApi {
  const AuthApi(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> login(String username, String password) {
    return _api.post('/auth/login', {
      'username': username,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String nickname,
  }) {
    return _api.post('/auth/register', {
      'username': username,
      'password': password,
      'nickname': nickname,
    });
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) {
    return _api.post('/auth/refresh', {'refresh_token': refreshToken});
  }
}
