import '../domain/auth_repository.dart';
import '../domain/token.dart';
import '../domain/user.dart';
import 'auth_api.dart';
import 'token_storage.dart';

class AuthRepositoryImpl implements AuthRepositoryContract {
  const AuthRepositoryImpl(this._api, this._tokens);

  final AuthApi _api;
  final TokenStorage _tokens;

  @override
  Future<(User, TokenPair)> login({
    required String username,
    required String password,
  }) async {
    final body = await _api.login(username, password);
    return _parseSession(body);
  }

  @override
  Future<(User, TokenPair)> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    final body = await _api.register(
      username: username,
      password: password,
      nickname: nickname,
    );
    return _parseSession(body);
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    final body = await _api.refresh(refreshToken);
    final pair = _parseTokens(body['tokens'] as Map<String, dynamic>? ?? body);
    await _tokens.save(pair);
    return pair;
  }

  @override
  Future<void> logout() => _tokens.delete();

  Future<(User, TokenPair)> _parseSession(Map<String, dynamic> body) async {
    final userJson = body['user'] as Map<String, dynamic>? ?? const {};
    final pair =
        _parseTokens(body['tokens'] as Map<String, dynamic>? ?? const {});
    await _tokens.save(pair);
    return (
      User(
        id: userJson['id'] as int? ?? 0,
        publicId: userJson['public_id'] as String? ?? '',
        username: userJson['username'] as String? ?? '',
        nickname: userJson['nickname'] as String? ?? '',
        avatarKey: userJson['avatar_key'] as String?,
      ),
      pair,
    );
  }

  TokenPair _parseTokens(Map<String, dynamic> json) {
    final expiresAtStr = json['expires_at'] as String?;
    final expiresAt = expiresAtStr != null
        ? DateTime.tryParse(expiresAtStr)
        : null;
    return TokenPair(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 15)),
    );
  }
}
